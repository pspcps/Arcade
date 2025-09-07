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

# Prompt user to input three regions

read -p "${YELLOW_TEXT}${BOLD_TEXT}Enter the ZONE: ${RESET_FORMAT}" ZONE
echo "${GREEN_TEXT}${BOLD_TEXT}✓ Zone received. Proceeding with environment setup...${RESET_FORMAT}"
echo
echo "${YELLOW_TEXT}${BOLD_TEXT}Setting up environment variables based on the provided zone...${RESET_FORMAT}"
export REGION="${ZONE%-*}"
export KEY_1=domain_type
export VALUE_1=source_data
echo "${GREEN_TEXT}${BOLD_TEXT}✓ Environment variables set successfully.${RESET_FORMAT}"
echo "${WHITE_TEXT}${BOLD_TEXT}Region:${RESET_FORMAT} ${WHITE_TEXT}$REGION${RESET_FORMAT}"
echo "${WHITE_TEXT}${BOLD_TEXT}Labels:${RESET_FORMAT} ${WHITE_TEXT}$KEY_1=$VALUE_1${RESET_FORMAT}"

# Storage setup
echo "${MAGENTA_TEXT}${BOLD_TEXT}Creating a storage bucket to store your data securely...${RESET_FORMAT}"
echo "${GREEN_TEXT}${BOLD_TEXT}✓ Proceeding with bucket creation...${RESET_FORMAT}"
gsutil mb -p $DEVSHELL_PROJECT_ID -l $REGION -b on gs://$DEVSHELL_PROJECT_ID-bucket/

# Dataplex Lake creation
echo "${BLUE_TEXT}${BOLD_TEXT}Creating a Dataplex Lake to manage your data assets...${RESET_FORMAT}"
echo "${GREEN_TEXT}${BOLD_TEXT}✓ Proceeding with Dataplex Lake creation...${RESET_FORMAT}"
gcloud alpha dataplex lakes create customer-lake \
    --display-name="Customer-Lake" \
    --location=$REGION \
    --labels="key_1=$KEY_1,value_1=$VALUE_1"

# Zone creation
echo "${CYAN_TEXT}${BOLD_TEXT}Creating a Public Zone within the Dataplex Lake...${RESET_FORMAT}"
echo "${GREEN_TEXT}${BOLD_TEXT}✓ Proceeding with zone creation...${RESET_FORMAT}"
gcloud dataplex zones create public-zone \
    --lake=customer-lake \
    --location=$REGION \
    --type=RAW \
    --resource-location-type=SINGLE_REGION \
    --display-name="Public-Zone"

# Environment creation
echo "${YELLOW_TEXT}${BOLD_TEXT}Setting up an analytics environment for data processing...${RESET_FORMAT}"
echo "${GREEN_TEXT}${BOLD_TEXT}✓ Proceeding with environment creation...${RESET_FORMAT}"
gcloud dataplex environments create dataplex-lake-env \
    --project=$DEVSHELL_PROJECT_ID \
    --location=$REGION \
    --lake=customer-lake \
    --os-image-version=1.0 \
    --compute-node-count 3 \
    --compute-max-node-count 3

# Data governance
echo "${MAGENTA_TEXT}${BOLD_TEXT}Setting up data governance policies for your data lake...${RESET_FORMAT}"
echo "${GREEN_TEXT}${BOLD_TEXT}✓ Proceeding with tag template creation...${RESET_FORMAT}"
gcloud data-catalog tag-templates create customer_data_tag_template \
    --location=$REGION \
    --display-name="Customer Data Tag Template" \
    --field=id=data_owner,display-name="Data Owner",type=string,required=TRUE \
    --field=id=pii_data,display-name="PII Data",type="enum(Yes|No)",required=TRUE

echo
echo "${YELLOW_TEXT}${BOLD_TEXT}OPEN THIS LINK: ${BLUE_TEXT}${BOLD_TEXT}https://console.cloud.google.com/projectselector2/dataplex/groups${RESET_FORMAT}"

echo
echo "${GREEN_TEXT}${BOLD_TEXT}=======================================================${RESET_FORMAT}"
echo "${GREEN_TEXT}${BOLD_TEXT}              LAB COMPLETED SUCCESSFULLY!              ${RESET_FORMAT}"
echo "${GREEN_TEXT}${BOLD_TEXT}=======================================================${RESET_FORMAT}"
echo
