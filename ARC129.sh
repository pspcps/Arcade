GREEN="\033[0;32m"
RESET="\033[0m"
RED="\033[0;31m"
YELLOW="\033[0;33m"

echo -e "${GREEN}⚡ Initializing Data Governance Configuration...${RESET}"
echo

# Section 1: User Input
echo -e "${GREEN}▬▬▬▬▬▬▬▬▬▬▬ USER CONFIGURATION ▬▬▬▬▬▬▬▬▬▬${RESET}"
echo -e "${GREEN}👤 Enter USERNAME 2 (for IAM cleanup): ${RESET}"
read -r USER_2
echo -e "${GREEN}✔ User input received${RESET}"
echo

# Section 2: Taxonomy Setup
echo -e "${GREEN}▬▬▬▬▬▬▬▬▬▬▬ TAXONOMY SETUP ▬▬▬▬▬▬▬▬▬▬▬▬${RESET}"
echo -e "${GREEN}🏷️  Fetching taxonomy details...${RESET}"
export TAXONOMY_NAME=$(gcloud data-catalog taxonomies list \
  --location=us \
  --project=$DEVSHELL_PROJECT_ID \
  --format="value(displayName)" \
  --limit=1)

export TAXONOMY_ID=$(gcloud data-catalog taxonomies list \
  --location=us \
  --format="value(name)" \
  --filter="displayName=$TAXONOMY_NAME" | awk -F'/' '{print $6}')

export POLICY_TAG=$(gcloud data-catalog taxonomies policy-tags list \
  --location=us \
  --taxonomy=$TAXONOMY_ID \
  --format="value(name)" \
  --limit=1)

echo -e "${GREEN}Taxonomy Name: $TAXONOMY_NAME${RESET}"
echo -e "${GREEN}Policy Tag: $POLICY_TAG${RESET}"
echo -e "${GREEN}✅ Taxonomy details retrieved successfully!${RESET}"
echo

# Section 3: BigQuery Setup
echo -e "${GREEN}▬▬▬▬▬▬▬▬▬▬▬ BIGQUERY SETUP ▬▬▬▬▬▬▬▬▬▬▬▬${RESET}"
echo -e "${GREEN}📊 Creating BigQuery dataset 'online_shop'${RESET}"
bq mk online_shop
echo -e "${GREEN}✅ Dataset created successfully!${RESET}"

echo -e "${GREEN}🔗 Creating BigQuery connection${RESET}"
bq mk --connection --location=US --project_id=$DEVSHELL_PROJECT_ID --connection_type=CLOUD_RESOURCE user_data_connection
echo -e "${GREEN}✅ Connection established!${RESET}"
echo

# Section 4: Permissions
echo -e "${GREEN}▬▬▬▬▬▬▬▬▬▬ PERMISSIONS SETUP ▬▬▬▬▬▬▬▬▬▬${RESET}"
echo -e "${GREEN}🔑 Configuring service account permissions${RESET}"
export SERVICE_ACCOUNT=$(bq show --format=json --connection $DEVSHELL_PROJECT_ID.US.user_data_connection | jq -r '.cloudResource.serviceAccountId')

gcloud projects add-iam-policy-binding $DEVSHELL_PROJECT_ID \
  --member=serviceAccount:$SERVICE_ACCOUNT \
  --role=roles/storage.objectViewer
echo -e "${GREEN}✅ Permissions granted successfully!${RESET}"
echo

# Section 5: Table Configuration
echo -e "${GREEN}▬▬▬▬▬▬▬▬▬▬ TABLE CONFIGURATION ▬▬▬▬▬▬▬▬▬${RESET}"
echo -e "${GREEN}📝 Creating table definition from Cloud Storage${RESET}"
bq mkdef \
--autodetect \
--connection_id=$DEVSHELL_PROJECT_ID.US.user_data_connection \
--source_format=CSV \
"gs://$DEVSHELL_PROJECT_ID-bucket/user-online-sessions.csv" > /tmp/tabledef.json
echo -e "${GREEN}Definition saved to /tmp/tabledef.json${RESET}"

