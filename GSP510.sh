
echo
echo "⚡ Initializing GKE Cluster Setup..."
echo

# User Input Section
echo "▬▬▬▬▬▬▬▬▬ CONFIGURATION PARAMETERS ▬▬▬▬▬▬▬▬▬"
read -p "Enter CLUSTER_NAME (e.g., monitoring-cluster): " CLUSTER_NAME
read -p "Enter ZONE (e.g., us-central1-a): " ZONE
read -p "Enter NAMESPACE (e.g., gmp-test): " NAMESPACE
read -p "Enter INTERVAL for monitoring (e.g., 30s): " INTERVAL
read -p "Enter REPO_NAME (e.g., hello-repo): " REPO_NAME
read -p "Enter SERVICE_NAME (e.g., hello-service): " SERVICE_NAME

# Export all variables
export CLUSTER_NAME ZONE NAMESPACE REPO_NAME INTERVAL SERVICE_NAME
export REGION="${ZONE%-*}"
export PROJECT_ID=$(gcloud config get-value project)

echo
echo "Configuration Summary:"
echo "Cluster Name: $CLUSTER_NAME"
echo "Zone: $ZONE"
echo "Region: $REGION"
echo "Namespace: $NAMESPACE"
echo "Repository: $REPO_NAME"
echo "Monitoring Interval: $INTERVAL"
echo "Service Name: $SERVICE_NAME"
echo

# Cluster Creation
echo "▬▬▬▬▬▬▬▬▬ CLUSTER CREATION ▬▬▬▬▬▬▬▬▬"
echo "Setting compute zone..."
gcloud config set compute/zone $ZONE

echo "Creating GKE cluster with autoscaling..."
gcloud container clusters create $CLUSTER_NAME \
  --release-channel regular \
  --cluster-version latest \
  --num-nodes 3 \
  --min-nodes 2 \
  --max-nodes 6 \
  --enable-autoscaling \
  --no-enable-ip-alias

echo "Enabling Managed Prometheus..."
gcloud container clusters update $CLUSTER_NAME \
  --enable-managed-prometheus \
  --zone $ZONE
echo "✅ Cluster created and configured successfully!"
echo

# Namespace Setup
echo "▬▬▬▬▬▬▬▬▬ NAMESPACE SETUP ▬▬▬▬▬▬▬▬▬"
echo "Creating namespace..."
kubectl create ns $NAMESPACE
echo "✅ Namespace $NAMESPACE created!"
echo

# Prometheus Application Deployment
echo "▬▬▬▬▬▬▬▬▬ PROMETHEUS SETUP ▬▬▬▬▬▬▬▬▬"
echo "Deploying Prometheus test application..."
cat > prometheus-app.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus-test
  labels:
    app: prometheus-test
spec:
  selector:
    matchLabels:
      app: prometheus-test
  replicas: 3
  template:
    metadata:
      labels:
        app: prometheus-test
    spec:
      nodeSelector:
        kubernetes.io/os: linux
        kubernetes.io/arch: amd64
      containers:
      - image: nilebox/prometheus-example-app:latest
        name: prometheus-test
        ports:
        - name: metrics
          containerPort: 1234
        command:
        - "/main"
        - "--process-metrics"
        - "--go-metrics"
EOF

kubectl -n $NAMESPACE apply -f prometheus-app.yaml
echo "✅ Prometheus test application deployed!"

echo "Configuring Pod Monitoring..."
cat > pod-monitoring.yaml <<EOF
apiVersion: monitoring.googleapis.com/v1alpha1
kind: PodMonitoring
metadata:
  name: prometheus-test
  labels:
    app.kubernetes.io/name: prometheus-test
spec:
  selector:
    matchLabels:
      app: prometheus-test
  endpoints:
  - port: metrics
    interval: $INTERVAL
EOF

kubectl -n $NAMESPACE apply -f pod-monitoring.yaml
echo "✅ Pod monitoring configured with ${INTERVAL} interval!"
echo

# Hello Application Deployment
echo "▬▬▬▬▬▬▬▬▬ HELLO APPLICATION DEPLOYMENT ▬▬▬▬▬▬▬▬▬"
echo "Setting up hello application..."
gsutil cp -r gs://spls/gsp510/hello-app/ .
cd ~/hello-app

