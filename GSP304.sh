#!/bin/bash


# Prompt user for zone input
echo "Step 1: Set the zone for your GKE cluster"
echo "Please enter your preferred zone (e.g., us-central1-a):"
read -p "Zone: " ZONE


export ZONE
REGION="${ZONE%-*}"
export REGION

echo
echo "✅ Using Zone: $ZONE"
echo "✅ Derived Region: $REGION"
echo

# Start execution
echo "${BG_MAGENTA}Starting Execution"
echo

# Create GKE cluster
echo "Creating GKE cluster 'echo-cluster' in zone $ZONE..."
gcloud beta container --project "$DEVSHELL_PROJECT_ID" clusters create "echo-cluster" \
--zone "$ZONE" \
--no-enable-basic-auth \
--cluster-version "latest" \
--release-channel "regular" \
--machine-type "e2-standard-2" \
--image-type "COS_CONTAINERD" \
--disk-type "pd-balanced" \
--disk-size "100" \
--metadata disable-legacy-endpoints=true \
--scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" \
--num-nodes "3" \
--logging=SYSTEM,WORKLOAD \
--monitoring=SYSTEM \
--enable-ip-alias \
--network "projects/$DEVSHELL_PROJECT_ID/global/networks/default" \
--subnetwork "projects/$DEVSHELL_PROJECT_ID/regions/$REGION/subnetworks/default" \
--no-enable-intra-node-visibility \
--default-max-pods-per-node "110" \
--security-posture=standard \
--workload-vulnerability-scanning=disabled \
--no-enable-master-authorized-networks \
--addons HorizontalPodAutoscaling,HttpLoadBalancing,GcePersistentDiskCsiDriver \
--enable-autoupgrade \
--enable-autorepair \
--max-surge-upgrade 1 \
--max-unavailable-upgrade 0 \
--enable-managed-prometheus \
--enable-shielded-nodes \
--node-locations "$ZONE"

echo
echo "✅ GKE cluster created successfully"
echo

# Get project ID
export PROJECT_ID=$(gcloud info --format='value(config.project)')
echo "Using Project ID: $PROJECT_ID"

# Download and extract application files
echo
echo "Downloading application files..."
gsutil cp gs://${PROJECT_ID}/echo-web.tar.gz .
tar -xvzf echo-web.tar.gz

# Build and push Docker image
echo
echo "Building and pushing Docker image..."
cd echo-web
docker build -t echo-app:v1 .
docker tag echo-app:v1 gcr.io/${PROJECT_ID}/echo-app:v1
docker push gcr.io/${PROJECT_ID}/echo-app:v1

# Deploy to GKE
echo
echo "Deploying application to GKE cluster..."
gcloud container clusters get-credentials echo-cluster --zone=$ZONE
kubectl create deployment echo-app --image=gcr.io/${PROJECT_ID}/echo-app:v1

# Expose the deployment
echo
echo "Creating service for the deployment..."
kubectl expose deployment echo-app --name echo-web \
   --type LoadBalancer --port 80 --target-port 8000

# Get service details
echo
echo "Getting service details..."
kubectl get service echo-web

# Completion message

echo "Completing The Lab !!!"
