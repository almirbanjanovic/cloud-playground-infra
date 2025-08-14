#!/bin/bash
# This script retrieves the service principal ID for the given AKS compute
# For more information, see Terraform documentation:
# https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/external

# Exit if any command fails
set -e

# Read input from Terraform (JSON) and parse it into shell variables
eval "$(jq -r '@sh "AKS_COMPUTE_NAME=\(.AKS_COMPUTE_NAME) MLW_RESOURCE_GROUP=\(.MLW_RESOURCE_GROUP) MLW_NAME=\(.MLW_NAME)"')"

# Verify that the input was parsed correctly
if [[ -z "$AKS_COMPUTE_NAME" || -z "$MLW_RESOURCE_GROUP" || -z "$MLW_NAME" ]]; then
  >&2 echo "Error: Missing input arguments."
  exit 1
fi

# Fetch the machine learning Kubernetes compute service principal ID using Azure CLI
COMPUTE_SP_ID=$(az ml compute show --name "$AKS_COMPUTE_NAME" --resource-group "$MLW_RESOURCE_GROUP" --workspace-name "$MLW_NAME" --query "identity.principal_id" --output tsv 2>/dev/null || echo "")

# Verify if the service principal ID was fetched successfully
if [ -z "$COMPUTE_SP_ID" ]; then
  >&2 echo "Error: Unable to fetch service principal ID."
  exit 1
fi

# Output the result as a valid JSON object
echo "{\"compute_sp_id\": \"$COMPUTE_SP_ID\"}"