#------------------------------------------------------------------------------------------------------------------------------
# Private DNS Zones Configuration (Global)
#------------------------------------------------------------------------------------------------------------------------------

module "dns_zone_blob" {
  source = "../private_dns_zone"

  resource_group_name  = var.resource_group_name
  dns_zone             = var.dns_zone_blob
  virtual_network_id   = var.vnet_id
  virtual_network_name = var.vnet_name

  tags = var.tags
}

module "dns_zone_file" {
  source = "../private_dns_zone"

  resource_group_name  = var.resource_group_name
  dns_zone             = var.dns_zone_file
  virtual_network_id   = var.vnet_id
  virtual_network_name = var.vnet_name

  tags = var.tags
}

module "dns_zone_table" {
  source = "../private_dns_zone"

  resource_group_name  = var.resource_group_name
  dns_zone             = var.dns_zone_table
  virtual_network_id   = var.vnet_id
  virtual_network_name = var.vnet_name

  tags = var.tags
}

module "dns_zone_queue" {
  source = "../private_dns_zone"

  resource_group_name  = var.resource_group_name
  dns_zone             = var.dns_zone_queue
  virtual_network_id   = var.vnet_id
  virtual_network_name = var.vnet_name

  tags = var.tags
}

module "dns_zone_web" {
  source = "../private_dns_zone"

  resource_group_name  = var.resource_group_name
  dns_zone             = var.dns_zone_web
  virtual_network_id   = var.vnet_id
  virtual_network_name = var.vnet_name

  tags = var.tags
}

module "dns_zone_dfs" {
  source = "../private_dns_zone"

  resource_group_name  = var.resource_group_name
  dns_zone             = var.dns_zone_dfs
  virtual_network_id   = var.vnet_id
  virtual_network_name = var.vnet_name

  tags = var.tags
}

module "dns_zone_afs" {
  source = "../private_dns_zone"

  resource_group_name  = var.resource_group_name
  dns_zone             = var.dns_zone_afs
  virtual_network_id   = var.vnet_id
  virtual_network_name = var.vnet_name

  tags = var.tags
}

module "dns_zone_acr" {
  source = "../private_dns_zone"

  resource_group_name  = var.resource_group_name
  dns_zone             = var.dns_zone_acr
  virtual_network_id   = var.vnet_id
  virtual_network_name = var.vnet_name

  tags = var.tags
}

module "dns_zone_acr_data" {
  source = "../private_dns_zone"

  resource_group_name  = var.resource_group_name
  dns_zone             = var.dns_zone_acr_data
  virtual_network_id   = var.vnet_id
  virtual_network_name = var.vnet_name

  tags = var.tags
}

module "dns_zone_aks" {
  source = "../private_dns_zone"

  resource_group_name  = var.resource_group_name
  dns_zone             = var.dns_zone_aks
  virtual_network_id   = var.vnet_id
  virtual_network_name = var.vnet_name

  tags = var.tags
}

module "dns_zone_kv" {
  source = "../private_dns_zone"

  resource_group_name  = var.resource_group_name
  dns_zone             = var.dns_zone_kv
  virtual_network_id   = var.vnet_id
  virtual_network_name = var.vnet_name

  tags = var.tags
}

module "dns_zone_ai_services_cognitive_services" {
  source = "../private_dns_zone"

  resource_group_name  = var.resource_group_name
  dns_zone             = var.dns_zone_ai_services_cognitive_services
  virtual_network_id   = var.vnet_id
  virtual_network_name = var.vnet_name

  tags = var.tags
}

module "dns_zone_ai_services_open_ai" {
  source = "../private_dns_zone"

  resource_group_name  = var.resource_group_name
  dns_zone             = var.dns_zone_ai_services_open_ai
  virtual_network_id   = var.vnet_id
  virtual_network_name = var.vnet_name

  tags = var.tags
}

module "dns_zone_ml" {
  source = "../private_dns_zone"

  resource_group_name  = var.resource_group_name
  dns_zone             = var.dns_zone_ml
  virtual_network_id   = var.vnet_id
  virtual_network_name = var.vnet_name

  tags = var.tags
}

module "dns_zone_ml_notebooks" {
  source = "../private_dns_zone"

  resource_group_name  = var.resource_group_name
  dns_zone             = var.dns_zone_ml_notebooks
  virtual_network_id   = var.vnet_id
  virtual_network_name = var.vnet_name

  tags = var.tags
}

module "dns_zone_azure_search" {
  source = "../private_dns_zone"

  resource_group_name  = var.resource_group_name
  dns_zone             = var.dns_zone_azure_search
  virtual_network_id   = var.vnet_id
  virtual_network_name = var.vnet_name

  tags = var.tags
}

module "dns_zone_azure_sql_database" {
  source = "../private_dns_zone"

  resource_group_name  = var.resource_group_name
  dns_zone             = var.dns_zone_azure_sql_database
  virtual_network_id   = var.vnet_id
  virtual_network_name = var.vnet_name

  tags = var.tags
}

module "dns_zone_azure_monitor" {
  source = "../private_dns_zone"

  resource_group_name  = var.resource_group_name
  dns_zone             = var.dns_zone_azure_monitor
  virtual_network_id   = var.vnet_id
  virtual_network_name = var.vnet_name

  tags = var.tags
}

module "dns_zone_oms_opinsights" {
  source = "../private_dns_zone"

  resource_group_name  = var.resource_group_name
  dns_zone             = var.dns_zone_oms_opinsights
  virtual_network_id   = var.vnet_id
  virtual_network_name = var.vnet_name

  tags = var.tags
}

module "dns_zone_ods_opinsights" {
  source = "../private_dns_zone"

  resource_group_name  = var.resource_group_name
  dns_zone             = var.dns_zone_ods_opinsights
  virtual_network_id   = var.vnet_id
  virtual_network_name = var.vnet_name

  tags = var.tags
}

module "dns_zone_agentsvc_automation" {
  source = "../private_dns_zone"

  resource_group_name  = var.resource_group_name
  dns_zone             = var.dns_zone_agentsvc_automation
  virtual_network_id   = var.vnet_id
  virtual_network_name = var.vnet_name

  tags = var.tags
}

module "dns_zone_prometheus" {
  source = "../private_dns_zone"

  resource_group_name  = var.resource_group_name
  dns_zone             = var.dns_zone_prometheus
  virtual_network_id   = var.vnet_id
  virtual_network_name = var.vnet_name

  tags = var.tags
}

module "dns_zone_grafana" {
  source = "../private_dns_zone"

  resource_group_name  = var.resource_group_name
  dns_zone             = var.dns_zone_grafana
  virtual_network_id   = var.vnet_id
  virtual_network_name = var.vnet_name

  tags = var.tags
}

module "dns_zone_web_apps" {
  source = "../private_dns_zone"

  resource_group_name  = var.resource_group_name
  dns_zone             = var.dns_zone_web_apps
  virtual_network_id   = var.vnet_id
  virtual_network_name = var.vnet_name

  tags = var.tags
}

module "dns_zone_web_apps_scm" {
  source = "../private_dns_zone"

  resource_group_name  = var.resource_group_name
  dns_zone             = var.dns_zone_web_apps_scm
  virtual_network_id   = var.vnet_id
  virtual_network_name = var.vnet_name

  tags = var.tags
}

module "dns_zone_azure_postgresql_database" {
  source = "../private_dns_zone"

  resource_group_name  = var.resource_group_name
  dns_zone             = var.dns_zone_azure_postgresql_database
  virtual_network_id   = var.vnet_id
  virtual_network_name = var.vnet_name

  tags = var.tags
}