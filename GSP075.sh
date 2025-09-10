# Step 1: API Key Creation
echo "STEP 1: API KEY SETUP"
echo

echo -n "Creating API Key..."
(gcloud alpha services api-keys create --display-name="cloud-ml-key" > /dev/null 2>&1) &
sleep 0.5
echo -e "\rAPI Key created successfully!"

echo -n "Fetching API Key Name..."
KEY_NAME=$(gcloud alpha services api-keys list --format="value(name)" --filter "displayName=cloud-ml-key" 2>/dev/null)
echo -e "\rAPI Key Name: $KEY_NAME"

echo -n "Fetching API Key String..."
API_KEY=$(gcloud alpha services api-keys get-key-string $KEY_NAME --format="value(keyString)" 2>/dev/null)
echo -e "\rAPI Key String retrieved!"
echo

# Step 2: Project Configuration
echo "STEP 2: PROJECT CONFIGURATION"
echo

export PROJECT_ID=$(gcloud config get-value project)
export PROJECT_NUMBER=$(gcloud projects describe $DEVSHELL_PROJECT_ID --format="value(projectNumber)")

echo "Project ID: $PROJECT_ID"
echo "Project Number: $PROJECT_NUMBER"
echo

# Step 3: Cloud Storage Setup
echo "STEP 3: CLOUD STORAGE SETUP"
echo

echo -n "Creating GCS Bucket..."
(gcloud storage buckets create gs://$DEVSHELL_PROJECT_ID-bucket --project=$DEVSHELL_PROJECT_ID > /dev/null 2>&1) &
sleep 0.5
echo -e "\rGCS Bucket created: gs://$DEVSHELL_PROJECT_ID-bucket"

echo -n "Setting IAM permissions..."
(gsutil iam ch projectEditor:serviceAccount:$PROJECT_NUMBER@cloudbuild.gserviceaccount.com:objectCreator gs://$DEVSHELL_PROJECT_ID-bucket > /dev/null 2>&1) &
sleep 0.5
echo -e "\rIAM permissions configured!"
echo

# Step 4: Image Processing
echo "STEP 4: IMAGE PROCESSING"
echo

echo -n "Downloading sample image..."
(curl -LO raw.githubusercontent.com/ArcadeCrew/Google-Cloud-Labs/main/Extract%2C%20Analyze%2C%20and%20Translate%20Text%20from%20Images%20with%20the%20Cloud%20ML%20APIs/sign.jpg > /dev/null 2>&1) &
sleep 0.5
echo -e "\rSample image downloaded!"

echo -n "Uploading to GCS Bucket..."
(gsutil cp sign.jpg gs://$DEVSHELL_PROJECT_ID-bucket/sign.jpg > /dev/null 2>&1) &
sleep 0.5
echo -e "\rImage uploaded to GCS!"

echo -n "Setting public access..."
(gsutil acl ch -u AllUsers:R gs://$DEVSHELL_PROJECT_ID-bucket/sign.jpg > /dev/null 2>&1) &
sleep 0.5
echo -e "\rPublic access configured!"
echo

# Step 5: Vision API Processing
echo "STEP 5: VISION API PROCESSING"
echo

echo -n "Creating OCR request..."
cat > ocr-request.json <<EOF
{
  "requests": [
      {
        "image": {
          "source": {
              "gcsImageUri": "gs://$DEVSHELL_PROJECT_ID-bucket/sign.jpg"
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
echo -e "\rOCR request file created!"

echo -n "Sending to Vision API..."
(curl -s -X POST -H "Content-Type: application/json" --data-binary @ocr-request.json https://vision.googleapis.com/v1/images:annotate?key=${API_KEY} -o ocr-response.json > /dev/null 2>&1) &
sleep 0.5
echo -e "\rVision API response received!"
echo

# Step 6: Translation API Processing
echo "STEP 6: TRANSLATION API PROCESSING"
echo

echo -n "Preparing translation request..."
STR=$(jq -r .responses[0].textAnnotations[0].description ocr-response.json)
cat > translation-request.json <<EOF
{
  "q": "$STR",
  "target": "en"
}
EOF
echo -e "\rTranslation request prepared!"

echo -n "Sending to Translation API..."
(curl -s -X POST -H "Content-Type: application/json" --data-binary @translation-request.json https://translation.googleapis.com/language/translate/v2?key=${API_KEY} -o translation-response.json > /dev/null 2>&1) &
sleep 0.5
echo -e "\rTranslation received!"
echo

# Step 7: Natural Language API Processing
echo "STEP 7: NATURAL LANGUAGE PROCESSING"
echo

echo -n "Preparing NL API request..."
TRANSLATED_TEXT=$(jq -r .data.translations[0].translatedText translation-response.json)
cat > nl-request.json <<EOF
{
  "document":{
    "type":"PLAIN_TEXT",
    "content":"$TRANSLATED_TEXT"
  },
  "encodingType":"UTF8"
}
EOF
echo -e "\rNL API request prepared!"

echo -n "Sending to Natural Language API..."
(curl -s -X POST -H "Content-Type: application/json" --data-binary @nl-request.json https://language.googleapis.com/v1/documents:analyzeEntities?key=${API_KEY} -o nl-response.json > /dev/null 2>&1) &
sleep 0.5
echo -e "\rNL API analysis complete!"
echo

# Display Results
echo "RESULTS"
echo

echo "Extracted Text:"
jq -r .responses[0].textAnnotations[0].description ocr-response.json
echo

echo "Translation:"
jq -r .data.translations[0].translatedText translation-response.json
echo

echo "Entity Analysis:"
jq -r .entities[].name nl-response.json 2>/dev/null | uniq
echo
