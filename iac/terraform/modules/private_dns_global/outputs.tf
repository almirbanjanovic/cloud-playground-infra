output "dns_zone_ids" {
  description = "The IDs of the Private DNS Zones"
  value = {
    acr                       = module.dns_zone_acr.id
    acr_data                  = module.dns_zone_acr_data.id
    agentsvc_automation       = module.dns_zone_agentsvc_automation.id
    afs                       = module.dns_zone_afs.id
    ai_services_cognitive     = module.dns_zone_ai_services_cognitive_services.id
    ai_services_openai        = module.dns_zone_ai_services_open_ai.id
    aks                       = module.dns_zone_aks.id
    azure_monitor             = module.dns_zone_azure_monitor.id
    azure_search              = module.dns_zone_azure_search.id
    azure_sql_database        = module.dns_zone_azure_sql_database.id
    azure_postgresql_database = module.dns_zone_azure_postgresql_database.id
    blob                      = module.dns_zone_blob.id
    dfs                       = module.dns_zone_dfs.id
    file                      = module.dns_zone_file.id
    grafana                   = module.dns_zone_grafana.id
    key_vault                 = module.dns_zone_kv.id
    machine_learning          = module.dns_zone_ml.id
    ml_notebooks              = module.dns_zone_ml_notebooks.id
    oms_opinsights            = module.dns_zone_oms_opinsights.id
    ods_opinsights            = module.dns_zone_ods_opinsights.id
    prometheus                = module.dns_zone_prometheus.id
    queue                     = module.dns_zone_queue.id
    table                     = module.dns_zone_table.id
    web                       = module.dns_zone_web.id
    web_apps                  = module.dns_zone_web_apps.id
    web_apps_scm              = module.dns_zone_web_apps_scm.id
  }
}

output "dns_zone_names" {
  description = "The names of the Private DNS Zones"
  value = {
    acr                       = module.dns_zone_acr.name
    acr_data                  = module.dns_zone_acr_data.name
    agentsvc_automation       = module.dns_zone_agentsvc_automation.name
    afs                       = module.dns_zone_afs.name
    ai_services_cognitive     = module.dns_zone_ai_services_cognitive_services.name
    ai_services_openai        = module.dns_zone_ai_services_open_ai.name
    aks                       = module.dns_zone_aks.name
    azure_monitor             = module.dns_zone_azure_monitor.name
    azure_search              = module.dns_zone_azure_search.name
    azure_sql_database        = module.dns_zone_azure_sql_database.name
    azure_postgresql_database = module.dns_zone_azure_postgresql_database.name
    blob                      = module.dns_zone_blob.name
    dfs                       = module.dns_zone_dfs.name
    file                      = module.dns_zone_file.name
    grafana                   = module.dns_zone_grafana.name
    key_vault                 = module.dns_zone_kv.name
    machine_learning          = module.dns_zone_ml.name
    ml_notebooks              = module.dns_zone_ml_notebooks.name
    oms_opinsights            = module.dns_zone_oms_opinsights.name
    ods_opinsights            = module.dns_zone_ods_opinsights.name
    prometheus                = module.dns_zone_prometheus.name
    queue                     = module.dns_zone_queue.name
    table                     = module.dns_zone_table.name
    web                       = module.dns_zone_web.name
    web_apps                  = module.dns_zone_web_apps.name
    web_apps_scm              = module.dns_zone_web_apps_scm.name
  }
}
