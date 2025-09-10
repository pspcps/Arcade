#!/bin/bash
set -euo pipefail

# Function to enable API with retries
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

# Show authenticated accounts
echo "🔐 Authenticated accounts:"
gcloud auth list

# Enable App Engine Admin API with retry
echo "⚙️ Enabling App Engine Admin API..."
enable_api_with_retry appengine.googleapis.com

# Get zone and region
echo "📍 Fetching default zone and region..."
export ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-region])")

if [[ -z "$ZONE" || -z "$REGION" ]]; then
  echo "❌ Default zone or region not set in project metadata."
  exit 1
fi

echo "✅ ZONE: $ZONE"
echo "✅ REGION: $REGION"

# Set compute region in gcloud config
gcloud config set compute/region "$REGION"

# Get current project ID
export PROJECT_ID=$(gcloud config get-value project)
echo "🔧 Project ID: $PROJECT_ID"

# Clone sample app
echo "📥 Cloning PHP sample app..."
git clone https://github.com/GoogleCloudPlatform/php-docs-samples.git

cd php-docs-samples/appengine/standard/helloworld

# Check if App Engine app already exists before creating
if gcloud app describe --project="$PROJECT_ID" &> /dev/null; then
  echo "✅ App Engine app already exists in project."
else
  echo "🚀 Creating App Engine app in $REGION..."
  gcloud app create --project="$PROJECT_ID" --region="$REGION"
fi

# Deploy with retries
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

echo "🚀 Deploying App Engine app..."
deploy_with_retry

# Open app in browser
echo "🌐 Opening app in browser..."
gcloud app browse
