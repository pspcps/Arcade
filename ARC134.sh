#!/bin/bash

# Get default zone
echo "Fetching default compute zone..."
export ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])")

echo "Creating prepare_disk.sh script for service account and instance setup..."

cat > prepare_disk.sh <<'EOF'
#!/bin/bash

# Authenticate (skipped if already authenticated in Qwiklabs)
export PROJECT_ID=$(gcloud config get-value project)
export ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])")

# Create service account
gcloud iam service-accounts create devops --display-name devops

# Wait for propagation
sleep 45

# Assign IAM roles
SA=$(gcloud iam service-accounts list --format="value(email)" --filter="displayName=devops")
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$SA" --role="roles/iam.serviceAccountUser"
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$SA" --role="roles/compute.instanceAdmin"

# Create compute instance with the new SA
gcloud compute instances create vm-2 --machine-type=e2-micro --service-account="$SA" --zone="$ZONE" --scopes="https://www.googleapis.com/auth/compute"

# Create custom role
cat > role-definition.yaml <<EOF_ROLE
title: "My Company Admin"
description: "My custom role description."
stage: "ALPHA"
includedPermissions:
- cloudsql.instances.connect
- cloudsql.instances.get
EOF_ROLE

gcloud iam roles create editor --project="$PROJECT_ID" --file=role-definition.yaml

# Create BigQuery service account
gcloud iam service-accounts create bigquery-qwiklab --display-name=bigquery-qwiklab
BQ_SA=$(gcloud iam service-accounts list --format="value(email)" --filter="displayName=bigquery-qwiklab")

# Assign BigQuery roles
gcloud projects add-iam-policy-binding "$PROJECT_ID" --member="serviceAccount:$BQ_SA" --role="roles/bigquery.dataViewer"
gcloud projects add-iam-policy-binding "$PROJECT_ID" --member="serviceAccount:$BQ_SA" --role="roles/bigquery.user"

# Create VM with BigQuery SA
gcloud compute instances create bigquery-instance \
  --service-account="$BQ_SA" \
  --scopes="https://www.googleapis.com/auth/bigquery" \
  --zone="$ZONE"
EOF

# Copy and run the script on lab-vm
echo "Copying setup script to lab-vm and executing..."
gcloud compute scp prepare_disk.sh lab-vm:/tmp --zone="$ZONE" --quiet
gcloud compute ssh lab-vm --zone="$ZONE" --quiet --command="bash /tmp/prepare_disk.sh"

sleep 30

# Create second part for BigQuery setup
echo "Preparing second setup script for BigQuery instance..."

cat > prepare_disk.sh <<'EOF'
#!/bin/bash

# Install required packages
sudo apt-get update
sudo apt install -y python3 python3-pip python3.11-venv git

# Create and activate virtual environment
python3 -m venv myvenv
source myvenv/bin/activate

# Install Python libraries
pip install --upgrade pip
pip install google-cloud-bigquery pyarrow pandas db-dtypes google-cloud

# Set environment variables
export PROJECT_ID=$(gcloud config get-value project)
export SA_EMAIL=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email" -H "Metadata-Flavor: Google")

# Create BigQuery Python script
cat > query.py <<EOF_PY
from google.auth import compute_engine
from google.cloud import bigquery

credentials = compute_engine.Credentials(service_account_email="$SA_EMAIL")
client = bigquery.Client(project="$PROJECT_ID", credentials=credentials)

query = '''
SELECT name, SUM(number) as total_people
FROM \`bigquery-public-data.usa_names.usa_1910_2013\`
WHERE state = 'TX'
GROUP BY name
ORDER BY total_people DESC
LIMIT 20
'''
print(client.query(query).to_dataframe())
EOF_PY

# Run BigQuery script
python3 query.py
EOF

# Copy and run second part on bigquery-instance
echo "Copying BigQuery setup script to bigquery-instance and executing..."
gcloud compute scp prepare_disk.sh bigquery-instance:/tmp --zone="$ZONE" --quiet
gcloud compute ssh bigquery-instance --zone="$ZONE" --quiet --command="bash /tmp/prepare_disk.sh"

echo "Lab setup completed successfully."
