#!/bin/bash
# Authenticate gcloud and list accounts
gcloud auth list

# Set zone and region environment variables
export ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-region])")

# Copy Google Cloud sample code
gsutil -m cp -r gs://spls/gsp067/python-docs-samples .

# Change to the hello_world sample directory
cd python-docs-samples/appengine/standard_python3/hello_world

# Update app.yaml to use python39 runtime
sed -i "s/python37/python39/g" app.yaml

# Create requirements.txt with necessary dependencies
cat > requirements.txt <<EOF_CP
Flask==1.1.2
itsdangerous==2.0.1
Jinja2==3.0.3
werkzeug==2.0.1
EOF_CP

# Create app.yaml specifying the runtime
cat > app.yaml <<EOF_CP
runtime: python39
EOF_CP

# Create the App Engine application in the specified region
gcloud app create --region=$REGION

# Deploy the application quietly (no prompts)
gcloud app deploy --quiet