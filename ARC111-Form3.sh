#!/bin/bash

# Prompt the user for bucket names
read -p "Enter name for Bucket 1 (Nearline): " Bucket_1
read -p "Enter name for Bucket 2 (sample.txt destination): " Bucket_2
read -p "Enter name for Bucket 3 (set default storage class to ARCHIVE): " Bucket_3

echo ""
echo "Creating gs://$Bucket_1 with Nearline storage class..."
gsutil mb -c nearline gs://$Bucket_1

echo ""
echo "Uploading sample.txt to gs://$Bucket_2..."
echo "This is an example of editing the file content for cloud storage object" | gsutil cp - gs://$Bucket_2/sample.txt

echo ""
echo "Setting default storage class to ARCHIVE for gs://$Bucket_3..."
gsutil defstorageclass set ARCHIVE gs://$Bucket_3

echo ""
echo "✅ All tasks completed successfully!"
