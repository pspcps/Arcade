#!/bin/bash

echo "=== Cloud Run HelloWorld Deployment Script ==="

# Retry function: retries command up to $MAX_RETRIES times with $SLEEP_SECONDS delay
retry() {
  local -r -i MAX_RETRIES="$1"; shift
  local -r CMD=("$@")
  local -i COUNT=0
  local STATUS=0

  until [[ $COUNT -ge $MAX_RETRIES ]]; do
    "${CMD[@]}"
    STATUS=$?
    if [[ $STATUS -eq 0 ]]; then
      return 0
    fi
    COUNT=$((COUNT+1))
    echo "Command failed with status $STATUS. Retrying ($COUNT/$MAX_RETRIES) in 5 seconds..."
    sleep 5
  done
  echo "Command failed after $MAX_RETRIES attempts."
  return $STATUS
}

read -p "Enter the GCP region (e.g., us-west1): " REGION

if [[ -z "$REGION" ]]; then
  echo "Error: Region cannot be empty."
  exit 1
fi

SERVICE_NAME="helloworld"
MAX_INSTANCES=5
EXEC_ENV="gen2"

PROJECT_ID=$(gcloud config get-value project)
if [[ -z "$PROJECT_ID" ]]; then
  echo "Error: No GCP project set. Please run 'gcloud config set project PROJECT_ID' first."
  exit 1
fi

echo "Using project: $PROJECT_ID"

echo "Enabling required APIs..."
retry 3 gcloud services enable cloudbuild.googleapis.com monitoring.googleapis.com run.googleapis.com --project="$PROJECT_ID"

echo "Getting default Compute Engine service account..."
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')
COMPUTE_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

echo "Granting Cloud Build Builder role to Compute Engine default service account..."
retry 3 gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${COMPUTE_SA}" \
  --role="roles/cloudbuild.builds.builder" \
  --quiet

echo "Creating temporary directory for Cloud Run source code..."
TMP_DIR=$(mktemp -d)
echo "Temp dir: $TMP_DIR"

# Write index.js
cat > "$TMP_DIR/index.js" <<EOF
const express = require('express');
const app = express();
const port = process.env.PORT || 8080;

app.get('/', (req, res) => {
  res.send('Hello World!');
});

app.listen(port, () => {
  console.log(\`Server listening on port \${port}\`);
});
EOF

# Write package.json
cat > "$TMP_DIR/package.json" <<EOF
{
  "name": "helloworld",
  "version": "1.0.0",
  "main": "index.js",
  "scripts": {
    "start": "node index.js"
  },
  "engines": {
    "node": ">=22"
  },
  "dependencies": {
    "express": "^4.18.2"
  }
}
EOF

cd "$TMP_DIR" || exit 1

echo "Deploying Cloud Run service '$SERVICE_NAME' in region '$REGION'..."
retry 3 gcloud run deploy "$SERVICE_NAME" \
  --region="$REGION" \
  --source="$TMP_DIR" \
  --max-instances="$MAX_INSTANCES" \
  --allow-unauthenticated \
  --execution-environment="$EXEC_ENV" \
  --quiet

if [[ $? -eq 0 ]]; then
  echo "Cloud Run service '$SERVICE_NAME' deployed successfully in region '$REGION'."
else
  echo "Failed to deploy Cloud Run service after retries."
fi

echo "Cleaning up temporary files..."
rm -rf "$TMP_DIR"




curl -LO 'https://github.com/tsenart/vegeta/releases/download/v12.12.0/vegeta_12.12.0_linux_386.tar.gz'

tar -xvzf vegeta_12.12.0_linux_386.tar.gz

gcloud logging metrics create CloudFunctionLatency-Logs \
    --project=$DEVSHELL_PROJECT_ID \
    --description="Subscribe to Arcade Helper" \
    --log-filter='resource.type="cloud_run_revision" AND resource.labels.function_name="helloWorld"'