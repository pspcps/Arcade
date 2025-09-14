#!/bin/bash

# Step 1: Create the genai.py file
cat > genai.py <<EOF
from google import genai
from google.genai.types import HttpOptions, Part

client = genai.Client(http_options=HttpOptions(api_version="v1"))
response = client.models.generate_content(
    model="gemini-2.0-flash-001",
    contents=[
        "What is shown in this image?",
        Part.from_uri(
            file_uri="https://storage.googleapis.com/cloud-samples-data/generative-ai/image/scones.jpg",
            mime_type="image/jpeg",
        ),
    ],
)
print(response.text)
EOF

echo "Created genai.py successfully."

# Step 2: Try to auto-fetch Project ID
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)

# Step 3: If Project ID not set, ask the user
if [ -z "$PROJECT_ID" ]; then
    echo "Google Cloud Project ID not found in gcloud config."
    read -p "Please enter your Google Cloud Project ID: " PROJECT_ID
else
    echo "Fetched Project ID from gcloud: $PROJECT_ID"
fi

# Step 4: Ask user for REGION
read -p "Enter your Region (e.g., us-central1): " REGION

# Step 5: Export required environment variables
export GOOGLE_CLOUD_PROJECT="$PROJECT_ID"
export GOOGLE_CLOUD_LOCATION="$REGION"
export GOOGLE_GENAI_USE_VERTEXAI=True

echo
echo "Environment variables set:"
echo "  GOOGLE_CLOUD_PROJECT=$GOOGLE_CLOUD_PROJECT"
echo "  GOOGLE_CLOUD_LOCATION=$GOOGLE_CLOUD_LOCATION"
echo "  GOOGLE_GENAI_USE_VERTEXAI=$GOOGLE_GENAI_USE_VERTEXAI"
echo

# Step 6: Run the Python file
echo "Running genai.py..."
/usr/bin/python3 genai.py

echo
echo "Note: If you encounter a 400 error, try re-running the script."
