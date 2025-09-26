#!/bin/bash
set -euo pipefail

echo "=== Compute Engine Apache Monitoring Setup Script ==="

# Ask user for zone
read -rp "Enter the GCP zone to create the VM (e.g., europe-west1-c): " ZONE

# Variables
VM_NAME="quickstart-vm"
MACHINE_TYPE="e2-small"
IMAGE_FAMILY="debian-12"
IMAGE_PROJECT="debian-cloud"

# Check and create firewall rules for HTTP and HTTPS
if ! gcloud compute firewall-rules describe default-allow-http &> /dev/null; then
  echo "Creating firewall rule to allow HTTP traffic..."
  gcloud compute firewall-rules create default-allow-http \
    --allow tcp:80 \
    --target-tags=http-server \
    --description="Allow HTTP traffic to VMs" \
    --direction=INGRESS
else
  echo "Firewall rule 'default-allow-http' already exists."
fi

if ! gcloud compute firewall-rules describe default-allow-https &> /dev/null; then
  echo "Creating firewall rule to allow HTTPS traffic..."
  gcloud compute firewall-rules create default-allow-https \
    --allow tcp:443 \
    --target-tags=https-server \
    --description="Allow HTTPS traffic to VMs" \
    --direction=INGRESS
else
  echo "Firewall rule 'default-allow-https' already exists."
fi

# Check if VM exists
if gcloud compute instances describe "$VM_NAME" --zone="$ZONE" &> /dev/null; then
  echo "VM '$VM_NAME' already exists in zone '$ZONE'. Proceeding..."
else
  echo "Creating VM instance '$VM_NAME' in zone '$ZONE'..."
  gcloud compute instances create "$VM_NAME" \
    --zone="$ZONE" \
    --machine-type="$MACHINE_TYPE" \
    --image-family="$IMAGE_FAMILY" \
    --image-project="$IMAGE_PROJECT" \
    --boot-disk-type=pd-balanced \
    --boot-disk-size=20GB \
    --tags=http-server,https-server
  echo "Waiting 15 seconds for VM to start..."
  sleep 15
fi

# Get external IP
EXTERNAL_IP=$(gcloud compute instances describe "$VM_NAME" --zone="$ZONE" --format="get(networkInterfaces[0].accessConfigs[0].natIP)")
echo "VM External IP: $EXTERNAL_IP"

# Install Apache separately to handle errors & confirm status
echo "Installing Apache2 and PHP on the VM..."
gcloud compute ssh "$VM_NAME" --zone="$ZONE" --command='
  set -e
  sudo apt-get update
  sudo apt-get install -y apache2 php || sudo apt-get install -y apache2 php7.0
  sudo systemctl restart apache2 || (
    echo "Restart failed, trying to remount filesystem and reboot..."
    sudo mount -o remount,rw /
    sudo reboot
  )
'

# Wait a little after reboot if reboot triggered
echo "Waiting 30 seconds to stabilize after install..."
sleep 30

# # Confirm Apache status interactively
# while true; do
#   echo "Please check if Apache is running on VM (http://$EXTERNAL_IP)."
#   read -rp "Is the Apache server running and displaying 'It works!'? (yes/no): " CONFIRM
#   if [[ "$CONFIRM" == "yes" ]]; then
#     break
#   else
#     echo "Retrying Apache install and restart..."
#     gcloud compute ssh "$VM_NAME" --zone="$ZONE" --command='
#       set -e
#       sudo systemctl restart apache2 || (
#         sudo mount -o remount,rw /
#         sudo reboot
#       )
#     '
#     sleep 30
#   fi
# done

echo "Apache confirmed running. Proceeding with Ops Agent installation..."

# Install Ops Agent and configure Apache telemetry
gcloud compute ssh "$VM_NAME" --zone="$ZONE" --command='
  set -e
  echo "Installing Google Cloud Ops Agent..."
  curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
  sudo bash add-google-cloud-ops-agent-repo.sh --also-install

  echo "Backing up existing Ops Agent config if exists..."
  sudo cp /etc/google-cloud-ops-agent/config.yaml /etc/google-cloud-ops-agent/config.yaml.bak || true

  echo "Configuring Ops Agent for Apache telemetry..."
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
  echo "Waiting 60 seconds for metrics collection..."
  sleep 60
'

# Generate traffic on Apache server
echo "Generating traffic to Apache server for 120 seconds..."
gcloud compute ssh "$VM_NAME" --zone="$ZONE" --command="timeout 120 bash -c -- 'while true; do curl localhost; sleep \$((RANDOM % 4)); done'"

echo "Traffic generation complete."

# Create alerting policy automatically
echo "Creating alerting policy for Apache traffic..."

PROJECT_ID=$(gcloud config get-value project)

gcloud monitoring policies create --project="$PROJECT_ID" --notification-channels="$(gcloud monitoring channels list --filter='type="email"' --format='value(name)' | head -n 1)" --notification-channel-coincidence-count=1 --notification-channel-parameters= \
  --policy='
{
  "displayName": "Apache traffic above threshold",
  "conditions": [
    {
      "displayName": "Apache traffic > 4000 bytes/sec",
      "conditionThreshold": {
        "filter": "metric.type=\"workload.googleapis.com/apache/traffic\" resource.type=\"gce_instance\"",
        "comparison": "COMPARISON_GT",
        "thresholdValue": 4000,
        "duration": "60s",
        "trigger": {
          "count": 1
        }
      }
    }
  ],
  "notificationChannels": [
    "'"$(gcloud monitoring channels list --filter='type="email"' --format='value(name)' | head -n 1) "'"
  ],
  "combiner": "OR",
  "enabled": true
}
'


echo
echo "✅ Setup complete!"
echo "Please Create alert policy as per mention in video"
echo "Check Cloud Monitoring for metrics and alerts."
