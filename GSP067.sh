#!/bin/bash
set -euo pipefail

# --------------------------
# Function: Retry API enabling
# --------------------------
enable_api_with_retry() {
  local api=$1
  local retries=5
  local wait=5
  local count=0
  until gcloud services enable "$api" --quiet; do
    count=$((count+1))
    if [ $count -ge $retries ]; then
      echo "❌ Failed to enable $api after $retries attempts"
      exit 1
    fi
    echo "🔁 Retrying to enable $api ($count/$retries)..."
    sleep $wait
  done
}

# --------------------------
# Auth Check
# --------------------------
echo "🔐 Checking authenticated accounts..."
gcloud auth list

# --------------------------
# Enable App Engine API
# --------------------------
echo "⚙️ Enabling App Engine Admin API..."
enable_api_with_retry appengine.googleapis.com

# --------------------------
# Set ZONE and REGION
# --------------------------
echo "📍 Fetching zone and region from project metadata..."
ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])" || true)

if [[ -z "$ZONE" ]]; then
  read -p "⚠️ Default zone not found. Please enter your compute zone (e.g., us-central1-a): " ZONE
  if [[ -z "$ZONE" ]]; then
    echo "❌ Zone is required to continue."
    exit 1
  fi
fi

REGION="${ZONE%-*}"
echo "✅ Zone: $ZONE"
echo "✅ Derived Region: $REGION"

# --------------------------
# Set gcloud config values
# --------------------------
PROJECT_ID=$(gcloud config get-value project)
if [[ -z "$PROJECT_ID" ]]; then
  echo "❌ Project ID not found. Please set it using 'gcloud config set project PROJECT_ID'"
  exit 1
fi

echo "🔧 Setting gcloud configurations..."
gcloud config set project "$PROJECT_ID"
gcloud config set compute/zone "$ZONE"
gcloud config set compute/region "$REGION"

# --------------------------
# Clone sample repo (if needed)
# --------------------------
if [[ ! -d "python-docs-samples" ]]; then
  echo "📥 Cloning Python sample app..."
  git clone https://github.com/GoogleCloudPlatform/python-docs-samples.git
fi

cd python-docs-samples/appengine/standard_python3/hello_world

# --------------------------
# Modify app content
# --------------------------
echo "✏️ Updating app message..."
sed -i 's/Hello World!/Hello, Cruel World!/g' main.py

# --------------------------
# Create App Engine app (if not already created)
# --------------------------
if gcloud app describe --project="$PROJECT_ID" &> /dev/null; then
  echo "✅ App Engine app already exists in this project."
else
  echo "🚀 Creating App Engine app in region: $REGION..."
  gcloud app create --region="$REGION"
fi

# --------------------------
# Deploy with retry logic
# --------------------------
deploy_with_retry() {
  local retries=3
  local wait=10
  local count=0
  until gcloud app deploy --quiet; do
    count=$((count+1))
    if [ $count -ge $retries ]; then
      echo "❌ Deployment failed after $retries attempts"
      exit 1
    fi
    echo "🔁 Retrying deployment ($count/$retries)..."
    sleep $wait
  done
}

echo "🚀 Deploying App Engine application..."
deploy_with_retry

echo "✅ Deployment complete."
gcloud app browse
