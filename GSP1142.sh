#!/bin/bash
set -e

echo "=============================="
echo "📄 Document AI Custom Extractor Setup"
echo "=============================="

# 🔧 Configuration
PROJECT_ID=$(gcloud config get-value project)
LOCATION="${1:-us}"  # default to "us"
DISPLAY_NAME="lab-custom-extractor"
PROCESSOR_TYPE="CUSTOM_EXTRACTION_PROCESSOR"

echo "🧩 Using Project: $PROJECT_ID"
echo "📍 Region: $LOCATION"
echo "📘 Processor Name: $DISPLAY_NAME"

# 1️⃣ Enable Document AI API
echo "1⃣ Enabling Document AI API..."
gcloud services enable documentai.googleapis.com

# 2️⃣ Install Python Client Library
echo "2⃣ Installing Document AI Python client..."
pip3 install --upgrade google-cloud-documentai

# 3️⃣ Create Custom Extractor Processor
echo "3⃣ Creating Custom Extractor Processor..."
cat <<EOF > create_processor.json
{
  "type": "${PROCESSOR_TYPE}",
  "displayName": "${DISPLAY_NAME}"
}
EOF

PROC_RESPONSE=$(curl -s -X POST \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d @create_processor.json \
  "https://${LOCATION}-documentai.googleapis.com/v1/projects/${PROJECT_ID}/locations/${LOCATION}/processors")

PROCESSOR_NAME=$(echo "$PROC_RESPONSE" | grep -o '"name"[ ]*:[ ]*"[^"]*' | cut -d'"' -f4)
PROCESSOR_ID=$(basename "$PROCESSOR_NAME")

echo "✅ Processor Created: $PROCESSOR_ID"
echo "🔗 GO TO : https://console.cloud.google.com/document-ai/location/${LOCATION}/processors/${PROCESSOR_ID}?project=${PROJECT_ID}"

echo "=============================="
echo "✅ Setup Complete!"
echo "📘 Processor ID: $PROCESSOR_ID"
