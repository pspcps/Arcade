#!/bin/bash

VM_NAME="speaking-with-a-webpage"
IMAGE_PROJECT="debian-cloud"
IMAGE_FAMILY="debian-11"
MACHINE_TYPE="e2-medium"

read -p "Enter the zone (e.g. us-central1-b): " ZONE
read -p "Press Enter to create VM and start Task 3, or type '4' to run Task 4 on existing VM: " STEP

function create_firewall_and_vm() {
  echo "Checking firewall rule..."
  if ! gcloud compute firewall-rules describe dev-ports &>/dev/null; then
    gcloud compute firewall-rules create dev-ports --allow=tcp:8443 --source-ranges=0.0.0.0/0 --target-tags=http-server,https-server
  fi

  echo "Checking VM..."
  if ! gcloud compute instances describe "$VM_NAME" --zone="$ZONE" &>/dev/null; then
    gcloud compute instances create "$VM_NAME" --zone="$ZONE" --machine-type="$MACHINE_TYPE" \
      --image-family="$IMAGE_FAMILY" --image-project="$IMAGE_PROJECT" --boot-disk-type=pd-balanced \
      --boot-disk-size=10GB --tags=http-server,https-server --scopes=https://www.googleapis.com/auth/cloud-platform \
      --metadata=enable-oslogin=TRUE --no-shielded-secure-boot --quiet
  fi

  echo "Waiting for VM to be ready..."
  sleep 20

  echo "Installing dependencies & cloning repo..."
  gcloud compute ssh "$VM_NAME" --zone="$ZONE" --command="
    sudo apt-get update -y &&
    sudo apt-get install -y git maven openjdk-11-jdk &&
    if [ ! -d speaking-with-a-webpage ]; then
      git clone https://github.com/googlecodelabs/speaking-with-a-webpage.git
    else
      echo 'Repo exists.'
    fi
  "

  EXTERNAL_IP=$(gcloud compute instances describe "$VM_NAME" --zone="$ZONE" --format='get(networkInterfaces[0].accessConfigs[0].natIP)')
  echo "External IP: $EXTERNAL_IP"

  echo "Starting Task 3 server in background..."
  gcloud compute ssh "$VM_NAME" --zone="$ZONE" --command="
    pkill -f 'jetty:run' || true
    cd speaking-with-a-webpage/01-hello-https
    nohup mvn clean jetty:run > jetty.log 2>&1 &
    echo \$! > jetty.pid
  "

  echo "Task 3 started. Open https://$EXTERNAL_IP:8443"
  echo "Run 'gcloud compute ssh $VM_NAME --zone=$ZONE' to connect to VM."
}

function run_task_4() {
  EXTERNAL_IP=$(gcloud compute instances describe "$VM_NAME" --zone="$ZONE" --format='get(networkInterfaces[0].accessConfigs[0].natIP)')
  if [ -z "$EXTERNAL_IP" ]; then
    echo "Cannot get external IP. Is VM running?"
    exit 1
  fi

  echo "Stopping any running Jetty servers..."
  gcloud compute ssh "$VM_NAME" --zone="$ZONE" --command="
    if [ -f jetty.pid ]; then
      kill \$(cat jetty.pid) && rm jetty.pid
      echo 'Stopped old Jetty server.'
    fi
    pkill -f 'jetty:run' || true
  "

  echo "Starting Task 4 server in background..."
  gcloud compute ssh "$VM_NAME" --zone="$ZONE" --command="
    cd speaking-with-a-webpage/02-webaudio
    nohup mvn clean jetty:run > jetty.log 2>&1 &
    echo \$! > jetty.pid
  "

  echo "Task 4 started. Open https://$EXTERNAL_IP:8443"
}

if [ "$STEP" == "4" ]; then
  run_task_4
else
  create_firewall_and_vm
fi
