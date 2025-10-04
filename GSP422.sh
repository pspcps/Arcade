#!/bin/bash


gcloud auth list

export ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])")

export REGION=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-region])")

gcloud config set compute/zone "$ZONE"

gcloud config set compute/region "$REGION"

export PROJECT_ID=$(gcloud config get-value project)

gcloud config set project "$DEVSHELL_PROJECT_ID"

gcloud services enable appengine.googleapis.com

git clone https://github.com/GoogleCloudPlatform/python-docs-samples

cd ~/python-docs-samples/appengine/standard_python3/hello_world

export "PROJECT_ID=${PROJECT_ID}"

gcloud app create --project $PROJECT_ID --region=$REGION

echo "Y" | gcloud app deploy app.yaml --project $PROJECT_ID

cd ~/python-docs-samples/appengine/standard_python3/hello_world

echo "Y" | gcloud app deploy -v v1
echo
