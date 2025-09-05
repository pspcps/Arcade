#!/bin/bash

echo "=================================================="
echo "          Starting Execution"
echo "=================================================="

# Step 1: Set REGION environment variable
echo "Setting the default Compute REGION from metadata"
export REGION=$(gcloud compute project-info describe \
--format="value(commonInstanceMetadata.items[google-compute-default-region])")

# Step 2: Create GCS bucket
echo "Creating Google Cloud Storage bucket"
gcloud storage buckets create gs://$GOOGLE_CLOUD_PROJECT --location=$REGION

# Step 3: Copy 'drivers' folder from public GCS to your GCS bucket
echo "Copying 'drivers' folder to your GCS bucket"
gcloud storage cp -r gs://configuring-singlestore-on-gcp/drivers gs://$GOOGLE_CLOUD_PROJECT

# Step 4: Copy 'trips' folder from public GCS to your GCS bucket
echo "Copying 'trips' folder to your GCS bucket"
gcloud storage cp -r gs://configuring-singlestore-on-gcp/trips gs://$GOOGLE_CLOUD_PROJECT

# Step 5: Copy 'neighborhoods.csv' to your GCS bucket
echo "Copying 'neighborhoods.csv' file to your GCS bucket"
gcloud storage cp gs://configuring-singlestore-on-gcp/neighborhoods.csv gs://$GOOGLE_CLOUD_PROJECT

# Step 6: Run Dataflow job to stream GCS JSON to Pub/Sub
echo "Running Dataflow job to stream JSON files from GCS to Pub/Sub"
gcloud dataflow jobs run "GCStoPS-clone" \
  --gcs-location=gs://dataflow-templates-$REGION/latest/Stream_GCS_Text_to_Cloud_PubSub \
  --region=$REGION \
  --parameters \
inputFilePattern=gs://$DEVSHELL_PROJECT_ID-dataflow/input/*.json,\
outputTopic=projects/$(gcloud config get-value project)/topics/Taxi

# Step 7: Pull messages from Pub/Sub subscription
echo "Pulling messages from 'Taxi-sub' Pub/Sub subscription"
gcloud pubsub subscriptions pull projects/$(gcloud config get-value project)/subscriptions/Taxi-sub \
--limit=10 --auto-ack

# Step 8: Run Dataflow Flex Template to stream Pub/Sub to GCS
echo "Running Dataflow Flex Template to write Pub/Sub messages to GCS"
gcloud dataflow flex-template run pstogcs \
  --template-file-gcs-location=gs://dataflow-templates-$REGION/latest/flex/Cloud_PubSub_to_GCS_Text_Flex \
  --region=$REGION \
  --parameters \
inputSubscription=projects/$(gcloud config get-value project)/subscriptions/Taxi-sub,\
outputDirectory=gs://$DEVSHELL_PROJECT_ID,\
outputFilenamePrefix=output

