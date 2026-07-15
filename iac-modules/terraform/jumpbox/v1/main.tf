#--------------------------------------------------------------------------------------------------------------------------------
# Jumpbox module — small Linux VM inside a customer VNet used to reach
# private-networked services (Foundry, Cosmos, Search, Storage, etc.) from
# an operator laptop. Also handy for validating DNS resolution and
# private-endpoint connectivity end-to-end.
#
# Auth model:
#   - SSH key only (password auth disabled).
#   - Optional Entra ID SSH login via the AADSSHLoginForLinux extension so
#     operators sign in with their AAD identity + `az ssh vm`.
#   - SystemAssigned + UserAssigned MI, so scripts on the VM can call
#     Azure APIs (e.g. `az login --identity`) without secrets.
#
# Networking:
#   - Public IP (Standard, static) is OPTIONAL — enable it only when you
#     need to reach the VM from outside Azure. When enabled, an NSG is
#     attached to the NIC and inbound SSH is restricted to the caller-
#     supplied `allowed_source_ip_prefixes` list. When disabled, no NSG
#     is attached; access is via `az ssh vm` over the VNet or via a
#     peered network (Bastion/VPN/ER — none of which this module owns).
#--------------------------------------------------------------------------------------------------------------------------------

locals {
  name_prefix = "${var.base_name}-${var.environment}-jumpbox"

  vm_name      = "vm-${local.name_prefix}"
  nic_name     = "nic-${local.name_prefix}"
  pip_name     = "pip-${local.name_prefix}"
  nsg_name     = "nsg-${local.name_prefix}"
  uami_name    = "uami-${local.name_prefix}"
  os_disk_name = "osdisk-${local.name_prefix}"
}

# -----------------------------------------------------------------------------
# User-assigned managed identity — used for scripts on the VM that need to
# call Azure Resource Manager. System-assigned MI is also attached below;
# use whichever fits the caller's RBAC model.
# -----------------------------------------------------------------------------
resource "azurerm_user_assigned_identity" "this" {
  name                = local.uami_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# -----------------------------------------------------------------------------
# Optional public IP (Standard SKU, static). Only created when
# `enable_public_ip = true`. Standard SKU is required for zone-redundant
# behavior and modern outbound patterns.
# -----------------------------------------------------------------------------
resource "azurerm_public_ip" "this" {
  count = var.enable_public_ip ? 1 : 0

  name                = local.pip_name
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = var.tags
}

# -----------------------------------------------------------------------------
# NSG — created only when the VM has a public IP, since a VNet-only jumpbox
# doesn't need Internet-facing rules. Rules:
#   - Allow SSH (22) from the caller's allowlist.
#   - Deny all other inbound (default behavior of NSG, made explicit).
# Outbound is left at NSG default (allow all) so cloud-init / patching /
# `az login` work.
# -----------------------------------------------------------------------------
resource "azurerm_network_security_group" "this" {
  count = var.enable_public_ip ? 1 : 0

  name                = local.nsg_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  security_rule {
    name                       = "Allow-SSH-Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = var.allowed_source_ip_prefixes
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "this" {
  count = var.enable_public_ip ? 1 : 0

  network_interface_id      = azurerm_network_interface.this.id
  network_security_group_id = azurerm_network_security_group.this[0].id
}

# -----------------------------------------------------------------------------
# NIC — attaches to the caller-supplied subnet and optionally to the public
# IP created above.
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
    public_ip_address_id          = var.enable_public_ip ? azurerm_public_ip.this[0].id : null
  }
}

# -----------------------------------------------------------------------------
# Linux VM. Ubuntu 22.04 LTS by default; small size (Standard_B2s) is
# plenty for a jumpbox.
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
}

# -----------------------------------------------------------------------------
# Entra ID SSH login extension (optional). Enabled by default so operators
# can `az ssh vm --name <vm>` with their AAD identity, no local SSH key
# management on the operator side.
#
# Requires the operator to have `Virtual Machine Administrator Login` or
# `Virtual Machine User Login` role on the VM — grant via
# `entra_admin_object_ids` (Administrator Login).
# -----------------------------------------------------------------------------
resource "azurerm_virtual_machine_extension" "aad_ssh" {
  count = var.enable_entra_ssh_login ? 1 : 0

  name                       = "AADSSHLoginForLinux"
  virtual_machine_id         = azurerm_linux_virtual_machine.this.id
  publisher                  = "Microsoft.Azure.ActiveDirectory"
  type                       = "AADSSHLoginForLinux"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
}

resource "azurerm_role_assignment" "entra_ssh_admin" {
  for_each = var.enable_entra_ssh_login ? toset(var.entra_admin_object_ids) : toset([])

  scope                = azurerm_linux_virtual_machine.this.id
  role_definition_name = "Virtual Machine Administrator Login"
  principal_id         = each.value
}
