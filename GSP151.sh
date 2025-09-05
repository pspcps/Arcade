
gcloud auth list

export ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])")

export REGION=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-region])")

export PROJECT_ID=$(gcloud config get-value project)

gcloud config set compute/zone "$ZONE"

gcloud config set compute/region "$REGION"

gcloud sql instances create myinstance --project=$DEVSHELL_PROJECT_ID --region=$REGION --root-password=techcps --tier=db-n1-standard-4 --database-version=MYSQL_8_0

gcloud sql databases create guestbook --instance=myinstance
