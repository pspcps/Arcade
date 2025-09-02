#!/bin/bash

# Exit on any error
set -e

# Constants
VM_NAME="speaking-with-a-webpage"
IMAGE_PROJECT="debian-cloud"
IMAGE_FAMILY="debian-11"
MACHINE_TYPE="e2-medium"

# Prompt for user input
read -p "Enter the zone (e.g. us-central1-b): " ZONE

# Step 1: Create the VM
echo "🚀 Creating VM '$VM_NAME' in zone '$ZONE'..."
gcloud compute instances create "$VM_NAME" \
  --zone="$ZONE" \
  --machine-type="$MACHINE_TYPE" \
  --image-family="$IMAGE_FAMILY" \
  --image-project="$IMAGE_PROJECT" \
  --boot-disk-type=pd-balanced \
  --boot-disk-size=10GB \
  --tags=http-server,https-server \
  --scopes=https://www.googleapis.com/auth/cloud-platform \
  --metadata=enable-oslogin=TRUE \
  --no-shielded-secure-boot \
  --quiet

# Wait for instance to be fully ready
echo "⏳ Waiting for instance to be ready..."
sleep 15

# Step 2: SSH and install dependencies
echo "🔧 Installing packages via SSH..."
gcloud compute ssh "$VM_NAME" --zone="$ZONE" --command="\
  sudo apt-get update -y && \
  sudo apt-get install -y git maven openjdk-11-jdk && \
  git clone https://github.com/googlecodelabs/speaking-with-a-webpage.git"

# Step 3: Open firewall port 8443
echo "🌐 Configuring firewall for port 8443..."
gcloud compute firewall-rules create dev-ports \
  --allow=tcp:8443 \
  --source-ranges=0.0.0.0/0 \
  --target-tags=http-server \
  --quiet || echo "Firewall rule 'dev-ports' may already exist."

# Completion message
echo "✅ Setup complete!"
echo "👉 Go to your Google Cloud Console to find the external IP."
echo "Then open: https://<your-external-ip>:8443 after running the servlet."
