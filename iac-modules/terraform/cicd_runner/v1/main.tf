#--------------------------------------------------------------------------------------------------------------------------------
# CI/CD Runner module — self-hosted GitHub Actions runner deployed as a
# Linux VM inside a private VNet. Purpose: give GitHub Actions workflows
# a foothold on the private plane so `terraform apply` can reach services
# with `public_network_access_enabled = false` (Foundry, Cosmos, AI Search,
# Storage, etc.).
#
# Design decisions:
#   - No public IP. Egress is via a NAT gateway that the CALLER wires to
#     the runner subnet (this module does not create one). Without a NAT
#     gateway the runner cannot reach github.com / ghcr.io / Azure ARM.
#   - SystemAssigned + UserAssigned managed identity (UAMI) attached to the
#     VM. The UAMI is NOT used for CI workflow authentication by default —
#     see the UAMI resource comment below for the two supported patterns.
#   - GitHub runner registration is done by cloud-init using a fine-grained
#     PAT (`github_pat`) that mints a fresh registration token at boot. The
#     PAT is passed through Terraform state and rendered into the VM's
#     `custom_data` (encrypted at rest by SSE). For a production setup,
#     replace with a Key Vault fetch via MI.
#   - NSG denies ALL inbound at priority 4000 (runners never accept inbound
#     connections). There is no SSH path to this VM — not from your laptop,
#     not from the jumpbox. The `admin_ssh_public_key` input is required by
#     `azurerm_linux_virtual_machine` when password auth is off; it is
#     installed but unreachable. Runner diagnostics are done via
#     `az vm run-command invoke` (control plane, no network path required).
#   - Ubuntu 22.04 LTS base image so scripts targeting `ubuntu-latest`
#     generally work, but this VM does NOT come with the extensive GitHub-
#     hosted runner tool cache — install extra tools via cloud-init or
#     workflow steps.
#--------------------------------------------------------------------------------------------------------------------------------

locals {
  name_prefix = "${var.base_name}-${var.environment}-runner"

  vm_name      = "vm-${local.name_prefix}"
  nic_name     = "nic-${local.name_prefix}"
  nsg_name     = "nsg-${local.name_prefix}"
  uami_name    = "uami-${local.name_prefix}"
  os_disk_name = "osdisk-${local.name_prefix}"

  cloud_init = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    admin_username = var.admin_username
    github_org     = var.github_org
    github_repo    = var.github_repo
    github_pat     = var.github_pat
    runner_labels  = join(",", var.runner_labels)
    runner_version = var.runner_version
    runner_group   = var.runner_group
  })
}

# -----------------------------------------------------------------------------
# User-assigned managed identity (UAMI). Created + attached to the VM as an
# optional identity slot. This module does NOT create a federated credential
# or grant role assignments on it — that's a caller decision.
#
# Two usage patterns:
#   1. (Default) Leave it dormant. Workflows authenticate as a separately-
#      created App Registration via OIDC; the UAMI is just an attachment
#      point the VM can use for VM-local `az login --identity` if needed
#      later. This is how the ai-foundry stack uses the module (see
#      ai-foundry README > Auth model).
#   2. Attach a GitHub Actions federated identity credential + role
#      assignments to this UAMI in the caller's stack. Workflows can then
#      `azure/login@v2` with `client-id = <this UAMI's client_id>`. Use this
#      when you want a per-runner identity instead of a shared App Reg.
# -----------------------------------------------------------------------------
resource "azurerm_user_assigned_identity" "this" {
  name                = local.uami_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# -----------------------------------------------------------------------------
# NSG — runners are outbound-only. Explicit deny of inbound is the default,
# but making it explicit here avoids any confusion when reviewing the ARM
# NSG resource later.
# -----------------------------------------------------------------------------
resource "azurerm_network_security_group" "this" {
  name                = local.nsg_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  security_rule {
    name                       = "Deny-All-Inbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "this" {
  network_interface_id      = azurerm_network_interface.this.id
  network_security_group_id = azurerm_network_security_group.this.id
}

# -----------------------------------------------------------------------------
# NIC — no public IP. Outbound Internet from the VM is via the NAT gateway
# the caller attaches to the subnet.
# -----------------------------------------------------------------------------
resource "azurerm_network_interface" "this" {
  name                = local.nic_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "primary"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}

# -----------------------------------------------------------------------------
# Linux VM. Ubuntu 22.04 LTS base image; scripts targeting `ubuntu-latest`
# generally work but the extensive GitHub-hosted runner tool cache is NOT
# preinstalled — install extras via cloud-init or workflow steps.
# -----------------------------------------------------------------------------
resource "azurerm_linux_virtual_machine" "this" {
  name                = local.vm_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  size                            = var.vm_size
  admin_username                  = var.admin_username
  disable_password_authentication = true

  network_interface_ids = [azurerm_network_interface.this.id]

  # SSH key is required by azurerm_linux_virtual_machine when password auth
  # is disabled, so we install one. It is NOT actually usable — the runner
  # has no public IP and the NSG (see above) denies all inbound at priority
  # 4000, blocking SSH even from inside the VNet. Runner diagnostics go
  # through `az vm run-command invoke` (Azure control plane).
  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  os_disk {
    name                 = local.os_disk_name
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  identity {
    type         = "SystemAssigned, UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.this.id]
  }

  # Cloud-init runs on first boot. Recreating the VM re-runs it, which
  # re-registers the runner (config.sh --replace handles the collision).
  custom_data = base64encode(local.cloud_init)
}