echo -e "${GREEN}🆕 Creating BigLake table 'user_online_sessions'${RESET}"
bq mk --external_table_definition=/tmp/tabledef.json \
--project_id=$DEVSHELL_PROJECT_ID \
online_shop.user_online_sessions
echo -e "${GREEN}✅ Table created successfully!${RESET}"
echo

# Section 6: Schema Management
echo -e "${GREEN}▬▬▬▬▬▬▬▬▬▬ SCHEMA MANAGEMENT ▬▬▬▬▬▬▬▬▬▬${RESET}"
echo -e "${GREEN}📋 Generating schema with policy tags${RESET}"
cat > schema.json << EOM
[
  {
    "mode": "NULLABLE",
    "name": "ad_event_id",
    "type": "INTEGER"
  },
  {
    "mode": "NULLABLE",
    "name": "user_id",
    "type": "INTEGER"
  },
  {
    "mode": "NULLABLE",
    "name": "uri",
    "type": "STRING"
  },
  {
    "mode": "NULLABLE",
    "name": "traffic_source",
    "type": "STRING"
  },
  {
    "mode": "NULLABLE",
    "name": "zip",
    "policyTags": {
      "names": [
        "$POLICY_TAG"
      ]
    },
    "type": "STRING"
  },
  {
    "mode": "NULLABLE",
    "name": "event_type",
    "type": "STRING"
  },
  {
    "mode": "NULLABLE",
    "name": "state",
    "type": "STRING"
  },
  {
    "mode": "NULLABLE",
    "name": "country",
    "type": "STRING"
  },
  {
    "mode": "NULLABLE",
    "name": "city",
    "type": "STRING"
  },
  {
    "mode": "NULLABLE",
    "name": "latitude",
    "policyTags": {
      "names": [
        "$POLICY_TAG"
      ]
    },
    "type": "FLOAT"
  },
  {
    "mode": "NULLABLE",
    "name": "created_at",
    "type": "TIMESTAMP"
  },
  {
    "mode": "NULLABLE",
    "name": "ip_address",
    "policyTags": {
      "names": [
        "$POLICY_TAG"
      ]
    },
    "type": "STRING"
  },
  {
    "mode": "NULLABLE",
    "name": "session_id",
    "type": "STRING"
  },
  {
    "mode": "NULLABLE",
    "name": "longitude",
    "policyTags": {
      "names": [
        "$POLICY_TAG"
      ]
    },
    "type": "FLOAT"
  },
  {
    "mode": "NULLABLE",
    "name": "id",
    "type": "INTEGER"
  }
]
EOM

echo -e "${GREEN}🔄 Updating table schema${RESET}"
bq update --schema schema.json $DEVSHELL_PROJECT_ID:online_shop.user_online_sessions
echo -e "${GREEN}✅ Schema updated successfully!${RESET}"
echo

# Section 7: Data Query
echo -e "${GREEN}▬▬▬▬▬▬▬▬▬▬▬ DATA QUERY ▬▬▬▬▬▬▬▬▬▬▬▬▬${RESET}"
echo -e "${GREEN}🔍 Running secure query (excluding sensitive columns)...${RESET}"
bq query --use_legacy_sql=false --format=csv \
"SELECT * EXCEPT(zip, latitude, ip_address, longitude) 
FROM \`${DEVSHELL_PROJECT_ID}.online_shop.user_online_sessions\`"
echo -e "${GREEN}✅ Query executed successfully!${RESET}"
echo

# Section 8: Cleanup
echo -e "${GREEN}▬▬▬▬▬▬▬▬▬▬▬ CLEANUP ▬▬▬▬▬▬▬▬▬▬▬▬▬${RESET}"
if [[ -n "$USER_2" ]]; then
    echo -e "${RED}🧹 Removing IAM policy binding for user $USER_2${RESET}"
    gcloud projects remove-iam-policy-binding ${DEVSHELL_PROJECT_ID} \
        --member="user:$USER_2" \
        --role="roles/storage.objectViewer"
    echo -e "${GREEN}✅ Permissions cleaned up successfully!${RESET}"
else
    echo -e "${YELLOW}⚠️  Skipping IAM cleanup - no username provided${RESET}"
fi

echo
