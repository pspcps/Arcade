#!/bin/bash

set -euo pipefail

echo "=== Compute Engine Apache Monitoring Setup Script ==="

# Ask user for zone
read -rp "Enter the GCP zone to create the VM (e.g., europe-west1-c): " ZONE

# Set variables
VM_NAME="quickstart-vm"
MACHINE_TYPE="e2-small"
IMAGE_FAMILY="debian-11"
IMAGE_PROJECT="debian-cloud"

# Create the VM instance
echo "Creating VM instance '$VM_NAME' in zone '$ZONE'..."
gcloud compute instances create "$VM_NAME" \
  --zone="$ZONE" \
  --machine-type="$MACHINE_TYPE" \
  --image-family="$IMAGE_FAMILY" \
  --image-project="$IMAGE_PROJECT" \
  --boot-disk-type=pd-balanced \
  --boot-disk-size=20GB \
  --tags=http-server,https-server \
  --metadata=startup-script='#! /bin/bash
    apt-get update
    apt-get install -y apache2 php
    systemctl restart apache2
  '

echo "Waiting for VM to start..."
sleep 15

# Get external IP
EXTERNAL_IP=$(gcloud compute instances describe "$VM_NAME" --zone="$ZONE" --format="get(networkInterfaces[0].accessConfigs[0].natIP)")
echo "VM created. External IP: $EXTERNAL_IP"

# Connect via SSH to install Ops Agent and configure telemetry
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

# Generate traffic to Apache server
echo "Generating traffic to Apache server..."
gcloud compute ssh "$VM_NAME" --zone="$ZONE" --command="timeout 120 bash -c -- 'while true; do curl localhost; sleep \$((RANDOM % 4)); done'"

echo "Traffic generation complete."
echo "You can now visit: http://$EXTERNAL_IP to see the Apache web server (should say 'It works!')"
echo
echo "✅ VM, Apache, and Ops Agent are configured."

echo "🔔 Now create an alerting policy manually in Google Cloud Console:"
echo "1. Go to Monitoring > Alerting > Create Policy"
echo "2. Metric: Apache > workload/apache.traffic"
echo "3. Rolling window: 1 min, Function: rate"
echo "4. Threshold: Above 4000 bytes/sec"
echo "5. Add your email notification channel"
echo "6. Name the policy: Apache traffic above threshold"

echo
echo "Done!"
