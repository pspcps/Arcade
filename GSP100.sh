

gcloud auth list

export ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])")

export REGION=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-region])")

gcloud config set compute/zone "$ZONE"

gcloud config set compute/region "$REGION"

gcloud container clusters create --machine-type=e2-medium --zone=$ZONE lab-cluster

gcloud container clusters get-credentials lab-cluster

kubectl create deployment hello-server --image=gcr.io/google-samples/hello-app:1.0

kubectl expose deployment hello-server --type=LoadBalancer --port 8080


#!/bin/bash

# Define color variables
YELLOW_TEXT=$'\033[0;93m'
BOLD=`tput bold`
RESET=`tput sgr0`


# Gather inputs for the required variables, cycling through colors
echo -n -e "${BOLD}${YELLOW_TEXT}⚠️ ☢️ Please Check Progress Till Task 4, and than Press Enter Than Y For Deleting Instance ${RESET} " 
read KEY 

gcloud container clusters delete lab-cluster