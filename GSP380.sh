#!/bin/bash

# Prompt user for input zone
read -p "Enter the GCP Zone (e.g. us-central1-a): " ZONE
export ZONE
export REGION="${ZONE%-*}"
export PROJECT_ID=$(gcloud config get-value project)
export DEVSHELL_PROJECT_ID=$PROJECT_ID

# Set config
gcloud config set compute/zone "$ZONE"
gcloud config set compute/region "$REGION"

# Re-enable Dataflow API to ensure clean state
gcloud services disable dataflow.googleapis.com --project $PROJECT_ID
gcloud services enable dataflow.googleapis.com --project $PROJECT_ID

echo "Creating Bigtable instance..."

# Create Bigtable instance with autoscaling
gcloud bigtable instances create ecommerce-recommendations \
  --cluster=ecommerce-recommendations-c1 \
  --cluster-zone=$ZONE \
  --cluster-storage-type=ssd \
  --autoscaling-min-nodes=1 \
  --autoscaling-max-nodes=5 \
  --autoscaling-cpu-target=60 \
  --display-name="ecommerce-recommendations"

# Create a bucket
echo "Creating Cloud Storage bucket..."
gsutil mb -l $REGION gs://$PROJECT_ID

# Create SessionHistory table
echo "Creating Bigtable table: SessionHistory"
gcloud bigtable instances tables create SessionHistory \
  --instance=ecommerce-recommendations \
  --column-families=Engagements,Sales

# Load data into SessionHistory via Dataflow
echo "Launching Dataflow job: import-sessions"

while true; do
  gcloud dataflow jobs run import-sessions \
    --region=$REGION \
    --project=$PROJECT_ID \
    --gcs-location gs://dataflow-templates-$REGION/latest/GCS_SequenceFile_to_Cloud_Bigtable \
    --staging-location gs://$PROJECT_ID/temp \
    --parameters bigtableProject=$PROJECT_ID,bigtableInstanceId=ecommerce-recommendations,bigtableTableId=SessionHistory,sourcePattern=gs://cloud-training/OCBL377/retail-engagements-sales-00000-of-00001,mutationThrottleLatencyMs=0

  if [ $? -eq 0 ]; then
    echo "Job import-sessions submitted successfully. Monitor in the console."
    break
  else
    echo "Job failed, retrying in 10 seconds..."
    sleep 10
  fi
done

# Create PersonalizedProducts table
echo "Creating Bigtable table: PersonalizedProducts"
gcloud bigtable instances tables create PersonalizedProducts \
  --instance=ecommerce-recommendations \
  --column-families=Recommendations

# Load data into PersonalizedProducts via Dataflow
echo "Launching Dataflow job: import-recommendations"

while true; do
  gcloud dataflow jobs run import-recommendations \
    --region=$REGION \
    --project=$PROJECT_ID \
    --gcs-location gs://dataflow-templates-$REGION/latest/GCS_SequenceFile_to_Cloud_Bigtable \
    --staging-location gs://$PROJECT_ID/temp \
    --parameters bigtableProject=$PROJECT_ID,bigtableInstanceId=ecommerce-recommendations,bigtableTableId=PersonalizedProducts,sourcePattern=gs://cloud-training/OCBL377/retail-recommendations-00000-of-00001,mutationThrottleLatencyMs=0

  if [ $? -eq 0 ]; then
    echo "Job import-recommendations submitted successfully."
    break
  else
    echo "Job failed, retrying in 10 seconds..."
    sleep 10
  fi
done

# Add replication: create a second cluster
SECOND_ZONE="${ZONE/a/b}"  # If zone is a, switch to b
echo "Creating replication cluster in zone $SECOND_ZONE"

gcloud bigtable clusters create ecommerce-recommendations-c2 \
  --instance=ecommerce-recommendations \
  --zone=$SECOND_ZONE \
  --autoscaling-min-nodes=1 \
  --autoscaling-max-nodes=5 \
  --autoscaling-cpu-target=60 \
  --storage-type=ssd

# Backup the PersonalizedProducts table
echo "Creating backup: PersonalizedProducts_7"

gcloud beta bigtable backups create PersonalizedProducts_7 \
  --instance=ecommerce-recommendations \
  --cluster=ecommerce-recommendations-c1 \
  --table=PersonalizedProducts \
  --retention-period=7d

# Restore the backup
echo "Restoring backup as table: PersonalizedProducts_7_restored"

gcloud beta bigtable instances tables restore \
  --source=projects/$PROJECT_ID/instances/ecommerce-recommendations/clusters/ecommerce-recommendations-c1/backups/PersonalizedProducts_7 \
  --destination=PersonalizedProducts_7_restored \
  --destination-instance=ecommerce-recommendations \
  --project=$PROJECT_ID \
  --async

# Wait for user confirmation before cleanup
read -p "Do you want to delete the tables and backup to clean up resources? (Y/n): " CONFIRM
if [[ "$CONFIRM" =~ ^[Yy]$ || -z "$CONFIRM" ]]; then
  echo "Deleting Bigtable tables and backup..."

  gcloud bigtable instances tables delete PersonalizedProducts \
    --instance=ecommerce-recommendations --quiet

  gcloud bigtable instances tables delete PersonalizedProducts_7_restored \
    --instance=ecommerce-recommendations --quiet

  gcloud bigtable instances tables delete SessionHistory \
    --instance=ecommerce-recommendations --quiet

  gcloud bigtable backups delete PersonalizedProducts_7 \
    --instance=ecommerce-recommendations \
    --cluster=ecommerce-recommendations-c1 --quiet

  # Optional: delete instance
  # gcloud bigtable instances delete ecommerce-recommendations --quiet

  echo "Cleanup complete."
else
  echo "Skipping cleanup."
fi

echo "All tasks completed."
