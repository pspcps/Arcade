#!/bin/bash
set -euo pipefail

echo "==== Cloud SQL PostgreSQL Migration Automation ===="

### === GET USER INPUT === ###
read -rp "Enter the GCP region (e.g. us-central1): " REGION
read -rp "Enter the PostgreSQL Migration Username (e.g. Postgres Migration User): " MIGRATION_USER
# read -rsp "Enter the Migration User Password (e.g. DMS_1s_cool!): " MIGRATION_PASSWORD; echo

read -rp "Enter the Destination Cloud SQL Instance ID (e.g. migrated-sql-instance): " DST_INSTANCE_ID
# read -rsp "Enter the Password for the Cloud SQL postgres user (e.g. supersecret!): " DST_INSTANCE_PASSWORD; echo

read -rp "Enter the IAM User Email (e.g. student123@qwiklabs.net): " IAM_USER_EMAIL
read -rp "Enter the Table name to secure with IAM (e.g. orders): " TABLE_TO_SECURE_WITH_IAM
read -rp "Enter Point-in-Time Recovery Retention Days (e.g. 1): " PITR_RETENTION_DAYS

POSTGRES_VM_NAME="postgres-vm"
DST_INSTANCE_PASSWORD= "supersecret!"
MIGRATION_PASSWORD = "DMS_1s_cool!"
# TABLE_TO_SECURE_WITH_IAM = "orders"
PROJECT_ID=$(gcloud config get-value project)
echo "Using GCP Project: $PROJECT_ID"

### === FETCH VM IPs === ###
echo "Fetching internal and external IPs of $POSTGRES_VM_NAME..."
SRC_VM_INTERNAL_IP=$(gcloud compute instances describe "$POSTGRES_VM_NAME" \
  --zone "$REGION"-b \
  --format="get(networkInterfaces[0].networkIP)")

SRC_VM_EXTERNAL_IP=$(gcloud compute instances describe "$POSTGRES_VM_NAME" \
  --zone "$REGION"-b \
  --format="get(networkInterfaces[0].accessConfigs[0].natIP)")

echo "Internal IP: $SRC_VM_INTERNAL_IP"
echo "External IP: $SRC_VM_EXTERNAL_IP"

### === ENABLE REQUIRED APIS === ###
echo "Enabling required APIs..."
gcloud services enable datamigration.googleapis.com \
    servicenetworking.googleapis.com \
    sqladmin.googleapis.com \
    compute.googleapis.com

### === CONFIGURE SOURCE POSTGRES VM === ###
echo "Configuring pglogical on source VM..."
gcloud compute ssh "$POSTGRES_VM_NAME" --zone "$REGION"-b --command "
  sudo apt-get update && sudo apt-get install -y postgresql-13-pglogical && \
  sudo sed -i \"s/^#*shared_preload_libraries =.*/shared_preload_libraries = 'pglogical'/\" /etc/postgresql/13/main/postgresql.conf && \
  echo 'host all all 0.0.0.0/0 md5' | sudo tee -a /etc/postgresql/13/main/pg_hba.conf && \
  sudo systemctl restart postgresql
"

echo "Creating migration user..."
gcloud compute ssh "$POSTGRES_VM_NAME" --zone "$REGION"-b --command "
  sudo -u postgres psql -c \"CREATE ROLE \\\"$MIGRATION_USER\\\" WITH LOGIN PASSWORD '$MIGRATION_PASSWORD';\" && \
  sudo -u postgres psql -d orders -c \"GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO \\\"$MIGRATION_USER\\\";\"
"

### === CREATE CLOUD SQL INSTANCE === ###
echo "Creating Cloud SQL instance: $DST_INSTANCE_ID"
gcloud sql instances create "$DST_INSTANCE_ID" \
  --database-version=POSTGRES_13 \
  --cpu=2 --memory=8GB \
  --region="$REGION" \
  --tier=db-custom-2-8192 \
  --edition=ENTERPRISE \
  --enable-point-in-time-recovery \
  --retained-transaction-log-days="$PITR_RETENTION_DAYS"

gcloud sql users set-password postgres \
  --instance="$DST_INSTANCE_ID" \
  --password="$DST_INSTANCE_PASSWORD"

### === CREATE CONNECTION PROFILES === ###
echo "Creating source and destination connection profiles..."
gcloud database-migration connection-profiles create pg-source-profile \
  --region="$REGION" \
  --display-name="Source VM" \
  --postgresql-host="$SRC_VM_INTERNAL_IP" \
  --postgresql-port=5432 \
  --postgresql-username="$MIGRATION_USER" \
  --postgresql-password="$MIGRATION_PASSWORD"

gcloud database-migration connection-profiles create pg-dest-profile \
  --region="$REGION" \
  --display-name="CloudSQL Target" \
  --cloudsql-instance="$DST_INSTANCE_ID"

### === CREATE & START MIGRATION JOB === ###
echo "Starting DMS continuous migration job..."
gcloud database-migration migration-jobs create pg-migration-job \
  --region="$REGION" \
  --type=CONTINUOUS \
  --source=pg-source-profile \
  --destination=pg-dest-profile \
  --display-name="Postgres DMS Job"

gcloud database-migration migration-jobs start pg-migration-job --region="$REGION"

echo "Waiting for migration to stabilize..."
sleep 120

### === PROMOTE CLOUD SQL INSTANCE === ###
echo "Promoting the Cloud SQL instance..."
gcloud database-migration migration-jobs promote pg-migration-job --region="$REGION"

### === ENABLE IAM AUTH === ###
echo "Enabling Cloud SQL IAM authentication..."
gcloud sql instances patch "$DST_INSTANCE_ID" \
  --authorized-networks="$SRC_VM_EXTERNAL_IP"

gcloud sql users create "$IAM_USER_EMAIL" \
  --instance="$DST_INSTANCE_ID" \
  --type=cloud_iam_user

### === GRANT SELECT ON TABLE === ###
echo "Granting SELECT on $TABLE_TO_SECURE_WITH_IAM to $IAM_USER_EMAIL"
gcloud sql connect "$DST_INSTANCE_ID" --user=postgres --quiet <<EOF
\c orders;
GRANT SELECT ON $TABLE_TO_SECURE_WITH_IAM TO "$IAM_USER_EMAIL";
EOF

### === RECORD PITR TIMESTAMP === ###
TIMESTAMP=$(date -u --rfc-3339=ns | sed -r 's/ /T/; s/\.([0-9]{3}).*/.\1Z/')
echo "Point-in-Time Recovery timestamp: $TIMESTAMP"

### === MAKE A DATABASE CHANGE === ###
echo "Adding test data for PITR..."
gcloud sql connect "$DST_INSTANCE_ID" --user=postgres --quiet <<EOF
\c orders;
INSERT INTO distribution_centers (id, name) VALUES (999, 'PITR Test Center');
EOF

### === CLONE FOR PITR TEST === ###
echo "Cloning Cloud SQL instance to test PITR..."
gcloud sql instances clone "$DST_INSTANCE_ID" postgres-orders-pitr \
  --region="$REGION" \
  --point-in-time="$TIMESTAMP"

echo "✅ Migration, IAM Auth, and PITR complete!"
