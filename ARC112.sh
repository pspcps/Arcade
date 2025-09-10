#!/bin/bash
set -euo pipefail

read -p "Enter the message to display in your app [default: Welcome to this world!]: " MESSAGE
MESSAGE=${MESSAGE:-Welcome to this world!}

function enable_api_with_retry() {
  local api=$1
  local retries=5
  local wait=10
  local count=0
  until gcloud services enable "$api" --quiet; do
    count=$((count+1))
    if [ $count -ge $retries ]; then
      echo "Failed to enable $api after $retries attempts"
      exit 1
    fi
    echo "Retrying to enable $api ($count/$retries)..."
    sleep $wait
  done
}

function deploy_with_retry() {
  local retries=3
  local wait=15
  local count=0
  until gcloud app deploy --quiet; do
    count=$((count+1))
    if [ $count -ge $retries ]; then
      echo "Deployment failed after $retries attempts"
      exit 1
    fi
    echo "Retrying deployment ($count/$retries)..."
    sleep $wait
  done
}

export MESSAGE

export ZONE="$(gcloud compute instances list --project=$DEVSHELL_PROJECT_ID --format='value(ZONE)')"
export REGION=${ZONE%-*}

enable_api_with_retry appengine.googleapis.com

echo "Waiting 10 seconds for API enablement..."
sleep 10

echo "ZONE: $ZONE"
echo "REGION: $REGION"

gcloud compute ssh "lab-setup" --zone=$ZONE --project=$DEVSHELL_PROJECT_ID --quiet --command "git clone https://github.com/GoogleCloudPlatform/python-docs-samples.git"

git clone https://github.com/GoogleCloudPlatform/python-docs-samples.git
cd python-docs-samples/appengine/standard_python3/hello_world

sed -i "32c\    return \"$MESSAGE\"" main.py

if [ "$REGION" == "us-east" ]; then
  REGION="us-east1"
fi

if ! gcloud app describe --project=$DEVSHELL_PROJECT_ID &> /dev/null; then
  echo "Creating App Engine app in $REGION"
  gcloud app create --region=$REGION
fi

deploy_with_retry

gcloud compute ssh "lab-setup" --zone=$ZONE --project=$DEVSHELL_PROJECT_ID --quiet --command "git clone https://github.com/GoogleCloudPlatform/python-docs-samples.git"
