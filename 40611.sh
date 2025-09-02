#!/bin/bash
set -euo pipefail

echo "=== Create Managed Instance Group with Autoscaling ==="

# Ask user for the required region
read -rp "Enter GCP Region (e.g., us-central1): " REGION

# Fixed values for template and group
INSTANCE_TEMPLATE="dev-instance-template"
INSTANCE_GROUP="dev-instance-group"

# Step 1: Create the managed instance group
echo "Creating managed instance group '$INSTANCE_GROUP' in region '$REGION'..."
gcloud compute instance-groups managed create "$INSTANCE_GROUP" \
  --template="$INSTANCE_TEMPLATE" \
  --size=1 \
  --region="$REGION"

# Step 2: Enable autoscaling
echo "Enabling autoscaling for '$INSTANCE_GROUP'..."
gcloud compute instance-groups managed set-autoscaling "$INSTANCE_GROUP" \
  --region="$REGION" \
  --min-num-replicas=1 \
  --max-num-replicas=3 \
  --target-cpu-utilization=0.6 \
  --mode=on

echo "✅ Managed instance group '$INSTANCE_GROUP' with autoscaling set up successfully."
