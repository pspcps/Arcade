# Section 1: User Input
echo "USER CONFIGURATION"
echo "Enter USERNAME 2 (for IAM cleanup):"
read -r USER_2
echo "User input received"
echo

# Section 2: Taxonomy Setup
echo "TAXONOMY SETUP"
echo "Fetching taxonomy details..."
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

echo "Taxonomy Name: $TAXONOMY_NAME"
echo "Policy Tag: $POLICY_TAG"
echo "Taxonomy details retrieved successfully"
echo

# Section 3: BigQuery Setup
echo "BIGQUERY SETUP"
echo "Creating BigQuery dataset 'online_shop'"
bq mk online_shop
echo "Dataset created successfully"

echo "Creating BigQuery connection"
bq mk --connection --location=US --project_id=$DEVSHELL_PROJECT_ID --connection_type=CLOUD_RESOURCE user_data_connection
echo "Connection established"
echo

# Section 4: Permissions
echo "PERMISSIONS SETUP"
echo "Configuring service account permissions"
export SERVICE_ACCOUNT=$(bq show --format=json --connection $DEVSHELL_PROJECT_ID.US.user_data_connection | jq -r '.cloudResource.serviceAccountId')

gcloud projects add-iam-policy-binding $DEVSHELL_PROJECT_ID \
  --member=serviceAccount:$SERVICE_ACCOUNT \
  --role=roles/storage.objectViewer
echo "Permissions granted successfully"
echo

# Section 5: Table Configuration
echo "TABLE CONFIGURATION"
echo "Creating table definition from Cloud Storage"
bq mkdef \
--autodetect \
--connection_id=$DEVSHELL_PROJECT_ID.US.user_data_connection \
--source_format=CSV \
"gs://$DEVSHELL_PROJECT_ID-bucket/user-online-sessions.csv" > /tmp/tabledef.json
echo "Definition saved to /tmp/tabledef.json"

echo "Creating BigLake table 'user_online_sessions'"
bq mk --external_table_definition=/tmp/tabledef.json \
--project_id=$DEVSHELL_PROJECT_ID \
online_shop.user_online_sessions
echo "Table created successfully"
echo

# Section 6: Schema Management
echo "SCHEMA MANAGEMENT"
echo "Generating schema with policy tags"
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

echo "Updating table schema"
bq update --schema schema.json $DEVSHELL_PROJECT_ID:online_shop.user_online_sessions
echo "Schema updated successfully"
echo

# Section 7: Data Query
echo "DATA QUERY"
echo "Running secure query (excluding sensitive columns)"
bq query --use_legacy_sql=false --format=csv \
"SELECT * EXCEPT(zip, latitude, ip_address, longitude) 
FROM \`${DEVSHELL_PROJECT_ID}.online_shop.user_online_sessions\`"
echo "Query executed successfully"
echo

# Section 8: Cleanup
echo "CLEANUP"
if [[ -n "$USER_2" ]]; then
    echo "Removing IAM policy binding for user $USER_2"
    gcloud projects remove-iam-policy-binding ${DEVSHELL_PROJECT_ID} \
        --member="user:$USER_2" \
        --role="roles/storage.objectViewer"
    echo "Permissions cleaned up successfully"
else
    echo "Skipping IAM cleanup - no username provided"
fi
