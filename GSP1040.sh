#!/bin/bash

GREEN="\033[0;32m"
RESET="\033[0m"

retry() {
  local -r -i max_attempts="$1"; shift
  local -r cmd="$@"
  local -i attempt_num=1

  until $cmd
  do
    if (( attempt_num == max_attempts ))
    then
      echo -e "${GREEN}Attempt $attempt_num failed and there are no more attempts left.${RESET}"
      return 1
    else
      echo -e "${GREEN}Attempt $attempt_num failed! Retrying in 5 seconds...${RESET}"
      sleep 5
      ((attempt_num++))
    fi
  done
}

echo -e "${GREEN}⚡ Initializing BigQuery BigLake Configuration...${RESET}"
echo

# Section 1: Project Setup
echo -e "${GREEN}--- PROJECT SETUP ---${RESET}"
echo -e "${GREEN}Getting your Project ID...${RESET}"
PROJECT_ID=$(gcloud config get-value project)
export PROJECT_ID


echo -e "${GREEN}Your Project ID: $PROJECT_ID${RESET}"
echo

# Section 2: Connection Creation
echo -e "${GREEN}--- CONNECTION SETUP ---${RESET}"
echo -e "${GREEN}Creating BigQuery connection 'my-connection' in US region...${RESET}"
retry 3 bq mk --connection --location=US --project_id="$PROJECT_ID" --connection_type=CLOUD_RESOURCE my-connection
echo -e "${GREEN}Connection created successfully!${RESET}"
echo

# Section 3: Service Account Configuration
echo -e "${GREEN}--- SERVICE ACCOUNT SETUP ---${RESET}"
echo -e "${GREEN}Retrieving connection service account...${RESET}"
retry 3 SERVICE_ACCOUNT=$(bq show --format=json --connection "$PROJECT_ID.US.my-connection" | jq -r '.cloudResource.serviceAccountId')

if [ -z "$SERVICE_ACCOUNT" ]; then
  echo -e "${GREEN}ERROR: Could not retrieve Service Account. Exiting.${RESET}"
  exit 1
fi

echo -e "${GREEN}Service Account: $SERVICE_ACCOUNT${RESET}"
echo -e "${GREEN}Granting Storage Object Viewer role...${RESET}"
retry 3 gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member=serviceAccount:"$SERVICE_ACCOUNT" \
  --role=roles/storage.objectViewer
echo -e "${GREEN}Permissions granted successfully!${RESET}"
echo

# Section 4: Dataset Creation
echo -e "${GREEN}--- DATASET SETUP ---${RESET}"
echo -e "${GREEN}Creating 'demo_dataset' in BigQuery...${RESET}"
retry 3 bq mk demo_dataset
echo -e "${GREEN}Dataset created successfully!${RESET}"
echo

# Section 5: Table Definitions
echo -e "${GREEN}--- TABLE DEFINITIONS ---${RESET}"
echo -e "${GREEN}Creating external table definition for invoice.csv...${RESET}"
retry 3 bq mkdef \
  --autodetect \
  --connection_id="$PROJECT_ID.US.my-connection" \
  --source_format=CSV \
  "gs://$PROJECT_ID/invoice.csv" > /tmp/tabledef.json
echo -e "${GREEN}Definition saved to /tmp/tabledef.json${RESET}"
echo

# Section 6: Table Creation
echo -e "${GREEN}--- TABLE CREATION ---${RESET}"
echo -e "${GREEN}Creating BigLake table 'biglake_table'...${RESET}"
retry 3 bq mk --external_table_definition=/tmp/tabledef.json --project_id="$PROJECT_ID" demo_dataset.biglake_table
echo -e "${GREEN}BigLake table created successfully!${RESET}"

echo -e "${GREEN}Creating external table 'external_table'...${RESET}"
retry 3 bq mk --external_table_definition=/tmp/tabledef.json --project_id="$PROJECT_ID" demo_dataset.external_table
echo -e "${GREEN}External table created successfully!${RESET}"
echo

# Section 7: Schema Management
echo -e "${GREEN}--- SCHEMA MANAGEMENT ---${RESET}"
echo -e "${GREEN}Extracting schema from external table...${RESET}"
retry 3 bq show --schema --format=prettyjson demo_dataset.external_table > /tmp/schema
echo -e "${GREEN}Schema saved to /tmp/schema${RESET}"

echo -e "${GREEN}Updating external table with schema...${RESET}"
retry 3 bq update --external_table_definition=/tmp/tabledef.json --schema=/tmp/schema demo_dataset.external_table
echo -e "${GREEN}Table updated successfully!${RESET}"
echo
