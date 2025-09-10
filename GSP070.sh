#!/bin/bash
set -euo pipefail

# Function to enable an API with retries
function enable_api_with_retry() {
  local api=$1
  local retries=5
  local wait=10
  local count=0
  until gcloud services enable "$api" --quiet; do
    count=$((count+1))
    if [ $count -ge $retries ]; then
      echo "❌ Failed to enable $api after $retries attempts"
      exit 1
    fi
    echo "🔄 Retrying to enable $api ($count/$retries)..."
    sleep $wait
  done
}

# Prompt user for region
read -p "Enter the region to deploy your App Engine app [default: us-central]: " USER_REGION
REGION=${USER_REGION:-us-central}

# Set compute region
echo "✅ Setting region: $REGION"
gcloud config set compute/region "$REGION"

# Enable App Engine API
echo "⚙️ Enabling App Engine Admin API..."
enable_api_with_retry appengine.googleapis.com

# Wait for propagation
sleep 10

# Clone sample app
git clone https://github.com/GoogleCloudPlatform/golang-samples.git
cd golang-samples/appengine/go11x/helloworld

# Ensure App Engine Go component is installed
if ! gcloud components list --filter="app-engine-go" --format="value(state.name)" | grep -q "Installed"; then
  echo "📦 Installing App Engine Go SDK..."
  sudo apt-get update
  sudo apt-get install -y google-cloud-sdk-app-engine-go
else
  echo "✅ App Engine Go SDK is already installed."
fi

# Get project ID
PROJECT_ID=$(gcloud config get-value project)
echo "🔧 Using project: $PROJECT_ID"

# Create App Engine app if needed
if gcloud app describe --project="$PROJECT_ID" &> /dev/null; then
  echo "✅ App Engine app already exists."
else
  echo "🚀 Creating App Engine app in $REGION..."
  gcloud app create --project="$PROJECT_ID" --region="$REGION"
fi

# Retry deployment if needed
function deploy_with_retry() {
  local retries=3
  local wait=15
  local count=0
  until gcloud app deploy --project="$PROJECT_ID" --quiet; do
    count=$((count+1))
    if [ $count -ge $retries ]; then
      echo "❌ Deployment failed after $retries attempts"
      exit 1
    fi
    echo "🔄 Retrying deployment ($count/$retries)..."
    sleep $wait
  done
}

echo "🚀 Deploying Go App Engine app..."
deploy_with_retry

# Browse the app
gcloud app browse
