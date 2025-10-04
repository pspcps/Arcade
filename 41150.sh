#!/bin/bash

echo ""
echo ""

read -p "Enter Bucket name: " BUCKET_NAME

gsutil iam ch -d allUsers:objectViewer gs://$BUCKET_NAME
gsutil iam get gs://$BUCKET_NAME