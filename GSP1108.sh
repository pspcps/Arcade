#!/bin/bash

set -euo pipefail

echo "=== Compute Engine Apache Monitoring + Alerting Setup Script ==="

# Ask user for zone
read -rp "Enter the GCP zone to create the VM (e.g., europe-west1-b): " ZONE

# Set variables
PROJECT_ID=$(gcloud config get-value project)
VM_NAME="quickstart-vm"
MACHINE_TYPE="e2-small"
IMAGE_FAMILY="debian-11"
IMAGE_PROJECT="debian-cloud"
DISK_TYPE="pd-balanced"
DISK_SIZE="20GB"

# Check if VM already exists
if gcloud compute instances describe "$VM_NAME" --zone="$ZONE" &> /dev/null; then
  echo "VM instance '$VM_NAME' already exists in zone '$ZONE'. Skipping creation."
else
  # Create the VM instance
  echo "Creating VM instance '$VM_NAME' in zone '$ZONE'..."
  gcloud compute instances create "$VM_NAME" \
    --zone="$ZONE" \
    --machine-type="$MACHINE_TYPE" \
    --image-family="$IMAGE_FAMILY" \
    --image-project="$IMAGE_PROJECT" \
    --boot-disk-type="$DISK_TYPE" \
    --boot-disk-size="$DISK_SIZE" \
    --tags=http-server,https-server

  echo "Waiting for VM to start..."
  sleep 15
fi

# Get external IP
EXTERNAL_IP=$(gcloud compute instances describe "$VM_NAME" --zone="$ZONE" --format="get(networkInterfaces[0].accessConfigs[0].natIP)")
echo "VM External IP: $EXTERNAL_IP"

# Install Apache with error handling
echo "Installing Apache web server (if not already installed)..."
gcloud compute ssh "$VM_NAME" --zone="$ZONE" --command='
  set -e

  # Check if apache2 is installed
  if dpkg -s apache2 >/dev/null 2>&1; then
    echo "Apache is already installed."
  else
    echo "Updating packages and installing Apache and PHP..."
    sudo apt-get update

    sudo apt-get install -y apache2 php || sudo apt-get install -y apache2 php7.0
  fi

  echo "Trying to restart Apache using systemctl..."
  if ! sudo systemctl restart apache2; then
    echo "systemctl failed. Attempting to recover..."
    sudo mount -o remount,rw /
    sudo reboot
  fi
'

# Confirm Task 2 success before proceeding
while true; do
  read -rp "Has Apache been installed and is running correctly? (yes/no): " yn
  case $yn in
    [Yy]* ) break ;;
    [Nn]* ) echo "Please fix Apache installation and start before proceeding. Exiting."; exit 1 ;;
    * ) echo "Please answer yes or no." ;;
  esac
done

# Install and configure the Ops Agent
echo "Installing Google Cloud Ops Agent and configuring for Apache..."
gcloud compute ssh "$VM_NAME" --zone="$ZONE" --command='
  set -e

  echo "Installing Ops Agent..."
  curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
  sudo bash add-google-cloud-ops-agent-repo.sh --also-install

  echo "Backing up existing Ops Agent config (if any)..."
  sudo cp /etc/google-cloud-ops-agent/config.yaml /etc/google-cloud-ops-agent/config.yaml.bak || true

  echo "Writing Apache telemetry config..."
  sudo tee /etc/google-cloud-ops-agent/config.yaml > /dev/null <<EOF
metrics:
  receivers:
    apache:
      type: apache
  service:
    pipelines:
      apache:
        receivers: [apache]
logging:
  receivers:
    apache_access:
      type: apache_access
    apache_error:
      type: apache_error
  service:
    pipelines:
      apache:
        receivers: [apache_access, apache_error]
EOF

  echo "Restarting Ops Agent..."
  sudo service google-cloud-ops-agent restart

  echo "Waiting 60 seconds for metrics to be collected..."
  sleep 60
'

# Generate traffic
echo "Generating traffic to Apache server..."
gcloud compute ssh "$VM_NAME" --zone="$ZONE" --command="timeout 120 bash -c -- 'while true; do curl localhost; sleep \$((RANDOM % 4)); done'"

echo
echo "✅ Apache and Ops Agent configured. Visit: http://$EXTERNAL_IP"

# -------------------------------
# 🔔 Create Alerting Policy
# -------------------------------

echo "Creating alerting policy..."

# Get the first email notification channel ID
NOTIF_CHANNEL=$(gcloud monitoring channels list --format="value(name)" --filter="type=email" | head -n 1 || true)

if [[ -z "$NOTIF_CHANNEL" ]]; then
  echo "❌ No email notification channel found. Please create one in the Monitoring > Alerting > Notification channels."
  exit 1
fi

cat > alert-policy.yaml <<EOF
displayName: "Apache traffic above threshold"
combiner: "OR"
conditions:
  - displayName: "Apache traffic > 4000 bytes/sec"
    conditionThreshold:
      filter: 'metric.type="workload.googleapis.com/apache.traffic" resource.type="gce_instance"'
      comparison: "COMPARISON_GT"
      thresholdValue: 4000
      duration: "60s"
      trigger:
        count: 1
alertStrategy:
  autoClose: "1800s"
notificationChannels:
  - $NOTIF_CHANNEL
enabled: true
EOF

# Create the policy
gcloud alpha monitoring policies create --policy-from-file=alert-policy.yaml
rm alert-policy.yaml

echo
echo "✅ Alerting policy created: Apache traffic > 4000 bytes/sec"
echo "📧 Notifications will be sent to your configured email channel."

echo
echo "🎉 Setup complete!"
