echo "STEP 1: Creating API Key..."
gcloud alpha services api-keys create --display-name="vision-lab-key" || {
    echo "Error: Failed to create API key; Close the tab and reopen"
    exit 1
}

KEY_NAME=$(gcloud alpha services api-keys list --format="value(name)" --filter "displayName=vision-lab-key")
export API_KEY=$(gcloud alpha services api-keys get-key-string $KEY_NAME --format="value(keyString)")
export PROJECT_ID=$(gcloud config get-value project)

echo "API Key created successfully"
echo "Key Value: $API_KEY"
echo ""

# IMAGE PROCESSING
echo "STEP 2: Setting Image Permissions..."
gsutil acl ch -u allUsers:R gs://$PROJECT_ID-bucket/manif-des-sans-papiers.jpg || {
    echo "Error: Failed to set image permissions"
    exit 1
}
echo "Image made publicly readable"
echo ""

# TEXT DETECTION
echo "STEP 3: Performing TEXT_DETECTION..."
cat > request.json <<EOF
{
  "requests": [
    {
      "image": {
        "source": {
          "gcsImageUri": "gs://$PROJECT_ID-bucket/manif-des-sans-papiers.jpg"
        }
      },
      "features": [
        {
          "type": "TEXT_DETECTION",
          "maxResults": 10
        }
      ]
    }
  ]
}
EOF

curl -s -X POST -H "Content-Type: application/json" --data-binary @request.json \
"https://vision.googleapis.com/v1/images:annotate?key=${API_KEY}" -o text-response.json || {
    echo "Error: Text detection failed"
    exit 1
}

gsutil cp text-response.json gs://$PROJECT_ID-bucket/ || {
    echo "Error: Failed to upload text response"
    exit 1
}

echo "Text detection completed"
echo "Results saved to: gs://$PROJECT_ID-bucket/text-response.json"
echo ""

# LANDMARK DETECTION
echo "STEP 4: Performing LANDMARK_DETECTION..."
cat > request.json <<EOF
{
  "requests": [
    {
      "image": {
        "source": {
          "gcsImageUri": "gs://$PROJECT_ID-bucket/manif-des-sans-papiers.jpg"
        }
      },
      "features": [
        {
          "type": "LANDMARK_DETECTION",
          "maxResults": 10
        }
      ]
    }
  ]
}
EOF

curl -s -X POST -H "Content-Type: application/json" --data-binary @request.json \
"https://vision.googleapis.com/v1/images:annotate?key=${API_KEY}" -o landmark-response.json || {
    echo "Error: Landmark detection failed"
    exit 1
}

gsutil cp landmark-response.json gs://$PROJECT_ID-bucket/ || {
    echo "Error: Failed to upload landmark response"
    exit 1
}

echo "Landmark detection completed"
echo "Results saved to: gs://$PROJECT_ID-bucket/landmark-response.json"
echo ""
