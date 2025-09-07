#!/bin/bash

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


echo "INITIATING EXECUTION..."

echo

read -p "${YELLOW_TEXT}${BOLD_TEXT}Enter the ZONE: ${RESET_FORMAT}" ZONE
echo "${GREEN_TEXT}${BOLD_TEXT}Zone received: ${ZONE}. Proceeding with environment setup...${RESET_FORMAT}"
echo
export REGION="${ZONE%-*}"

echo "${CYAN_TEXT}${BOLD_TEXT}Step 1: Creating a Dataplex lake named 'customer-lake'...${RESET_FORMAT}"
gcloud alpha dataplex lakes create customer-lake \
--display-name="Customer-Lake" \
 --location=$REGION \
 --labels="key_1=$KEY_1,value_1=$VALUE_1"

echo "${CYAN_TEXT}${BOLD_TEXT}Step 2: Creating a Dataplex zone named 'public-zone'...${RESET_FORMAT}"
gcloud dataplex zones create public-zone \
    --lake=customer-lake \
    --location=$REGION \
    --type=RAW \
    --resource-location-type=SINGLE_REGION \
    --display-name="Public-Zone"

echo "${CYAN_TEXT}${BOLD_TEXT}Step 3: Creating a Dataplex asset for raw data in Cloud Storage...${RESET_FORMAT}"
gcloud dataplex assets create customer-raw-data --location=$REGION \
            --lake=customer-lake --zone=public-zone \
            --resource-type=STORAGE_BUCKET \
            --resource-name=projects/$DEVSHELL_PROJECT_ID/buckets/$DEVSHELL_PROJECT_ID-customer-bucket \
            --discovery-enabled \
            --display-name="Customer Raw Data"

echo "${CYAN_TEXT}${BOLD_TEXT}Step 4: Creating a Dataplex asset for reference data in BigQuery...${RESET_FORMAT}"
gcloud dataplex assets create customer-reference-data --location=$REGION \
            --lake=customer-lake --zone=public-zone \
            --resource-type=BIGQUERY_DATASET \
            --resource-name=projects/$DEVSHELL_PROJECT_ID/datasets/customer_reference_data \
            --display-name="Customer Reference Data"

echo "${CYAN_TEXT}${BOLD_TEXT}Step 5: You can now create entities in the Dataplex zone.${RESET_FORMAT}"
echo "${YELLOW_TEXT}${BOLD_TEXT}OPEN THIS LINK:${BLUE_TEXT}${BOLD_TEXT} https://console.cloud.google.com/dataplex/lakes/customer-lake/zones/public-zone/create-entity;location=$REGION?project=$DEVSHELL_PROJECT_ID ${RESET_FORMAT}"

echo
echo "LAB COMPLETED SUCCESSFULLY!"
echo
