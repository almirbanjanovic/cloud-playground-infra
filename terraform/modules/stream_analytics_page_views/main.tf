locals {
  stream_analytics_job_name = "sa-${var.base_name}-${var.environment}-${var.location}"
  path_pattern_lower_prefix = "resourceId=/"
  path_pattern_upper        = upper("SUBSCRIPTIONS/${data.azurerm_client_config.current.subscription_id}/RESOURCEGROUPS/${var.resource_group_name}/PROVIDERS/MICROSOFT.INSIGHTS/COMPONENTS/${var.app_insights_name}/")
  path_pattern_lower_suffix = "y={datetime:yyyy}/m={datetime:MM}/d={datetime:dd}/h={datetime:HH}/m={datetime:mm}"
  path_pattern              = "${local.path_pattern_lower_prefix}${local.path_pattern_upper}${local.path_pattern_lower_suffix}"
}

// Get current Azure Client Configuration
data "azurerm_client_config" "current" {}

#--------------------------------------------------------------------------------------------------------------------------------
# Storage Acccount
#--------------------------------------------------------------------------------------------------------------------------------
module "storage_account" {
  source                           = "../storage_account"
  base_name                        = var.base_name
  environment                      = var.environment
  location                         = var.location
  resource_group_name              = var.resource_group_name
  suffix                           = var.suffix
  storage_account_tier             = var.storage_account_tier
  storage_account_replication_type = var.storage_account_replication_type
  min_tls_version                  = var.storage_account_min_tls_version
  enable_https_traffic_only        = var.storage_account_enable_https_traffic_only

  subnet_id                  = var.storage_account_subnet_id
  blob_private_dns_zone_ids  = var.blob_private_dns_zone_ids
  table_private_dns_zone_ids = var.table_private_dns_zone_ids
  queue_private_dns_zone_ids = var.queue_private_dns_zone_ids
  file_private_dns_zone_ids  = var.file_private_dns_zone_ids
  web_private_dns_zone_ids   = var.web_private_dns_zone_ids
  dfs_private_dns_zone_ids   = var.dfs_private_dns_zone_ids

  tags = var.tags
}

#------------------------------------------------------------------------------------------------------------------------------
# Diagnostic Settings
#------------------------------------------------------------------------------------------------------------------------------

resource "azurerm_monitor_diagnostic_setting" "app_insights_page_views" {
  name               = "${var.app_insights_name}-page-views-diag"
  target_resource_id = var.app_insights_id
  storage_account_id = module.storage_account.id

  enabled_log {
    category = "AppPageViews"
  }
}

#--------------------------------------------------------------------------------------------------------------------------------
# Page Views Log Analytics Data Export Rule - This accomplishes same task as above Diagnostic Setting, but introduces lag.
#--------------------------------------------------------------------------------------------------------------------------------
# resource "azurerm_log_analytics_data_export_rule" "page_views" {
#   name                    = "${var.log_analytics_workspace_name}-page-views-export"
#   resource_group_name     = var.resource_group_name
#   workspace_resource_id   = var.log_analytics_workspace_id
#   destination_resource_id = module.storage_account.id 
#   table_names             = ["AppPageViews"]
#   enabled                 = true
# }

#--------------------------------------------------------------------------------------------------------------------------------
# Stream Analytics Job with Virtual Network Integration
#--------------------------------------------------------------------------------------------------------------------------------

# The latest API provider version for Stream Analytics Jobs is 2021-10-01-preview, while Virtual Network integration was released June 2023.
# Must use AzApi provider instead of AzureRM for two reasons:
# 1. The Virtual Network feature is not available in the AzureRM provider.
# 2. The AzureRM provider only supports 'ConnectionString' authentication mode and not 'Msi' (managed identity), 
#    which is required for a Stream Analytics job to work with Virtual Network integration and function with
#    trusted access based on a managed identity.  For more information see:
#    https://learn.microsoft.com/en-us/azure/storage/common/storage-network-security?tabs=azure-portal#trusted-access-based-on-a-managed-identity
resource "azapi_resource" "this" {
  type      = "Microsoft.StreamAnalytics/streamingJobs@2021-10-01-preview"
  name      = local.stream_analytics_job_name
  parent_id = var.resource_group_id
  location  = var.location

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags

  body = {
    properties = {
      compatibilityLevel   = "1.2"
      contentStoragePolicy = "SystemAccount"

      jobStorageAccount = {
        accountName        = module.storage_account.name
        authenticationMode = var.stream_analytics_authentication_mode
      }

      sku = {
        capacity = var.stream_analytics_sku_capacity
        name     = var.stream_analytics_sku_name
      }

      transformation = null
    }

    sku = {
      capacity = var.stream_analytics_sku_capacity
      name     = var.stream_analytics_sku_name
    }
  }
}

resource "azurerm_role_assignment" "stream_analytics_storage_table_data_contributor" {
  principal_id         = azapi_resource.this.identity[0].principal_id
  role_definition_name = "Storage Table Data Contributor"
  scope                = module.storage_account.id
}

