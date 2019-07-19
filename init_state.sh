#!/bin/bash

set -e

export LOCATION=westus2
export COMMON_RESOURCE_GROUP_NAME=org1-tfstate-rg
export TF_STATE_STORAGE_ACCOUNT_NAME=org1tfstate
export TF_STATE_CONTAINER_NAME=tfstate
export KEYVAULT_NAME=org1-shared-secrets

# Create the resource group
echo "Creating $COMMON_RESOURCE_GROUP_NAME resource group..."
az group create -n $COMMON_RESOURCE_GROUP_NAME -l $LOCATION >/dev/null 2>&1

echo "Resource group $COMMON_RESOURCE_GROUP_NAME created."

# Create the storage account
echo "Creating $TF_STATE_STORAGE_ACCOUNT_NAME storage account..."
az storage account create -g $COMMON_RESOURCE_GROUP_NAME -l $LOCATION \
  --name $TF_STATE_STORAGE_ACCOUNT_NAME \
  --sku Standard_LRS \
  --encryption-services blob >/dev/null 2>&1

echo "Storage account $TF_STATE_STORAGE_ACCOUNT_NAME created."

# Retrieve the storage account key
echo "Retrieving storage account key..."
ACCOUNT_KEY=$(az storage account keys list --resource-group $COMMON_RESOURCE_GROUP_NAME --account-name $TF_STATE_STORAGE_ACCOUNT_NAME --query [0].value -o tsv) >/dev/null 2>&1

echo "Storage account key retrieved."

# Create a storage container (for the Terraform State)
echo "Creating $TF_STATE_CONTAINER_NAME storage container..."
az storage container create \
  --name $TF_STATE_CONTAINER_NAME \
  --account-name $TF_STATE_STORAGE_ACCOUNT_NAME \
  --account-key $ACCOUNT_KEY \
  >/dev/null 2>&1

echo "Storage container $TF_STATE_CONTAINER_NAME created."

# Create an Azure KeyVault
echo "Creating $KEYVAULT_NAME key vault..."
az keyvault create -g $COMMON_RESOURCE_GROUP_NAME -l $LOCATION --name $KEYVAULT_NAME >/dev/null 2>&1

echo "Key vault $KEYVAULT_NAME created."

# Store the Terraform State Storage Key into KeyVault
echo "Storage storage access key into key vault secret..."
az keyvault secret set --name tfstate-storage-key --value $ACCOUNT_KEY --vault-name $KEYVAULT_NAME >/dev/null 2>&1

echo "Key vault secret created."

# Display information
echo "Azure Storage Account and KeyVault have been created."
echo "Run the following command to initialize Terraform to store its state into Azure Storage:"
echo "terraform init -backend-config=\"storage_account_name=$TF_STATE_STORAGE_ACCOUNT_NAME\" -backend-config=\"container_name=$TF_STATE_CONTAINER_NAME\" -backend-config=\"access_key=\$(az keyvault secret show --name tfstate-storage-key --vault-name $KEYVAULT_NAME --query value -o tsv)\" -backend-config=\"key=terraform-ref-architecture-tfstate\""