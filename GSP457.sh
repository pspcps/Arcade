#!/bin/bash

# Define color variables
BLACK_TEXT=$'\033[0;90m'
RED_TEXT=$'\033[0;91m'
GREEN_TEXT=$'\033[0;92m'
YELLOW_TEXT=$'\033[0;93m'
BLUE_TEXT=$'\033[0;94m'
MAGENTA_TEXT=$'\033[0;95m'
CYAN_TEXT=$'\033[0;96m'
WHITE_TEXT=$'\033[0;97m'

NO_COLOR=$'\033[0m'
RESET_FORMAT=$'\033[0m'
BOLD_TEXT=$'\033[1m'
UNDERLINE_TEXT=$'\033[4m'

clear

read -p "${YELLOW_TEXT}${BOLD_TEXT}Enter the location: ${RESET_FORMAT}" LOCATION
export LOCATION=$LOCATION
export PROJECT_ID=$(gcloud config list --format 'value(core.project)')
export PROJECT_NUMBER=$(gcloud projects list --filter=projectId:$PROJECT_ID \
  --format="value(projectNumber)")
export DATASET_ID=dataset1
export FHIR_STORE_ID=fhirstore1
export TOPIC=fhir-topic
export HL7_STORE_ID=hl7v2store1 # Note: This variable isn't used later, maybe remove if not needed?

echo "${CYAN_TEXT}Enabling Healthcare API...${RESET_FORMAT}"
gcloud services enable healthcare.googleapis.com --project=$PROJECT_ID
# Adding a small sleep just in case enablement needs a moment, though often not strictly required
sleep 10

echo "${CYAN_TEXT}Creating Pub/Sub topic: $TOPIC...${RESET_FORMAT}"
gcloud pubsub topics create $TOPIC --project=$PROJECT_ID

echo "${CYAN_TEXT}Creating BigQuery dataset: $DATASET_ID...${RESET_FORMAT}"
bq --location=$LOCATION mk --dataset --description "HCAPI dataset" $PROJECT_ID:$DATASET_ID

echo "${CYAN_TEXT}Creating BigQuery dataset: de_id...${RESET_FORMAT}"
bq --location=$LOCATION mk --dataset --description "HCAPI dataset de-id" $PROJECT_ID:de_id

echo "${CYAN_TEXT}Creating Healthcare dataset: $DATASET_ID...${RESET_FORMAT}"
gcloud healthcare datasets create $DATASET_ID \
  --location=$LOCATION \
  --project=$PROJECT_ID

# It's good practice to wait a bit after creating the dataset for the service account to provision
echo "${YELLOW_TEXT}Waiting for Healthcare service account propagation...${RESET_FORMAT}"
sleep 15

# --- MOVED THESE SECTIONS HERE ---
echo "${CYAN_TEXT}Granting BigQuery Data Editor role to Healthcare service account...${RESET_FORMAT}"
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:service-$PROJECT_NUMBER@gcp-sa-healthcare.iam.gserviceaccount.com" \
  --role="roles/bigquery.dataEditor"

echo "${CYAN_TEXT}Granting BigQuery Job User role to Healthcare service account...${RESET_FORMAT}"
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:service-$PROJECT_NUMBER@gcp-sa-healthcare.iam.gserviceaccount.com" \
  --role="roles/bigquery.jobUser"
# --- END OF MOVED SECTION ---

echo "${CYAN_TEXT}Creating FHIR store: $FHIR_STORE_ID...${RESET_FORMAT}"
gcloud healthcare fhir-stores create $FHIR_STORE_ID \
  --dataset=$DATASET_ID \
  --location=$LOCATION \
  --version=R4 \
  --project=$PROJECT_ID

echo "${CYAN_TEXT}Updating FHIR store $FHIR_STORE_ID with Pub/Sub topic...${RESET_FORMAT}"
gcloud healthcare fhir-stores update $FHIR_STORE_ID \
  --dataset=$DATASET_ID \
  --location=$LOCATION \
  --pubsub-topic=projects/$PROJECT_ID/topics/$TOPIC \
  --project=$PROJECT_ID

# NOTE: You are creating a FHIR store named 'de_id' inside dataset 'dataset1'.
# This might be confusing later. Consider naming it something like 'fhir_store_deid'
# or creating a separate Healthcare dataset for de-identified data if appropriate.
echo "${CYAN_TEXT}Creating FHIR store: de_id...${RESET_FORMAT}"
gcloud healthcare fhir-stores create de_id \
  --dataset=$DATASET_ID \
  --location=$LOCATION \
  --version=R4 \
  --project=$PROJECT_ID

echo "${CYAN_TEXT}Importing data into FHIR store $FHIR_STORE_ID...${RESET_FORMAT}"
gcloud healthcare fhir-stores import gcs $FHIR_STORE_ID \
  --dataset=$DATASET_ID \
  --location=$LOCATION \
  --gcs-uri=gs://spls/gsp457/fhir_devdays_gcp/fhir1/* \
  --content-structure=BUNDLE_PRETTY \
  --project=$PROJECT_ID

echo "${CYAN_TEXT}Exporting data from FHIR store $FHIR_STORE_ID to BigQuery dataset $DATASET_ID...${RESET_FORMAT}"
gcloud healthcare fhir-stores export bq $FHIR_STORE_ID \
  --dataset=$DATASET_ID \
  --location=$LOCATION \
  --bq-dataset=bq://$PROJECT_ID.$DATASET_ID \
  --schema-type=analytics \
  --project=$PROJECT_ID

# ... (rest of the script with prompts and links remains the same) ...

echo
echo "${YELLOW_TEXT}${BOLD_TEXT}*****************************************${RESET_FORMAT}"
echo "${YELLOW_TEXT}${BOLD_TEXT}       NOW FOLLOW VIDEO STEPS...         ${RESET_FORMAT}"
echo "${YELLOW_TEXT}${BOLD_TEXT}*****************************************${RESET_FORMAT}"
echo

echo "${CYAN_TEXT}${BOLD_TEXT}OPEN THIS LINK: ${BLUE_TEXT}${BOLD_TEXT}https://console.cloud.google.com/healthcare/browser?project=${PROJECT_ID} ${RESET_FORMAT}" # Added project ID to link

echo "${RED_TEXT}${BOLD_TEXT}Have you completed the video steps? (y/n): ${RESET_FORMAT}"
read -r answer
if [[ $answer == "y" || $answer == "Y" ]]; then
    echo "${GREEN_TEXT}${BOLD_TEXT}Great! Proceeding with the next steps...${RESET_FORMAT}"
else
    echo "${RED_TEXT}${BOLD_TEXT}Please complete the video steps before proceeding.${RESET_FORMAT}"
    # Consider exiting if they don't complete the steps: exit 1
fi
echo


echo "${YELLOW_TEXT}Waiting (30s) for manual steps completion (if any)...${RESET_FORMAT}"
sleep 30

echo "${CYAN_TEXT}Exporting data from FHIR store de_id to BigQuery dataset de_id...${RESET_FORMAT}"
gcloud healthcare fhir-stores export bq de_id \
  --dataset=$DATASET_ID \
  --location=$LOCATION \
  --bq-dataset=bq://$PROJECT_ID.de_id \
  --schema-type=analytics \
  --project=$PROJECT_ID



echo "${CYAN_TEXT}${BOLD_TEXT}OPEN THIS LINK: ${BLUE_TEXT}${BOLD_TEXT}https://console.cloud.google.com/bigquery?project=${PROJECT_ID} ${RESET_FORMAT}" # Added project ID to link

