## Azure

You need an Azure subscription where you can create:

- Resource groups
- Storage accounts
- AKS clusters
- Public IPs (for the auto-created LoadBalancer)

If you don't have rights to assign roles, that's OK as long as you'll be the only principal touching these resources.

## Local tools

| Tool | Minimum version | Install |
|------|-----------------|---------|
| Azure CLI (`az`) | 2.60+ | <https://learn.microsoft.com/cli/azure/install-azure-cli> |
| Terraform | 1.14.4+ | <https://developer.hashicorp.com/terraform/install> |
| `kubectl` | 1.30+ | <https://kubernetes.io/docs/tasks/tools/> |
| `curl` | any | usually pre-installed |
| Git | any | <https://git-scm.com/downloads> |

> **Windows attendees:** PowerShell 7+ recommended. The `bash`-style commands below also work in WSL or Git Bash.

## Background knowledge

You should be comfortable with:

- Basic Azure concepts (subscriptions, resource groups)
- Basic Kubernetes concepts (pods, services, namespaces)
- Running CLI commands and editing YAML

If KAITO is new to you, skim the previous unit again, or open the demo [README.md](../README.md) in another tab.

## Clone the repository

```bash
git clone https://github.com/almirbanjanovic/cloud-playground-infra.git
cd cloud-playground-infra/environments/kaito-on-aks
```

All commands in this workshop assume your working directory is `environments/kaito-on-aks`.
