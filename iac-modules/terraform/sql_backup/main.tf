#------------------------------------------------------------------------------------------------------------------------------
# General configuration
#------------------------------------------------------------------------------------------------------------------------------
locals {
  db_backup_container_name = "database-backups"
  k8s_cron_job_name        = "export-db-bacpac"
}

resource "null_resource" "force_recreate" {
  triggers = {
    always_recreate = timestamp()
  }
}

#--------------------------------------------------------------------------------------------------------------------------------
# Tenant DB Backup Storage Container
#--------------------------------------------------------------------------------------------------------------------------------
resource "azurerm_storage_container" "database_backups" {
  name = local.db_backup_container_name

  storage_account_id = var.storage_account_id

  lifecycle {
    prevent_destroy = true
  }

}

#------------------------------------------------------------------------------------------------------------------------------
# Kubernetes Resources
#------------------------------------------------------------------------------------------------------------------------------

resource "kubernetes_manifest" "database_secrets" {

  manifest = yamldecode(templatefile("../../../../../assets/kubernetes/database/secrets.yaml",
    {
      secret_name    = "${local.k8s_cron_job_name}-secrets"
      namespace      = var.aks_namespace_name
      storage_key    = base64encode(var.storage_account_primary_access_key)
      admin_password = base64encode(var.sql_admin_password)
  }))

  # Do NOT change this setting.  This is required so "terraform destroy" works correctly.  
  # The kubernetes provider API has a bug in it that causes the provider to not be able to
  # delete the CronJob resource.  This setting tells Terraform to ignore changes to the manifest.
  # Error says it cannot unmashall the manifest due to custom resource definition (CRD).
  lifecycle {
    ignore_changes = [
      manifest
    ]
  }

  depends_on = [
    null_resource.force_recreate
  ]
}

resource "kubernetes_config_map" "database_cleanup" {
  metadata {
    name      = "sql-db-cleanup"
    namespace = var.aks_namespace_name
  }

  data = {
    "sql_db_clean_sync_objects.sql" = file("../../../../../assets/kubernetes/database/sql_db_clean_sync_objects.sql")
  }
}

resource "kubernetes_manifest" "export_bacpac" {

  manifest = yamldecode(templatefile("../../../../../assets/kubernetes/database/export_db_bacpac.yaml",
    {
      resource_group    = var.resource_group_name
      name              = local.k8s_cron_job_name
      agentpool         = "application"
      namespace         = var.aks_namespace_name
      schedule          = var.sql_cron_job_schedule
      db_name           = var.sql_database_name
      server_name       = var.sql_server_name
      storage_account   = var.storage_account_name
      storage_container = azurerm_storage_container.database_backups.name
      admin_user        = var.sql_admin_user
      identity_id       = var.aks_identity_id
      secrets_name      = "${local.k8s_cron_job_name}-secrets"
      volume_name       = kubernetes_config_map.database_cleanup.metadata[0].name
    })
  )

  # Do NOT change this setting.  This is required so "terraform destroy" works correctly.  
  # The kubernetes provider API has a bug in it that causes the provider to not be able to
  # delete the CronJob resource.  This setting tells Terraform to ignore changes to the manifest.
  # Error says it cannot unmashall the manifest due to custom resource definition (CRD).
  lifecycle {
    ignore_changes = [
      manifest
    ]
  }

  depends_on = [
    azurerm_storage_container.database_backups,
    azurerm_role_assignment.aks_sql_db,
    azurerm_role_assignment.aks_storage_account_blob_data_contributor,
    azurerm_role_assignment.aks_storage_account_contributor,
    null_resource.force_recreate,
    kubernetes_config_map.database_cleanup,
    kubernetes_manifest.database_secrets
  ]
}

#------------------------------------------------------------------------------------------------------------------------------
# Role Assignments
#------------------------------------------------------------------------------------------------------------------------------

resource "azurerm_role_assignment" "aks_sql_db" {
  principal_id         = var.aks_identity_id
  scope                = var.sql_server_id
  role_definition_name = "SQL Server Contributor"
}

resource "azurerm_role_assignment" "aks_storage_account_blob_data_contributor" {
  principal_id         = var.aks_identity_id
  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
}

resource "azurerm_role_assignment" "aks_storage_account_contributor" {
  principal_id         = var.aks_identity_id
  scope                = var.storage_account_id
  role_definition_name = "Contributor"
}