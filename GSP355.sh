#!/bin/bash
set -euo pipefail

echo "==== Cloud SQL PostgreSQL Migration Automation ===="

# --- Collect User Input ---
read -rp "Enter the GCP region (e.g. us-central1): " REGION
read -rp "Enter the PostgreSQL Migration Username (e.g. migration_admin): " MIGRATION_USER
read -rp "Enter the Destination Cloud SQL Instance ID (e.g. migrated-sql-instance): " DST_INSTANCE_ID
read -rp "Enter the IAM User Email (e.g. student123@qwiklabs.net): " IAM_USER_EMAIL
read -rp "Enter the Table name to secure with IAM (e.g. inventory_items): " TABLE_TO_SECURE_WITH_IAM
read -rp "Enter Point-in-Time Recovery Retention Days (e.g. 1): " PITR_RETENTION_DAYS

MIGRATION_PASSWORD="DMS_1s_cool!"
DST_INSTANCE_PASSWORD="supersecret!"
PROJECT_ID=$(gcloud config get-value project)
echo "Using GCP Project: $PROJECT_ID"

# --- Detect VM ---
POSTGRES_VM_NAME=$(gcloud compute instances list --format="value(name)" --filter="name~'postgres'")
POSTGRES_VM_ZONE=$(gcloud compute instances list --filter="name=$POSTGRES_VM_NAME" --format="value(zone)" | awk -F/ '{print $NF}')

if [[ -z "$POSTGRES_VM_ZONE" ]]; then
  echo "❌ Could not detect VM zone. Exiting."
  exit 1
fi

echo "✅ Found VM: $POSTGRES_VM_NAME in zone: $POSTGRES_VM_ZONE"

# --- Get VM IPs ---
SRC_VM_INTERNAL_IP=$(gcloud compute instances describe "$POSTGRES_VM_NAME" --zone "$POSTGRES_VM_ZONE" --format="get(networkInterfaces[0].networkIP)")
SRC_VM_EXTERNAL_IP=$(gcloud compute instances describe "$POSTGRES_VM_NAME" --zone "$POSTGRES_VM_ZONE" --format="get(networkInterfaces[0].accessConfigs[0].natIP)")

echo "Internal IP: $SRC_VM_INTERNAL_IP"
echo "External IP: $SRC_VM_EXTERNAL_IP"

# --- Install pglogical and apply config ---
echo "Configuring pglogical on VM..."
gcloud compute ssh "$POSTGRES_VM_NAME" --zone "$POSTGRES_VM_ZONE" --command "
  sudo apt update && sudo apt install -y postgresql-13-pglogical jq &&

  sudo gsutil cp gs://cloud-training/gsp918/pg_hba_append.conf /tmp/
  sudo gsutil cp gs://cloud-training/gsp918/postgresql_append.conf /tmp/

  sudo bash -c 'cat /tmp/pg_hba_append.conf >> /etc/postgresql/13/main/pg_hba.conf'
  sudo bash -c 'cat /tmp/postgresql_append.conf >> /etc/postgresql/13/main/postgresql.conf'

  sudo systemctl restart postgresql@13-main
"

# --- Create Migration User and Set Permissions ---
echo "Generating SQL commands to create migration user and grant privileges..."

cat <<EOF
-- Connect to default DB postgres first:
\\c postgres;

-- Create migration user if not exists
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$MIGRATION_USER') THEN
    CREATE USER $MIGRATION_USER PASSWORD '$MIGRATION_PASSWORD';
  END IF;
END
\$\$;

ALTER ROLE $MIGRATION_USER WITH REPLICATION;
ALTER DATABASE orders OWNER TO $MIGRATION_USER;

-- Connect to orders DB for schema grants
\\c orders;

CREATE EXTENSION IF NOT EXISTS pglogical;

GRANT USAGE ON SCHEMA pglogical TO $MIGRATION_USER;
GRANT ALL ON SCHEMA pglogical TO $MIGRATION_USER;

GRANT SELECT ON pglogical.tables TO $MIGRATION_USER;
GRANT SELECT ON pglogical.depend TO $MIGRATION_USER;
GRANT SELECT ON pglogical.local_node TO $MIGRATION_USER;
GRANT SELECT ON pglogical.local_sync_status TO $MIGRATION_USER;
GRANT SELECT ON pglogical.node TO $MIGRATION_USER;
GRANT SELECT ON pglogical.node_interface TO $MIGRATION_USER;
GRANT SELECT ON pglogical.queue TO $MIGRATION_USER;
GRANT SELECT ON pglogical.replication_set TO $MIGRATION_USER;
GRANT SELECT ON pglogical.replication_set_seq TO $MIGRATION_USER;
GRANT SELECT ON pglogical.replication_set_table TO $MIGRATION_USER;
GRANT SELECT ON pglogical.sequence_state TO $MIGRATION_USER;
GRANT SELECT ON pglogical.subscription TO $MIGRATION_USER;

GRANT USAGE ON SCHEMA public TO $MIGRATION_USER;
GRANT ALL ON SCHEMA public TO $MIGRATION_USER;

