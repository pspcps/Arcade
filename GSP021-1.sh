#!/bin/bash

echo "🚀 Starting Kubernetes Setup Script"

# Step 1: Get Zone, Region, and Project ID
echo "🌍 Fetching GCP configuration..."
ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
REGION=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-region])")
PROJECT_ID=$(gcloud config get-value project)

echo "🔧 Setting compute zone to: $ZONE"
gcloud config set compute/zone "$ZONE" --quiet

# Step 2: Create GKE Cluster
echo "☸️ Creating GKE cluster: io..."
for i in {1..3}; do
    gcloud container clusters create io --quiet && break || {
        echo "⚠️ Failed to create cluster. Retrying in 5s..."
        sleep 5
    }
done


gcloud storage cp -r gs://spls/gsp021/* .

cd orchestrate-with-kubernetes/kubernetes

# Step 4: Deploy basic NGINX
echo "🚀 Deploying nginx pod..."

kubectl create deployment nginx --image=nginx:1.27.0 || echo "ℹ️ nginx deployment may already exist"


echo "🌐 Exposing nginx deployment as LoadBalancer..."
kubectl expose deployment nginx --port 80 --type LoadBalancer || echo "ℹ️ nginx service may already exist"


cd ~/orchestrate-with-kubernetes/kubernetes


# Step 5: Deploy monolith pod

echo "🚀 Creating fortune-app pod..."

kubectl create -f pods/fortune-app.yaml || echo "ℹ️ fortune-app pod may already exist"


sleep 30

# kubectl port-forward fortune-app 10080:8080  || echo "ℹ️ fortune-app  port-forward  failed"



cd ~/orchestrate-with-kubernetes/kubernetes

kubectl create secret generic tls-certs --from-file tls/  
kubectl create configmap nginx-proxy-conf --from-file nginx/proxy.conf  
sleep 10
kubectl create -f pods/secure-fortune.yaml
sleep 10
kubectl create -f services/fortune-app.yaml

sleep 20

gcloud compute firewall-rules create allow-fortune-nodeport --allow tcp:31000


sleep 30

kubectl label pods secure-fortune 'secure=enabled'


sleep 30
kubectl create -f deployments/auth.yaml

kubectl create -f services/auth.yaml
kubectl create -f deployments/fortune-service.yaml
kubectl create -f services/fortune-service.yaml
kubectl create configmap nginx-frontend-conf --from-file=nginx/frontend.conf  
kubectl create -f deployments/frontend.yaml  
kubectl create -f services/frontend.yaml


