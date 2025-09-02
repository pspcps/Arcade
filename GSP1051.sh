#!/bin/bash

echo "=== 🧠 OmegaTrade Backend Deployment Script ==="

# Automatically get active project ID
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)

if [ -z "$PROJECT_ID" ]; then
  echo "❌ No active GCP project found. Set one using:"
  echo "    gcloud config set project [PROJECT_ID]"
  exit 1
fi

echo "✅ Using Project ID: $PROJECT_ID"

# Ask user for Cloud Run region
read -p "📍 Enter the Cloud Run region (e.g. us-central1): " REGION

# --- Step 1: Enable Required APIs ---
echo "⏳ Enabling required Google Cloud APIs..."
gcloud services enable \
  spanner.googleapis.com \
  artifactregistry.googleapis.com \
  containerregistry.googleapis.com \
  run.googleapis.com

# --- Step 2: Clone the Repo ---
echo "📦 Cloning the OmegaTrade app repository..."
git clone https://github.com/GoogleCloudPlatform/training-data-analyst

cd training-data-analyst/courses/cloud-spanner/omegatrade/ || {
  echo "❌ Failed to access repo directory."
  exit 1
}

# --- Step 3: Create .env File ---
echo "🛠️ Creating .env file for backend..."
cd backend || { echo "❌ 'backend' folder not found."; exit 1; }

cat <<EOF > .env
PROJECTID=${PROJECT_ID}
INSTANCE=omegatrade-instance
DATABASE=omegatrade-db
JWT_KEY=w54p3Y?4dj%8Xqa2jjVC84narhe5Pk
EXPIRE_IN=30d
EOF

# --- Step 4: Set Up Node & Install Dependencies ---
echo "📦 Setting up Node.js and installing dependencies..."
nvm install 22.6
npm install npm -g
npm install --loglevel=error

# --- Step 5: Build Docker Image ---
echo "🐳 Building Docker image..."
docker build -t gcr.io/${PROJECT_ID}/omega-trade/backend:v1 -f dockerfile.prod .

# --- Step 6: Auth Docker with GCP ---
echo "🔐 Configuring Docker authentication with GCP..."
gcloud auth configure-docker

# --- Step 7: Push Docker Image ---
echo "📤 Pushing Docker image to Google Container Registry..."
docker push gcr.io/${PROJECT_ID}/omega-trade/backend:v1

# --- Step 8: Deploy to Cloud Run ---
echo "🚀 Deploying backend to Cloud Run..."
BACKEND_URL=$(gcloud run deploy omegatrade-backend \
  --platform managed \
  --region "${REGION}" \
  --image gcr.io/${PROJECT_ID}/omega-trade/backend:v1 \
  --memory 512Mi \
  --allow-unauthenticated \
  --quiet \
  --format="value(status.url)")

# --- Step 9: Import Sample Data ---
echo "🗃️ Importing sample data into Cloud Spanner..."
unset SPANNER_EMULATOR_HOST
node seed-data.js

# --- Finish ---
echo "✅ OmegaTrade backend deployed successfully!"
echo "🌐 Backend URL: $BACKEND_URL"
