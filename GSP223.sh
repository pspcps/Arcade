#!/bin/bash

# Authenticate (ensure you're logged in)
gcloud auth list

# Create Cloud Storage bucket
BUCKET_NAME="${GOOGLE_CLOUD_PROJECT}-vcm"
gsutil mb -p $GOOGLE_CLOUD_PROJECT -c standard -l us gs://$BUCKET_NAME

# Set environment variable
export BUCKET=$BUCKET_NAME

# Copy training images to the new bucket
gsutil -m cp -r gs://spls/gsp223/images/* gs://${BUCKET}

# Copy the placeholder CSV to your Cloud Shell
gsutil cp gs://spls/gsp223/data.csv .

# Replace "placeholder" with actual bucket name in CSV
sed -i -e "s/placeholder/${BUCKET}/g" ./data.csv

# Upload updated CSV to Cloud Storage
gsutil cp ./data.csv gs://${BUCKET}

# Automatically create the dataset in Vertex AI
gcloud beta ai datasets import \
    --region=us-central1 \
    --display-name="clouds" \
    --data-schema=text-csv \
    --multi-label=false \
    --input-uris=gs://${BUCKET}/data.csv \
    --dataset-type=vision.image-classification.single-label

# Final instruction (optional manual fallback)
echo -e "\033[1;32m✅ Dataset creation initiated. It may take 2-5 minutes to finish importing images.\033[0m"
echo -e "\033[1;33mCheck your dataset here:\033[0m \033[1;34mhttps://console.cloud.google.com/vertex-ai/datasets?project=$DEVSHELL_PROJECT_ID\033[0m"