echo "Deploying initial version..."
kubectl -n $NAMESPACE apply -f manifests/helloweb-deployment.yaml
echo "✅ Initial deployment complete!"

echo "Updating deployment configuration..."
cat > manifests/helloweb-deployment.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: helloweb
  labels:
    app: hello
spec:
  selector:
    matchLabels:
      app: hello
      tier: web
  template:
    metadata:
      labels:
        app: hello
        tier: web
    spec:
      containers:
      - name: hello-app
        image: us-docker.pkg.dev/google-samples/containers/gke/hello-app:1.0
        ports:
        - containerPort: 8080
        resources:
          requests:
            cpu: 200m
EOF

kubectl delete deployments helloweb -n $NAMESPACE
kubectl -n $NAMESPACE apply -f manifests/helloweb-deployment.yaml
echo "✅ Deployment updated!"
echo

# Application Update
echo "▬▬▬▬▬▬▬▬▬ APPLICATION UPDATE ▬▬▬▬▬▬▬▬▬"
echo "Building and pushing new version..."
cat > main.go <<EOF
package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
)

func main() {
	// register hello function to handle all requests
	mux := http.NewServeMux()
	mux.HandleFunc("/", hello)

	// use PORT environment variable, or default to 8080
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	// start the web server on port and accept requests
	log.Printf("Server listening on port %s", port)
	log.Fatal(http.ListenAndServe(":"+port, mux))
}

// hello responds to the request with a plain-text "Hello, world" message.
func hello(w http.ResponseWriter, r *http.Request) {
	log.Printf("Serving request: %s", r.URL.Path)
	host, _ := os.Hostname()
	fmt.Fprintf(w, "Hello, world!\n")
	fmt.Fprintf(w, "Version: 2.0.0\n")
	fmt.Fprintf(w, "Hostname: %s\n", host)
}
EOF

gcloud auth configure-docker $REGION-docker.pkg.dev --quiet
docker build -t $REGION-docker.pkg.dev/$PROJECT_ID/$REPO_NAME/hello-app:v2 .
docker push $REGION-docker.pkg.dev/$PROJECT_ID/$REPO_NAME/hello-app:v2

echo "Updating deployment with new image..."
kubectl set image deployment/helloweb -n $NAMESPACE hello-app=$REGION-docker.pkg.dev/$PROJECT_ID/$REPO_NAME/hello-app:v2

echo "Exposing service..."
kubectl expose deployment helloweb -n $NAMESPACE --name=$SERVICE_NAME --type=LoadBalancer --port 8080 --target-port 8080
echo "✅ Application updated and service exposed!"
echo

# Monitoring Configuration
echo "▬▬▬▬▬▬▬▬▬ MONITORING CONFIGURATION ▬▬▬▬▬▬▬▬▬"
echo "Creating logging metric..."
gcloud logging metrics create pod-image-errors \
  --description="Pod image errors monitoring" \
  --log-filter="resource.type=\"k8s_pod\" severity=WARNING"

echo "Creating alert policy..."
cat > awesome.json <<EOF_END
{
  "displayName": "Pod Error Alert",
  "userLabels": {},
  "conditions": [
    {
      "displayName": "Kubernetes Pod - logging/user/pod-image-errors",
      "conditionThreshold": {
        "filter": "resource.type = \"k8s_pod\" AND metric.type = \"logging.googleapis.com/user/pod-image-errors\"",
        "aggregations": [
          {
            "alignmentPeriod": "600s",
            "crossSeriesReducer": "REDUCE_SUM",
            "perSeriesAligner": "ALIGN_COUNT"
          }
        ],
        "comparison": "COMPARISON_GT",
        "duration": "0s",
        "trigger": {
          "count": 1
        },
        "thresholdValue": 0
      }
    }
  ],
  "alertStrategy": {
    "autoClose": "604800s"
  },
  "combiner": "OR",
  "enabled": true,
  "notificationChannels": []
}
EOF_END

gcloud alpha monitoring policies create --policy-from-file="awesome.json"
echo "✅ Monitoring and alerting configured!"
echo

# Completion Message

echo "LAB COMPLETE!            "