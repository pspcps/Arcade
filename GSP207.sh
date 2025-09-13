read -p "Enter the REGION (e.g., us-central1, europe-west1): " LOCATION
export LOCATION


gcloud config set compute/region $LOCATION
gsutil mb gs://$DEVSHELL_PROJECT_ID-bucket/
gcloud services disable dataflow.googleapis.com
sleep 20
gcloud services enable dataflow.googleapis.com
sleep 20
docker run -it -e DEVSHELL_PROJECT_ID=$DEVSHELL_PROJECT_ID -e LOCATION=$LOCATION python:3.9 /bin/bash -c '
pip install "apache-beam[gcp]"==2.42.0 && \
python -m apache_beam.examples.wordcount --output OUTPUT_FILE && \
HUSTLER=gs://$DEVSHELL_PROJECT_ID-bucket && \
python -m apache_beam.examples.wordcount --project $DEVSHELL_PROJECT_ID \
  --runner DataflowRunner \
  --staging_location $HUSTLER/staging \
  --temp_location $HUSTLER/temp \
  --output $HUSTLER/results/output \
  --region $LOCATION
'


echo "Wait for few Mins."
