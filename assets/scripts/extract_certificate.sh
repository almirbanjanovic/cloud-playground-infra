#!/bin/bash
set -e  # Exit immediately if a command fails
set -x  # Debug mode: print all commands

# Read input from Terraform (JSON) and parse it into shell variables
eval "$(jq -r '@sh "CERT_PFX=\(.CERT_PFX)"')"

# Ensure CERT_PFX is set
if [[ -z "${CERT_PFX}" ]]; then
  echo "ERROR: CERT_PFX is empty"
  exit 1
fi

# Decode and write to file
echo "${CERT_PFX}" | base64 --decode > hero-app.pfx || { echo "ERROR: Failed to decode base64"; exit 1; }

# Debug: Check if PFX file exists
if [[ ! -s hero-app.pfx ]]; then
  echo "ERROR: PFX file is empty or not created"
  exit 1
fi

# Extract the certificate (Public Key)
openssl pkcs12 -in hero-app.pfx -clcerts -nokeys -out hero-app.crt -passout pass: -passin pass: || { echo "ERROR: Failed to extract .crt"; exit 1; }

# Extract the private key in PEM format
openssl pkcs12 -in hero-app.pfx -nocerts -nodes -out hero-app.pem -passout pass: -passin pass: || { echo "ERROR: Failed to extract .pem"; exit 1; }

# Debug: Ensure extracted files exist
if [[ ! -s hero-app.crt ]]; then
  echo "ERROR: hero-app.crt file is empty"
  exit 1
fi

if [[ ! -s hero-app.pem ]]; then
  echo "ERROR: hero-app.pem file is empty"
  exit 1
fi

CRT_BASE64=$(base64 -w 0 hero-app.crt)
PEM_BASE64=$(base64 -w 0 hero-app.pem)

# Output JSON for Terraform
echo "{ \"crt\": \"${CRT_BASE64}\", \"pem\": \"${PEM_BASE64}\" }"