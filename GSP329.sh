#!/bin/bash

#---------------------------------------------------- Start --------------------------------------------------#

# User Input Section
echo "Configuration Parameters"
echo "------------------------"
read -p "Enter LANGUAGE (e.g., en, fr, es): " LANGUAGE
read -p "Enter LOCAL (e.g., en_US, fr_FR): " LOCAL
read -p "Enter BIGQUERY_ROLE (e.g., roles/bigquery.admin): " BIGQUERY_ROLE
read -p "Enter CLOUD_STORAGE_ROLE (e.g., roles/storage.admin): " CLOUD_STORAGE_ROLE
echo ""

# Service Account Setup
echo "Creating service account 'sample-sa'..."
gcloud iam service-accounts create sample-sa
echo ""

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

echo "Waiting 2 minutes for IAM changes to propagate..."
for i in {1..120}; do
    echo -ne "$i/120 seconds elapsed...\r"
    sleep 1
done
echo -e "\n"

echo "Creating service account key..."
gcloud iam service-accounts keys create sample-sa-key.json \
    --iam-account="sample-sa@$DEVSHELL_PROJECT_ID.iam.gserviceaccount.com"
export GOOGLE_APPLICATION_CREDENTIALS="${PWD}/sample-sa-key.json"
echo "Key created and exported to environment"
echo ""

# Image Analysis Section
echo "Downloading image analysis script..."
wget -q https://raw.githubusercontent.com/guys-in-the-cloud/cloud-skill-boosts/main/Challenge-labs/Integrate%20with%20Machine%20Learning%20APIs%3A%20Challenge%20Lab/analyze-images-v2.py
echo "Script downloaded"
echo ""

echo "Updating script locale to $LOCAL..."
sed -i "s/'en'/'${LOCAL}'/g" analyze-images-v2.py
echo "Locale updated"
echo ""

echo "Running image analysis..."
python3 analyze-images-v2.py
python3 analyze-images-v2.py "$DEVSHELL_PROJECT_ID" "$DEVSHELL_PROJECT_ID"
echo "Image analysis completed"
echo ""

# Results Section
echo "Querying locale distribution from BigQuery..."
bq query --use_legacy_sql=false \
    "SELECT locale, COUNT(locale) as lcount FROM image_classification_dataset.image_text_detail GROUP BY locale ORDER BY lcount DESC"
echo ""

echo "Lab Completed Successfully!"
echo ""

#----------------------------------------------------- End --------------------------------------------------#
