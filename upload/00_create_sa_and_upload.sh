#!/bin/bash

# Define the .env file path
ENV_FILE=".env"

# Check if .env file exists
if [ ! -f "${ENV_FILE}" ]; then
  echo ".env file does not exist. Creating it..."
  
  # Generate a 5-digit random number
  RANDOM_NUMBER=$((RANDOM % 90000 + 10000)) # Ensures a 5-digit number

  # Create the .env file and add the RANDOM_NUMBER variable
  echo "RANDOM_NUMBER=${RANDOM_NUMBER}" > "${ENV_FILE}"

  echo ".env file created with RANDOM_NUMBER=${RANDOM_NUMBER}"
else
  echo ".env file already exists. No changes made."
fi

source "${ENV_FILE}"

# Variables
RESOURCE_GROUP_NAME="rgp-uks-and-play-pfsense"
LOCATION="uksouth"  # Change this to your desired Azure region
STORAGE_ACCOUNT_NAME="pfsensevhds${RANDOM_NUMBER}" # Append random number to ensure uniqueness
CONTAINER_NAME="vhds"
VHD_FILE_PATH="/mnt/c/VMs/Virtual Hard Disks/pfsense.vhd"

# Create a resource group
echo "Creating resource group: ${RESOURCE_GROUP_NAME} in ${LOCATION}..."
az group create \
  --name ${RESOURCE_GROUP_NAME} \
  --location ${LOCATION} \
  -o table

if [ $? -ne 0 ]; then
  echo "Failed to create resource group. Exiting."
  exit 1
fi

# Create a storage account
echo "Creating storage account: ${STORAGE_ACCOUNT_NAME}..."
az storage account create \
  --name "${STORAGE_ACCOUNT_NAME}" \
  --resource-group "${RESOURCE_GROUP_NAME}" \
  --location "${LOCATION}" \
  --sku Standard_LRS \
  --kind StorageV2 \
  -o table

if [ $? -ne 0 ]; then
  echo "Failed to create storage account. Exiting."
  exit 1
fi

# Assign permissions to storage account
USER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)
SCOPE=$(az storage account show --name "${STORAGE_ACCOUNT_NAME}" --resource-group "${RESOURCE_GROUP_NAME}" --query id -o tsv)
ROLE="Storage Blob Data Contributor"
echo "Assigning az cli context user Storage Blob Data Contributor to ${STORAGE_ACCOUNT_NAME}..."
az role assignment create \
  --assignee "${USER_OBJECT_ID}" \
  --role "${ROLE}" \
  --scope "${SCOPE}" \
  -o table

echo "Waiting for role assignment to propagate..."
while true; do
  # Check if the role assignment exists
  ASSIGNMENT_EXISTS=$(az role assignment list \
    --assignee "${USER_OBJECT_ID}" \
    --role "${ROLE}" \
    --scope "${SCOPE}" \
    --query "[?principalId=='${USER_OBJECT_ID}'] | length(@)" -o tsv)

  if [[ "${ASSIGNMENT_EXISTS}" -gt 0 ]]; then
    echo "Role assignment successfully applied."
    break
  fi
  sleep 5
done

# Create a blob container
echo "Creating blob container: ${CONTAINER_NAME}..."
az storage container create \
  --name "${CONTAINER_NAME}" \
  --account-name "${STORAGE_ACCOUNT_NAME}" \
  --auth-mode login -o table

if [ $? -ne 0 ]; then
  echo "Failed to create blob container. Exiting."
  exit 1
fi

echo "Successfully created resource group, storage account, and blob container!"
echo "Resource Group: ${RESOURCE_GROUP_NAME}"
echo "Storage Account: ${STORAGE_ACCOUNT_NAME}"
echo "Blob Container: ${CONTAINER_NAME}"

# Upload VHD
az storage blob upload \
  --account-name "${STORAGE_ACCOUNT_NAME}" \
  --container-name "${CONTAINER_NAME}" \
  --file "${VHD_FILE_PATH}" \
  --name "$(basename "${VHD_FILE_PATH}")" \
  --max-connections 1000 \
  --overwrite \
  --auth-mode login \
  -o table

if [ $? -eq 0 ]; then
  echo "VHD file uploaded successfully!"
else
  echo "Failed to upload the VHD file. Please check the error message above."
  exit 1
fi
