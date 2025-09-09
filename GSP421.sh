
# Step 1: Creating Buckets
echo "Step 1: Creating Cloud Storage Buckets"
gsutil mb gs://$DEVSHELL_PROJECT_ID
gsutil mb gs://$DEVSHELL_PROJECT_ID-2
echo "Buckets created successfully"

# Step 2: Downloading Images
echo
echo "Step 2: Downloading Demo Images"
curl -# -LO https://raw.githubusercontent.com/pspcps/Arcade/refs/heads/main/demo-image1.png
curl -# -LO https://raw.githubusercontent.com/pspcps/Arcade/refs/heads/main/demo-image2.png

echo "Images downloaded successfully"

# Step 3: Uploading Images
echo
echo "Step 3: Uploading Images to Cloud Storage"
gsutil cp demo-image1.png gs://$DEVSHELL_PROJECT_ID/demo-image1.png
gsutil cp demo-image2.png gs://$DEVSHELL_PROJECT_ID/demo-image2.png
gsutil cp demo-image1.png gs://$DEVSHELL_PROJECT_ID-2/demo-image1-copy.png
echo "Files uploaded successfully"
