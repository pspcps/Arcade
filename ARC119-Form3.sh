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

echo "${BLUE_TEXT}${BOLD_TEXT}=======================================${RESET_FORMAT}"
echo "${BLUE_TEXT}${BOLD_TEXT}         INITIATING EXECUTION...  ${RESET_FORMAT}"
echo "${BLUE_TEXT}${BOLD_TEXT}=======================================${RESET_FORMAT}"
echo

read -p "${YELLOW_TEXT}${BOLD_TEXT}Enter the ZONE: ${RESET_FORMAT}" ZONE
echo "${GREEN_TEXT}${BOLD_TEXT}✓ Zone received. Proceeding with environment setup...${RESET_FORMAT}"
echo
echo "${GREEN_TEXT}${BOLD_TEXT}Please wait while we configure the region from the provided zone.${RESET_FORMAT}"
export REGION="${ZONE%-*}"
echo "${GREEN_TEXT}${BOLD_TEXT}Region has been set successfully!${RESET_FORMAT}"
echo "${BOLD_TEXT}Region:${RESET_FORMAT} ${WHITE_TEXT}$REGION${RESET_FORMAT}"

# BigQuery operations
echo "${BOLD}${GREEN}✓${RESET} ${BLUE}Creating Raw_data dataset...${RESET}"
bq mk --location=US Raw_data

echo "${BOLD}${GREEN}✓${RESET} ${BLUE}Loading public data from Cloud Storage...${RESET}"
bq load --source_format=AVRO Raw_data.public-data gs://spls/gsp1145/users.avro

# Dataplex configuration
echo "${BOLD}${GREEN}✓${RESET} ${MAGENTA}Creating temperature-raw-data zone...${RESET}"
gcloud dataplex zones create temperature-raw-data \
    --lake=public-lake \
    --location=$REGION \
    --type=RAW \
    --resource-location-type=SINGLE_REGION \
    --display-name="temperature-raw-data"

echo "${BOLD}${GREEN}✓${RESET} ${MAGENTA}Creating customer-details-dataset asset...${RESET}"
gcloud dataplex assets create customer-details-dataset \
    --location=$REGION \
    --lake=public-lake \
    --zone=temperature-raw-data \
    --resource-type=BIGQUERY_DATASET \
    --resource-name=projects/$DEVSHELL_PROJECT_ID/datasets/customer_reference_data \
    --display-name="Customer Details Dataset" \
    --discovery-enabled

# Data Catalog setup
echo "${BOLD}${GREEN}✓${RESET} ${CYAN}Creating protected data tag template...${RESET}"
gcloud data-catalog tag-templates create protected_data_template \
    --location=$REGION \
    --display-name="Protected Data Template" \
    --field=id=protected_data_flag,display-name="Protected Data Flag",type='enum(Yes|No)',required=TRUE

echo "${GREEN_TEXT}${BOLD_TEXT}All resources have been configured successfully!${RESET_FORMAT}"
echo ""
echo "${WHITE_TEXT}1. Review your Dataplex lake at:${RESET_FORMAT}"
echo "${BLUE_TEXT}${BOLD_TEXT}https://console.cloud.google.com/dataplex/search?project=$DEVSHELL_PROJECT_ID&q=us-states&qSystems=BIGQUERY${RESET_FORMAT}"
echo ""
echo "${BLUE_TEXT}${BOLD_TEXT}https://console.cloud.google.com/dataplex/govern${RESET_FORMAT}"

echo
echo "${GREEN_TEXT}${BOLD_TEXT}              LAB COMPLETED SUCCESSFULLY!              ${RESET_FORMAT}"
echo
