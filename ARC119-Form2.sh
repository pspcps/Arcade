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
echo "${BOLD_TEXT}Region:${RESET_FORMAT} ${WHITE_TEXT}$REGION${RESET_FORMAT}"
echo "${BOLD_TEXT}Labels:${RESET_FORMAT} ${WHITE_TEXT}$KEY_1=$VALUE_1${RESET_FORMAT}"

# Dataplex Lake creation
echo "${CYAN_TEXT}${BOLD_TEXT}Step 1: Configuring Dataplex Lake...${RESET_FORMAT}"
echo "${YELLOW_TEXT}${BOLD_TEXT}This step will create a Dataplex Lake named 'Customer-Lake' in the specified region.${RESET_FORMAT}"
echo "${BOLD_TEXT}${GREEN}✓${RESET_FORMAT} ${BLUE_TEXT}Creating Customer Lake...${RESET_FORMAT}"
gcloud alpha dataplex lakes create customer-lake \
    --display-name="Customer-Lake" \
    --location=$REGION \
    --labels="key_1=$KEY_1,value_1=$VALUE_1"

# Zone creation
echo "${CYAN_TEXT}${BOLD_TEXT}Step 2: Setting up Dataplex Zone...${RESET_FORMAT}"
echo "${YELLOW_TEXT}${BOLD_TEXT}This step will create a Public Zone under the Dataplex Lake.${RESET_FORMAT}"
echo "${BOLD_TEXT}${GREEN}✓${RESET_FORMAT} ${MAGENTA_TEXT}Creating Public Zone...${RESET_FORMAT}"
gcloud dataplex zones create public-zone \
    --lake=customer-lake \
    --location=$REGION \
    --type=RAW \
    --resource-location-type=SINGLE_REGION \
    --display-name="Public-Zone"

# Environment creation
echo "${CYAN_TEXT}${BOLD_TEXT}Step 3: Creating Dataplex Environment...${RESET_FORMAT}"
echo "${YELLOW_TEXT}${BOLD_TEXT}This step will create an environment for Dataplex Lake with compute resources.${RESET_FORMAT}"
echo "${BOLD_TEXT}${GREEN}✓${RESET_FORMAT} ${CYAN_TEXT}Creating Dataplex Environment...${RESET_FORMAT}"
gcloud dataplex environments create dataplex-lake-env \
    --project=$DEVSHELL_PROJECT_ID \
    --location=$REGION \
    --lake=customer-lake \
    --os-image-version=1.0 \
    --compute-node-count 3 \
    --compute-max-node-count 3

# Asset creation
echo "${CYAN_TEXT}${BOLD_TEXT}Step 4: Creating Data Assets...${RESET_FORMAT}"
echo "${YELLOW_TEXT}${BOLD_TEXT}This step will create two assets: Customer Raw Data and Customer Reference Data.${RESET_FORMAT}"
echo "${BOLD_TEXT}${GREEN}✓${RESET_FORMAT} ${YELLOW_TEXT}Creating Customer Raw Data asset...${RESET_FORMAT}"
gcloud dataplex assets create customer-raw-data \
    --location=$REGION \
    --lake=customer-lake \
    --zone=public-zone \
    --resource-type=STORAGE_BUCKET \
    --resource-name=projects/$DEVSHELL_PROJECT_ID/buckets/$DEVSHELL_PROJECT_ID-customer-bucket \
    --discovery-enabled \
    --display-name="Customer Raw Data"

echo "${BOLD_TEXT}${GREEN}✓${RESET_FORMAT} ${YELLOW_TEXT}Creating Customer Reference Data asset...${RESET_FORMAT}"
gcloud dataplex assets create customer-reference-data \
    --location=$REGION \
    --lake=customer-lake \
    --zone=public-zone \
    --resource-type=BIGQUERY_DATASET \
    --resource-name=projects/$DEVSHELL_PROJECT_ID/datasets/customer_reference_data \
    --display-name="Customer Reference Data"

# Data Catalog setup
echo "${CYAN_TEXT}${BOLD_TEXT}Step 5: Configuring Data Governance...${RESET_FORMAT}"
echo "${BOLD_TEXT}${GREEN_TEXT}Executing command...${RESET_FORMAT}"
echo "${BOLD_TEXT}${GREEN}✓${RESET_FORMAT} ${BLUE_TEXT}Creating Data Catalog Tag Template...${RESET_FORMAT}"
gcloud data-catalog tag-templates create customer_data_tag_template \
    --location=$REGION \
    --display-name="Customer Data Tag Template" \
    --field=id=data_owner,display-name="Data Owner",type=string,required=TRUE \
    --field=id=pii_data,display-name="PII Data",type='enum(Yes|No)',required=TRUE

echo
echo "${YELLOW_TEXT}${BOLD_TEXT}OPEN THIS LINK: ${BLUE_TEXT}${BOLD_TEXT}https://console.cloud.google.com/projectselector2/dataplex/groups${RESET_FORMAT}"

echo
echo "${GREEN_TEXT}${BOLD_TEXT}=======================================================${RESET_FORMAT}"
echo "${GREEN_TEXT}${BOLD_TEXT}              LAB COMPLETED SUCCESSFULLY!              ${RESET_FORMAT}"
echo "${GREEN_TEXT}${BOLD_TEXT}=======================================================${RESET_FORMAT}"
echo
