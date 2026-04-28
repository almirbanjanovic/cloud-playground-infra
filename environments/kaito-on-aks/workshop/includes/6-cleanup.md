## Goal

Remove everything created during the workshop so nothing keeps charging your subscription.

## 1. Destroy the Terraform-managed resources

```bash
terraform destroy -var "resource_group_name=$RG_NAME" -auto-approve
```

This removes the AKS cluster, the namespace, and the KAITO workspace.

## 2. Verify the AKS-managed resource group is gone

When AKS is created, Azure provisions a "node" resource group (typically named `MC_<rg>_<cluster>_<region>`) that holds the VMs, NICs, disks, and load balancer. It should be deleted automatically when the cluster is destroyed — verify:

```bash
az group list --query "[?starts_with(name, 'MC_${RG_NAME}_')]" --output table
```

If anything is still listed, delete it manually:

```bash
az group delete --name "<MC_...>" --yes --no-wait
```

## 3. Delete the workshop resource group

This removes the storage account holding Terraform state and anything else left behind:

```bash
az group delete --name "$RG_NAME" --yes --no-wait
```

## 4. Confirm

```bash
az group show --name "$RG_NAME" 2>&1 | grep -i "could not be found"
```

You're back to a clean subscription.
