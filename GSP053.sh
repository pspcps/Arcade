#!/bin/bash

set -euo pipefail

### Utility functions
function safe_kubectl_create() {
    local file=$1
    if kubectl apply -f "$file"; then
        echo "✅ Applied $file"
    else
        echo "⚠️ Warning: Failed to apply $file"
    fi
}

function wait_for_external_ip() {
    local svc_name=$1
    local retries=30

    echo "⏳ Waiting for External IP for service '$svc_name'..."
    for ((i=1; i<=retries; i++)); do
        EXTERNAL_IP=$(kubectl get svc $svc_name -o=jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
        if [[ -n "$EXTERNAL_IP" ]]; then
            echo "🌐 External IP acquired: $EXTERNAL_IP"
            return 0
        fi
        echo "🔄 [$i/$retries] Waiting for external IP..."
        sleep 5
    done

    echo "❌ Timed out waiting for External IP."
    return 1
}

function wait_for_service_ready() {
    local url=$1
    local retries=20

    echo "⏳ Waiting for service to respond at $url..."
    for ((i=1; i<=retries; i++)); do
        if curl -s --max-time 5 "$url" > /dev/null; then
            echo "✅ Service is responding."
            return 0
        fi
        echo "🔁 [$i/$retries] Retrying..."
        sleep 5
    done

    echo "❌ Service did not become ready in time."
    return 1
}

### Authentication & Environment Setup
echo "🔐 Checking gcloud authentication..."
if ! gcloud auth list | grep -q ACTIVE; then
    echo "❌ Please run 'gcloud auth login' to authenticate."
    exit 1
fi

echo "📛 Getting current GCP Project ID..."
PROJECT_ID=$(gcloud config get-value project)
if [[ -z "$PROJECT_ID" ]]; then
    echo "❌ Project ID not set. Use 'gcloud config set project PROJECT_ID'"
    exit 1
fi

echo "📍 Getting default zone and region..."
ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
REGION=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-region])")

if [[ -z "$ZONE" || -z "$REGION" ]]; then
    echo "❌ Zone or region not set. Please configure in GCP."
    exit 1
fi

echo "🧭 Setting gcloud compute zone and region..."
gcloud config set compute/zone "$ZONE"
gcloud config set compute/region "$REGION"

### Download Lab Code
echo "📥 Downloading sample Kubernetes code..."
gcloud storage cp -r gs://spls/gsp053/kubernetes .
cd kubernetes

### Cluster Creation
echo "☁️ Creating Kubernetes cluster (if not exists)..."
if gcloud container clusters describe bootcamp --zone "$ZONE" >/dev/null 2>&1; then
    echo "✅ Cluster 'bootcamp' already exists. Skipping creation."
else
    gcloud container clusters create bootcamp \
        --zone "$ZONE" \
        --machine-type e2-small \
        --num-nodes 3 \
        --scopes "https://www.googleapis.com/auth/projecthosting,storage-rw"
fi

### Initial Setup
echo "📦 Creating deployment: fortune-app-blue..."
kubectl apply -f deployments/fortune-app-blue.yaml || echo "⚠️ Deployment may already exist."

echo "🌐 Creating service..."
kubectl apply -f services/fortune-app.yaml || echo "⚠️ Service may already exist."

wait_for_external_ip "fortune-app"
EXTERNAL_IP=$(kubectl get svc fortune-app -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')
SERVICE_URL="http://$EXTERNAL_IP/version"

wait_for_service_ready "$SERVICE_URL"
curl -s "$SERVICE_URL"

### Scaling
echo "🔁 Scaling deployment to 5 replicas..."
kubectl scale deployment fortune-app-blue --replicas=5
sleep 10

echo "🔁 Scaling back to 3 replicas..."
kubectl scale deployment fortune-app-blue --replicas=3
sleep 10

### Rolling Update
echo "🔄 Performing rolling update to v2.0.0..."
kubectl set image deployment/fortune-app-blue \
    fortune-app=us-central1-docker.pkg.dev/qwiklabs-resources/spl-lab-apps/fortune-service:2.0.0
kubectl rollout status deployment/fortune-app-blue

wait_for_service_ready "$SERVICE_URL"
curl -s "$SERVICE_URL"

echo "↩️ Rolling back to v1.0.0..."
kubectl rollout undo deployment/fortune-app-blue
kubectl rollout status deployment/fortune-app-blue
curl -s "$SERVICE_URL"

### Canary Deployment
echo "🐦 Creating canary deployment..."
kubectl apply -f deployments/fortune-app-canary.yaml

echo "📈 Checking canary traffic distribution:"
for i in {1..10}; do
    curl -s "$SERVICE_URL"
    echo
done

### Confirmation Before Blue-Green
read -p "✅ Ready to continue to Blue-Green deployment? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "🛑 Exiting as per user request."
    exit 0
fi

### Blue-Green Deployment
echo "💙 Applying blue service..."
kubectl apply -f services/fortune-app-blue-service.yaml

echo "💚 Deploying green version..."
kubectl apply -f deployments/fortune-app-green.yaml

echo "✅ Verifying current version (should be 1.0.0):"
curl -s "$SERVICE_URL"

echo "🔁 Switching service to green version..."
kubectl apply -f services/fortune-app-green-service.yaml
sleep 10
curl -s "$SERVICE_URL"

echo "🔙 Rolling back to blue version..."
kubectl apply -f services/fortune-app-blue-service.yaml
sleep 10
curl -s "$SERVICE_URL"

echo "🎉 All tasks completed successfully!"
