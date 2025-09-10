

gcloud auth list

export ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-region])")

gcloud config set compute/zone "$ZONE"
gcloud config set compute/region "$REGION"

export PROJECT_ID=$(gcloud info --format='value(config.project)')

gcloud container clusters create gmp-cluster --num-nodes=1 --zone $ZONE

gcloud logging metrics create stopped-vm --log-filter='resource.type="gce_instance" protoPayload.methodName="v1.compute.instances.stop"' --description="Metric for stopped VMs"


cat > cp-channel.json <<EOF_CP
{
  "type": "pubsub",
  "displayName": "mazekro",
  "description": "subscribe to mazekro",
  "labels": {
    "topic": "projects/$DEVSHELL_PROJECT_ID/topics/notificationTopic"
  }
}
EOF_CP


gcloud beta monitoring channels create --channel-content-from-file=cp-channel.json


email_channel=$(gcloud beta monitoring channels list)
channel_id=$(echo "$email_channel" | grep -oP 'name: \K[^ ]+' | head -n 1)


cat > stopped-vm-cp-policy.json <<EOF_CP
{
  "displayName": "stopped vm",
  "documentation": {
    "content": "Documentation content for the stopped vm alert policy",
    "mime_type": "text/markdown"
  },
  "userLabels": {},
  "conditions": [
    {
      "displayName": "Log match condition",
      "conditionMatchedLog": {
        "filter": "resource.type=\"gce_instance\" protoPayload.methodName=\"v1.compute.instances.stop\""
      }
    }
  ],
  "alertStrategy": {
    "notificationRateLimit": {
      "period": "300s"
    },
    "autoClose": "3600s"
  },
  "combiner": "OR",
  "enabled": true,
  "notificationChannels": [
    "$channel_id"
  ]
}

EOF_CP


gcloud alpha monitoring policies create --policy-from-file=stopped-vm-cp-policy.json

gcloud artifacts repositories create docker-repo --repository-format=docker \
    --location="$REGION" --description="Docker repository" \
    --project="$PROJECT_ID"

 wget https://storage.googleapis.com/spls/gsp1024/flask_telemetry.zip
 unzip flask_telemetry.zip
 docker load -i flask_telemetry.tar

docker tag gcr.io/ops-demo-330920/flask_telemetry:61a2a7aabc7077ef474eb24f4b69faeab47deed9 \
"$REGION"-docker.pkg.dev/"$PROJECT_ID"/docker-repo/flask-telemetry:v1

docker push "$REGION"-docker.pkg.dev/"$PROJECT_ID"/docker-repo/flask-telemetry:v1


gcloud container clusters list


kubectl create ns gmp-test

wget https://storage.googleapis.com/spls/gsp1024/gmp_prom_setup.zip
unzip gmp_prom_setup.zip
cd gmp_prom_setup


sed -i "s|<ARTIFACT REGISTRY IMAGE NAME>|$REGION-docker.pkg.dev/$DEVSHELL_PROJECT_ID/docker-repo/flask-telemetry:v1|g" flask_deployment.yaml


kubectl -n gmp-test apply -f flask_deployment.yaml


kubectl -n gmp-test apply -f flask_service.yaml

kubectl get services -n gmp-test



kubectl get services -n gmp-test



gcloud logging metrics create hello-app-error \
    --description="Metric for hello-app errors" \
    --log-filter='severity=ERROR
resource.labels.container_name="hello-app"
textPayload: "ERROR: 404 Error page not found"' 




cat > mazekro.json <<'EOF_CP'
{
  "displayName": "log based metric alert",
  "userLabels": {},
  "conditions": [
    {
      "displayName": "New condition",
      "conditionThreshold": {
        "filter": 'metric.type="logging.googleapis.com/user/hello-app-error" AND resource.type="global"',
        "aggregations": [
          {
            "alignmentPeriod": "120s",
            "crossSeriesReducer": "REDUCE_SUM",
            "perSeriesAligner": "ALIGN_DELTA"
          }
        ],
        "comparison": "COMPARISON_GT",
        "duration": "60s",
        "trigger": {
          "count": 1
        }
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

EOF_CP


gcloud alpha monitoring policies create --policy-from-file=mazekro.json


timeout 120 bash -c -- 'while true; do curl $(kubectl get services -n gmp-test -o jsonpath='{.items[*].status.loadBalancer.ingress[0].ip}')/error; sleep $((RANDOM % 4)) ; done'
