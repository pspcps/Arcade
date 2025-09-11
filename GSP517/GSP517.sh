#!/bin/bash

# Retry mechanism function
retry() {
  local retries=5
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
echo "=== Starting Execution ==="
echo ""

# Step 1: Enable Cloud Run API
echo "Step 1: Enabling Cloud Run API..."
retry gcloud services enable run.googleapis.com
echo ""

# Step 2: Clone the repository
echo "Step 2: Cloning Google Cloud generative AI repository..."
retry git clone https://github.com/GoogleCloudPlatform/generative-ai.git
echo ""

# Step 3: Navigate to the required directory
echo "Step 3: Navigating to the 'gemini-streamlit-cloudrun' directory..."
cd generative-ai/gemini/sample-apps/gemini-streamlit-cloudrun
echo ""

# Step 4: Copy chef.py from the cloud storage bucket
echo "Step 4: Copying 'chef.py' from Google Cloud Storage..."
retry gsutil cp gs://spls/gsp517/chef.py .
echo ""

# Step 5: Remove unnecessary files
echo "Step 5: Removing existing files: Dockerfile, chef.py, requirements.txt..."
rm -rf Dockerfile chef.py requirements.txt
echo ""

# Step 6: Download required files
echo "Step 6: Downloading required files..."
retry wget 
retry wget 
retry wget 
echo ""

# Step 7: Upload chef.py to the Cloud Storage bucket
echo "Step 7: Uploading 'chef.py' to Cloud Storage bucket..."
retry gcloud storage cp chef.py gs://$DEVSHELL_PROJECT_ID-generative-ai/
echo ""

# Step 8: Set project and region variables
echo "Step 8: Setting GCP project and region variables..."
GCP_PROJECT=$(gcloud config get-value project)
GCP_REGION=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-region])")
echo ""

# Step 9: Create a virtual environment and install dependencies
echo "Step 9: Setting up Python virtual environment..."
python3 -m venv gemini-streamlit
source gemini-streamlit/bin/activate
python3 -m pip install --upgrade pip
retry python3 -m pip install -r requirements.txt
echo ""

# Step 10: Start Streamlit application
echo "Step 10: Running Streamlit application in the background..."
nohup streamlit run chef.py \
  --browser.serverAddress=localhost \
  --server.enableCORS=false \
  --server.enableXsrfProtection=false \
  --server.port 8080 > streamlit.log 2>&1 &
echo ""

# Step 11: Create Artifact Repository
echo "Step 11: Creating Artifact Registry repository..."
AR_REPO='chef-repo'
SERVICE_NAME='chef-streamlit-app'
retry gcloud artifacts repositories create "$AR_REPO" --location="$GCP_REGION" --repository-format=Docker
echo ""

# Step 12: Submit Cloud Build
echo "Step 12: Submitting Cloud Build..."
retry gcloud builds submit --tag "$GCP_REGION-docker.pkg.dev/$GCP_PROJECT/$AR_REPO/$SERVICE_NAME"
echo ""

# Step 13: Deploy Cloud Run Service
# Step 13: Deploy Cloud Run Service
echo "Step 13: Deploying Cloud Run service..."
retry gcloud run deploy "$SERVICE_NAME" \
  --port=8080 \
  --image="$GCP_REGION-docker.pkg.dev/$GCP_PROJECT/$AR_REPO/$SERVICE_NAME" \
  --allow-unauthenticated \
  --region=$GCP_REGION \
  --platform=managed \
  --project=$GCP_PROJECT \
  --set-env-vars=GCP_PROJECT=$GCP_PROJECT,GCP_REGION=$GCP_REGION
echo ""

# Step 14: Get Cloud Run Service URL
echo "Step 14: Fetching Cloud Run service URL..."
CLOUD_RUN_URL=$(gcloud run services describe "$SERVICE_NAME" --region="$GCP_REGION" --format='value(status.url)')
echo ""

echo "=== Execution Complete ==="
echo ""
echo "Streamlit is running locally at: http://localhost:8080"
echo "Cloud Run Service is available at: $CLOUD_RUN_URL"
echo ""
