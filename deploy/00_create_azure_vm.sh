#!/bin/bash

set -eu

# Define the .env file path
ENV_FILE=".env"

# Check if .env file exists
if [ ! -f "${ENV_FILE}" ]; then
  echo ".env file does not exist. Please run create_sa_and_upload.sh script first."
  exit 1
else
  source "${ENV_FILE}"
fi

# Variables
env="play"
loc="uks"
org="pfsense"
location="UK South"
rgp_vnet="rgp-uks-and-play-pfsense"
rgp_pfsense="rgp-uks-and-play-pfsense"
sa_account_name="pfsensevhds${RANDOM_NUMBER}"
vnet_name="vnet-${loc}-${org}-${env}"
vnet_prefix="10.0.0.0/16"
vnet_subnets=$(cat <<EOF
[
    {
        "name": "external",
        "addressPrefix": "10.0.0.0/24"
    },
    {
        "name": "internal",
        "addressPrefix": "10.0.1.0/24"
    }
]
EOF
)
vmName="vm-${loc}-corp-${env}-pfsense-00"
vmSize="Standard_D2ls_v5"
vhdUri="https://${sa_account_name}.blob.core.windows.net/vhds/pfsense.vhd"

az config set core.display_region_identified=false # stop warning about cheaper in alternative region

echo "Creating Resource Group"
az group create -g "${rgp_pfsense}" -l "${location}" -o table

echo "Creating Virtual Network"
exists=$(az network vnet list --query "[?name==\`${vnet_name}\`].name" -o tsv)
if [[ "${vnet_name}" != "$exists" ]]; then
    az network vnet create \
        --resource-group "${rgp_vnet}" \
        --location "${location}" \
        --name "${vnet_name}" \
        --address-prefixes "${vnet_prefix}" -o table
else
    printf "\n(skipped - vnet exists)\n\n"
    az network vnet show -g "${rgp_vnet}" -n "${vnet_name}" -o table
fi

echo "Creating Subnets"
for subnet in $(printf "%s" "${vnet_subnets}" | jq -c '.[]'); do
    name=$(printf "%s" "${subnet}" | jq -r '.name')
    addressPrefix=$(printf "%s" "${subnet}" | jq -r '.addressPrefix')

    exists=$(az network vnet subnet list -g "${rgp_vnet}" --vnet-name "${vnet_name}" --query "[?name==\`${name}\`].name" -o tsv)
    if [[ "${name}" != "$exists" ]]; then
        az network vnet subnet create -n "${name}" --vnet-name "${vnet_name}" -g "${rgp_vnet}" --address-prefixes "${addressPrefix}" -o table
    else
        printf "\n(skipped - subnet exists)\n\n"
        az network vnet subnet show -g "${rgp_vnet}" --vnet-name "${vnet_name}" -n "${name}" -o table
    fi
done

# Get the VNet details
echo "Retrieving VNET details"
vnet_id=$(az network vnet show --name "${vnet_name}" --resource-group "${rgp_vnet}" --query "id" -o tsv)
snet_internal_id=$(az network vnet subnet show --name internal --vnet-name "${vnet_name}" --resource-group "${rgp_vnet}" --query "id" -o tsv)
snet_external_id=$(az network vnet subnet show --name external --vnet-name "${vnet_name}" --resource-group "${rgp_vnet}" --query "id" -o tsv)

# Create a public IP address
echo "Creating Public IP"
public_ip_id=$(az network public-ip create --name "pubip-${loc}-pfsense-${env}" --resource-group "${rgp_pfsense}" --location "${location}" --allocation-method "Static" --zone 1 2 3 --query "publicIp.id" -o tsv)

# Create NICs
echo "Creating Network Interfaces"
nic_ext_id=$(az network nic create --name "vnic-${loc}-pfsense-${env}-ext" --resource-group "${rgp_pfsense}" --location "${location}" --subnet "${snet_external_id}" --public-ip-address "${public_ip_id}" --query "id" -o tsv)
nic_int_id=$(az network nic create --name "vnic-${loc}-pfsense-${env}-int" --resource-group "${rgp_pfsense}" --location "${location}" --subnet "${snet_internal_id}" --query "id" -o tsv)

echo "Creating Image"
az image create --resource-group "${rgp_pfsense}" --name PfSenseImage --source "${vhdUri}" --os-type Linux --hyper-v-generation V2 -o table

image_id=$(az image show --resource-group "${rgp_pfsense}" --name PfSenseImage --query id -o tsv)

# Create VM configuration
echo "Creating Virtual Machine"
az vm create --resource-group "${rgp_pfsense}" --name "${vmName}" \
  --size "${vmSize}" --generate-ssh-keys \
  --image "${image_id}" --storage-sku StandardSSD_LRS \
  --nics "vnic-${loc}-pfsense-${env}-ext" "vnic-${loc}-pfsense-${env}-int" \
  --encryption-at-host --os-disk-name "${vmName}-osdisk" \
  -o table

  az vm boot-diagnostics enable --name "${vnName}" --resource-group "${rgp_pfsense}" -o table
