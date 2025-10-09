#!/bin/bash
# Script: create_vpcs.sh
# Description: Creates two custom VPC networks ("staging" and "development") in GCP
# Usage: ./create_vpcs.sh <region>

# Exit immediately if any command fails
set -e


read -p "Please enter the region (e.g., us-central1): " REGION


echo "📍 Using region: $REGION"

echo "Creating VPC networks in region: $REGION"
echo "----------------------------------------"

# Step 1: Create a custom VPC network named "staging" (no subnet, no firewall)
echo "Creating VPC network 'staging'..."
gcloud compute networks create staging \
  --subnet-mode=custom \
  --quiet

# Step 2: Create a custom VPC network named "development" with one subnet
echo "Creating VPC network 'development'..."
gcloud compute networks create development \
  --subnet-mode=custom \
  --quiet

# Step 3: Create subnet 'dev-1' in the 'development' VPC
echo "Creating subnet 'dev-1' in 'development'..."
gcloud compute networks subnets create dev-1 \
  --network=development \
  --region=$REGION \
  --range=10.1.0.0/24 \
  --quiet

echo "----------------------------------------"
echo "✅ VPC setup complete!"
echo "VPCs created:"
echo " - staging (no subnets)"
echo " - development (with subnet dev-1 in region $REGION)"