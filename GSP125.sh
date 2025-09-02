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

echo "🌐 Checking if firewall rule 'dev-ports' exists..."
if ! gcloud compute firewall-rules describe dev-ports &>/dev/null; then
  echo "🌐 Creating firewall rule 'dev-ports' to allow TCP:8443 from 0.0.0.0/0..."
  gcloud compute firewall-rules create dev-ports \
    --allow=tcp:8443 \
    --source-ranges=0.0.0.0/0 \
    --target-tags=http-server,https-server
else
  echo "🔒 Firewall rule 'dev-ports' already exists, skipping creation."
fi

echo "🚀 Checking if VM '$VM_NAME' exists in zone '$ZONE'..."
if ! gcloud compute instances describe "$VM_NAME" --zone="$ZONE" &>/dev/null; then
  echo "🚀 Creating VM '$VM_NAME'..."
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
else
  echo "🖥️ VM '$VM_NAME' already exists, skipping creation."
fi

echo "⏳ Waiting a bit for VM to be ready..."
sleep 20

# Install required packages and clone repo via SSH
echo "🔧 Installing dependencies and cloning repo on VM..."
gcloud compute ssh "$VM_NAME" --zone="$ZONE" --command="
  sudo apt-get update -y &&
  sudo apt-get install -y git maven openjdk-11-jdk &&
  if [ ! -d speaking-with-a-webpage ]; then
    git clone https://github.com/googlecodelabs/speaking-with-a-webpage.git
  else
    echo 'Repo already cloned, skipping.'
  fi
"

# Get External IP
EXTERNAL_IP=$(gcloud compute instances describe "$VM_NAME" --zone="$ZONE" --format='get(networkInterfaces[0].accessConfigs[0].natIP)')
echo "🌍 External IP address: $EXTERNAL_IP"

echo ""
echo "🚪 Starting Task 3: Jetty server (01-hello-https)."
echo "👉 Your browser: https://$EXTERNAL_IP:8443"
echo "⚠️ You will see a security warning due to a self-signed SSL certificate."
echo ""
echo "This SSH session will run the Jetty server in the foreground."
echo "Use CTRL+C to stop the server when done testing Task 3."
echo ""

# Run Task 3 Jetty server in foreground
gcloud compute ssh "$VM_NAME" --zone="$ZONE" --command="
  cd speaking-with-a-webpage/01-hello-https &&
  mvn clean jetty:run
"

echo ""
read -p "✅ Task 3 completed. Press Enter to start Task 4..."

echo ""
echo "🚪 Starting Task 4: Jetty server (02-webaudio)."
echo "👉 Your browser: https://$EXTERNAL_IP:8443"
echo "⚠️ You will see a security warning due to a self-signed SSL certificate."
echo ""
echo "This SSH session will run the Jetty server in the foreground."
echo "Use CTRL+C to stop the server when done testing Task 4."
echo ""

# Run Task 4 Jetty server in foreground
gcloud compute ssh "$VM_NAME" --zone="$ZONE" --command="
  cd speaking-with-a-webpage/02-webaudio &&
  mvn clean jetty:run
"

echo ""
echo "🎉 Lab complete! Remember to stop any running servers by exiting the SSH session."
echo ""
