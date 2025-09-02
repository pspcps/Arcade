#!/bin/bash
set -euo pipefail

echo "=== Create GCP Machine Image ==="

# Ask user for required inputs
read -rp "Enter Machine Image Name: " IMAGE_NAME
read -rp "Enter Source VM Name: " VM_NAME
read -rp "Enter Source VM Zone (e.g., us-central1-a): " ZONE

# Run the gcloud command to create the machine image
echo "Creating machine image '$IMAGE_NAME' from VM '$VM_NAME' in zone '$ZONE'..."
gcloud compute machine-images create "$IMAGE_NAME" \
  --source-instance="$VM_NAME" \
  --source-instance-zone="$ZONE"

echo "✅ Machine image '$IMAGE_NAME' created successfully."
