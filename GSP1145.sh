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

echo "Using project: $PROJECT_ID"
echo "Region: $REGION"

# 1. Create a Dataplex lake
echo "Creating Dataplex lake..."
gcloud dataplex lakes create $LAKE_NAME \
  --location=$REGION \
  --project=$PROJECT_ID \
  --display-name="$LAKE_DISPLAY_NAME"

# Wait for lake to be ready
echo "Waiting for lake to be active..."
until [[ "$(gcloud dataplex lakes describe $LAKE_NAME --location=$REGION --project=$PROJECT_ID --format='value(state)')" == "ACTIVE" ]]; do
  echo "Waiting for lake to become ACTIVE..."
  sleep 10
done

# 2. Create a curated zone
echo "Creating curated zone..."
gcloud dataplex zones create $ZONE_NAME \
  --lake=$LAKE_NAME \
  --location=$REGION \
  --project=$PROJECT_ID \
  --display-name="$ZONE_DISPLAY_NAME" \
  --type=CURATED \
  --resource-location-type=REGIONAL

# Wait for zone to be active
echo "Waiting for zone to be active..."
until [[ "$(gcloud dataplex zones describe $ZONE_NAME --lake=$LAKE_NAME --location=$REGION --project=$PROJECT_ID --format='value(state)')" == "ACTIVE" ]]; do
  echo "Waiting for zone to become ACTIVE..."
  sleep 10
done

# 3. Add BigQuery dataset as asset
echo "Attaching BigQuery dataset as an asset..."
gcloud dataplex assets create $ASSET_NAME \
  --project=$PROJECT_ID \
  --location=$REGION \
  --lake=$LAKE_NAME \
  --zone=$ZONE_NAME \
  --display-name="$ASSET_DISPLAY_NAME" \
  --asset-type=BIGQUERY_DATASET \
  --resource-name=projects/$PROJECT_ID/datasets/customers \
  --discovery-enabled

# 4. Create an aspect type
echo "Creating aspect type..."
gcloud dataplex aspect-types create $ASPECT_TYPE_ID \
  --project=$PROJECT_ID \
  --location=$REGION \
  --display-name="$ASPECT_TYPE_DISPLAY_NAME" \
  --fields="protected_data_flag:enum:Yes,No:required"

echo "Script complete. For tagging aspects and columns, continue in the Dataplex Universal Catalog UI as tagging via CLI is limited."

