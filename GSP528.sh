#!/bin/bash

set -euo pipefail

PROJECT_ID=$(gcloud config get-value project)
HUB_NAME="ncc-hub"

echo "🔍 Detecting region from existing VPN tunnels..."
REGION=$(gcloud compute vpn-tunnels list --format="value(region)" --limit=1)

if [[ -z "$REGION" ]]; then
  echo "❌ Unable to detect region from VPN tunnels."
  # exit 1
fi

echo "✅ Region detected: $REGION"

# Function to check and create a spoke if it doesn't exist
create_spoke_if_not_exists() {
  local SPOKE_NAME="$1"
  local REGION_FLAG="$2"  # Either "--region=$REGION" or "--global"
  local OTHER_FLAGS="$3"

  if gcloud alpha network-connectivity spokes describe "$SPOKE_NAME" --project="$PROJECT_ID" $REGION_FLAG >/dev/null 2>&1; then
    echo "✅ Spoke $SPOKE_NAME already exists, skipping."
  else
    echo "🚀 Creating spoke $SPOKE_NAME..."
    gcloud alpha network-connectivity spokes create "$SPOKE_NAME" \
      --project="$PROJECT_ID" \
      --hub="$HUB_NAME" \
      $REGION_FLAG \
      $OTHER_FLAGS
  fi
}

# Create NCC Hub (global)
if gcloud network-connectivity hubs describe "$HUB_NAME" --project="$PROJECT_ID" >/dev/null 2>&1; then
  echo "✅ Hub $HUB_NAME already exists, skipping creation."
else
  echo "🚀 Creating NCC hub $HUB_NAME..."
  gcloud network-connectivity hubs create "$HUB_NAME" \
    --project="$PROJECT_ID" \
    --description="Global NCC Hub"
fi

# Gather VPN tunnels for On-Prem Offices
OFFICE1_TUNNELS=$(gcloud compute vpn-tunnels list --filter="name~'office1'" --format="value(name)")
OFFICE2_TUNNELS=$(gcloud compute vpn-tunnels list --filter="name~'office2'" --format="value(name)")

if [[ -z "$OFFICE1_TUNNELS" ]]; then
  echo "❌ No Office 1 VPN tunnels found!"
  # exit 1
fi

if [[ -z "$OFFICE2_TUNNELS" ]]; then
  echo "❌ No Office 2 VPN tunnels found!"
  # exit 1
fi

# Create VPN spokes for Office 1
echo "🔧 Creating VPN spokes for On-Prem Office 1..."
i=1
while read -r tunnel_name; do
  tunnel_full="projects/$PROJECT_ID/regions/$REGION/vpnTunnels/$tunnel_name"
  spoke_name="office-1-spoke-$i"
  create_spoke_if_not_exists "$spoke_name" "--region=$REGION" "--vpn-tunnel=$tunnel_full --description='Spoke for On-Prem Office 1 tunnel $i'"
  ((i++))
done <<< "$OFFICE1_TUNNELS"

# Create VPN spokes for Office 2
echo "🔧 Creating VPN spokes for On-Prem Office 2..."
i=1
while read -r tunnel_name; do
  tunnel_full="projects/$PROJECT_ID/regions/$REGION/vpnTunnels/$tunnel_name"
  spoke_name="office-2-spoke-$i"
  create_spoke_if_not_exists "$spoke_name" "--region=$REGION" "--vpn-tunnel=$tunnel_full --description='Spoke for On-Prem Office 2 tunnel $i'"
  ((i++))
done <<< "$OFFICE2_TUNNELS"

# Create Linked VPC Spokes (global)
WORKLOAD_VPC1="workload-vpc-1"
WORKLOAD_VPC2="workload-vpc-2"

echo "🔧 Creating Linked VPC spokes..."
create_spoke_if_not_exists "workload-1-spoke" "--global" "--vpc-network=$WORKLOAD_VPC1 --description='Spoke for Workload VPC 1'"
create_spoke_if_not_exists "workload-2-spoke" "--global" "--vpc-network=$WORKLOAD_VPC2 --description='Spoke for Workload VPC 2'"

# Create Hybrid spokes for Office 1 (if needed)
echo "🔧 Creating Hybrid VPN spokes for Office 1..."
i=1
while read -r tunnel_name; do
  tunnel_full="projects/$PROJECT_ID/regions/$REGION/vpnTunnels/$tunnel_name"
  spoke_name="hybrid-office-1-spoke-$i"
  create_spoke_if_not_exists "$spoke_name" "--region=$REGION" "--vpn-tunnel=$tunnel_full --description='Hybrid spoke for On-Prem Office 1 tunnel $i'"
  ((i++))
done <<< "$OFFICE1_TUNNELS"

echo "✅ All NCC resources created or verified successfully."
