variable "tags" {
  type = map(string)
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "base_name" {
  description = "Base name"
  type        = string
}

variable "environment" {
  description = "Environment (e.g., dev, prod, etc.)"
  type        = string
}

variable "location" {
  description = "Azure location"
  type        = string
}

variable "subnet_id" {
  description = "Subnet id"
  type        = string
}

variable "private_dns_zone_ids" {
  description = "Private DNS zone ids"
  type        = list(string)
}

variable "postgre_sql_administrator_login" {
  description = "PostgreSQL administrator login"
  type        = string
}

variable "postgre_sql_administrator_password" {
  description = "PostgreSQL administrator password"
  type        = string
}

variable "key_vault_id" {
  description = "Key Vault ID"
  type        = string
}

variable "ca_certificate_name" {
  description = "Name of the DigiCert wildcard certificate uploaded to SafeTower environment Key Vault."
  type        = string
}