echo "Initializing Video Queue Monitoring Configuration..."
echo

# User Input Section
echo "-------------------- USER INPUT --------------------"
read -p "Enter custom_metric: " custom_metric
read -p "Enter VALUE: " VALUE
echo

# Authentication Check
echo "-------------------- AUTHENTICATION --------------------"
echo "Checking active GCP account..."
gcloud auth list
echo

# Project Configuration
echo "-------------------- PROJECT SETUP --------------------"
export PROJECT_ID=$(gcloud config get-value project)
export PROJECT_ID=$DEVSHELL_PROJECT_ID
echo "Project ID: $PROJECT_ID"
echo

# Service Enablement
echo "-------------------- SERVICE ENABLEMENT --------------------"
echo "Enabling Monitoring API..."
gcloud services enable monitoring.googleapis.com --project="$DEVSHELL_PROJECT_ID"
echo "Monitoring API enabled successfully!"
echo

# Zone and Region Configuration
echo "-------------------- REGION SETUP --------------------"
ZONE=$(gcloud compute instances list --project="$DEVSHELL_PROJECT_ID" --format="get(zone)" --limit=1)
gcloud config set compute/zone $ZONE
export REGION=${ZONE%-*}
gcloud config set compute/region $REGION
echo "Zone: $ZONE"
echo "Region: $REGION"
echo

# Instance Configuration
echo "-------------------- INSTANCE SETUP --------------------"
echo "Retrieving instance details..."
INSTANCE_ID=$(gcloud compute instances describe video-queue-monitor --project="$DEVSHELL_PROJECT_ID" --zone="$ZONE" --format="get(id)")
echo "Stopping video-queue-monitor instance..."
gcloud compute instances stop video-queue-monitor --project="$DEVSHELL_PROJECT_ID" --zone="$ZONE"
echo "Instance stopped successfully!"
echo

# Startup Script Creation
echo "-------------------- STARTUP SCRIPT --------------------"
echo "Creating startup script..."
cat > startup-script.sh <<EOF_CP
#!/bin/bash

ZONE="$ZONE"
REGION="${ZONE%-*}"
PROJECT_ID="$DEVSHELL_PROJECT_ID"

echo "ZONE: \$ZONE"
echo "REGION: \$REGION"
echo "PROJECT_ID: \$PROJECT_ID"

sudo apt update && sudo apt -y
sudo apt-get install wget -y
sudo apt-get -y install git
sudo chmod 777 /usr/local/
sudo wget https://go.dev/dl/go1.22.8.linux-amd64.tar.gz 
sudo tar -C /usr/local -xzf go1.22.8.linux-amd64.tar.gz
export PATH=\$PATH:/usr/local/go/bin

curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
sudo bash add-google-cloud-ops-agent-repo.sh --also-install
sudo service google-cloud-ops-agent start

mkdir -p /work/go/cache
export GOPATH=/work/go
export GOCACHE=/work/go/cache

cd /work/go
mkdir -p video
gsutil cp gs://spls/gsp338/video_queue/main.go /work/go/video/main.go

go get go.opencensus.io
go get contrib.go.opencensus.io/exporter/stackdriver

# Set project metadata
export MY_PROJECT_ID="$DEVSHELL_PROJECT_ID"
export MY_GCE_INSTANCE_ID="$INSTANCE_ID"
export MY_GCE_INSTANCE_ZONE="$ZONE"

cd /work
go mod init go/video/main
go mod tidy
go run /work/go/video/main.go
EOF_CP

echo "Startup script created successfully!"
echo

# Apply Startup Script and Start Instance
echo "-------------------- INSTANCE DEPLOYMENT --------------------"
echo "Applying startup script and starting instance..."
gcloud compute instances add-metadata video-queue-monitor --project="$DEVSHELL_PROJECT_ID" --zone="$ZONE" --metadata-from-file startup-script=startup-script.sh
gcloud compute instances start video-queue-monitor --project="$DEVSHELL_PROJECT_ID" --zone="$ZONE"
echo "Instance configured and started successfully!"
echo

# Logging Metric Creation
echo "-------------------- LOGGING METRIC --------------------"
echo "Creating logging metric for high resolution videos..."
gcloud logging metrics create $custom_metric \
    --description="Metric for high resolution video uploads" \
    --log-filter='textPayload=("file_format=4K" OR "file_format=8K")'
