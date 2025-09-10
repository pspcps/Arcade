#!/bin/bash

# Ask for region
read -rp "Enter your region (e.g., us-central1): " REGION



# Set initial gcloud configuration
gcloud config set project $DEVSHELL_PROJECT_ID
gcloud config set run/region $REGION
gcloud config set run/platform managed
gcloud config set eventarc/location $REGION

# Get project number
echo
echo "Getting Project Number..."
export PROJECT_NUMBER="$(gcloud projects list \
  --filter=$(gcloud config get-value project) \
  --format='value(PROJECT_NUMBER)')"

# Add IAM Policy Binding
echo
echo "Adding IAM Policy Binding..."
gcloud projects add-iam-policy-binding $(gcloud config get-value project) \
  --member=serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com \
  --role='roles/eventarc.admin'

# List Eventarc Providers
echo
echo "Listing Eventarc Providers..."
gcloud eventarc providers list

echo
echo "Describing PubSub Provider..."
gcloud eventarc providers describe pubsub.googleapis.com

# Deploy Cloud Run Service
export SERVICE_NAME=event-display
export IMAGE_NAME="gcr.io/cloudrun/hello"

echo
echo "Deploying Cloud Run Service..."
gcloud run deploy ${SERVICE_NAME} \
  --image ${IMAGE_NAME} \
  --allow-unauthenticated \
  --max-instances=3

# Create PubSub Trigger
echo
echo "Creating PubSub Trigger..."
gcloud eventarc triggers create trigger-pubsub \
  --destination-run-service=${SERVICE_NAME} \
  --event-filters="type=google.cloud.pubsub.topic.v1.messagePublished"

export TOPIC_ID=$(gcloud eventarc triggers describe trigger-pubsub \
  --format='value(transport.pubsub.topic)')

echo "Publishing Topic ID: ${TOPIC_ID}"

# List Triggers
echo
echo "Listing Eventarc Triggers..."
gcloud eventarc triggers list

# Publish test message to Pub/Sub
echo
echo "Publishing Test Message..."
gcloud pubsub topics publish ${TOPIC_ID} --message="Hello there"

# Create Cloud Storage bucket
export BUCKET_NAME=$(gcloud config get-value project)-cr-bucket

echo
echo "Creating Storage Bucket..."
gsutil mb -p $(gcloud config get-value project) \
  -l $(gcloud config get-value run/region) \
  gs://${BUCKET_NAME}/

# Update IAM Policy
echo
echo "Updating IAM Policy..."
gcloud projects get-iam-policy $DEVSHELL_PROJECT_ID > policy.yaml

cat <<EOF >> policy.yaml
auditConfigs:
- auditLogConfigs:
  - logType: ADMIN_READ
  - logType: DATA_READ
  - logType: DATA_WRITE
  service: storage.googleapis.com
EOF

gcloud projects set-iam-policy $DEVSHELL_PROJECT_ID policy.yaml

# Upload a test file to the bucket
echo
echo "Creating and Uploading Test File..."
echo "Hello World" > random.txt
gsutil cp random.txt gs://${BUCKET_NAME}/random.txt

sleep 30

# Create Audit Log Trigger
echo
echo "Setting Up Audit Log Trigger..."
gcloud eventarc triggers create trigger-auditlog \
  --destination-run-service=${SERVICE_NAME} \
  --event-filters="type=google.cloud.audit.log.v1.written" \
  --event-filters="serviceName=storage.googleapis.com" \
  --event-filters="methodName=storage.objects.create" \
  --service-account=${PROJECT_NUMBER}-compute@developer.gserviceaccount.com

# Final verification
echo
echo "Verifying Triggers..."
gcloud eventarc triggers list

# Final test: upload the file again
echo
echo "Triggering Final Test..."
gsutil cp random.txt gs://${BUCKET_NAME}/random.txt
