#!/bin/bash

# Ask for cluster name
read -p "Enter the CLUSTER_NAME: " CLUSTER_NAME

# Fetch environment variables
ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
REGION=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-region])")
PROJECT_ID=$(gcloud config get-value project)
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")

echo "Using Project: $PROJECT_ID"
echo "Using Region:  $REGION"
echo "Using Zone:    $ZONE"
echo

# IAM Role Binding
echo "Assigning IAM permissions..."
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$PROJECT_NUMBER-compute@developer.gserviceaccount.com" \
  --role="roles/storage.admin"

# Function to deploy cluster
deploy_cluster() {
  gcloud dataproc clusters create "$CLUSTER_NAME" \
    --region "$REGION" \
    --zone "$ZONE" \
    --master-machine-type n1-standard-2 \
    --worker-machine-type n1-standard-2 \
    --num-workers 2 \
    --worker-boot-disk-size 100 \
    --worker-boot-disk-type pd-standard \
    --no-address
}

# Retry logic for cluster creation
attempt=1
max_attempts=3
success=false

while [ "$attempt" -le "$max_attempts" ]; do
  echo "Creating Dataproc cluster (Attempt $attempt)..."
  deploy_cluster
  if [ $? -eq 0 ]; then
    echo "Cluster created successfully."
    success=true
    break
  else
    echo "Cluster creation failed."
    if gcloud dataproc clusters describe "$CLUSTER_NAME" --region "$REGION" >/dev/null 2>&1; then
      echo "Cluster already exists. Deleting existing cluster..."
      gcloud dataproc clusters delete "$CLUSTER_NAME" --region "$REGION" --quiet
    fi
    attempt=$((attempt + 1))
    if [ "$attempt" -le "$max_attempts" ]; then
      echo "Retrying in 10 seconds..."
      sleep 10
    fi
  fi
done

if [ "$success" = false ]; then
  echo "Failed to create Dataproc cluster after $max_attempts attempts. Exiting."
  exit 1
fi

# Submit Spark job
echo
echo "Submitting SparkPi job..."
gcloud dataproc jobs submit spark \
  --project "$PROJECT_ID" \
  --region "$REGION" \
  --cluster "$CLUSTER_NAME" \
  --class org.apache.spark.examples.SparkPi \
  --jars file:///usr/lib/spark/examples/jars/spark-examples.jar \
  -- 1000

# Completion info
echo
echo "Cluster: $CLUSTER_NAME"
echo "Dataproc Job submitted."
echo "View jobs: https://console.cloud.google.com/dataproc/jobs?project=${PROJECT_ID}"
echo "Manage cluster: https://console.cloud.google.com/dataproc/clusters?project=${PROJECT_ID}"
