#!/bin/bash

# ------------------------------------ Start ------------------------------------

# Prompt user for required configuration
echo "Configuration Parameters"
read -p "Enter LANGUAGE (e.g., Japanese, English): " LANGUAGE
read -p "Enter LOCAL (e.g., en, fr, es): " LOCAL
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
wget -q https://raw.githubusercontent.com/pspcps/Arcade/refs/heads/main/analyze-images-v3.py
echo "Script downloaded."
echo ""

# Replace locale in script
echo "Updating script locale..."
sed -i "s/'en'/'${LOCAL}'/g" analyze-images-v3.py
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
# echo "Running image analysis script..."
# python3 analyze-images-v2.py "$DEVSHELL_PROJECT_ID" "$DEVSHELL_PROJECT_ID"
# echo ""

echo "Running image analysis script..."
if python3 analyze-images-v3.py "$DEVSHELL_PROJECT_ID" "$DEVSHELL_PROJECT_ID"; then
    echo "Image analysis script completed successfully."
else
    echo "Warning: Image analysis script encountered an error but continuing..."
fi
echo ""

# Query results
echo "Querying BigQuery for locale distribution..."
bq query --use_legacy_sql=false \
  "SELECT locale, COUNT(locale) as lcount FROM image_classification_dataset.image_text_detail GROUP BY locale ORDER BY lcount DESC"
echo ""

echo "Lab completed successfully."

# ------------------------------------ End ------------------------------------

# Ask for confirmation before deleting and reloading data
read -p "Do you want to delete all existing data and reload from JSON? (y/n): " confirm

if [[ "$confirm" =~ ^[Yy]$ ]]; then
    echo "Deleting all data from image_classification_dataset.image_text_detail..."
    bq query --use_legacy_sql=false --quiet --format=none \
      "DELETE FROM image_classification_dataset.image_text_detail WHERE TRUE"
    echo "Data deleted."

    echo "Downloading JSON data..."
    curl -s -o data.json https://raw.githubusercontent.com/pspcps/Arcade/refs/heads/main/GSP329.json

    echo "Converting JSON array to newline-delimited JSON..."
    jq -c '.[]' data.json > data_ndjson.json

    echo "Loading data into BigQuery..."
    bq load --source_format=NEWLINE_DELIMITED_JSON \
      --replace=false \
      "$DEVSHELL_PROJECT_ID:image_classification_dataset.image_text_detail" \
      data_ndjson.json \
      original_text:STRING,locale:STRING,translated_text:STRING,filename:STRING

    echo "Data reloaded from JSON successfully."

    # Optional: Remove temporary files
    rm data.json data_ndjson.json
else
    echo "Data reload cancelled by user."
fi
