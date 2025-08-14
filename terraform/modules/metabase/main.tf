#------------------------------------------------------------------------------------------------------------------------------
# General configuration
#------------------------------------------------------------------------------------------------------------------------------
locals {
  kubernetes_namespace                = "metabase"
  kubernetes_database_secrets_name    = "metabase-database-secrets-${var.environment}"
  kubernetes_certificate_secrets_name = "metabase-certificate-secrets-${var.environment}"
  kubernetes_deployment_name          = "metabase-deployment-${var.environment}"
  kubernetes_container_name           = "metabase-${var.environment}"
  kubernetes_service_name             = "metabase-service-${var.environment}"
  kubernetes_ingress_name             = "metabase-ingress-${var.environment}"
}

data "azurerm_key_vault_secret" "this" {
  name         = var.ca_certificate_name
  key_vault_id = var.key_vault_id
}

resource "null_resource" "force_recreate" {
  triggers = {
    always_recreate = timestamp()
  }
}

#------------------------------------------------------------------------------------------------------------------------------
# PostgreSQL Server and Database - prerequisites for Metabase Business Intelligence tool
#------------------------------------------------------------------------------------------------------------------------------

module "postgre_sql" {
  source = "../postgresql"

  base_name           = var.base_name
  environment         = var.environment
  location            = var.location
  resource_group_name = var.resource_group_name

  administrator_login    = var.postgre_sql_administrator_login
  administrator_password = var.postgre_sql_administrator_password

  private_dns_zone_ids = var.private_dns_zone_ids
  subnet_id            = var.subnet_id

  suffix = "metabase"

  tags = var.tags
}

#------------------------------------------------------------------------------------------------------------------------------
# Kubernetes Resources - secrets, deployment, service and ingress for Metabase Business Intelligence tool
#------------------------------------------------------------------------------------------------------------------------------

resource "kubernetes_namespace" "this" {
  metadata {
    annotations = {
      name = local.kubernetes_namespace
    }

    name = local.kubernetes_namespace
  }
}

# This script retrieves the service principal ID for the given AKS compute
# For more information please see Terraform documentation:
# https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/external
data "external" "extract_certificate" {
  program = ["bash", "../../../../../assets/scripts/extract_certificate.sh"]

  query = {
    CERT_PFX = data.azurerm_key_vault_secret.this.value
  }
}

resource "kubernetes_secret" "certificate" {
  metadata {
    name      = local.kubernetes_certificate_secrets_name
    namespace = local.kubernetes_namespace
  }

  data = {
    "tls.crt" = base64decode(data.external.extract_certificate.result["crt"]) # Public Certificate, needs to be decoded because it is already base64 encoded, kubernetes_secret will base64 encode again.
    "tls.key" = base64decode(data.external.extract_certificate.result["pem"]) # Private Key in PEM format, needs to be decoded because it is already base64 encoded, kubernetes_secret will base64 encode again.
  }

  type = "kubernetes.io/tls"

  depends_on = [
    data.external.extract_certificate
  ]
}

resource "kubernetes_manifest" "database_secrets" {

  manifest = yamldecode(templatefile("../../../../../assets/kubernetes/metabase/secrets.yaml",
    {
      secret_name = local.kubernetes_database_secrets_name
      namespace   = local.kubernetes_namespace
      db_user     = base64encode(var.postgre_sql_administrator_login)
      db_pass     = base64encode(var.postgre_sql_administrator_password)
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
    kubernetes_namespace.this,
    module.postgre_sql,
    null_resource.force_recreate
  ]
}

resource "kubernetes_manifest" "deployment" {

  manifest = yamldecode(templatefile("../../../../../assets/kubernetes/metabase/deployment.yaml",
    {
      deployment_name = local.kubernetes_deployment_name
      secrets_name    = local.kubernetes_database_secrets_name
      namespace       = local.kubernetes_namespace
      container_name  = local.kubernetes_container_name
      db_host         = "${module.postgre_sql.server_name}.postgres.database.azure.com"
      db_name         = module.postgre_sql.database_name
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
    kubernetes_namespace.this,
    module.postgre_sql,
    kubernetes_manifest.database_secrets,
    kubernetes_secret.certificate,
    null_resource.force_recreate
  ]
}

resource "kubernetes_manifest" "service" {

  manifest = yamldecode(templatefile("../../../../../assets/kubernetes/metabase/service.yaml",
    {
      namespace    = local.kubernetes_namespace
      service_name = local.kubernetes_service_name
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
    kubernetes_namespace.this,
    module.postgre_sql,
    kubernetes_manifest.database_secrets,
    kubernetes_secret.certificate,
    kubernetes_manifest.deployment,
    null_resource.force_recreate
  ]
}

resource "kubernetes_manifest" "ingress" {

  manifest = yamldecode(templatefile("../../../../../assets/kubernetes/metabase/ingress.yaml",
    {
      namespace       = local.kubernetes_namespace
      service_name    = local.kubernetes_service_name
      ingress_name    = local.kubernetes_ingress_name
      host            = var.environment == "prod" ? "metabase.safetower.com" : "metabase-${var.environment}.safetower.com"
      tls_secret_name = local.kubernetes_certificate_secrets_name
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
    kubernetes_namespace.this,
    module.postgre_sql,
    kubernetes_manifest.database_secrets,
    kubernetes_secret.certificate,
    kubernetes_manifest.deployment,
    null_resource.force_recreate
  ]
}