GRANT SELECT ON public.distribution_centers TO $MIGRATION_USER;
GRANT SELECT ON public.order_items TO $MIGRATION_USER;
GRANT SELECT ON public.products TO $MIGRATION_USER;
GRANT SELECT ON public.users TO $MIGRATION_USER;
GRANT SELECT ON public."$TABLE_TO_SECURE_WITH_IAM" TO $MIGRATION_USER;

ALTER TABLE public.distribution_centers OWNER TO $MIGRATION_USER;
ALTER TABLE public.order_items OWNER TO $MIGRATION_USER;
ALTER TABLE public.products OWNER TO $MIGRATION_USER;
ALTER TABLE public.users OWNER TO $MIGRATION_USER;
ALTER TABLE public."$TABLE_TO_SECURE_WITH_IAM" OWNER TO $MIGRATION_USER;

-- Add primary key on $TABLE_TO_SECURE_WITH_IAM if missing
DO \$\$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu
      ON tc.constraint_name = kcu.constraint_name
    WHERE tc.table_name = '$TABLE_TO_SECURE_WITH_IAM'
      AND tc.constraint_type = 'PRIMARY KEY'
  ) THEN
    EXECUTE format('ALTER TABLE public.%I ADD PRIMARY KEY (id)', '$TABLE_TO_SECURE_WITH_IAM');
  END IF;
END
\$\$;
EOF

echo "==== Please copy the above SQL and execute it inside your PostgreSQL psql shell on the source VM ===="

# --- Create Cloud SQL instance ---
echo "Creating Cloud SQL instance: $DST_INSTANCE_ID"
gcloud sql instances create "$DST_INSTANCE_ID" \
  --database-version=POSTGRES_13 \
  --cpu=2 --memory=8GB \
  --region="$REGION" \
  --edition=ENTERPRISE \
  --enable-point-in-time-recovery \
  --retained-transaction-log-days="$PITR_RETENTION_DAYS"

gcloud sql users set-password postgres --instance="$DST_INSTANCE_ID" --password="$DST_INSTANCE_PASSWORD"

# --- Create Connection Profiles ---
echo "Creating connection profiles..."

gcloud database-migration connection-profiles create pg-source-profile \
  --region="$REGION" \
  --display-name="Source VM" \
  --type=postgresql \
  --settings='{"host":"'"$SRC_VM_INTERNAL_IP"'","port":5432,"username":"'"$MIGRATION_USER"'","password":"'"$MIGRATION_PASSWORD"'"}'

gcloud database-migration connection-profiles create pg-dest-profile \
  --region="$REGION" \
  --display-name="CloudSQL Target" \
  --type=cloudsql \
  --cloudsql-instance="$DST_INSTANCE_ID"

# --- Start Migration Job ---
echo "Starting continuous migration job..."
gcloud database-migration migration-jobs create pg-migration-job \
  --region="$REGION" \
  --type=CONTINUOUS \
  --source=pg-source-profile \
  --destination=pg-dest-profile \
  --display-name="Postgres DMS Job"

gcloud database-migration migration-jobs start pg-migration-job --region="$REGION"

echo "⏳ Waiting for migration to stabilize..."
sleep 120

gcloud database-migration migration-jobs promote pg-migration-job --region="$REGION"

# --- Enable IAM auth ---
echo "Patching Cloud SQL instance to authorize source VM external IP"
gcloud sql instances patch "$DST_INSTANCE_ID" \
  --authorized-networks="$SRC_VM_EXTERNAL_IP"

echo "Creating IAM user for Cloud SQL"
gcloud sql users create "$IAM_USER_EMAIL" \
  --instance="$DST_INSTANCE_ID" \
  --type=cloud_iam_user || echo "User $IAM_USER_EMAIL may already exist"

# --- Grant SELECT on secured table to IAM user ---
echo "Granting SELECT on $TABLE_TO_SECURE_WITH_IAM to $IAM_USER_EMAIL in Cloud SQL..."
gcloud sql connect "$DST_INSTANCE_ID" --user=postgres --quiet <<EOF
\c orders;
GRANT SELECT ON "$TABLE_TO_SECURE_WITH_IAM" TO "$IAM_USER_EMAIL";
EOF

# --- Record PITR timestamp ---
TIMESTAMP=$(date -u --rfc-3339=seconds)
echo "⏱️ PITR timestamp: $TIMESTAMP"

# --- Make data change for PITR test ---
echo "Making data change to test PITR"
gcloud sql connect "$DST_INSTANCE_ID" --user=postgres --quiet <<EOF
\c orders;
INSERT INTO distribution_centers (id, name) VALUES (999, 'PITR Test Center');
EOF

# --- PITR Clone ---
echo "Cloning Cloud SQL instance for PITR testing"
gcloud sql instances clone "$DST_INSTANCE_ID" postgres-orders-pitr \
  --region="$REGION" \
  --point-in-time="$TIMESTAMP"

echo "✅ All steps completed successfully: Migration, IAM, PITR!"