
echo "Please set the below values correctly"
read -p "Enter the MESSAGE: " MESSAGE

# Export variables after collecting input
export MESSAGE

export ZONE="$(gcloud compute instances list --project=$DEVSHELL_PROJECT_ID --format='value(ZONE)')"

export REGION=${ZONE%-*}

gcloud services enable appengine.googleapis.com

sleep 10

echo $ZONE
echo $REGION

gcloud compute ssh "lab-setup" --zone=$ZONE --project=$DEVSHELL_PROJECT_ID --quiet --command "git clone https://github.com/GoogleCloudPlatform/python-docs-samples.git"

git clone https://github.com/GoogleCloudPlatform/python-docs-samples.git
cd python-docs-samples/appengine/standard_python3/hello_world

sed -i "32c\    return \"$MESSAGE\"" main.py

if [ "$REGION" == "us-east" ]; then
  REGION="us-east1"
fi

gcloud app create --region=$REGION

gcloud app deploy --quiet

gcloud compute ssh "lab-setup" --zone=$ZONE --project=$DEVSHELL_PROJECT_ID --quiet --command "git clone https://github.com/GoogleCloudPlatform/python-docs-samples.git"
