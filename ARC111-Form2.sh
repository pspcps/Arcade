#!/bin/bash

# Prompt user for bucket names and user email
read -p "Enter name for Bucket 1: " Bucket_1
read -p "Enter name for Bucket 2: " Bucket_2
read -p "Enter name for Bucket 3: " Bucket_3
read -p "Enter user email for ACL change: " USER_EMAIL

# Create Bucket 1 with Nearline storage class
gsutil mb -c nearline gs://$Bucket_1

# Disable uniform bucket-level access on Bucket 2
gcloud alpha storage buckets update gs://$Bucket_2 --no-uniform-bucket-level-access

# Change ACL to give OWNER permission to the user for Bucket 2
gsutil acl ch -u $USER_EMAIL:OWNER gs://$Bucket_2

# Remove file sample.txt from Bucket 2 (if it exists)
gsutil rm gs://$Bucket_2/sample.txt

# Create a local sample.txt file
echo "Cloud Storage Demo" > sample.txt

# Upload the file to Bucket 2
gsutil cp sample.txt gs://$Bucket_2

# Make the uploaded file public
gsutil acl ch -u allUsers:R gs://$Bucket_2/sample.txt

# Update labels on Bucket 3
gcloud storage buckets update gs://$Bucket_3 --update-labels=key=value

echo "All operations completed."
