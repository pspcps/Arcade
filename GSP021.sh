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

# Step 3: Clone repo and create symlink
echo "📥 Cloning training-data-analyst repo..."
git clone https://github.com/GoogleCloudPlatform/training-data-analyst || echo "ℹ️ Repo already cloned"
ln -s ~/training-data-analyst/courses/ak8s/CloudBridge ~/ak8s 2>/dev/null || echo "ℹ️ Symlink already exists"

cd ~/ak8s/ || exit

# Step 4: Deploy basic NGINX
echo "🚀 Deploying nginx pod..."
kubectl create deployment nginx --image=nginx:1.10.0 || echo "ℹ️ nginx deployment may already exist"

kubectl get pods

echo "🌐 Exposing nginx deployment as LoadBalancer..."
kubectl expose deployment nginx --port 80 --type LoadBalancer || echo "ℹ️ nginx service may already exist"

kubectl get services

# Step 5: Deploy monolith pod
cd ~/ak8s || exit
echo "🚀 Creating monolith pod..."
kubectl create -f pods/monolith.yaml || echo "ℹ️ monolith pod may already exist"
kubectl get pods

# Step 6: Deploy secure-monolith and supporting configs
cd ~/ak8s || exit

echo "🔐 Creating TLS secrets..."
kubectl create secret generic tls-certs --from-file tls/ || echo "ℹ️ Secret may already exist"

echo "⚙️ Creating nginx proxy configmap..."
kubectl create configmap nginx-proxy-conf --from-file nginx/proxy.conf || echo "ℹ️ ConfigMap may already exist"

echo "🔐 Deploying secure-monolith pod..."
kubectl create -f pods/secure-monolith.yaml || echo "ℹ️ secure-monolith may already exist"

echo "🌐 Creating monolith service..."
kubectl create -f services/monolith.yaml || echo "ℹ️ Service may already exist"

echo "🔥 Creating firewall rule for monolith access..."
gcloud compute firewall-rules create allow-monolith-nodeport \
  --allow=tcp:31000 --quiet || echo "ℹ️ Firewall rule may already exist"

# Step 7: Working with labels and endpoints
echo "🔎 Listing monolith pods..."
kubectl get pods -l "app=monolith"

echo "🔎 Listing secure monolith pods..."
kubectl get pods -l "app=monolith,secure=enabled"

echo "🏷️ Labeling secure-monolith pod..."
kubectl label pods secure-monolith 'secure=enabled' --overwrite

echo "🔍 Showing labels on secure-monolith:"
kubectl get pods secure-monolith --show-labels

echo "🔎 Checking service endpoints..."
kubectl describe services monolith | grep Endpoints

# Step 8: Deploy additional services (auth, hello, frontend)
echo "📦 Deploying auth service..."
kubectl create -f deployments/auth.yaml || echo "ℹ️ Auth deployment may already exist"
kubectl create -f services/auth.yaml || echo "ℹ️ Auth service may already exist"

echo "📦 Deploying hello service..."
kubectl create -f deployments/hello.yaml || echo "ℹ️ Hello deployment may already exist"
kubectl create -f services/hello.yaml || echo "ℹ️ Hello service may already exist"

echo "⚙️ Creating frontend configmap..."
kubectl create configmap nginx-frontend-conf --from-file=nginx/frontend.conf || echo "ℹ️ ConfigMap may already exist"

echo "🚀 Deploying frontend..."
kubectl create -f deployments/frontend.yaml || echo "ℹ️ Frontend deployment may already exist"
kubectl create -f services/frontend.yaml || echo "ℹ️ Frontend service may already exist"

echo "🔍 Listing frontend service:"
kubectl get services frontend

echo "✅ Kubernetes setup script completed successfully."
