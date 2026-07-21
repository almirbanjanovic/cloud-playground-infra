variable "tags" {
  description = "Tags applied to the private endpoint."
  type        = map(string)
}

# ----------------------------------------------------------------------------
# LEGACY inputs — accepted but ignored by this module. The current version
# derives the PE name from `resource_name` and lets `private_dns_zone_group`
# auto-create the A record inside the zone. `base_name`, `environment`,
# `private_dns_a_record_name`, and `private_dns_resource_group_name` are
# kept in the signature so existing callers (`storage account/v1`,
# `cognitive_account/v1`, `cosmos_db/v1`, `ai_search/v1`) don't have to
# change. Drop these when you clean up those callers.
# ----------------------------------------------------------------------------
variable "base_name" {
  description = "LEGACY / ignored. See file header."
  type        = string
}

variable "environment" {
  description = "LEGACY / ignored. See file header."
  type        = string
}

variable "resource_name" {
  description = "Short name of the Azure resource the PE connects to. Used as the PE name (`pep-<resource_name>`) and its private-service-connection name."
  type        = string
}

variable "resource_id" {
  description = "Resource ID of the Azure resource this PE connects to."
  type        = string
}

variable "subresource_names" {
  description = "Subresource group IDs for the PE connection (e.g. `[\"blob\"]`, `[\"Sql\"]`, `[\"account\"]`, `[\"searchService\"]`). One PE per subresource group."
  type        = list(string)
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "location" {
  description = "Azure location"
  type        = string
}

variable "is_manual_connection" {
  description = "If true, the PE connection requires manual approval on the target side (used for cross-tenant/cross-subscription scenarios). Default false."
  type        = bool
  default     = false
}

variable "private_dns_zone_ids" {
  description = "IDs of the private DNS zones to link into the PE's `private_dns_zone_group`. The zone group auto-creates the A record for `<resource_name>` in each zone."
  type        = list(string)
}

variable "private_dns_a_record_name" {
  description = "LEGACY / ignored. A records are created automatically by the `private_dns_zone_group` above."
  type        = string
}

variable "private_dns_resource_group_name" {
  description = "LEGACY / ignored. A records are created automatically by the `private_dns_zone_group` above."
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet where the PE NIC is placed."
  type        = string
}