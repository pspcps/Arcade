#!/bin/bash

# Exit on errors
set -e


read -p "Please enter the region to use for bucket creation (e.g., us-central1): " REGION


echo "📍 Using region: $REGION"


# Fetch the current GCP Project ID
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)

if [[ -z "$PROJECT_ID" ]]; then
  echo "❌ No active GCP project set. Use 'gcloud config set project PROJECT_ID' to set one."
  exit 1
fi

echo "✅ Using Project ID: $PROJECT_ID"

# # Check if the 'app' bucket exists to fetch the region from
# APP_BUCKET="${PROJECT_ID}-app"
# REGION=""

# if gsutil ls -b "gs://${APP_BUCKET}" &>/dev/null; then
#   echo "ℹ️ Found existing bucket: $APP_BUCKET"
#   REGION=$(gsutil ls -L -b "gs://${APP_BUCKET}" 2>/dev/null | grep "Location constraint" | awk -F": " '{print $2}')
#   echo "✅ Region found from app bucket: $REGION"
# fi

# # If region still not found, ask the user to input it manually
# if [[ -z "$REGION" ]]; then
#   echo "❓ Region not found from the app bucket or configuration."
  
# fi


# Define bucket names
PRIVATE_BUCKET="${PROJECT_ID}-private-bucket"
PUBLIC_BUCKET="${PROJECT_ID}-public-bucket"

echo "🔧 Creating buckets:"
echo " - Private Bucket: $PRIVATE_BUCKET"
echo " - Public  Bucket: $PUBLIC_BUCKET"

# Create private bucket (if doesn't exist)
if gsutil ls -b "gs://${PRIVATE_BUCKET}" &>/dev/null; then
  echo "ℹ️ Private bucket already exists: $PRIVATE_BUCKET"
else
  gsutil mb -p "$PROJECT_ID" -l "$REGION" -b on "gs://${PRIVATE_BUCKET}/"
  echo "✅ Created private bucket: $PRIVATE_BUCKET"
fi

# Create public bucket (if doesn't exist)
if gsutil ls -b "gs://${PUBLIC_BUCKET}" &>/dev/null; then
  echo "ℹ️ Public bucket already exists: $PUBLIC_BUCKET"
else
  gsutil mb -p "$PROJECT_ID" -l "$REGION" -b on "gs://${PUBLIC_BUCKET}/"
  echo "✅ Created public bucket: $PUBLIC_BUCKET"
fi

# Disable public access prevention
# echo "🚫 Disabling public access prevention on: $PUBLIC_BUCKET"
# gcloud storage buckets update "$PUBLIC_BUCKET" --public-access-prevention=unspecified

# Grant allUsers Storage Object Viewer
echo "👥 Granting allUsers Storage Object Viewer access on: $PUBLIC_BUCKET"
gsutil iam ch allUsers:objectViewer "gs://${PUBLIC_BUCKET}"

echo "✅ Setup complete!"
