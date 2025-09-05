#!/bin/bash

# Exit immediately on error
set -e

echo "=============================="
echo "🚀 Cloud Run Deployment Script"
echo "=============================="

# === 🧠 Ask for Region ===
read -p "📍 Enter the deployment region (e.g., us-central1, europe-west4): " REGION
if [[ -z "$REGION" ]]; then
  echo "❌ Region is required. Exiting."
  exit 1
fi

# === 🔧 Environment Setup ===
export PROJECT_ID=$(gcloud config get-value project)
export AR_REPO='chat-app-repo'
export SERVICE_NAME='chat-flask-app'

echo "🔧 Using:"
echo "   ➤ Project: $PROJECT_ID"
echo "   ➤ Region:  $REGION"
echo "   ➤ Repo:    $AR_REPO"
echo "   ➤ Service: $SERVICE_NAME"

# === 🛠️ Step 1: Download Source Code ===
echo "📥 Downloading source code from Cloud Storage..."
gsutil cp -R gs://spls/gsp1201/chat-flask-cloudrun .

cd chat-flask-cloudrun
echo "📁 Entered project directory: $(pwd)"

# === 🗃️ Step 2: Create Artifact Registry ===
echo "📦 Creating Artifact Registry (if not exists)..."
gcloud artifacts repositories create "$AR_REPO" \
  --location="$REGION" \
  --repository-format=Docker || echo "ℹ️ Repo may already exist."

# === 🐳 Step 3: Build & Push Docker Image ===
echo "🔐 Configuring Docker authentication..."
gcloud auth configure-docker "$REGION-docker.pkg.dev" --quiet

echo "🐳 Building and pushing Docker image..."
gcloud builds submit --tag "$REGION-docker.pkg.dev/$PROJECT_ID/$AR_REPO/$SERVICE_NAME"

# === ☁️ Step 4: Deploy to Cloud Run ===
echo "🚀 Deploying to Cloud Run..."
gcloud run deploy "$SERVICE_NAME" \
  --port=8080 \
  --image="$REGION-docker.pkg.dev/$PROJECT_ID/$AR_REPO/$SERVICE_NAME:latest" \
  --allow-unauthenticated \
  --region="$REGION" \
  --platform=managed \
  --project="$PROJECT_ID" \
  --set-env-vars=GCP_PROJECT="$PROJECT_ID",GCP_REGION="$REGION"

echo ""
echo "✅ Deployment complete!"
echo "🌐 Open the service URL printed above to test the application."
