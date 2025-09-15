
echo "Starting Execution"


read -p "Enter User2:" USER_2
# Enable necessary Google Cloud services for Dataplex, Data Catalog, and Dataproc
gcloud services enable \
  dataplex.googleapis.com \
  datacatalog.googleapis.com \
  dataproc.googleapis.com

# Set environment variables for project ID, zone, and region
export PROJECT_ID=$(gcloud config get-value project)
export ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo "$ZONE" | cut -d '-' -f 1-2)

# Create a Dataplex lake named "sales-lake" in the specified region
gcloud dataplex lakes create sales-lake \
  --location=$REGION \
  --display-name="Sales Lake" \
  --description="Lake for sales data"

# Create a raw data zone within the "sales-lake"
gcloud dataplex zones create raw-customer-zone \
  --lake=sales-lake \
  --location=$REGION \
  --resource-location-type=SINGLE_REGION \
  --display-name="Raw Customer Zone" \
  --discovery-enabled \
  --discovery-schedule="0 * * * *" \
  --type=RAW

# Create a curated data zone within the "sales-lake"
gcloud dataplex zones create curated-customer-zone \
  --lake=sales-lake \
  --location=$REGION \
  --resource-location-type=SINGLE_REGION \
  --display-name="Curated Customer Zone" \
  --discovery-enabled \
  --discovery-schedule="0 * * * *" \
  --type=CURATED

# Create an asset representing customer engagement data in the raw zone
gcloud dataplex assets create customer-engagements \
  --lake=sales-lake \
  --zone=raw-customer-zone \
  --location=$REGION \
  --display-name="Customer Engagements" \
  --resource-type=STORAGE_BUCKET \
  --resource-name=projects/$DEVSHELL_PROJECT_ID/buckets/$DEVSHELL_PROJECT_ID-customer-online-sessions \
  --discovery-enabled

# Create an asset representing customer order data in the curated zone
gcloud dataplex assets create customer-orders \
  --lake=sales-lake \
  --zone=curated-customer-zone \
  --location=$REGION \
  --display-name="Customer Orders" \
  --resource-type=BIGQUERY_DATASET \
  --resource-name=projects/$DEVSHELL_PROJECT_ID/datasets/customer_orders \
  --discovery-enabled

# # Create a Data Catalog tag template for protected customer data
# gcloud dataplex aspect-types create protected_customer_data_aspect \
#     --location=$REGION \
#     --display-name="Protected Customer Data Aspect" \
#     --field=id=raw_data_flag,display-name="Raw Data Flag",type='enum(Yes|No)',required=TRUE \
#     --field=id=protected_contact_information_flag,display-name="Protected Contact Information Flag",type='enum(Yes|No)',required=TRUE

# Grant "dataWriter" role to user $USER_2 on the "customer-engagements" asset
gcloud dataplex assets add-iam-policy-binding customer-engagements \
    --location=$REGION \
    --lake=sales-lake \
    --zone=raw-customer-zone \
    --role=roles/dataplex.dataWriter \
    --member=user:$USER_2



# Create a YAML file named "dq-customer-orders.yaml" with the following content:
cat > dq-customer-orders.yaml <<EOF_CP
rules:
  - nonNullExpectation: {}
    column: user_id
    dimension: COMPLETENESS
    threshold: 1.0
  - nonNullExpectation: {}
    column: order_id
    dimension: COMPLETENESS
    threshold: 1.0

postScanActions:
  bigqueryExport:
    resultsTable: "projects/$DEVSHELL_PROJECT_ID/datasets/orders_dq_dataset/tables/results"

EOF_CP


# Copy the YAML file to a Cloud Storage bucket
gsutil cp dq-customer-orders.yaml gs://$DEVSHELL_PROJECT_ID-dq-config


echo
echo
echo
read -p "Create Tag and Attach Tags and than press enter." 
echo
echo
echo
sleep 30

# export PROJECT_ID=$(gcloud config get-value project)
# export ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
# export REGION=$(echo "$ZONE" | cut -d '-' -f 1-2)


gcloud dataplex datascans create data-quality customer-orders-data-quality-job \
  --project=$PROJECT_ID \
  --location=$REGION \
  --data-source-resource="//bigquery.googleapis.com/projects/$PROJECT_ID/datasets/customer_orders/tables/ordered_items" \
  --data-quality-spec-file="gs://$DEVSHELL_PROJECT_ID-dq-config/dq-customer-orders.yaml"

