
read -p "Please enter the region to use for bucket creation (e.g., us-central1): " REGION


echo "📍 Using region: $REGION"


# Fetch the current GCP Project ID
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)

PRIVATE_BUCKET="${PROJECT_ID}-bucket"

gsutil mb -p "$PROJECT_ID" -l "$REGION" -b on "gs://${PRIVATE_BUCKET}/"