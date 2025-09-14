GREEN="\033[0;32m"
RESET="\033[0m"

echo -e "${GREEN}Checking active gcloud account...${RESET}"
gcloud auth list

echo -e "${GREEN}Disabling Data Catalog API...${RESET}"
gcloud services disable datacatalog.googleapis.com

echo -e "${GREEN}Enabling Data Catalog API...${RESET}"
gcloud services enable datacatalog.googleapis.com

echo -e "${GREEN}Getting default compute zone and region...${RESET}"
export ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-region])")

echo -e "${GREEN}Setting compute region to $REGION...${RESET}"
gcloud config set compute/region $REGION

echo -e "${GREEN}Getting current project ID...${RESET}"
export PROJECT_ID=$(gcloud config get-value project)
echo -e "${GREEN}Project ID is: $PROJECT_ID${RESET}"

echo -e "${GREEN}Creating BigQuery dataset 'demo_dataset'...${RESET}"
bq mk demo_dataset

echo -e "${GREEN}Copying public dataset table to demo_dataset.trips...${RESET}"
bq cp bigquery-public-data:new_york_taxi_trips.tlc_yellow_trips_2018 ${PROJECT_ID}:demo_dataset.trips

echo -e "${GREEN}Creating Data Catalog tag template 'demo_tag_template'...${RESET}"
gcloud data-catalog tag-templates create demo_tag_template \
    --location=$REGION \
    --display-name="Demo Tag Template" \
    --field=id=source_of_data_asset,display-name="Source of data asset",type=string,required=TRUE \
    --field=id=number_of_rows_in_data_asset,display-name="Number of rows in data asset",type=double \
    --field=id=has_pii,display-name="Has PII",type=bool \
    --field=id=pii_type,display-name="PII type",type='enum(Email|Social Security Number|None)'

echo -e "${GREEN}Looking up BigQuery entry for 'trips' table...${RESET}"
CP=$(gcloud data-catalog entries lookup "//bigquery.googleapis.com/projects/${PROJECT_ID}/datasets/demo_dataset/tables/trips" --format="value(name)")

echo -e "${GREEN}Creating tag file JSON...${RESET}"
cat > tag_file.json << EOF_CP
{
  "source_of_data_asset": "tlc_yellow_trips_2018",
  "pii_type": "None"
}
EOF_CP

echo -e "${GREEN}Creating Data Catalog tag on entry...${RESET}"
gcloud data-catalog tags create --entry=${CP} --tag-template-location=$REGION --tag-template=demo_tag_template --tag-file=tag_file.json

echo -e "${GREEN}Script completed successfully!${RESET}"
