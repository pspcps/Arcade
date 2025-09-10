echo "Step 1: Fetching Your Project ID"
export BUCKET="$(gcloud config get-value project)"
if [ -z "$BUCKET" ]; then
  echo "Failed to get project ID. Please ensure you're authenticated."
  exit 1
fi
echo "Your Project ID: ${BUCKET}"
echo

# Create Cloud Storage Bucket
echo "Step 2: Creating Cloud Storage Bucket"
BUCKET_NAME="${BUCKET}-bucket-$(date +%s)"
echo "Creating bucket: gs://${BUCKET_NAME}"

gsutil mb -p $BUCKET -l US gs://$BUCKET_NAME || {
  echo "Failed to create bucket. Common issues:"
  echo "1. Bucket name must be globally unique"
  echo "2. Insufficient permissions"
  echo "3. Invalid project ID"
  exit 1
}
echo "Bucket created successfully: gs://${BUCKET_NAME}"
echo

# Download Demo Image
echo "Step 3: Downloading Demo Image"
IMAGE_URL="https://raw.githubusercontent.com/pspcps/Arcade/refs/heads/main/sign.jpg"
IMAGE_FILE="sign.jpg"

if ! curl -s -o $IMAGE_FILE -L "$IMAGE_URL"; then
  echo "Using fallback image URL"
  IMAGE_URL="https://storage.googleapis.com/gweb-cloudblog-publish/images/Google_Cloud.max-1100x1100.jpg"
  curl -s -o $IMAGE_FILE -L "$IMAGE_URL" || {
    echo "Failed to download image"
    exit 1
  }
fi
echo "Image downloaded: ${IMAGE_FILE}"
echo

# Upload Image to Bucket
echo "Step 4: Uploading Image to Bucket"
gsutil cp $IMAGE_FILE gs://$BUCKET_NAME/demo-image.jpg || {
  echo "Failed to upload image to bucket"
  exit 1
}
echo "Image uploaded to gs://${BUCKET_NAME}/demo-image.jpg"
echo

# Set Public Access
echo "Step 5: Configuring Public Access"
gsutil acl ch -u AllUsers:R gs://$BUCKET_NAME/demo-image.jpg || {
  echo "Failed to set public access"
  exit 1
}
echo "Image is now publicly accessible"
echo
