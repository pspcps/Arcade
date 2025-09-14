BLUE_BOLD="\033[1;34m"
RESET="\033[0m"

echo -ne "${BLUE_BOLD}Please enter the REGION: ${RESET}"
read -r REGION


gcloud auth list
gcloud services enable datacatalog.googleapis.com bigqueryconnection.googleapis.com

sleep 15

bq mk --dataset ecommerce

export PROJECT_ID=$(gcloud config get-value project)

CP_URI="gs://$PROJECT_ID-bucket/customer-online-sessions.csv"


bq mk --connection --project_id=$PROJECT_ID --location=$REGION --connection_type=CLOUD_RESOURCE customer_data_connection

bq mk --external_table_definition=gs://$PROJECT_ID-bucket/customer-online-sessions.csv ecommerce.customer_online_sessions


# cat > mazekro.sh <<EOF_CP

# #!/bin/bash

# GS_URL=\$(bq show --connection \$PROJECT_ID.\$REGION.customer_data_connection | grep "serviceAccountId" | awk '{gsub(/"/, "", \$8); print \$8}')
# CP="\${GS_URL%?}"

# gcloud projects add-iam-policy-binding \$PROJECT_ID \\
#     --member="serviceAccount:\$CP" \\
#     --role="roles/storage.objectViewer"

    
# EOF_CP



# cat > mazekro.sh <<'EOF_CP'
# #!/bin/bash

# PROJECT_ID=$(gcloud config get-value project)
# REGION=$REGION

# EOF_CP



# chmod +x mazekro.sh && ./mazekro.sh


gcloud data-catalog tag-templates create sensitive_data_template --location=$REGION \
    --display-name="Sensitive Data Template" \
    --field=id=has_sensitive_data,display-name="Has Sensitive Data",type=bool \
    --field=id=sensitive_data_type,display-name="Sensitive Data Type",type='enum(Location Info|Contact Info|None)'



echo "------------Click the below link----------------"

echo -e "${BLUE_BOLD}Click here to open the link: https://console.cloud.google.com/dataplex/search?cloudshell=true&project=$PROJECT_ID${RESET}"




echo -ne "${BLUE_BOLD}Please press ENTER once the above step is completed: ${RESET}"
read


# Retry logic (max 3 attempts)
MAX_RETRIES=3
COUNT=0
SUCCESS=0

while [[ $COUNT -lt $MAX_RETRIES ]]; do

  SERVICE_ACCOUNT=$(bq show --format=json --connection ${PROJECT_ID}.${REGION}.customer_data_connection | jq -r '.cloudResource.serviceAccountId')
  
  if gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:${SERVICE_ACCOUNT}" \
    --role="roles/storage.objectViewer"; then
    echo "✅ IAM policy binding successful."
    SUCCESS=1
    break
  else
    echo "❌ Failed to bind IAM policy. Retrying in 5 seconds... (Attempt $((COUNT+1))/$MAX_RETRIES)"
    ((COUNT++))
    sleep 15
  fi
done