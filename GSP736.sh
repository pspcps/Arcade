
echo "⚡ Initializing Microservices Monitoring Setup..."
echo

# User Input for Zone
echo "▬▬▬▬▬▬▬▬▬ ZONE CONFIGURATION ▬▬▬▬▬▬▬▬▬"
read -p "Enter the ZONE (e.g., us-central1-a): " ZONE
export ZONE
echo "✅ Zone set to: $ZONE"
echo

# Environment Setup
echo "▬▬▬▬▬▬▬▬▬ ENVIRONMENT CONFIGURATION ▬▬▬▬▬▬▬▬▬"
echo "Setting compute zone to $ZONE"
gcloud config set compute/zone $ZONE

export PROJECT_ID=$(gcloud info --format='value(config.project)')
echo "Project ID: $PROJECT_ID"
echo

# Cluster Configuration
echo "▬▬▬▬▬▬▬▬▬ CLUSTER CONFIGURATION ▬▬▬▬▬▬▬▬▬"
echo "Getting cluster credentials..."
gcloud container clusters get-credentials central --zone $ZONE
echo "✅ Cluster credentials configured!"
echo

# Microservices Deployment
echo "▬▬▬▬▬▬▬▬▬ MICROSERVICES DEPLOYMENT ▬▬▬▬▬▬▬▬▬"
echo "Cloning microservices demo repository..."
git clone https://github.com/xiangshen-dk/microservices-demo.git
cd microservices-demo

echo "Deploying microservices..."
kubectl apply -f release/kubernetes-manifests.yaml
echo "✅ Microservices deployed successfully!"
echo "Waiting 30 seconds for services to initialize..."
sleep 30
echo

# Monitoring Setup
echo "▬▬▬▬▬▬▬▬▬ MONITORING CONFIGURATION ▬▬▬▬▬▬▬▬▬"
echo "Creating Error Rate SLI metric..."
gcloud logging metrics create Error_Rate_SLI \
  --description="Error rate for recommendationservice" \
  --log-filter="resource.type=\"k8s_container\" severity=ERROR labels.\"k8s-pod/app\": \"recommendationservice\""
echo "✅ Error Rate SLI metric created!"
echo "Waiting 30 seconds for metric to propagate..."
sleep 30
echo

# Alert Policy Creation
echo "▬▬▬▬▬▬▬▬▬ ALERT POLICY SETUP ▬▬▬▬▬▬▬▬▬"
echo "Creating alert policy configuration..."
cat > awesome.json <<EOF_END
{
  "displayName": "Error Rate SLI",
  "userLabels": {},
  "conditions": [
    {
      "displayName": "Kubernetes Container - logging/user/Error_Rate_SLI",
      "conditionThreshold": {
        "filter": "resource.type = \"k8s_container\" AND metric.type = \"logging.googleapis.com/user/Error_Rate_SLI\"",
        "aggregations": [
          {
            "alignmentPeriod": "300s",
            "crossSeriesReducer": "REDUCE_NONE",
            "perSeriesAligner": "ALIGN_RATE"
          }
        ],
        "comparison": "COMPARISON_GT",
        "duration": "0s",
        "trigger": {
          "count": 1
        },
        "thresholdValue": 0.5
      }
    }
  ],
  "alertStrategy": {
    "autoClose": "604800s"
  },
  "combiner": "OR",
  "enabled": true,
  "notificationChannels": [],
  "severity": "SEVERITY_UNSPECIFIED"
}
EOF_END

echo "Creating monitoring policy..."
gcloud alpha monitoring policies create --policy-from-file="awesome.json"
echo "✅ Alert policy created successfully!"
echo
