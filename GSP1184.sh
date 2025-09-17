#!/bin/bash

# Start of the script
echo
echo "Starting the process..."
echo

echo "Fetching project details..."
export ZONE=$(gcloud compute project-info describe \
--format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo "$ZONE" | cut -d '-' -f 1-2)
export PROJECT_ID=$(gcloud config get-value project)
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID \
    --format='value(projectNumber)')

echo "Enabling necessary Google Cloud services..."
gcloud services enable \
  cloudkms.googleapis.com \
  cloudbuild.googleapis.com \
  container.googleapis.com \
  containerregistry.googleapis.com \
  artifactregistry.googleapis.com \
  containerscanning.googleapis.com \
  ondemandscanning.googleapis.com \
  binaryauthorization.googleapis.com

echo "Granting required IAM permissions..."
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
        --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
        --role="roles/iam.serviceAccountUser"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
        --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
        --role="roles/ondemandscanning.admin"



# Step 2: Define service account email
SA_EMAIL=${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com
SA="serviceAccount:$SA_EMAIL"

echo "👤 Target Service Account: $SA_EMAIL"

# Step 3: Define all the roles to assign
ROLES=(
  "roles/cloudfunctions.developer"
  "roles/run.admin"
  "roles/appengine.admin"
  "roles/container.developer"
  "roles/compute.instanceAdmin.v1"
  "roles/firebase.admin"
  "roles/cloudkms.cryptoKeyDecrypter"
  "roles/secretmanager.secretAccessor"
  "roles/iam.serviceAccountUser"
  "roles/logging.configWriter"
  "roles/storage.admin"
  "roles/storage.objectCreator"
  "roles/artifactregistry.writer"
  "roles/cloudbuild.workerPoolUser"
)

# Step 4: Bind each role
for ROLE in "${ROLES[@]}"; do
  echo "🔑 Granting $ROLE to $SA_EMAIL"
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="$SA" \
    --role="$ROLE" \
    --quiet
done


echo "Creating and navigating to project directory..."
mkdir vuln-scan && cd vuln-scan

echo "Creating Dockerfile..."
cat > ./Dockerfile << EOF
FROM gcr.io/google-appengine/debian10@sha256:d25b680d69e8b386ab189c3ab45e219fededb9f91e1ab51f8e999f3edc40d2a1

# System
RUN apt update && apt install python3-pip -y

# App
WORKDIR /app
COPY . ./

RUN pip3 install Flask==1.1.4  
RUN pip3 install gunicorn==20.1.0  

CMD exec gunicorn --bind :\$PORT --workers 1 --threads 8 --timeout 0 main:app
EOF

echo "Creating main.py..."
cat > ./main.py << EOF
import os
from flask import Flask

app = Flask(__name__)

@app.route("/")
def hello_world():
    name = os.environ.get("NAME", "World")
    return "Hello {}!".format(name)

if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))
EOF

echo "Creating Cloud Build YAML file..."
cat > ./cloudbuild.yaml << EOF
steps:

# build
- id: "build"
  name: 'gcr.io/cloud-builders/docker'
  args: ['build', '-t', '$REGION-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image', '.']
  waitFor: ['-']
EOF

echo "Submitting Cloud Build..."
gcloud builds submit

echo "Creating Artifact Registry..."
gcloud artifacts repositories create artifact-scanning-repo \
  --repository-format=docker \
  --location=$REGION \
  --description="Docker repository"

# Authenticate with Google Cloud
echo "Authenticating Docker with Google Cloud..."
gcloud auth configure-docker $REGION-docker.pkg.dev

echo "Creating cloudbuild.yaml file..."
cat > ./cloudbuild.yaml << EOF
steps:

# build
- id: "build"
  name: 'gcr.io/cloud-builders/docker'
  args: ['build', '-t', '$REGION-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image', '.']
  waitFor: ['-']

# push to artifact registry
- id: "push"
  name: 'gcr.io/cloud-builders/docker'
  args: ['push',  '$REGION-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image']

images:
  - $REGION-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image
EOF

echo "Submitting the Cloud Build..."
gcloud builds submit

echo "Building the Docker image locally..."
docker build -t $REGION-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image .

echo "Scanning the Docker image for vulnerabilities..."
gcloud artifacts docker images scan \
    $REGION-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image \
    --format="value(response.scan)" > scan_id.txt

echo "Scan ID stored in scan_id.txt. Fetching results..."
cat scan_id.txt

gcloud artifacts docker images list-vulnerabilities $(cat scan_id.txt)

echo "Checking for critical vulnerabilities..."
export SEVERITY=CRITICAL
gcloud artifacts docker images list-vulnerabilities $(cat scan_id.txt) --format="value(vulnerability.effectiveSeverity)" | if grep -Fxq ${SEVERITY}; then echo "Failed vulnerability check for ${SEVERITY} level"; else echo "No ${SEVERITY} vulnerabilities found"; fi

echo "Granting IAM permissions to Cloud Build service account..."
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
        --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
        --role="roles/iam.serviceAccountUser"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
        --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
        --role="roles/ondemandscanning.admin"

echo "Creating a more detailed cloudbuild.yaml..."
cat > ./cloudbuild.yaml << EOF
steps:

# build
- id: "build"
  name: 'gcr.io/cloud-builders/docker'
  args: ['build', '-t', '$REGION-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image', '.']
  waitFor: ['-']

# Run a vulnerability scan
- id: "scan"
  name: 'gcr.io/cloud-builders/gcloud'
  entrypoint: 'bash'
  args:
  - '-c'
  - |
    gcloud artifacts docker images scan \
    $REGION-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image \
    --location us \
    --format="value(response.scan)" > /workspace/scan_id.txt

# Analyze the result of the scan
- id: "severity_check"
  name: 'gcr.io/cloud-builders/gcloud'
  entrypoint: 'bash'
  args:
  - '-c'
  - |
    gcloud artifacts docker images list-vulnerabilities \$(cat /workspace/scan_id.txt) \
    --format="value(vulnerability.effectiveSeverity)" | if grep -Fxq CRITICAL; \
    then echo "Failed vulnerability check for CRITICAL level" && exit 1; else echo "No CRITICAL vulnerability found!" && exit 0; fi

# Retagging and pushing
- id: "retag"
  name: 'gcr.io/cloud-builders/docker'
  args: ['tag', '$REGION-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image', '$REGION-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image:good']

- id: "push"
  name: 'gcr.io/cloud-builders/docker'
  args: ['push', '$REGION-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image:good']

images:
  - $REGION-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image
EOF

echo "Submitting final Cloud Build..."
gcloud builds submit

echo "Creating Dockerfile..."
cat > ./Dockerfile << EOF
FROM python:3.8-alpine 

# App
WORKDIR /app
COPY . ./

RUN pip3 install Flask==2.1.0
RUN pip3 install gunicorn==20.1.0
RUN pip3 install Werkzeug==2.2.2

CMD exec gunicorn --bind :\$PORT --workers 1 --threads 8 main:app
EOF

echo "Submitting final build with Dockerfile..."
gcloud builds submit
echo

# Safely delete the script if it exists
SCRIPT_NAME="arcadecrew.sh"
if [ -f "$SCRIPT_NAME" ]; then
    echo "Deleting the script ($SCRIPT_NAME) for safety purposes..."
    rm -- "$SCRIPT_NAME"
fi

echo
# Completion message
echo "Lab Completed Successfully!"