resource "azurerm_role_assignment" "stream_analytics_storage_blob_data_contributor" {
  principal_id         = azapi_resource.this.identity[0].principal_id
  role_definition_name = "Storage Blob Data Contributor"
  scope                = module.storage_account.id
}

# Now update the Stream Analytics Job with the correct transformation.
resource "azapi_update_resource" "this" {
  type        = "Microsoft.StreamAnalytics/streamingJobs@2021-10-01-preview"
  resource_id = azapi_resource.this.id
  body = {
    properties = {

      transformation = {
        name = "main"
        properties = {
          query = templatefile("../../../../../assets/scripts/page_views_query.sql", {
            input_alias  = var.stream_analytics_input_alias,
            output_alias = var.stream_analytics_output_alias,
          })
          streamingUnits = var.stream_analytics_sku_capacity
        }
      }
    }
  }

  depends_on = [
    azapi_resource.this,
    azurerm_role_assignment.stream_analytics_storage_blob_data_contributor,
    azurerm_role_assignment.stream_analytics_storage_table_data_contributor
  ]
}

resource "azapi_resource_action" "patch_subnet" {
  type        = "Microsoft.StreamAnalytics/streamingJobs@2021-10-01-preview"
  resource_id = azapi_resource.this.id
  method      = "PATCH"
  body = {
    properties = {
      subnetResourceId = var.stream_analytics_subnet_id # IDE may throw an error here, but 'subnetResourceId' is correct and works
    }
  }

  depends_on = [
    azapi_resource.this,
    azurerm_role_assignment.stream_analytics_storage_blob_data_contributor,
    azurerm_role_assignment.stream_analytics_storage_table_data_contributor,
    azapi_update_resource.this
  ]
}

resource "azapi_resource" "stream_analytics_input_blob" {
  type      = "Microsoft.StreamAnalytics/streamingjobs/inputs@2021-10-01-preview"
  name      = var.stream_analytics_input_alias
  parent_id = azapi_resource.this.id

  body = {
    properties = {

      type = "Stream"

      compression = {
        type = "None"
      }

      serialization = {
        properties = {
          encoding = "UTF8"
        }
        type = "Json"
      }

      datasource = {
        type = "Microsoft.Storage/Blob"
        properties = {
          authenticationMode = var.stream_analytics_authentication_mode
          container          = var.stream_analytics_datasource_storage_container_name
          dateFormat         = var.stream_analytics_datasource_date_format
          pathPattern        = local.path_pattern
          storageAccounts = [
            {
              accountKey         = module.storage_account.primary_access_key
              accountName        = module.storage_account.name
              authenticationMode = var.stream_analytics_authentication_mode
            }
          ]
          timeFormat = "HH"
        }
      }
    }
  }

  depends_on = [
    azapi_resource_action.patch_subnet
  ]
}

resource "azurerm_stream_analytics_output_mssql" "this" {
  name                      = var.stream_analytics_output_alias
  stream_analytics_job_name = local.stream_analytics_job_name
  resource_group_name       = var.resource_group_name

  server   = var.sql_server_name
  user     = var.sql_admin_user
  password = var.sql_admin_password
  database = var.sql_db_name
  table    = var.sql_db_table_name

  depends_on = [
    azapi_resource_action.patch_subnet
  ]
}

resource "azurerm_stream_analytics_job_schedule" "this" {
  stream_analytics_job_id = azapi_resource.this.id
  start_mode              = "CustomTime"
  start_time              = var.stream_analytics_job_start_time

  depends_on = [
    azapi_resource.this,
    azapi_resource_action.patch_subnet,
    azapi_update_resource.this,
    azapi_resource.stream_analytics_input_blob,
    azurerm_stream_analytics_output_mssql.this,
    azurerm_monitor_diagnostic_setting.app_insights_page_views
  ]
}


# This is not available in AzureRM provider 4.11.0, must upgrade to at least 4.17.0
# resource "azurerm_stream_analytics_stream_input_blob" "this" {
#   name                      = var.stream_analytics_input_alias
#   stream_analytics_job_name = local.stream_analytics_job_name
#   resource_group_name       = var.resource_group_name
#   storage_account_name      = var.storage_account_name
#   storage_account_key       = var.storage_account_primary_access_key
#   storage_container_name    = var.stream_analytics_datasource_storage_container_name
#   authentication_mode       = var.stream_analytics_authentication_mode 

#   path_pattern = "resourceId=/SUBSCRIPTIONS/{subscriptionId}/RESOURCEGROUPS/{resourceGroupName}/PROVIDERS/MICROSOFT.INSIGHTS/COMPONENTS/{componentName}/y={year}/m={month}/d={day}/h={hour}/m={minute}/"
#   date_format  = "yyyy/MM/dd"
#   time_format  = "HH"

#   serialization {
#     type     = "Json"
#     encoding = "UTF8"
#   }

#   depends_on = [ 
#     azapi_resource_action.patch_subnet
#    ]
# }