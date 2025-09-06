#!/bin/bash

# Prompt user for LOCATION
read -p "Enter the GCP region (e.g. us-central1): " LOCATION

# Set project ID
PROJECT_ID=$(gcloud config get-value project)

echo "Enabling required services..."
gcloud services enable datacatalog.googleapis.com
gcloud services enable dataplex.googleapis.com

echo "Creating Dataplex lake..."
gcloud dataplex lakes create customer-engagements \
   --location="$LOCATION" \
   --display-name="Customer Engagements"

echo "Creating Dataplex zone..."
gcloud dataplex zones create raw-event-data \
    --location="$LOCATION" \
    --lake=customer-engagements \
    --display-name="Raw Event Data" \
    --type=RAW \
    --resource-location-type=SINGLE_REGION \
    --discovery-enabled

echo "Creating GCS bucket..."
gsutil mb -p "$PROJECT_ID" -c REGIONAL -l "$LOCATION" gs://"$PROJECT_ID"

echo "Creating Dataplex asset..."
gcloud dataplex assets create raw-event-files \
  --location="$LOCATION" \
  --lake=customer-engagements \
  --zone=raw-event-data \
  --display-name="Raw Event Files" \
  --resource-type=STORAGE_BUCKET \
  --resource-name=projects/$PROJECT_ID/buckets/$PROJECT_ID

echo "Lab completed successfully."
