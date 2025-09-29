echo "🚀 Starting Execution"

echo
echo -n "Enter Repository Name: "
read REPO
echo -n "Enter Docker Image: "
read DCKR_IMG
echo -n "Enter Tag Name: "
read TAG

export REPO="$REPO"
export DCKR_IMG="$DCKR_IMG"
export TAG="$TAG"

# Step 1: Fetching region and zone details...
echo "🌍 Fetching region and zone details..."

export ZONE=$(gcloud compute project-info describe \
  --format="value(commonInstanceMetadata.items[google-compute-default-zone])")

export REGION=$(gcloud compute project-info describe \
  --format="value(commonInstanceMetadata.items[google-compute-default-region])")

# Step 2: Sourcing setup script...
echo "📦 Sourcing setup script..."
# source <(gsutil cat gs://cloud-training/gsp318/marking/setup_marking_v2.sh)
source <(gsutil cat gs://spls/gsp318/script.sh)

# Step 3: Downloading and extracting application...
echo "📥 Downloading and extracting application..."
for i in {1..3}; do
  gsutil cp gs://spls/gsp318/valkyrie-app.tgz . && break || sleep 5
done
tar -xzf valkyrie-app.tgz 2>/dev/null || echo "✅ Already extracted"
cd valkyrie-app 2>/dev/null || cd valkyrie-app

# Step 4: Creating Dockerfile...
echo "📝 Creating Dockerfile..."
cat > Dockerfile <<EOF
FROM golang:1.10
WORKDIR /go/src/app
COPY source .
RUN go install -v
ENTRYPOINT ["app","-single=true","-port=8080"]
EOF

# Step 5: Building Docker image...
echo "🔧 Building Docker image..."
for i in {1..3}; do
  docker build -t $DCKR_IMG:$TAG . && break || sleep 5
done

# Step 6: Executing Step 1 script...
echo "▶️ Executing Step 1 script..."
cd ..
./step1_v2.sh || echo "⚠️ Step1 script failed or already done"

# Step 7: Running Docker container...
echo "🐳 Running Docker container..."
cd valkyrie-app
docker run -d -p 8080:8080 $DCKR_IMG:$TAG || echo "⚠️ Container may already be running"

# Step 8: Executing Step 2 script...
echo "▶️ Executing Step 2 script..."
cd ..
./step2_v2.sh || echo "⚠️ Step2 script failed or already done"

cd valkyrie-app

# Step 9: Creating Artifact Repository...
echo "🏗️ Creating Artifact Repository..."
gcloud artifacts repositories create $REPO \
  --repository-format=docker \
  --location=$REGION \
  --description="awesome lab" \
  --async || echo "ℹ️ Repo $REPO may already exist, continuing..."

# Step 10: Configuring Docker authentication...
echo "🔐 Configuring Docker authentication..."
for i in {1..3}; do
  gcloud auth configure-docker $REGION-docker.pkg.dev --quiet && break || sleep 5
done

sleep 30

# Step 11: Tagging and pushing Docker image...
echo "📤 Tagging and pushing Docker image..."

Image_ID=$(docker images --format='{{.ID}}' | head -n 1)

docker tag $Image_ID $REGION-docker.pkg.dev/$DEVSHELL_PROJECT_ID/$REPO/$DCKR_IMG:$TAG || echo "⚠️ Tagging failed"
for i in {1..3}; do
  docker push $REGION-docker.pkg.dev/$DEVSHELL_PROJECT_ID/$REPO/$DCKR_IMG:$TAG && break || sleep 5
done

# Step 12: Updating Kubernetes deployment...
echo "♻️ Updating Kubernetes deployment..."
sed -i s#IMAGE_HERE#$REGION-docker.pkg.dev/$DEVSHELL_PROJECT_ID/$REPO/$DCKR_IMG:$TAG#g k8s/deployment.yaml

# Step 13: Configuring Kubernetes cluster...
echo "🔧 Configuring Kubernetes cluster..."
for i in {1..3}; do
  gcloud container clusters get-credentials valkyrie-dev --zone $ZONE && break || sleep 5
done

# Step 14: Deploying application to Kubernetes...
echo "🚢 Deploying application to Kubernetes..."

kubectl apply -f k8s/deployment.yaml || echo "⚠️ Deployment may already exist"
kubectl apply -f k8s/service.yaml || echo "⚠️ Service may already exist"

echo "✅ Script execution completed (with resilience)"
