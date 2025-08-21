# Cloud Playground Infrastructure

This repository contains infrastructure-as-code (IaC) templates and Kubernetes manifests for deploying a comprehensive Azure cloud environment. The infrastructure is designed to support containerized applications, data analytics, monitoring, and machine learning workloads.

## Table of Contents

- [Repository Structure](#repository-structure)
  - [📁 Terraform Modules](#-terraform-modules)
    - [Core Infrastructure](#core-infrastructure)
    - [Container Platform](#container-platform)
    - [Data & Storage](#data--storage)
    - [AI & Analytics](#ai--analytics)
    - [Monitoring & Observability](#monitoring--observability)
    - [Security & Access](#security--access)
    - [Networking & DNS](#networking--dns)
  - [📁 Kubernetes Assets](#-kubernetes-assets)
    - [Database](#database)
    - [Machine Learning](#machine-learning)
  - [📁 Utility Scripts](#-utility-scripts)
  - [CI/CD Workflows](#ci-cd-workflows)
- [Key Features](#key-features)
  - [🔒 Security First](#-security-first)
  - [🏗️ Enterprise-Ready Architecture](#️-enterprise-ready-architecture)
  - [🔧 Infrastructure as Code](#-infrastructure-as-code)
  - [☸️ Kubernetes-Native](#️-kubernetes-native)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Basic Usage](#basic-usage)
- [Module Dependencies](#module-dependencies)
- [Contributing](#contributing)
- [License](#license)
- [Support](#support)

## Repository Structure

### 📁 Terraform Modules

The `terraform/modules/` directory contains reusable Terraform modules for Azure resources:

#### Core Infrastructure

- **`resource_group/`** - Azure Resource Group provisioning
- **`vnet/`** - Virtual Network with multiple specialized subnets
- **`nat_gateway/`** - NAT Gateway for outbound internet connectivity
- **`vpn_gateway/`** - VPN Gateway for hybrid connectivity

#### Container Platform

- **`aks/`** - Azure Kubernetes Service (AKS) cluster with:
  - Private cluster configuration
  - Multiple node pools (system, application, training)
  - Azure AD integration
  - Application Gateway ingress
  - Azure Policy integration
- **`acr/`** - Azure Container Registry with private endpoints

#### Data & Storage

- **`storage_account/`** - Azure Storage Account with multiple private endpoints for:
  - Blob storage
  - File shares
  - Tables
  - Queues
  - Data Lake File System (ADLS Gen2)
- **`sql/`** - Azure SQL Database with private endpoints
- **`sql_backup/`** - SQL Database backup configuration

#### AI & Analytics

- **`open_ai/`** - Azure OpenAI Service with cognitive deployments
- **`sftp/`** - SFTP server for data transfer

#### Monitoring & Observability

- **`monitor/`** - Azure Monitor with:
  - Log Analytics Workspace
  - Application Insights
  - Azure Monitor Private Link Scope (AMPLS)
- **`prometheus/`** - Azure Monitor Workspace for Prometheus metrics
- **`grafana/`** - Azure Managed Grafana for visualization
- **`container_insights/`** - Container monitoring for AKS

#### Security & Access

- **`key_vault/`** - Azure Key Vault with private endpoints
- **`key_vault_secrets/`** - Key Vault secrets management
- **`app_gateway/`** - Application Gateway with Web Application Firewall (WAF)

#### Networking & DNS

- **`private_dns_global/`** - Global private DNS zones for Azure services
- **`private_dns_zone/`** - Individual private DNS zone management
- **`private_dns_resolver/`** - Azure DNS Private Resolver
- **`private_endpoint/`** - Reusable private endpoint module
- **`monitor_private_link_scope/`** - Azure Monitor Private Link Scope

### 📁 Kubernetes Assets

The `assets/kubernetes/` directory contains Kubernetes manifests and configurations:

#### Database

- **`database/`** - Database-related Kubernetes resources:
  - SQL database export jobs (`export_db_bacpac.yaml`)
  - Database secrets management (`secrets.yaml`)
  - Database synchronization scripts (`sql_db_clean_sync_objects.sql`)

#### Machine Learning

- **`machine_learning/`** - ML workload configurations:
  - Instance type specifications (`instance_type.yaml`)

### 📁 Utility Scripts

The `assets/scripts/` directory contains utility scripts:

- **`extract_certificate.sh`** - Certificate extraction utility for TLS/SSL management
- **`get_compute_sp_id.sh`** - Script to retrieve compute service principal IDs
- **`page_views_query.sql`** - Analytics query for page view metrics

## CI/CD Workflows

The `.github/workflows/` directory contains GitHub Actions workflows for automating infrastructure and application tasks:

- **`terraform-plan.yaml`** / **`terraform-apply.yaml`** – Plan and apply Terraform changes automatically
- **`apim-tf-plan.yaml`** / **`apim-init-backend.yaml`** – Specialized workflows for API Management infrastructure
- **`init.yaml`** – Initialization tasks for the repository or environments
- **`test-oidc.yaml`** – Test OpenID Connect (OIDC) integration for secure authentication

These workflows help ensure consistent, automated deployment and validation of your cloud infrastructure.

## Key Features

### 🔒 Security First

- **Private Endpoints**: All Azure PaaS services are configured with private endpoints
- **Network Isolation**: Resources deployed in private subnets with controlled access
- **Azure AD Integration**: Role-based access control (RBAC) throughout the infrastructure
- **Key Vault Integration**: Centralized secrets management

### 🏗️ Enterprise-Ready Architecture

- **High Availability**: Zone-redundant configurations where supported
- **Scalability**: Auto-scaling enabled for compute resources
- **Monitoring**: Comprehensive observability with Azure Monitor, Prometheus, and Grafana
- **Backup & Recovery**: Automated backup strategies for critical data

### 🔧 Infrastructure as Code

- **Modular Design**: Reusable Terraform modules for consistent deployments
- **Environment Separation**: Support for multiple environments (dev, staging, prod)
- **Standardized Naming**: Consistent resource naming conventions
- **Tag Management**: Comprehensive resource tagging strategy

### ☸️ Kubernetes-Native

- **Private AKS Cluster**: Secure Kubernetes environment
- **Multiple Node Pools**: Dedicated pools for different workload types
- **Container Registry Integration**: Seamless container image management
- **Application Gateway Ingress**: Enterprise-grade load balancing and routing

## Getting Started

### Prerequisites

- Azure CLI installed and configured
- Terraform >= 0.14
- kubectl for Kubernetes management
- Access to an Azure subscription with appropriate permissions

### Basic Usage

1. **Clone the repository**

   ```bash
   git clone https://github.com/almirbanjanovic/cloud-playground-infra.git
   cd cloud-playground-infra
   ```

2. **Configure Terraform backend** (recommended)
   - Set up Azure Storage Account for Terraform state
   - Configure backend in your Terraform configuration

3. **Deploy infrastructure**
   - Create a main Terraform configuration that uses these modules
   - Set appropriate variables for your environment
   - Run `terraform init`, `terraform plan`, and `terraform apply`

4. **Deploy Kubernetes workloads**
   - Connect to your AKS cluster
   - Apply manifests from the `assets/kubernetes/` directory

## Module Dependencies

The modules are designed with clear dependencies:

- **VNet** → **Subnets** → **Private Endpoints**
- **AKS** depends on **VNet**, **ACR**, **Application Gateway**
- **Monitoring** components integrate with **AKS** and **Storage**
- **Private DNS** zones support **Private Endpoints**

## Contributing

This infrastructure is designed to be extensible. When adding new modules:

1. Follow the existing naming conventions
2. Include proper tagging
3. Implement private endpoints where applicable
4. Add appropriate outputs for module integration
5. Update this README with new components

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## Support

For questions or issues with this infrastructure:

1. Check existing documentation in module directories
2. Review Azure best practices documentation
3. Open an issue in this repository for infrastructure-specific problems

---

*This infrastructure represents a production-ready, enterprise-grade Azure environment suitable for modern cloud-native applications, data analytics, and machine learning workloads.*
