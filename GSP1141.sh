#!/bin/bash
set -e

echo "=============================="
echo "📄 Document AI Automated Setup"
echo "=============================="

# 🔧 Config
PROJECT_ID=$(gcloud config get-value project)
LOCATION="${1:-us}"  # Default to "us" if no arg passed
DISPLAY_NAME="lab-invoice-uptraining"
PROCESSOR_TYPE="INVOICE_PROCESSOR"
BUCKET_NAME="${PROJECT_ID}-uptraining-lab"
SAMPLE_GCS_PATH="gs://cloud-samples-data/documentai/codelabs/uptraining/pdfs"
DEST_PATH="pdfs"  # Folder inside your bucket

echo "🧩 Using Project: $PROJECT_ID"
echo "📍 Location: $LOCATION"
echo "🧾 Processor Display Name: $DISPLAY_NAME"
echo "🪣 GCS Bucket: $BUCKET_NAME"

# 1️⃣ Enable Document AI API
echo "1⃣ Enabling Document AI API..."
gcloud services enable documentai.googleapis.com

# 2️⃣ Install Python Client Library
echo "2⃣ Installing Document AI Python client..."
pip3 install --upgrade google-cloud-documentai

# 3️⃣ Create Processor
echo "3⃣ Creating Processor..."
cat <<EOF > create_proc.json
{
  "type": "${PROCESSOR_TYPE}",
  "displayName": "${DISPLAY_NAME}"
}
EOF

PROC_RESPONSE=$(curl -s -X POST \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d @create_proc.json \
  "https://${LOCATION}-documentai.googleapis.com/v1/projects/${PROJECT_ID}/locations/${LOCATION}/processors")

PROCESSOR_NAME=$(echo "$PROC_RESPONSE" | grep -o '"name"[ ]*:[ ]*"[^"]*' | cut -d'"' -f4)
PROCESSOR_ID=$(basename "$PROCESSOR_NAME")

echo "✅ Processor Created: $PROCESSOR_ID"

# 4️⃣ Create GCS Bucket (if not exists)
echo "4⃣ Creating GCS Bucket (if needed)..."
if ! gsutil ls -b "gs://${BUCKET_NAME}" &>/dev/null; then
  gcloud storage buckets create "gs://${BUCKET_NAME}" --location="${LOCATION}"
  echo "✅ Bucket created: gs://${BUCKET_NAME}"
else
  echo "ℹ️ Bucket already exists: gs://${BUCKET_NAME}"
fi

# 5️⃣ Create Dataset for Processor
echo "5⃣ Creating Dataset in Custom GCS Bucket..."
cat <<EOF > create_dataset.json
{
  "name":"projects/${PROJECT_ID}/locations/${LOCATION}/processors/${PROCESSOR_ID}/dataset",
  "gcs_managed_config": {
    "gcs_prefix": {
      "gcs_uri_prefix": "gs://${BUCKET_NAME}"
    }
  },
  "spanner_indexing_config": {}
}
EOF

curl -s -X PATCH \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d @create_dataset.json \
  "https://${LOCATION}-documentai.googleapis.com/v1beta3/projects/${PROJECT_ID}/locations/${LOCATION}/processors/${PROCESSOR_ID}/dataset"

echo "✅ Dataset configured."

# 6️⃣ Copy Sample Documents to User Bucket
echo "6⃣ Copying sample documents into your GCS bucket..."
gsutil -m cp -r "${SAMPLE_GCS_PATH}" "gs://${BUCKET_NAME}/${DEST_PATH}/"
echo "✅ Sample documents copied to: gs://${BUCKET_NAME}/${DEST_PATH}/"

echo "=============================="
echo "✅ steps 3 completed!"
echo "🧾 Processor ID: $PROCESSOR_ID"
echo "🗂 Sample documents path: gs://${BUCKET_NAME}/${DEST_PATH}/"
echo "🕒 You can monitor the import operation in the Document AI Console or via:"
echo "   gcloud ai operations describe $OP_NAME --location=$LOCATION"
