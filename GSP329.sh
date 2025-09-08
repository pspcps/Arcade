#!/bin/bash

# ------------------------------------ Start ------------------------------------

# Prompt user for required configuration
echo "Configuration Parameters"
read -p "Enter LANGUAGE (e.g., en, fr, es): " LANGUAGE
read -p "Enter LOCAL (e.g., en_US, fr_FR): " LOCAL
read -p "Enter BIGQUERY_ROLE (e.g., roles/bigquery.admin): " BIGQUERY_ROLE
read -p "Enter CLOUD_STORAGE_ROLE (e.g., roles/storage.admin): " CLOUD_STORAGE_ROLE
# read -p "Enter GCS Bucket Name (e.g., my-bucket): " BUCKET_NAME
echo ""

# Create service account
echo "Creating service account 'sample-sa'..."
gcloud iam service-accounts create sample-sa
echo ""

# Assign IAM roles
echo "Assigning IAM roles to service account..."
gcloud projects add-iam-policy-binding "$DEVSHELL_PROJECT_ID" \
  --member="serviceAccount:sample-sa@$DEVSHELL_PROJECT_ID.iam.gserviceaccount.com" \
  --role="$BIGQUERY_ROLE"

gcloud projects add-iam-policy-binding "$DEVSHELL_PROJECT_ID" \
  --member="serviceAccount:sample-sa@$DEVSHELL_PROJECT_ID.iam.gserviceaccount.com" \
  --role="$CLOUD_STORAGE_ROLE"

gcloud projects add-iam-policy-binding "$DEVSHELL_PROJECT_ID" \
  --member="serviceAccount:sample-sa@$DEVSHELL_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/serviceusage.serviceUsageConsumer"
echo ""

# Wait for IAM propagation
echo "Waiting 2 minutes for IAM changes to propagate..."
for i in {1..120}; do
    echo -ne "$i/120 seconds elapsed...\r"
    sleep 1
done
echo ""

# Create service account key
echo "Creating service account key..."
gcloud iam service-accounts keys create sample-sa-key.json \
  --iam-account="sample-sa@$DEVSHELL_PROJECT_ID.iam.gserviceaccount.com"
export GOOGLE_APPLICATION_CREDENTIALS="${PWD}/sample-sa-key.json"
echo "Key created and environment variable set."
echo ""

# Download analysis script
echo "Downloading image analysis script..."
wget -q https://raw.githubusercontent.com/pspcps/Arcade/refs/heads/main/analyze-images-v2.py
echo "Script downloaded."
echo ""

# Replace locale in script
echo "Updating script locale..."
sed -i "s/'en'/'${LOCAL}'/g" analyze-images-v2.py
echo "Locale updated."
echo ""

# Create BigQuery dataset/table if not exists
echo "Ensuring BigQuery dataset and table exist..."
bq --location=US mk -d --description "Image classification data" "$DEVSHELL_PROJECT_ID:image_classification_dataset" 2>/dev/null
bq mk --table "$DEVSHELL_PROJECT_ID:image_classification_dataset.image_text_detail" \
  desc:STRING,locale:STRING,translated_text:STRING,filename:STRING 2>/dev/null
echo "Dataset and table ready."
echo ""

# Run the Python script
echo "Running image analysis script..."
python3 analyze-images-v2.py "$DEVSHELL_PROJECT_ID" "$DEVSHELL_PROJECT_ID"
echo ""

# Query results
echo "Querying BigQuery for locale distribution..."
bq query --use_legacy_sql=false \
  "SELECT locale, COUNT(locale) as lcount FROM image_classification_dataset.image_text_detail GROUP BY locale ORDER BY lcount DESC"
echo ""

echo "Lab completed successfully."

# ------------------------------------ End ------------------------------------