echo "Logging metric created successfully!"
echo

# Notification Channel Creation
echo "-------------------- NOTIFICATION CHANNEL --------------------"
echo "Creating email notification channel..."
cat > email-channel.json <<EOF_CP
{
  "type": "email",
  "displayName": "MazekroAlerts",
  "description": "Video Queue Monitoring by Mazekro",
  "labels": {
    "email_address": "$USER_EMAIL"
  }
}
EOF_CP

gcloud beta monitoring channels create --channel-content-from-file="email-channel.json"
echo "Notification channel created successfully!"
echo

# Alert Policy Creation
echo "-------------------- ALERT POLICY --------------------"
echo "Creating alert policy..."
channel_info=$(gcloud beta monitoring channels list)
channel_id=$(echo "$channel_info" | grep -oP 'name: \K[^ ]+' | head -n 1)

cat > video-queue-alert.json <<EOF_CP
{
  "displayName": "MazekroVideoAlerts",
  "userLabels": {},
  "conditions": [
    {
      "displayName": "High Resolution Video Upload Rate",
      "conditionThreshold": {
        "filter": "resource.type = \"gce_instance\" AND metric.type = \"logging.googleapis.com/user/$custom_metric\"",
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
        "thresholdValue": $VALUE
      }
    }
  ],
  "alertStrategy": {
    "notificationPrompts": [
      "OPENED"
    ]
  },
  "combiner": "OR",
  "enabled": true,
  "notificationChannels": [
    "$channel_id"
  ],
  "severity": "SEVERITY_UNSPECIFIED"
}
EOF_CP

gcloud alpha monitoring policies create --policy-from-file=video-queue-alert.json
echo "Alert policy created successfully!"
echo
# -------------------- DASHBOARD UPDATE --------------------
echo "Fetching existing Media_Dashboard..."

DASHBOARD_NAME="Media_Dashboard"
DASHBOARD_ID=$(gcloud monitoring dashboards list --format="value(name)" --filter="displayName=$DASHBOARD_NAME")

if [[ -z "$DASHBOARD_ID" ]]; then
  echo "Dashboard '$DASHBOARD_NAME' not found!"
  exit 1
fi

gcloud monitoring dashboards describe "$DASHBOARD_ID" --format=json > media_dashboard.json
echo "Media_Dashboard JSON exported."

echo "Injecting new charts into Media_Dashboard JSON..."

# Define the charts to be added
cat <<EOF > charts.json
[
  {
    "title": "High-Res Video Upload Rate",
    "xyChart": {
      "dataSets": [
        {
          "timeSeriesQuery": {
            "timeSeriesFilter": {
              "filter": "metric.type=\"logging.googleapis.com/user/huge_video_upload_rate\"",
              "aggregation": {
                "alignmentPeriod": "60s",
                "perSeriesAligner": "ALIGN_RATE"
              }
            }
          }
        }
      ],
      "timeshiftDuration": "0s",
      "yAxis": {
        "label": "Upload Rate",
        "scale": "LINEAR"
      }
    }
  },
  {
    "title": "OpenCensus - Video Input Queue Length",
    "xyChart": {
      "dataSets": [
        {
          "timeSeriesQuery": {
            "timeSeriesFilter": {
              "filter": "metric.type=\"custom.googleapis.com/opencensus/my.videoservice.org/measure/input_queue_size\"",
              "aggregation": {
                "alignmentPeriod": "60s",
                "perSeriesAligner": "ALIGN_MEAN"
              }
            }
          }
        }
      ],
      "timeshiftDuration": "0s",
      "yAxis": {
        "label": "Queue Length",
        "scale": "LINEAR"
      }
    }
  }
]
EOF

# Ensure jq is installed
if ! command -v jq &> /dev/null; then
  echo "Installing jq for JSON processing..."
  sudo apt-get update && sudo apt-get install jq -y
fi

# Merge charts into existing dashboard, preserving etag and structure
jq --argjson charts "$(cat charts.json)" '
  .gridLayout.widgets += $charts
' media_dashboard.json > updated_media_dashboard.json

echo "Updating Media_Dashboard with new charts..."
gcloud monitoring dashboards update "$DASHBOARD_ID" --config-from-file=updated_media_dashboard.json
echo "✅ Dashboard updated successfully with new charts!"
