
echo "Please enter your preferred Region (e.g., us-central1):"
read -p "REGION: " REGION



gcloud auth list

gcloud services enable dataproc.googleapis.com dataplex.googleapis.com datacatalog.googleapis.com

sleep 10

gcloud dataplex lakes create ecommerce-lake --location=$REGION --display-name="Ecommerce Lake"

gcloud projects add-iam-policy-binding $DEVSHELL_PROJECT_ID --member=user:$USER_EMAIL --role=roles/dataplex.admin

sleep 20

gcloud dataplex zones create customer-contact-raw-zone --location=$REGION --display-name="Customer Contact Raw Zone" --lake=ecommerce-lake --type=RAW --resource-location-type=SINGLE_REGION

gcloud dataplex assets create contact-info --location=$REGION --display-name="Contact Info" --lake=ecommerce-lake --zone=customer-contact-raw-zone --resource-type=BIGQUERY_DATASET --resource-name=projects/$DEVSHELL_PROJECT_ID/datasets/customers --discovery-enabled 


# bq query --use_legacy_sql=false "
#   SELECT * FROM \`$DEVSHELL_PROJECT_ID.customers.contact_info\`
#   ORDER BY id
#   LIMIT 50
# "


cat > dq-customer-raw-data.yaml <<EOF_CP
rules:
- nonNullExpectation: {}
  column: id
  dimension: COMPLETENESS
  threshold: 1
- regexExpectation:
    regex: '^[^@]+[@]{1}[^@]+$'
  column: email
  dimension: CONFORMANCE
  ignoreNull: true
  threshold: .85
postScanActions:
  bigqueryExport:
    resultsTable: projects/$DEVSHELL_PROJECT_ID/datasets/customers_dq_dataset/tables/dq_results
EOF_CP


gsutil cp dq-customer-raw-data.yaml gs://$DEVSHELL_PROJECT_ID-bucket


  
# bq query --use_legacy_sql=false "
#   SELECT * FROM \`$DEVSHELL_PROJECT_ID.customers.contact_info\`
#   ORDER BY id
#   LIMIT 50
# "


gcloud dataplex datascans create data-quality customer-orders-data-quality-job \
    --project=$DEVSHELL_PROJECT_ID \
    --location=$REGION \
    --data-source-resource="//bigquery.googleapis.com/projects/$DEVSHELL_PROJECT_ID/datasets/customers/tables/contact_info" \
    --data-quality-spec-file="gs://$DEVSHELL_PROJECT_ID-bucket/dq-customer-raw-data.yaml"

  
