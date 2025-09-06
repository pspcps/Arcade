#!/bin/bash
set -euo pipefail

echo "==== Cloud SQL PostgreSQL Migration Automation ===="

# --- Collect User Input ---
read -rp "Enter the GCP region (e.g. us-central1): " REGION
read -rp "Enter the PostgreSQL Migration Username (e.g. migration_admin): " MIGRATION_USER




# REGION="us-east4"  
# MIGRATION_USER="migration_user"

MIGRATION_PASSWORD="DMS_1s_cool!"

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

cat <<EOF > migration_permissions.sql
-- Create user if not exists
DO
\$do\$
BEGIN
   IF NOT EXISTS (
      SELECT FROM pg_catalog.pg_roles WHERE rolname = '$MIGRATION_USER'
   ) THEN
      CREATE USER $MIGRATION_USER PASSWORD '$MIGRATION_PASSWORD';
   END IF;
END
\$do\$;

ALTER ROLE $MIGRATION_USER WITH REPLICATION;
ALTER DATABASE orders OWNER TO $MIGRATION_USER;

\c orders;

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
GRANT SELECT ON public.inventory_items TO $MIGRATION_USER;

ALTER TABLE public.distribution_centers OWNER TO $MIGRATION_USER;
ALTER TABLE public.order_items OWNER TO $MIGRATION_USER;
ALTER TABLE public.products OWNER TO $MIGRATION_USER;
ALTER TABLE public.users OWNER TO $MIGRATION_USER;
ALTER TABLE public.inventory_items OWNER TO $MIGRATION_USER;

-- Add primary key if missing on the dynamic table
DO \$do\$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints tc
    WHERE tc.table_name = 'inventory_items' AND tc.constraint_type = 'PRIMARY KEY'
  ) THEN
    EXECUTE format('ALTER TABLE public.%I ADD PRIMARY KEY (id)', 'inventory_items');
  END IF;
END
\$do\$;
EOF


echo "Copying migration_permissions.sql to VM..."
gcloud compute scp migration_permissions.sql "$POSTGRES_VM_NAME":~/ --zone "$POSTGRES_VM_ZONE"


echo "Executing migration permissions SQL on VM..."
gcloud compute ssh "$POSTGRES_VM_NAME" --zone "$POSTGRES_VM_ZONE" --command "
  sudo -u postgres psql -f migration_permissions.sql
"
