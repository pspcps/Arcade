#!/bin/bash

set -e

VM_NAME="speaking-with-a-webpage"
IMAGE_FAMILY="debian-11"
IMAGE_PROJECT="debian-cloud"
FIREWALL_NAME="dev-ports"

read -p "Enter the Compute Engine Zone (e.g. us-central1-a): " ZONE

echo "🚀 Creating VM '$VM_NAME' in zone '$ZONE'..."

# Create the VM with necessary scopes and firewall access
gcloud compute instances create "$VM_NAME" \
    --zone="$ZONE" \
    --image-family="$IMAGE_FAMILY" \
    --image-project="$IMAGE_PROJECT" \
    --machine-type=e2-medium \
    --boot-disk-size=10GB \
    --scopes=https://www.googleapis.com/auth/cloud-platform \
    --tags=http-server,https-server
    
echo "✅ VM created successfully."

# Add HTTP/HTTPS access to firewall
echo "🌐 Adding firewall rules for ports 80 and 443 (HTTP/HTTPS)..."

gcloud compute instances add-tags "$VM_NAME" \
    --zone="$ZONE" \
    --tags=http-server,https-server

# Firewall rule for port 8443 (used by the lab)
echo "🌐 Checking for firewall rule '$FIREWALL_NAME'..."

if ! gcloud compute firewall-rules describe "$FIREWALL_NAME" &>/dev/null; then
    gcloud compute firewall-rules create "$FIREWALL_NAME" \
        --allow=tcp:8443 \
        --source-ranges=0.0.0.0/0 \
        --target-tags=http-server
    echo "✅ Firewall rule '$FIREWALL_NAME' created."
else
    echo "⚠️ Firewall rule '$FIREWALL_NAME' already exists. Skipping."
fi

# SSH and install dependencies
echo "🔧 Connecting to VM via SSH to install dependencies..."

gcloud compute ssh "$VM_NAME" --zone="$ZONE" --command="\
    sudo apt update && \
    sudo apt install -y git maven openjdk-11-jdk && \
    git clone https://github.com/googlecodelabs/speaking-with-a-webpage.git"

echo "✅ Dependencies installed and repo cloned."

# Get external IP
EXTERNAL_IP=$(gcloud compute instances describe "$VM_NAME" \
    --zone="$ZONE" \
    --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

echo ""
echo "🎉 VM setup is complete!"
echo "➡️ You can SSH into the VM again anytime:"
echo "   gcloud compute ssh $VM_NAME --zone $ZONE"
echo ""
echo "➡️ Run the Java servlet:"
echo "   cd speaking-with-a-webpage/01-hello-https"
echo "   mvn clean jetty:run"
echo ""
echo "🌐 Open your browser and visit:"
echo "   https://$EXTERNAL_IP:8443"
echo ""
echo "⚠️ You may see a warning due to self-signed cert. Proceed anyway."
