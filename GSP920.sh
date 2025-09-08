#!/bin/bash

set -euo pipefail

# === CONFIG ===
CLOUDSQL_INSTANCE="postgres-orders"
DB_VERSION="POSTGRES_13"
DB_ROOT_PASSWORD="supersecret!"
KMS_KEYRING_ID="cloud-sql-keyring"
KMS_KEY_ID="cloud-sql-key"
SQL_SERVICE="sqladmin.googleapis.com"

echo "⏳ Starting Cloud SQL with CMEK automation..."

# Get the current project
PROJECT_ID=$(gcloud config get-value project)
echo "🔹 Project ID: $PROJECT_ID"

# Enable the Cloud SQL Admin API if not already enabled
echo "🔹 Enabling Cloud SQL Admin API..."
gcloud services enable $SQL_SERVICE

# Create the Cloud SQL service account for CMEK
echo "🔹 Creating Cloud SQL service account identity..."
gcloud beta services identity create \
  --service=$SQL_SERVICE \
  --project=$PROJECT_ID

# Get ZONE and REGION based on bastion-vm
echo "🔹 Fetching bastion-vm zone and region..."
ZONE=$(gcloud compute instances list --filter="NAME=bastion-vm" --format=json | jq -r '.[0].zone' | awk -F "/zones/" '{print $NF}')
REGION=${ZONE::-2}
echo "🔹 Zone: $ZONE | Region: $REGION"

# Create KMS keyring
echo "🔹 Creating KMS keyring..."
gcloud kms keyrings create $KMS_KEYRING_ID --location=$REGION || echo "⚠️ Keyring may already exist."

# Create KMS key
echo "🔹 Creating KMS key..."
gcloud kms keys create $KMS_KEY_ID \
  --location=$REGION \
  --keyring=$KMS_KEYRING_ID \
  --purpose=encryption || echo "⚠️ Key may already exist."

# Bind KMS key to SQL service account
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format 'value(projectNumber)')
echo "🔹 Binding key to service account..."
gcloud kms keys add-iam-policy-binding $KMS_KEY_ID \
  --location=$REGION \
  --keyring=$KMS_KEYRING_ID \
  --member="serviceAccount:service-${PROJECT_NUMBER}@gcp-sa-cloud-sql.iam.gserviceaccount.com" \
  --role="roles/cloudkms.cryptoKeyEncrypterDecrypter"

# Get external IPs
echo "🔹 Getting external IPs..."
AUTHORIZED_IP=$(gcloud compute instances describe bastion-vm --zone=$ZONE --format 'value(networkInterfaces[0].accessConfigs[0].natIP)')
CLOUD_SHELL_IP=$(curl -s ifconfig.me)
echo "🔹 Bastion IP: $AUTHORIZED_IP"
echo "🔹 Cloud Shell IP: $CLOUD_SHELL_IP"

# Get KMS key full resource name
KEY_NAME=$(gcloud kms keys describe $KMS_KEY_ID \
    --keyring=$KMS_KEYRING_ID --location=$REGION \
    --format='value(name)')

# Create Cloud SQL instance with CMEK enabled
echo "🚀 Creating Cloud SQL instance with CMEK..."
gcloud sql instances create $CLOUDSQL_INSTANCE \
    --project=$PROJECT_ID \
    --authorized-networks=${AUTHORIZED_IP}/32,${CLOUD_SHELL_IP}/32 \
    --disk-encryption-key=$KEY_NAME \
    --database-version=$DB_VERSION \
    --cpu=1 \
    --memory=3840MB \
    --region=$REGION \
    --root-password=$DB_ROOT_PASSWORD

echo "✅ Cloud SQL instance created."

# Task 2: Enable pgAudit
echo "🛠️ Enabling pgAudit on the SQL instance..."
gcloud sql instances patch $CLOUDSQL_INSTANCE \
    --database-flags=cloudsql.enable_pgaudit=on,pgaudit.log=all

echo "✅ pgAudit enabled."

echo "🎉 All tasks completed successfully!"
