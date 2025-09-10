# API Key Creation
echo "STEP 1: Creating API Key..."
gcloud alpha services api-keys create --display-name="vision-api-key" || {
    echo "Error: Failed to create API key"
    exit 1
}

KEY_NAME=$(gcloud alpha services api-keys list --format="value(name)" --filter "displayName=vision-api-key")
export API_KEY=$(gcloud alpha services api-keys get-key-string $KEY_NAME --format="value(keyString)")
export PROJECT_ID=$(gcloud config get-value project)

echo "API Key created successfully"
echo "Key: $API_KEY"
echo ""

# Storage Setup
echo "STEP 2: Creating Cloud Storage Bucket..."
gsutil mb gs://$PROJECT_ID-vision-lab || {
    echo "Error: Bucket creation failed"
    exit 1
}
echo "Bucket gs://$PROJECT_ID-vision-lab created successfully"
echo ""

# Image Processing
echo "STEP 3: Downloading Sample Images..."
declare -a IMAGE_FILES=(
    "city.png"
    "donuts.png"
    "selfie.png"
)

for IMAGE in "${IMAGE_FILES[@]}"; do
    echo "Downloading $IMAGE..."
    curl -LO "https://raw.githubusercontent.com/GoogleCloudPlatform/cloud-vision/main/samples/$IMAGE" || {
        echo "Error: Download failed for $IMAGE"
        continue
    }
    gsutil cp $IMAGE gs://$PROJECT_ID-vision-lab/
    gsutil acl ch -u AllUsers:R gs://$PROJECT_ID-vision-lab/$IMAGE
    echo "Uploaded: $IMAGE"
done
echo ""
