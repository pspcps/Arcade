#!/bin/bash

# Prompt for ZONE only
read -p "Enter the ZONE (e.g. us-central1-a): " ZONE

# Auto-derive REGION from ZONE
REGION=$(echo "$ZONE" | rev | cut -d'-' -f2- | rev)

# Set config for gcloud
gcloud config set compute/zone "$ZONE"
gcloud config set compute/region "$REGION"

# Export for internal script use
export ZONE=$ZONE
export REGION=$REGION

# Define instance name
INSTANCE_NAME="gcelab"

echo "Creating VM instance: $INSTANCE_NAME in zone $ZONE (region $REGION)..."



# Create VM with startup script to install NGINX
gcloud compute instances create "$INSTANCE_NAME" \
  --zone="$ZONE" \
  --machine-type="e2-medium" \
  --image-family="debian-12" \
  --image-project="debian-cloud" \
  --boot-disk-size="10GB" \
  --boot-disk-type="pd-balanced" \
  --tags=http-server \
  --metadata=startup-script='#! /bin/bash
    apt-get update
    apt-get install -y nginx
    systemctl enable nginx
    systemctl start nginx' \
  --quiet

# Check for existing firewall rule
echo "Checking HTTP firewall rule..."
if ! gcloud compute firewall-rules describe allow-http &>/dev/null; then
  gcloud compute firewall-rules create allow-http \
    --allow tcp:80 \
    --target-tags=http-server \
    --description="Allow port 80 access to http-server" \
    --direction=INGRESS \
    --priority=1000 \
    --network=default
else
  echo "Firewall rule 'allow-http' already exists."
fi

# Get external IP
EXTERNAL_IP=$(gcloud compute instances describe "$INSTANCE_NAME" \
  --zone="$ZONE" \
  --format='get(networkInterfaces[0].accessConfigs[0].natIP)')



gcloud compute instances create gcelab2 --machine-type e2-medium --zone=$ZONE


echo ""
echo "======================================"
echo "✅ VM '$INSTANCE_NAME' created successfully!"
echo "🌐 Access the NGINX welcome page at: http://$EXTERNAL_IP"
echo "======================================"
