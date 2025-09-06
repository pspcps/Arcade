#!/bin/bash

set -euo pipefail

# Prompt variables
read -p "Enter GCP REGION: " REGION
read -p "Enter LOCATION (for Dataplex or other tasks): " LOCATION
read -p "Enter VM internal IP of postgres-vm: " SRC_VM_IP
DST_INSTANCE="migrated-cloudsql"
SRC_CONN_PROFILE="src-pg-vm"
DST_CONN_PROFILE="dst-cloudsql"
MIGRATION_JOB="pg-migration-job"

PROJECT=$(gcloud config get-value project)
echo "Using project: $PROJECT"

echo "Enabling required APIs..."
gcloud services enable datamigration.googleapis.com servicenetworking.googleapis.com

echo "Installing and configuring pglogical on source VM..."
# Assume SSH access; install the extension
gcloud compute ssh postgres-vm --region="$REGION" --command="
  sudo apt-get update && \
  sudo apt-get install -y postgresql-13-pglogical && \
  sudo sed -i \"s/#shared_preload_libraries =.*/shared_preload_libraries = 'pglogical'/\" /etc/postgresql/13/main/postgresql.conf && \
  echo \"host all all 0.0.0.0/0 md5\" | sudo tee -a /etc/postgresql/13/main/pg_hba.conf && \
  sudo systemctl restart postgresql
"
echo "pglogical installed and configured."

echo "Creating migration user..."
gcloud compute ssh postgres-vm --region="$REGION" --command="
psql -U postgres -c \"CREATE ROLE \\\"Postgres Migration User\\\" WITH LOGIN PASSWORD 'DMS_1s_cool!';\" && \
psql -U postgres -d orders -c \"GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO \\\"Postgres Migration User\\\";\""
echo "Migration user configured."

# ------- Create connection profiles -------
echo "Creating source connection profile..."
gcloud database-migration connection-profiles create postgresql "$SRC_CONN_PROFILE" \
  --region="$REGION" \
  --display-name="Postgres VM" \
  --vm=postgres-vm --vm-ip="$SRC_VM_IP" --vm-port=5432 --no-async

echo "Creating destination Cloud SQL instance..."
gcloud sql instances create "$DST_INSTANCE" \
  --database-version="POSTGRES_13" \
  --region="$REGION" \
  --cpu=2 --memory=8GB \
  --no-assign-ip \
  --storage-auto-increase
gcloud database-migration connection-profiles create postgresql "$DST_CONN_PROFILE" \
  --region="$REGION" \
  --display-name="Cloud SQL Destination" \
  --cloudsql-instance="$DST_INSTANCE" --no-async

# ------- Create migration job -------
echo "Creating continuous migration job..."
gcloud database-migration migration-jobs create "$MIGRATION_JOB" \
  --region="$REGION" \
  --display-name="Orders Migration" \
  --source="$SRC_CONN_PROFILE" \
  --destination="$DST_CONN_PROFILE" \
  --type=CONTINUOUS --no-async

# Poll migration job status (simplified example)
while true; do
  STATUS=$(gcloud database-migration migration-jobs describe "$MIGRATION_JOB" --region="$REGION" --format="value(state)")
  echo "Migration job status: $STATUS"
  if [[ "$STATUS" == "RUNNING" || "$STATUS" == "COMPLETED" ]]; then break; fi
  sleep 10
done

echo "Migration job is $STATUS"

# ------- Promote replica -------
echo "Promoting Cloud SQL replica to stand-alone..."
gcloud database-migration migration-jobs promote "$MIGRATION_JOB" --region="$REGION" --no-async

# ------- Enable IAM authentication -------
gcloud sql instances patch "$DST_INSTANCE" --authorized-networks="$(gcloud compute instances describe postgres-vm --format='get(networkInterfaces[0].accessConfigs[0].natIP)')"

# Example: creating IAM user—replace with actual principal
# gcloud sql users create "user@example.com" --instance="$DST_INSTANCE" --type=cloud_iam_user
# Grant SELECT privileges manually or via SQL

# ------- Enable point-in-time recovery -------
gcloud sql backups update "$DST_INSTANCE" --backup-start-time=00:00
gcloud sql instances patch "$DST_INSTANCE" --point-in-time-recovery-enabled --backup-retention-settings=transactionLogDays=1

# Capture timestamp
TIMESTAMP=$(date -u --rfc-3339=ns | sed -r 's/ /T/; s/\.[0-9]+/\.000Z/')
echo "PIT timestamp: $TIMESTAMP"

# Make a change on orders.distribution_centers (omitted)

# Clone instance for PITR test
NEW_INSTANCE="postgres-orders-pitr"
gcloud sql instances clone "$DST_INSTANCE" "$NEW_INSTANCE" --point-in-time="$TIMESTAMP" --region="$REGION"

echo "Automation complete."
