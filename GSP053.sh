#!/bin/bash

set -e

echo "🔐 Checking if you're authenticated with gcloud..."
gcloud auth list >/dev/null 2>&1 || {
    echo "❌ You are not authenticated. Please run 'gcloud auth login' first."
    exit 1
}

echo "📛 Getting current GCP Project ID..."
export PROJECT_ID=$(gcloud config get-value project)
if [[ -z "$PROJECT_ID" ]]; then
    echo "❌ Project ID is not set. Please run 'gcloud config set project PROJECT_ID' first."
    exit 1
fi

echo "📍 Getting default zone and region..."
export ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-region])")

if [[ -z "$ZONE" || -z "$REGION" ]]; then
    echo "❌ Default zone or region not found. Please set them using the GCP Console or CLI."
    exit 1
fi

echo "🧭 Setting compute zone and region in gcloud config..."
gcloud config set compute/zone "$ZONE"
gcloud config set compute/region "$REGION"

echo "🔽 Downloading sample code..."
gcloud storage cp -r gs://spls/gsp053/kubernetes .
cd kubernetes

echo "☁️ Creating Kubernetes cluster in zone $ZONE..."
if gcloud container clusters describe bootcamp --zone "$ZONE" >/dev/null 2>&1; then
    echo "ℹ️ Cluster 'bootcamp' already exists. Skipping creation."
else
    gcloud container clusters create bootcamp \
      --zone "$ZONE" \
      --machine-type e2-small \
      --num-nodes 3 \
      --scopes "https://www.googleapis.com/auth/projecthosting,storage-rw"
fi

echo "⏳ Waiting for cluster to be ready..."
sleep 30

echo "📦 Creating deployment (fortune-app-blue)..."
kubectl create -f deployments/fortune-app-blue.yaml

echo "🔍 Verifying deployment and pods..."
kubectl get deployments
kubectl get replicasets
kubectl get pods

echo "🌐 Creating service..."
kubectl create -f services/fortune-app.yaml

echo "⏳ Waiting for External IP..."
for i in {1..30}; do
    EXTERNAL_IP=$(kubectl get svc fortune-app -o=jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    if [[ -n "$EXTERNAL_IP" ]]; then
        echo "✔️ External IP acquired: $EXTERNAL_IP"
        break
    fi
    echo "⏳ Still waiting for External IP... ($i)"
    sleep 5
done

if [[ -z "$EXTERNAL_IP" ]]; then
    echo "❌ External IP was not assigned within timeout. Exiting."
    exit 1
fi

# Wait for service to respond
echo "🔍 Verifying service availability..."
for i in {1..10}; do
    if curl -s "http://$EXTERNAL_IP/version"; then
        break
    fi
    echo "⏳ Waiting for service to become available... ($i)"
    sleep 5
done

echo "🔁 Scaling deployment to 5 replicas..."
kubectl scale deployment fortune-app-blue --replicas=5
sleep 10
kubectl get pods | grep fortune-app-blue | wc -l

echo "🔁 Scaling back to 3 replicas..."
kubectl scale deployment fortune-app-blue --replicas=3
sleep 10
kubectl get pods | grep fortune-app-blue | wc -l

echo "🔄 Performing rolling update to version 2.0.0..."
kubectl set image deployment/fortune-app-blue fortune-app=us-central1-docker.pkg.dev/qwiklabs-resources/spl-lab-apps/fortune-service:2.0.0
kubectl rollout status deployment/fortune-app-blue

echo "🧪 Verifying version after rolling update..."
curl http://$EXTERNAL_IP/version || echo "⚠️ curl failed (service may not be ready yet)"

echo "↩️ Rolling back to version 1.0.0..."
kubectl rollout undo deployment/fortune-app-blue
kubectl rollout status deployment/fortune-app-blue
curl http://$EXTERNAL_IP/version || echo "⚠️ curl failed (service may not be ready yet)"

echo "🐦 Creating canary deployment..."
kubectl create -f deployments/fortune-app-canary.yaml
kubectl get deployments

echo "📈 Verifying canary traffic distribution..."
for i in {1..10}; do
    curl -s http://$EXTERNAL_IP/version || echo "❌ request failed"
done

# 🚦 Ask for confirmation before proceeding
read -p "✅ Please check progress. Proceed to Blue-Green deployment? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "🛑 Stopping script as per user request."
    exit 0
fi

echo "💙 Creating green deployment..."
kubectl apply -f services/fortune-app-blue-service.yaml
kubectl create -f deployments/fortune-app-green.yaml

echo "✅ Verifying blue version (1.0.0)..."
curl http://$EXTERNAL_IP/version || echo "⚠️ curl failed"

echo "💚 Switching to green version (2.0.0)..."
kubectl apply -f services/fortune-app-green-service.yaml
sleep 10
curl http://$EXTERNAL_IP/version || echo "⚠️ curl failed"

echo "🔙 Rolling back to blue version (1.0.0)..."
kubectl apply -f services/fortune-app-blue-service.yaml
sleep 10
curl http://$EXTERNAL_IP/version || echo "⚠️ curl failed"

echo "🎉 All tasks completed successfully!"
