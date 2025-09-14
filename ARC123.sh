GREEN="\033[0;32m"
RESET="\033[0m"
BLUE_BOLD="\033[1;34m"

echo -ne "${BLUE_BOLD}Please enter the REGION: ${RESET}"
read -r REGION

echo -e "${GREEN}Listing gcloud authenticated accounts...${RESET}"
gcloud auth list

echo -e "${GREEN}Enabling Data Catalog and BigQuery Connection APIs...${RESET}"
gcloud services enable datacatalog.googleapis.com bigqueryconnection.googleapis.com

echo -e "${GREEN}Waiting 15 seconds for services to enable...${RESET}"
sleep 15

echo -e "${GREEN}Creating BigQuery dataset 'ecommerce'...${RESET}"
bq mk --dataset ecommerce

echo -e "${GREEN}Getting current project ID...${RESET}"
export PROJECT_ID=$(gcloud config get-value project)
echo -e "${GREEN}Project ID is: $PROJECT_ID${RESET}"

echo -e "${GREEN}Setting Cloud Storage URI for customer data CSV...${RESET}"
CP_URI="gs://$PROJECT_ID-bucket/customer-online-sessions.csv"
echo -e "${GREEN}CSV URI: $CP_URI${RESET}"

echo -e "${GREEN}Creating BigQuery connection 'customer_data_connection'...${RESET}"
bq mk --connection --project_id=$PROJECT_ID --location=$REGION --connection_type=CLOUD_RESOURCE customer_data_connection

echo -e "${GREEN}Creating external table 'customer_online_sessions' using CSV from Cloud Storage...${RESET}"
bq mk --external_table_definition=$CP_URI ecommerce.customer_online_sessions

echo -e "${GREEN}Generating mazekro.sh script for IAM binding...${RESET}"
cat > mazekro.sh <<EOF_CP
#!/bin/bash

GS_URL=\$(bq show --connection \$PROJECT_ID.\$REGION.customer_data_connection | grep "serviceAccountId" | awk '{gsub(/"/, "", \$8); print \$8}')
CP="\${GS_URL%?}"


SERVICE_ACCOUNT=$(bq show --format=json --connection $PROJECT_ID.$REGION.customer_data_connection | jq -r '.cloudResource.serviceAccountId')

if [[ -z "$SERVICE_ACCOUNT" ]]; then
  echo "Error: Service account not found."
  exit 1
fi

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SERVICE_ACCOUNT" \
  --role="roles/storage.objectViewer"
EOF_CP



echo -e "${GREEN}Making mazekro.sh executable and running it...${RESET}"
chmod +x mazekro.sh && ./mazekro.sh

echo -e "${GREEN}Creating Data Catalog tag template 'sensitive_data_template'...${RESET}"
gcloud data-catalog tag-templates create sensitive_data_template --location=$REGION \
    --display-name="Sensitive Data Template" \
    --field=id=has_sensitive_data,display-name="Has Sensitive Data",type=bool \
    --field=id=sensitive_data_type,display-name="Sensitive Data Type",type='enum(Location Info|Contact Info|None)'


echo -e "${GREEN}------------Click the below link----------------${RESET}"


echo -e "${BLUE_BOLD}Click here to open the link: https://console.cloud.google.com/dataplex/search?cloudshell=true&project=$PROJECT_ID${RESET}"
