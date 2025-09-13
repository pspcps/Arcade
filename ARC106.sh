#!/bin/bash

# Prompt the user to enter required variables
read -p "Enter REGION: " REGION
export REGION

read -p "Enter DATASET name: " DATASET
export DATASET

read -p "Enter TABLE name: " TABLE
export TABLE

read -p "Enter Pub/Sub TOPIC name: " TOPIC
export TOPIC

read -p "Enter JOB name: " JOB
export JOB

echo "Starting Execution..."

# Get current project ID from gcloud config
export PROJECT_ID=$(gcloud config get-value project)

# Create GCS bucket
gsutil mb gs://$PROJECT_ID

# Create BigQuery dataset and table
bq mk $DATASET
bq mk --table \
$PROJECT_ID:$DATASET.$TABLE \
data:string

# Create Pub/Sub topic and subscription
gcloud pubsub topics create $TOPIC
gcloud pubsub subscriptions create $TOPIC-sub --topic=$TOPIC

# Run Flex Template Dataflow job
gcloud dataflow flex-template run $JOB --region $REGION \
--template-file-gcs-location gs://dataflow-templates-$REGION/latest/flex/PubSub_to_BigQuery_Flex \
--temp-location gs://$PROJECT_ID/temp/ \
--parameters outputTableSpec=$PROJECT_ID:$DATASET.$TABLE,\
inputTopic=projects/$PROJECT_ID/topics/$TOPIC,\
outputDeadletterTable=$PROJECT_ID:$DATASET.$TABLE,\
javascriptTextTransformReloadIntervalMinutes=0,\
useStorageWriteApi=false,\
useStorageWriteApiAtLeastOnce=false,\
numStorageWriteApiStreams=0

# Wait for the Dataflow job to start and publish a test message
while true; do
    STATUS=$(gcloud dataflow jobs list --region="$REGION" --format='value(STATE)' | grep Running)
    
    if [ "$STATUS" == "Running" ]; then
        echo "The Dataflow job is running successfully."

        sleep 20
        gcloud pubsub topics publish $TOPIC --message='{"data": "73.4 F"}'

        bq query --nouse_legacy_sql "SELECT * FROM \`$PROJECT_ID.$DATASET.$TABLE\`"
        break
    else
        sleep 30
        echo "The Dataflow job is not running. Please wait..."
    fi
done

# Optionally run a classic Dataflow job
gcloud dataflow jobs run $JOB-sparkwave --gcs-location gs://dataflow-templates-$REGION/latest/PubSub_to_BigQuery \
--region=$REGION \
--project=$PROJECT_ID \
--staging-location gs://$PROJECT_ID/temp \
--parameters inputTopic=projects/$PROJECT_ID/topics/$TOPIC,outputTableSpec=$PROJECT_ID:$DATASET.$TABLE

# Wait for the second job to start
while true; do
    STATUS=$(gcloud dataflow jobs list --region=$REGION --project=$PROJECT_ID --filter="name:$JOB-sparkwave AND state:Running" --format="value(state)")
    
    if [ "$STATUS" == "Running" ]; then
        echo "The second Dataflow job is running successfully."

        sleep 20
        gcloud pubsub topics publish $TOPIC --message='{"data": "73.4 F"}'

        bq query --nouse_legacy_sql "SELECT * FROM \`$PROJECT_ID.$DATASET.$TABLE\`"
        break
    else
        sleep 30
        echo "The second Dataflow job is not running. Please wait..."
    fi
done

echo "Congratulations for completing the lab!"
