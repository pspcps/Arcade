#!/bin/bash


echo "Starting Execution"

read -p "Enter HTTP Function Name: " HTTP_FUNCTION

read -p "Enter Cloud Storage-triggered Function Name: " FUNCTION_NAME

read -p "Enter Region (e.g. us-central1): " REGION

# Enable necessary APIs
gcloud services enable \
  artifactregistry.googleapis.com \
  cloudfunctions.googleapis.com \
  cloudbuild.googleapis.com \
  eventarc.googleapis.com \
  run.googleapis.com \
  logging.googleapis.com \
  pubsub.googleapis.com

# Wait for APIs to be enabled
sleep 30

# Get project number
PROJECT_NUMBER=$(gcloud projects list --filter="project_id:$DEVSHELL_PROJECT_ID" --format='value(project_number)')

# Get service account for KMS (used by gsutil internally)
SERVICE_ACCOUNT=$(gsutil kms serviceaccount -p $PROJECT_NUMBER)

# Grant Pub/Sub publisher role to the service account
gcloud projects add-iam-policy-binding $DEVSHELL_PROJECT_ID \
  --member serviceAccount:$SERVICE_ACCOUNT \
  --role roles/pubsub.publisher

# Create Cloud Storage bucket
gsutil mb -l $REGION gs://$DEVSHELL_PROJECT_ID
export BUCKET="gs://$DEVSHELL_PROJECT_ID"

# Create folder and files for Cloud Storage-triggered function
mkdir ~/$FUNCTION_NAME && cd $_
touch index.js package.json

# Write the CloudEvent function code
cat > index.js <<EOF
const functions = require('@google-cloud/functions-framework');
functions.cloudEvent('$FUNCTION_NAME', (cloudevent) => {
  console.log('A new event in your Cloud Storage bucket has been logged!');
  console.log(cloudevent);
});
EOF

# Write package.json
cat > package.json <<EOF
{
  "name": "nodejs-functions-gen2-codelab",
  "version": "0.0.1",
  "main": "index.js",
  "dependencies": {
    "@google-cloud/functions-framework": "^2.0.0"
  }
}
EOF

# Define deploy function for storage-triggered Cloud Function
deploy_function() {
  gcloud functions deploy $FUNCTION_NAME \
    --gen2 \
    --runtime nodejs20 \
    --entry-point $FUNCTION_NAME \
    --source . \
    --region $REGION \
    --trigger-bucket $BUCKET \
    --trigger-location $REGION \
    --max-instances 2 \
    --quiet
}

# Deploy loop until service is available
while true; do
  deploy_function

  if gcloud run services describe $FUNCTION_NAME --region $REGION &> /dev/null; then
    echo "Cloud Run service is created. Exiting the loop."
    break
  else
    echo "Waiting for Cloud Run service to be created..."
    sleep 10
  fi
done

cd ..

# Create folder and files for HTTP-triggered function
mkdir ~/HTTP_FUNCTION && cd $_
touch index.js package.json

# Write HTTP function code
cat > index.js <<EOF
const functions = require('@google-cloud/functions-framework');
functions.http('$HTTP_FUNCTION', (req, res) => {
  res.status(200).send('awesome lab');
});
EOF

# Write package.json
cat > package.json <<EOF
{
  "name": "nodejs-functions-gen2-codelab",
  "version": "0.0.1",
  "main": "index.js",
  "dependencies": {
    "@google-cloud/functions-framework": "^2.0.0"
  }
}
EOF

# Define deploy function for HTTP-triggered Cloud Function
deploy_function() {
  gcloud functions deploy $HTTP_FUNCTION \
    --gen2 \
    --runtime nodejs20 \
    --entry-point $HTTP_FUNCTION \
    --source . \
    --region $REGION \
    --trigger-http \
    --timeout 600s \
    --max-instances 2 \
    --min-instances 1 \
    --quiet
}

# Deploy loop until service is available
while true; do
  deploy_function

  if gcloud run services describe $HTTP_FUNCTION --region $REGION &> /dev/null; then
    echo "Cloud Run service is created. Exiting the loop."
    break
  else
    echo "Waiting for Cloud Run service to be created..."
    sleep 10
  fi
done

echo "Congratulations For Completing The Lab !!!"
