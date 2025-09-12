#!/bin/bash

# Retry Function
retry() {
  local retries=10
  local count=0
  local delay=5
  until "$@"; do
    exit_code=$?
    count=$((count + 1))
    if [ $count -lt $retries ]; then
      echo "Command failed. Attempt $count/$retries. Retrying in $delay seconds..."
      sleep $delay
    else
      echo "Command failed after $retries attempts."
      return $exit_code
    fi
  done
}

echo ""
echo "=================================================="
echo "        Cloud Run Monolith Deployment Script       "
echo "=================================================="
echo ""

# Step 1: Initial Setup
echo "Step 1: Initial Setup"
echo "Checking authentication and region..."
retry gcloud auth list

export REGION=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-region])")
echo "Region set to: $REGION"
echo ""

# Step 2: Clone Repository
echo "Step 2: Cloning Repository"
retry git clone https://github.com/googlecodelabs/monolith-to-microservices.git
cd ~/monolith-to-microservices

echo "Running setup script..."
retry ./setup.sh
echo ""

# Step 3: Artifact Registry Setup
echo "Step 3: Artifact Registry Setup"
cd ~/monolith-to-microservices/monolith

echo "Creating Artifact Registry repository..."
retry gcloud artifacts repositories create monolith-demo \
  --location=$REGION \
  --repository-format=docker \
  --description="Docker repository for monolith demo"

echo "Configuring Docker authentication..."
retry gcloud auth configure-docker $REGION-docker.pkg.dev
echo ""

# Step 4: Enable Required GCP Services
echo "Step 4: Enabling GCP Services"
retry gcloud services enable artifactregistry.googleapis.com \
    cloudbuild.googleapis.com \
    run.googleapis.com
echo ""

# Step 5: Initial Build and Deploy
echo "Step 5: Initial Build and Deploy"
echo "Building monolith image (v1.0.0)..."
retry gcloud builds submit --tag $REGION-docker.pkg.dev/${GOOGLE_CLOUD_PROJECT}/monolith-demo/monolith:1.0.0

echo "Deploying monolith to Cloud Run..."
retry gcloud run deploy monolith \
  --image $REGION-docker.pkg.dev/${GOOGLE_CLOUD_PROJECT}/monolith-demo/monolith:1.0.0 \
  --allow-unauthenticated \
  --region $REGION
echo ""

# Step 6: Concurrency Testing
echo "Step 6: Concurrency Testing"
echo "Testing with concurrency = 1..."
retry gcloud run deploy monolith \
  --image $REGION-docker.pkg.dev/${GOOGLE_CLOUD_PROJECT}/monolith-demo/monolith:1.0.0 \
  --allow-unauthenticated \
  --region $REGION \
  --concurrency 1

echo "Testing with concurrency = 80..."
retry gcloud run deploy monolith \
  --image $REGION-docker.pkg.dev/${GOOGLE_CLOUD_PROJECT}/monolith-demo/monolith:1.0.0 \
  --allow-unauthenticated \
  --region $REGION \
  --concurrency 80
echo ""

# Step 7: Frontend Update
echo "Step 7: Frontend Update"
cd ~/monolith-to-microservices/react-app/src/pages/Home
mv index.js.new index.js
cat index.js
echo ""

# Step 8: Rebuild and Redeploy
echo "Step 8: Rebuild and Redeploy"
cd ~/monolith-to-microservices/react-app
retry npm install
retry npm run build:monolith

cd ~/monolith-to-microservices/monolith
echo "Building monolith image (v2.0.0)..."
retry gcloud builds submit --tag $REGION-docker.pkg.dev/${GOOGLE_CLOUD_PROJECT}/monolith-demo/monolith:2.0.0

echo "Deploying updated monolith to Cloud Run..."
retry gcloud run deploy monolith \
  --image $REGION-docker.pkg.dev/${GOOGLE_CLOUD_PROJECT}/monolith-demo/monolith:2.0.0 \
  --allow-unauthenticated \
  --region $REGION
echo ""

# Completion Message
echo "=================================================="
echo "       Deployment Completed Successfully!         "
echo "=================================================="
echo ""
