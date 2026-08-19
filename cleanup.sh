#!/bin/bash
set -e

RESOURCE_GROUP="az104-project-rg"

echo "Deleting resource group and all resources inside it..."
az group delete --name $RESOURCE_GROUP --yes --no-wait

echo "Deletion started. This runs in the background and may take a few minutes."
