#!/bin/bash

# Prompt for the region
read -p "Enter the region (e.g., us-east4): " REGION

# Fetch the active GCP project
PROJECT_ID=$(gcloud config get-value project)

# Variables
LAKE_NAME="orders-lake"
LAKE_DISPLAY_NAME="Orders Lake"
ZONE_NAME="customer-curated-zone"
ZONE_DISPLAY_NAME="Customer Curated Zone"
ASSET_NAME="customer-details-dataset"
ASSET_DISPLAY_NAME="Customer Details Dataset"
BQ_DATASET="${PROJECT_ID}.customers"
ASPECT_TYPE_ID="protected-data-aspect"
ASPECT_TYPE_DISPLAY_NAME="Protected Data Aspect"
ASPECT_JSON_FILE="aspect_type.json"

echo "Using project: $PROJECT_ID"
echo "Region: $REGION"

# 1. Create a Dataplex lake
echo "Creating Dataplex lake..."
gcloud dataplex lakes create $LAKE_NAME \
  --location=$REGION \
  --project=$PROJECT_ID \
  --display-name="$LAKE_DISPLAY_NAME"

# Wait for lake to be ready
echo "Waiting for lake to become ACTIVE..."
ATTEMPTS=0
MAX_ATTEMPTS=20

while true; do
  LAKE_STATE=$(gcloud dataplex lakes describe $LAKE_NAME \
    --location=$REGION \
    --project=$PROJECT_ID \
    --format='value(state)' 2>/dev/null)

  if [[ "$LAKE_STATE" == "ACTIVE" ]]; then
    echo "Lake is now ACTIVE."
    break
  fi

  ((ATTEMPTS++))
  if [[ $ATTEMPTS -ge $MAX_ATTEMPTS ]]; then
    echo "ERROR: Lake did not become ACTIVE within expected time."
    exit 1
  fi

  echo "Lake state: $LAKE_STATE. Waiting 30 seconds..."
  sleep 30
done

# 2. Create a curated zone
echo "Creating curated zone..."
gcloud dataplex zones create $ZONE_NAME \
  --lake=$LAKE_NAME \
  --location=$REGION \
  --project=$PROJECT_ID \
  --display-name="$ZONE_DISPLAY_NAME" \
  --type=CURATED \
  --resource-location-type=SINGLE_REGION

# Wait for zone to be active
echo "Waiting for zone to become ACTIVE..."
ATTEMPTS=0

while true; do
  ZONE_STATE=$(gcloud dataplex zones describe $ZONE_NAME \
    --lake=$LAKE_NAME \
    --location=$REGION \
    --project=$PROJECT_ID \
    --format='value(state)' 2>/dev/null)

  if [[ "$ZONE_STATE" == "ACTIVE" ]]; then
    echo "Zone is now ACTIVE."
    break
  fi

  ((ATTEMPTS++))
  if [[ $ATTEMPTS -ge $MAX_ATTEMPTS ]]; then
    echo "ERROR: Zone did not become ACTIVE within expected time."
    exit 1
  fi

  echo "Zone state: $ZONE_STATE. Waiting 30 seconds..."
  sleep 30
done

# 3. Attach BigQuery dataset as asset
echo "Attaching BigQuery dataset as asset..."
gcloud dataplex assets create $ASSET_NAME \
  --project=$PROJECT_ID \
  --location=$REGION \
  --lake=$LAKE_NAME \
  --zone=$ZONE_NAME \
  --display-name="$ASSET_DISPLAY_NAME" \
  --resource-type=BIGQUERY_DATASET \
  --resource-name=projects/$PROJECT_ID/datasets/customers \
  --discovery-enabled

# 4. Create aspect type via JSON
if [[ ! -f "$ASPECT_JSON_FILE" ]]; then
  echo "ERROR: Required file '$ASPECT_JSON_FILE' not found!"
  exit 1
fi

echo "Creating aspect type from JSON..."
gcloud dataplex aspect-types import $ASPECT_TYPE_ID \
  --project=$PROJECT_ID \
  --location=$REGION \
  --file=$ASPECT_JSON_FILE

echo "✅ Script complete!"
echo "👉 Proceed to Dataplex UI to tag aspects to schema columns."
