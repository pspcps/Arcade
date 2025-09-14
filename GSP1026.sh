echo "⚡ Initializing GMP Cluster Setup..."
echo

# User Input for Zone
echo "▬▬▬▬▬▬▬▬▬ ZONE CONFIGURATION ▬▬▬▬▬▬▬▬▬"
read -p "Enter the ZONE (e.g., us-central1-a): " ZONE
export ZONE
echo "✅ Zone set to: $ZONE"
echo

# Cluster Creation
echo "▬▬▬▬▬▬▬▬▬ CLUSTER CREATION ▬▬▬▬▬▬▬▬▬"
echo "Creating GMP cluster..."
gcloud beta container clusters create gmp-cluster \
  --num-nodes=1 \
  --zone $ZONE \
  --enable-managed-prometheus
echo "✅ GMP cluster created successfully!"
echo

# Cluster Configuration
echo "▬▬▬▬▬▬▬▬▬ CLUSTER CONFIGURATION ▬▬▬▬▬▬▬▬▬"
echo "Getting cluster credentials..."
gcloud container clusters get-credentials gmp-cluster --zone=$ZONE
echo "✅ Cluster credentials configured!"
echo

# Namespace and Application Setup
echo "▬▬▬▬▬▬▬▬▬ APPLICATION DEPLOYMENT ▬▬▬▬▬▬▬▬▬"
echo "Creating gmp-test namespace..."
kubectl create ns gmp-test
echo "✅ Namespace created!"

echo "Deploying example application..."
kubectl -n gmp-test apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/prometheus-engine/v0.2.3/examples/example-app.yaml
kubectl -n gmp-test apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/prometheus-engine/v0.2.3/examples/pod-monitoring.yaml
echo "✅ Application deployed successfully!"
echo

# Prometheus Setup
echo "▬▬▬▬▬▬▬▬▬ PROMETHEUS CONFIGURATION ▬▬▬▬▬▬▬▬▬"
echo "Setting up Prometheus..."
git clone https://github.com/GoogleCloudPlatform/prometheus && cd prometheus
git checkout v2.28.1-gmp.4
wget https://storage.googleapis.com/kochasoft/gsp1026/prometheus

export PROJECT_ID=$(gcloud config get-value project)
echo "Project ID: $PROJECT_ID"

echo "Starting Prometheus with zone export..."
./prometheus \
  --config.file=documentation/examples/prometheus.yml \
  --export.label.project-id=$PROJECT_ID \
  --export.label.location=$ZONE
echo "✅ Prometheus configured with zone export!"
echo

# Node Exporter Setup
echo "▬▬▬▬▬▬▬▬▬ NODE EXPORTER SETUP ▬▬▬▬▬▬▬▬▬"
echo "Installing node exporter..."
wget https://github.com/prometheus/node_exporter/releases/download/v1.3.1/node_exporter-1.3.1.linux-amd64.tar.gz
tar xvfz node_exporter-1.3.1.linux-amd64.tar.gz
cd node_exporter-1.3.1.linux-amd64

echo "Creating node exporter config..."
cat > config.yaml <<EOF_END
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: node
    static_configs:
      - targets: ['localhost:9100']
EOF_END

echo "Uploading config to Cloud Storage..."
export PROJECT=$(gcloud config get-value project)
gsutil mb -p $PROJECT gs://$PROJECT
gsutil cp config.yaml gs://$PROJECT
gsutil -m acl set -R -a public-read gs://$PROJECT
echo "✅ Node exporter setup complete!"
echo
