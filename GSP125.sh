#!/bin/bash

# Constants
VM_NAME="speaking-with-a-webpage"
IMAGE_PROJECT="debian-cloud"
IMAGE_FAMILY="debian-11"
MACHINE_TYPE="e2-medium"

read -p "Enter the zone (e.g. us-central1-b): " ZONE
read -p "Press Enter to create VM and start Task 3, or type '4' to run Task 4 on existing VM: " STEP

EXTERNAL_IP=""

function create_firewall_and_vm() {
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

  gcloud compute ssh "$VM_NAME" --zone="$ZONE" --command="
    cd speaking-with-a-webpage/01-hello-https &&
    mvn clean jetty:run
  "
}

function run_task_4() {
  EXTERNAL_IP=$(gcloud compute instances describe "$VM_NAME" --zone="$ZONE" --format='get(networkInterfaces[0].accessConfigs[0].natIP)')
  if [ -z "$EXTERNAL_IP" ]; then
    echo "❌ Could not find external IP for VM '$VM_NAME' in zone '$ZONE'. Please make sure the VM exists."
    exit 1
  fi

  echo ""
  echo "🚪 Starting Task 4: Jetty server (02-webaudio)."
  echo "👉 Your browser: https://$EXTERNAL_IP:8443"
  echo "⚠️ You will see a security warning due to a self-signed SSL certificate."
  echo ""
  echo "This SSH session will run the Jetty server in the foreground."
  echo "Use CTRL+C to stop the server when done testing Task 4."
  echo ""

  gcloud compute ssh "$VM_NAME" --zone="$ZONE" --command="
    cd speaking-with-a-webpage/02-webaudio &&
    mvn clean jetty:run
  "
}

if [ "$STEP" == "4" ]; then
  run_task_4
else
  create_firewall_and_vm
fi
