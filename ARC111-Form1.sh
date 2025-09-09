#!/bin/bash

# ----------- Prompt the user for bucket names -----------
read -p "Enter the name for Bucket1 (to be created with Coldline storage class): " BUCKET1
read -p "Enter the name of the pre-created Bucket2 (to apply 30-second retention policy): " BUCKET2
read -p "Enter the name of the pre-created Bucket3 (to upload a file into): " BUCKET3

# ----------- Task 1: Create Bucket1 with Coldline Storage Class -----------
echo "Creating bucket $BUCKET1 with Coldline storage class..."
gsutil mb -c coldline gs://$BUCKET1

# ----------- Task 2: Set a 30-second retention policy on Bucket2 -----------
echo "Setting a 30-second retention policy on bucket $BUCKET2..."
gcloud storage buckets update gs://$BUCKET2 --retention-period=30s

# ----------- Task 3: Upload a file to Bucket3 -----------
echo "Creating a local file and uploading it to bucket $BUCKET3..."
echo "Cloud Storage Task File" > task_file.txt
gsutil cp task_file.txt gs://$BUCKET3

echo "✅ All tasks completed successfully."
