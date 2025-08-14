variable "secrets" {
  description = "Map of secrets"
  type        = map(string)
}

variable "key_vault_id" {
  description = "ID of the key vault"
  type        = string
}