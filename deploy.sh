#!/bin/bash
set -e

# ---- Config ----
RESOURCE_GROUP="az104-project-rg"
LOCATION="francecentral"
VNET_NAME="az104-vnet"
SUBNET_NAME="az104-subnet"
NSG_NAME="az104-nsg"
VM_NAME="az104-vm1"
VMSS_NAME="az104-vmss"
ADMIN_USER="azureuser"

# ---- Resource Group ----
echo "Creating resource group..."
az group create --name $RESOURCE_GROUP --location $LOCATION

# ---- Networking ----
echo "Creating virtual network and subnet..."
az network vnet create \
  --resource-group $RESOURCE_GROUP \
  --name $VNET_NAME \
  --address-prefix 10.0.0.0/16 \
  --subnet-name $SUBNET_NAME \
  --subnet-prefix 10.0.1.0/24

echo "Creating network security group..."
az network nsg create \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --name $NSG_NAME

echo "Allowing SSH (port 22)..."
az network nsg rule create \
  --resource-group $RESOURCE_GROUP \
  --nsg-name $NSG_NAME \
  --name allow-ssh \
  --priority 1000 \
  --destination-port-ranges 22 \
  --access Allow \
  --protocol Tcp

echo "Allowing HTTP (port 80)..."
az network nsg rule create \
  --resource-group $RESOURCE_GROUP \
  --nsg-name $NSG_NAME \
  --name allow-http \
  --priority 1010 \
  --destination-port-ranges 80 \
  --access Allow \
  --protocol Tcp

# ---- Single VM ----
echo "Creating single VM (with nginx via cloud-init)..."
az vm create \
  --resource-group $RESOURCE_GROUP \
  --name $VM_NAME \
  --location $LOCATION \
  --vnet-name $VNET_NAME \
  --subnet $SUBNET_NAME \
  --nsg $NSG_NAME \
  --image Ubuntu2204 \
  --size Standard_B1s \
  --admin-username $ADMIN_USER \
  --generate-ssh-keys \
  --custom-data cloud-init.txt

# ---- VM Scale Set ----
echo "Creating VM Scale Set with load balancer..."
az vmss create \
  --resource-group $RESOURCE_GROUP \
  --name $VMSS_NAME \
  --location $LOCATION \
  --image Ubuntu2204 \
  --vm-sku Standard_B1s \
  --instance-count 2 \
  --vnet-name $VNET_NAME \
  --subnet $SUBNET_NAME \
  --nsg $NSG_NAME \
  --admin-username $ADMIN_USER \
  --generate-ssh-keys \
  --custom-data cloud-init.txt \
  --upgrade-policy-mode automatic \
  --lb-sku Standard

# ---- Autoscale ----
echo "Configuring autoscale rules..."
VMSS_ID=$(az vmss show --resource-group $RESOURCE_GROUP --name $VMSS_NAME --query id --output tsv)

az monitor autoscale create \
  --resource-group $RESOURCE_GROUP \
  --resource $VMSS_ID \
  --name az104-autoscale \
  --min-count 2 \
  --max-count 3 \
  --count 2

az monitor autoscale rule create \
  --resource-group $RESOURCE_GROUP \
  --autoscale-name az104-autoscale \
  --condition "Percentage CPU > 70 avg 5m" \
  --scale out 1

az monitor autoscale rule create \
  --resource-group $RESOURCE_GROUP \
  --autoscale-name az104-autoscale \
  --condition "Percentage CPU < 30 avg 5m" \
  --scale in 1

echo "Deployment complete!"
