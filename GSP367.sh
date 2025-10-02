clear

#!/bin/bash
# Define color variables

BLACK=`tput setaf 0`
RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 3`
BLUE=`tput setaf 4`
MAGENTA=`tput setaf 5`
CYAN=`tput setaf 6`
WHITE=`tput setaf 7`

BG_BLACK=`tput setab 0`
BG_RED=`tput setab 1`
BG_GREEN=`tput setab 2`
BG_YELLOW=`tput setab 3`
BG_BLUE=`tput setab 4`
BG_MAGENTA=`tput setab 5`
BG_CYAN=`tput setab 6`
BG_WHITE=`tput setab 7`

BOLD=`tput bold`
RESET=`tput sgr0`

# Array of color codes excluding black and white
TEXT_COLORS=($RED $GREEN $YELLOW $BLUE $MAGENTA $CYAN)
BG_COLORS=($BG_RED $BG_GREEN $BG_YELLOW $BG_BLUE $BG_MAGENTA $BG_CYAN)

# Pick random colors
RANDOM_TEXT_COLOR=${TEXT_COLORS[$RANDOM % ${#TEXT_COLORS[@]}]}
RANDOM_BG_COLOR=${BG_COLORS[$RANDOM % ${#BG_COLORS[@]}]}

#----------------------------------------------------start--------------------------------------------------#

echo "${RANDOM_BG_COLOR}${RANDOM_TEXT_COLOR}${BOLD}Starting Execution${RESET}"

# Function to prompt user for input and export it as PROCESSOR
get_processor_input() {
    # Prompt user for input
    echo
    echo -n "${MAGENTA}${BOLD}Enter the processor name: ${RESET}"
    read -r processor_input
    
    # Export the input as an environment variable
    export PROCESSOR="$processor_input"
    
    # Print confirmation
    echo
    echo "${GREEN}${BOLD}Thanks for your input!${RESET}"
    echo

}

# Call the function
get_processor_input

# Step 1: Retrieve project details
echo "${CYAN}${BOLD}Fetching Project Details...${RESET}"
export PROJECT_ID=$(gcloud config get-value core/project)
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')
export ZONE=$(gcloud compute instances list lab-vm --format 'csv[no-heading](zone)')
export REGION=$(gcloud compute project-info describe \
--format="value(commonInstanceMetadata.items[google-compute-default-region])")
export BUCKET_LOCATION=$REGION

# Step 2: Enable required Google Cloud services
echo "${BLUE}${BOLD}Enabling Required Services...${RESET}"
gcloud services enable documentai.googleapis.com      
gcloud services enable cloudfunctions.googleapis.com  
gcloud services enable cloudbuild.googleapis.com    
gcloud services enable geocoding-backend.googleapis.com 
gcloud services enable eventarc.googleapis.com
gcloud services enable run.googleapis.com

# Step 3: Create a local directory and copy files
echo "${YELLOW}${BOLD}Setting up local environment...${RESET}"
  mkdir ./document-ai-challenge
  gsutil -m cp -r gs://spls/gsp367/* \
    ~/document-ai-challenge/

# Step 4: Create a processor
echo "${MAGENTA}${BOLD}Creating Processor...${RESET}"
ACCESS_TOKEN=$(gcloud auth application-default print-access-token)

curl -X POST \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "display_name": "'"$PROCESSOR"'",
    "type": "FORM_PARSER_PROCESSOR"
  }' \
  "https://documentai.googleapis.com/v1/projects/$PROJECT_ID/locations/us/processors"

# Step 5: Create Cloud Storage buckets
echo "${BLUE}${BOLD}Creating Cloud Storage Buckets...${RESET}"
gsutil mb -c standard -l ${BUCKET_LOCATION} -b on \
 gs://${PROJECT_ID}-input-invoices
gsutil mb -c standard -l ${BUCKET_LOCATION} -b on \
 gs://${PROJECT_ID}-output-invoices
gsutil mb -c standard -l ${BUCKET_LOCATION} -b on \
 gs://${PROJECT_ID}-archived-invoices

# Step 6: Create BigQuery dataset and table
echo "${CYAN}${BOLD}Setting up BigQuery Dataset and Table...${RESET}"
bq --location="US" mk  -d \
    --description "Form Parser Results" \
    ${PROJECT_ID}:invoice_parser_results
    
cd ~/document-ai-challenge/scripts/table-schema/

bq mk --table \
invoice_parser_results.doc_ai_extracted_entities \
doc_ai_extracted_entities.json

cd ~/document-ai-challenge/scripts 

# Step 7: Grant IAM permissions
echo "${MAGENTA}${BOLD}Granting IAM Permissions...${RESET}"
SERVICE_ACCOUNT=$(gcloud storage service-agent --project=$PROJECT_ID)

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member serviceAccount:$SERVICE_ACCOUNT \
  --role roles/pubsub.publisher

# Step 8: Set Cloud Function location and deploy function
echo "${BLUE}${BOLD}Deploying Cloud Function...${RESET}"
export CLOUD_FUNCTION_LOCATION=$REGION

sleep 20

deploy_function() {
gcloud functions deploy process-invoices \
  --gen2 \
  --region=${CLOUD_FUNCTION_LOCATION} \
  --entry-point=process_invoice \
  --runtime=python39 \
  --service-account=${PROJECT_ID}@appspot.gserviceaccount.com \
  --source=cloud-functions/process-invoices \
  --timeout=400 \
  --env-vars-file=cloud-functions/process-invoices/.env.yaml \
  --trigger-resource=gs://${PROJECT_ID}-input-invoices \
  --trigger-event=google.storage.object.finalize\
  --service-account $PROJECT_NUMBER-compute@developer.gserviceaccount.com \
  --allow-unauthenticated
}

deploy_success=false

while [ "$deploy_success" = false ]; do
  if deploy_function; then
    echo "${GREEN}${BOLD}Function deployed successfully.${RESET}"
    deploy_success=true
  else
    echo "${RED}${BOLD}Deployment failed, retrying in 30 seconds...${RESET}"
    sleep 30
  fi
done

# Step 9: Fetch and update PROCESSOR_ID
echo "${CYAN}${BOLD}Fetching Processor ID...${RESET}"
PROCESSOR_ID=$(curl -X GET \
  -H "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
  -H "Content-Type: application/json" \
  "https://documentai.googleapis.com/v1/projects/$PROJECT_ID/locations/us/processors" | \
  grep '"name":' | \
  sed -E 's/.*"name": "projects\/[0-9]+\/locations\/us\/processors\/([^"]+)".*/\1/')

export PROCESSOR_ID

# Step 10: Update Cloud Function
echo "${BLUE}${BOLD}Updating Cloud Function...${RESET}"
gcloud functions deploy process-invoices \
  --gen2 \
  --region=${CLOUD_FUNCTION_LOCATION} \
  --entry-point=process_invoice \
  --runtime=python39 \
  --source=cloud-functions/process-invoices \
  --timeout=400 \
  --trigger-resource=gs://${PROJECT_ID}-input-invoices \
  --trigger-event=google.storage.object.finalize \
  --update-env-vars=PROCESSOR_ID=${PROCESSOR_ID},PARSER_LOCATION=us,PROJECT_ID=${PROJECT_ID} \
  --service-account=$PROJECT_NUMBER-compute@developer.gserviceaccount.com


# Step 11: Upload invoices
echo "${MAGENTA}${BOLD}Uploading Sample Invoices...${RESET}"
gsutil -m cp -r gs://cloud-training/gsp367/* \
~/document-ai-challenge/invoices gs://${PROJECT_ID}-input-invoices/

echo
