#!/bin/bash
set -euo pipefail

echo "==== Cloud SQL PostgreSQL Migration Automation ===="

# --- Collect User Input ---
read -rp "Enter the GCP region (e.g. us-central1): " REGION
read -rp "Enter the PostgreSQL Migration Username (e.g. migration_admin): " MIGRATION_USER
read -rp "Enter the Destination Cloud SQL Instance ID (e.g. migrated-sql-instance): " DST_INSTANCE_ID
read -rp "Enter the Table name to secure with IAM (e.g. orders): " TABLE_TO_SECURE_WITH_IAM
read -rp "Enter the IAM User Email (e.g. student123@qwiklabs.net): " IAM_USER_EMAIL





### === ENABLE REQUIRED APIS === ###
echo "Enabling required APIs..."
gcloud services enable datamigration.googleapis.com \
    servicenetworking.googleapis.com
    

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


# --- Create Migration User and Set Permissions ---
echo "Generating SQL commands to create migration user and grant privileges..."

cat > dbScript.txt <<EOF_CP


************************************************************************************************
**********************************Copy And past in any tool************************************
**********************************************************************************************



gcloud compute ssh "$POSTGRES_VM_NAME" \
  --zone="$POSTGRES_VM_ZONE" \
  --quiet

----------------Step1---------------

sudo su - postgres

psql


\c postgres;

CREATE EXTENSION pglogical;

\c orders;

CREATE EXTENSION pglogical;


----------------Step2---------------

CREATE USER $MIGRATION_USER PASSWORD '$MIGRATION_PASSWORD';
ALTER DATABASE orders OWNER TO $MIGRATION_USER;
ALTER ROLE $MIGRATION_USER WITH REPLICATION;


ALTER TABLE inventory_items ADD PRIMARY KEY (id);



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
GRANT SELECT ON public.inventory_items TO $MIGRATION_USER;
GRANT SELECT ON public.order_items TO $MIGRATION_USER;
GRANT SELECT ON public.products TO $MIGRATION_USER;
GRANT SELECT ON public.users TO $MIGRATION_USER;



ALTER TABLE public.distribution_centers OWNER TO $MIGRATION_USER;
ALTER TABLE public.inventory_items OWNER TO $MIGRATION_USER;
ALTER TABLE public.order_items OWNER TO $MIGRATION_USER;
ALTER TABLE public.products OWNER TO $MIGRATION_USER;
ALTER TABLE public.users OWNER TO $MIGRATION_USER;



----------------Step3---------------


\c postgres;


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




---------------------------------------------Step4---------------


supersecret!

\c orders

supersecret!


GRANT ALL PRIVILEGES ON TABLE $TABLE_TO_SECURE_WITH_IAM TO "$IAM_USER_EMAIL";
\q

 ----------------------------------------------------Step5---------------

supersecret!

\c orders

supersecret!


insert into distribution_centers values(-80.1918,25.7617,'Miami FL',11);
\q



----------------Step6---------------

gcloud auth login --quiet

gcloud projects get-iam-policy $DEVSHELL_PROJECT_ID


gcloud sql instances clone '$DST_INSTANCE_ID'  postgres-orders-pitr --point-in-time ''
 

\q



\$\$;
EOF_CP

cat dbScript.txt 

echo "==== Please copy the above SQL and execute it inside your PostgreSQL psql shell on the source VM ===="


