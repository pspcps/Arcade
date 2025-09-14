#!/bin/bash

# Retry function: run a command up to MAX_RETRIES times with delay between attempts
retry_command() {
  local cmd="$1"
  local max_retries=${2:-3}
  local delay=${3:-5}
  local attempt=1

  until $cmd; do
    if (( attempt == max_retries )); then
      echo "ERROR: Command failed after $attempt attempts: $cmd"
      return 1
    else
      echo "Warning: Command failed. Retrying $attempt/$max_retries in $delay seconds..."
      ((attempt++))
      sleep $delay
    fi
  done
  return 0
}

# Section 1: Project Setup
echo "Getting Project ID..."
retry_command "export PROJECT_ID=\$(gcloud config get-value project)" || exit 1
echo "Project ID: $PROJECT_ID"
echo

# Section 2: Connection Creation
echo "Creating BigQuery connection 'my-connection' in US region..."
retry_command "bq mk --connection --location=US --project_id=$PROJECT_ID --connection_type=CLOUD_RESOURCE my-connection" || exit 1
echo "Connection created successfully."
echo

# Section 3: Service Account Configuration
echo "Retrieving service account for connection..."
retry_command "SERVICE_ACCOUNT=\$(bq show --format=json --connection $PROJECT_ID.US.my-connection | jq -r '.cloudResource.serviceAccountId')" || exit 1
echo "Service Account: $SERVICE_ACCOUNT"

echo "Granting Storage Object Viewer role to service account..."
retry_command "gcloud projects add-iam-policy-binding $PROJECT_ID --member=serviceAccount:$SERVICE_ACCOUNT --role=roles/storage.objectViewer" || exit 1
echo "Permissions granted."
echo

# Section 4: Dataset Creation
echo "Creating BigQuery dataset 'demo_dataset'..."
retry_command "bq mk demo_dataset" || exit 1
echo "Dataset created."
echo

# Section 5: Table Definitions
echo "Creating external table definition for invoice.csv..."
retry_command "bq mkdef --autodetect --connection_id=$PROJECT_ID.US.my-connection --source_format=CSV gs://$PROJECT_ID/invoice.csv > /tmp/tabledef.json" || exit 1
echo "Definition saved to /tmp/tabledef.json"
echo

# Section 6: Table Creation
echo "Creating BigLake table 'biglake_table'..."
retry_command "bq mk --external_table_definition=/tmp/tabledef.json --project_id=$PROJECT_ID demo_dataset.biglake_table" || exit 1
echo "BigLake table created."

echo "Creating external table 'external_table'..."
retry_command "bq mk --external_table_definition=/tmp/tabledef.json --project_id=$PROJECT_ID demo_dataset.external_table" || exit 1
echo "External table created."
echo

# Section 7: Schema Management
echo "Extracting schema from external table..."
retry_command "bq show --schema --format=prettyjson demo_dataset.external_table > /tmp/schema" || exit 1
echo "Schema saved to /tmp/schema"

echo "Updating external table with extracted schema..."
retry_command "bq update --external_table_definition=/tmp/tabledef.json --schema=/tmp/schema demo_dataset.external_table" || exit 1
echo "Table updated successfully."
echo
