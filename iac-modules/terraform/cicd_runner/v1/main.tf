#--------------------------------------------------------------------------------------------------------------------------------
# CI/CD Runner module — self-hosted GitHub Actions runner deployed as a
# Linux VM inside a private VNet. Purpose: give GitHub Actions workflows
# a foothold on the private plane so `terraform apply` can reach services
# with `public_network_access_enabled = false` (Foundry, Cosmos, AI Search,
# Storage, etc.).
#
# Design decisions:
#   - No public IP. Egress is via the VNet's NAT gateway (caller wires
#     that separately at the subnet level).
#   - SystemAssigned + UserAssigned MI attached to the VM. The UAMI is NOT
#     used for CI workflow authentication (workflows use OIDC federation on
#     an App Registration owned by the caller — see the ai-foundry README).
#     The UAMI is provisioned for potential future VM-local use via
#     `az login --identity`. Callers who DO want to use it should attach a
#     federated credential + role assignments in the caller's stack.
#   - GitHub runner registration is done by cloud-init using a fine-grained
#     PAT (`github_pat`) that mints a fresh registration token at boot.
#     The PAT stays in the VM's user-data blob (encrypted at rest by SSE)
#     — for a production setup, replace with a Key Vault fetch via MI.
#   - NSG denies all inbound (runners never accept inbound connections)
#     and leaves outbound at NSG defaults (allow all) so the runner can
#     reach github.com, ghcr.io, and Azure ARM.
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
# User-assigned managed identity. The caller is expected to attach a GitHub
# Actions federated identity credential to this UAMI so workflows can
# `azure/login@v2` with `client-id = this.client_id`.
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
# Linux VM. Ubuntu 22.04 LTS is the standard base for GitHub-hosted runners,
# so tools / tests behave the same as on `ubuntu-latest`.
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

  # SSH key is required by azurerm_linux_virtual_machine even when we
  # never intend to SSH in. Callers use `az ssh vm` via the jumpbox +
  # AAD SSH login extension instead. This key is only a break-glass path.
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
