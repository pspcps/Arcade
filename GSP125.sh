#!/bin/bash

# Ask for Zone input
read -p "Enter the zone (e.g. us-central1-b): " ZONE

# Constants
VM_NAME="speaking-with-a-webpage"
MACHINE_TYPE="e2-medium"
IMAGE_FAMILY="debian-11"
IMAGE_PROJECT="debian-cloud"

echo "🚀 Creating VM '$VM_NAME' in zone '$ZONE'..."

# Create the VM
if ! gcloud compute instances create "$VM_NAME" \
  --zone="$ZONE" \
  --machine-type="$MACHINE_TYPE" \
  --image-family="$IMAGE_FAMILY" \
  --image-project="$IMAGE_PROJECT" \
  --tags=http-server,https-server \
  --boot-disk-size=10GB \
  --boot-disk-type=pd-balanced \
  --boot-disk-device-name="$VM_NAME" \
  --quiet \
  --no-shielded-secure-boot \
  --metadata=enable-oslogin=TRUE \
  --scopes=https://www.googleapis.com/auth/cloud-platform \
  --create-disk=auto-delete=yes,boot=yes,device-name="$VM_NAME",image=projects/$IMAGE_PROJECT/global/images/family/$IMAGE_FAMILY,type=pd-balanced;do
  echo "❌ VM creation failed. Exiting."
  exit 1
fi

echo "✅ VM '$VM_NAME' created successfully."

# Open firewall for port 8443
echo "🔓 Creating firewall rule to allow TCP traffic on port 8443..."
if ! gcloud compute firewall-rules create dev-ports \
  --allow=tcp:8443 \
  --source-ranges=0.0.0.0/0 \
  --target-tags=http-server,https-server \
  --quiet; then
  echo "⚠️ Firewall rule might already exist or failed to create."
else
  echo "✅ Firewall rule created."
fi

# Install packages and clone repo via SSH
echo "🔧 Connecting via SSH and setting up environment..."

gcloud compute ssh "$VM_NAME" --zone="$ZONE" --quiet --command="bash -s" <<'EOF'
  set -e
  echo "📦 Updating system and installing required packages..."
  sudo apt update -y && sudo apt install -y git maven openjdk-11-jdk

  echo "📥 Cloning speaking-with-a-webpage repository..."
  if [ -d "speaking-with-a-webpage" ]; then
    echo "⚠️ Directory already exists. Skipping clone."
  else
    git clone https://github.com/googlecodelabs/speaking-with-a-webpage.git
  fi

  echo "✅ Environment setup completed."
EOF

# Show external IP
EXTERNAL_IP=$(gcloud compute instances describe "$VM_NAME" --zone="$ZONE" --format='get(networkInterfaces[0].accessConfigs[0].natIP)')
echo "🌐 Access your app via: https://$EXTERNAL_IP:8443 (after running the servlet)"
echo ""

echo "📣 Next Steps (manual in SSH):"
echo "1. Run the servlet for Task 3:"
echo "   gcloud compute ssh $VM_NAME --zone=$ZONE"
echo "   cd ~/speaking-with-a-webpage/01-hello-https"
echo "   mvn clean jetty:run"
echo ""
echo "2. To test audio capture (Task 4):"
echo "   Press CTRL+C to stop previous servlet"
echo "   cd ~/speaking-with-a-webpage/02-webaudio"
echo "   mvn clean jetty:run"
echo ""
echo "📘 Note: You may need to accept the self-signed HTTPS certificate in your browser."
