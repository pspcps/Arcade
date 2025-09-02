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
#!/bin/bash

echo "🚀 Creating VM '$VM_NAME' in zone '$ZONE'..."

# Create firewall rule for port 8443 if it doesn't exist
if ! gcloud compute firewall-rules describe dev-ports &>/dev/null; then
  echo "🌐 Creating firewall rule 'dev-ports' to allow TCP:8443 from 0.0.0.0/0..."
  gcloud compute firewall-rules create dev-ports \
    --allow=tcp:8443 \
    --source-ranges=0.0.0.0/0 \
    --target-tags=http-server,https-server
else
  echo "🔒 Firewall rule 'dev-ports' already exists, skipping creation."
fi


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


# Wait for VM to be ready
echo "⏳ Waiting 30 seconds for VM to initialize..."
sleep 30

# Get External IP
EXTERNAL_IP=$(gcloud compute instances describe "$VM_NAME" --zone="$ZONE" --format='get(networkInterfaces[0].accessConfigs[0].natIP)')
echo "🌍 External IP address: $EXTERNAL_IP"

echo "🚪 Connecting to VM via SSH to finish setup..."

# Run commands on VM via SSH: start Task 3 server in background
gcloud compute ssh "$VM_NAME" --zone="$ZONE" --command="
  # Make sure Java 11 is default
  sudo update-alternatives --set java /usr/lib/jvm/java-11-openjdk-amd64/bin/java || true

  # Go to project directory
  cd speaking-with-a-webpage/01-hello-https

  # Run the Jetty server in background with nohup
  nohup mvn clean jetty:run > jetty.log 2>&1 &

  echo \$! > jetty.pid
"

echo "🟢 Jetty server for Task 3 started on VM."

echo ""
echo "👉 Open your browser and visit: https://$EXTERNAL_IP:8443"
echo "⚠️ Your browser will warn about the self-signed SSL certificate — this is expected."
echo ""
read -p "✅ After confirming the servlet is working and you've checked your progress in the lab, press Enter to continue to Task 4..."

# Stop Task 3 Jetty server
gcloud compute ssh "$VM_NAME" --zone="$ZONE" --command="
  if [ -f jetty.pid ]; then
    kill \$(cat jetty.pid) && rm jetty.pid
    echo '✅ Task 3 Jetty server stopped.'
  else
    echo 'No jetty.pid file found, nothing to stop.'
  fi
"

# Start Task 4 (02-webaudio)
gcloud compute ssh "$VM_NAME" --zone="$ZONE" --command="
  cd speaking-with-a-webpage/02-webaudio
  nohup mvn clean jetty:run > jetty.log 2>&1 &
  echo \$! > jetty.pid
"

echo ""
echo "🟢 Jetty server for Task 4 started on VM."
echo "👉 Open your browser and visit: https://$EXTERNAL_IP:8443"
echo ""
read -p "✅ After confirming the Task 4 servlet is working and you've checked your progress in the lab, press Enter to finish..."

echo ""
echo "🎉 Lab completed! Remember to stop the server when you're done by running:"
echo "   kill \$(cat jetty.pid)  # on the VM"
echo ""
echo "Script completed."