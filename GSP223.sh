#!/bin/bash

# List authenticated accounts
gcloud auth list

# Set bucket name
BUCKET_NAME="${GOOGLE_CLOUD_PROJECT}-vcm"
export BUCKET=$BUCKET_NAME

# Create a GCS bucket
gsutil mb -p $GOOGLE_CLOUD_PROJECT -c standard -l us gs://$BUCKET

# Copy images
gsutil -m cp -r gs://spls/gsp223/images/* gs://${BUCKET}

# Copy placeholder CSV
gsutil cp gs://spls/gsp223/data.csv .

# Replace placeholder with your bucket name
sed -i -e "s/placeholder/${BUCKET}/g" ./data.csv

# Upload updated CSV to Cloud Storage
gsutil cp ./data.csv gs://${BUCKET}

# Create dataset in Vertex AI
DATASET_ID=$(gcloud ai datasets create \
  --region=us-central1 \
  --display-name="clouds" \
  --metadata-schema-uri=gs://google-cloud-aiplatform/schema/dataset/metadata/image_1.0.0.yaml \
  --format="value(name)" \
)

# Import data into the dataset
gcloud ai datasets import-data $DATASET_ID \
  --region=us-central1 \
  --import-schema-uri=gs://google-cloud-aiplatform/schema/dataset/ioformat/image_classification_single_label_io_format_1.0.0.yaml \
  --import-config='gcsSource={"uris":["gs://'${BUCKET}'/data.csv"]}'

# Done!
echo -e "\n\033[1;32m✅ Dataset creation and import initiated.\033[0m"
echo -e "\033[1;33mCheck your dataset here:\033[0m \033[1;34mhttps://console.cloud.google.com/vertex-ai/datasets?project=$DEVSHELL_PROJECT_ID\033[0m"
