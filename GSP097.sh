# Auto-detect zone of 'linux-instance'
ZONE=$(gcloud compute instances list --filter="name=linux-instance" --format="value(zone)")

# Confirm the zone found
echo "Detected zone: $ZONE"

# List current authenticated account
gcloud auth list

# List current configured project
gcloud config list project

# Set environment variable for the project
export GOOGLE_CLOUD_PROJECT=$(gcloud config get-value core/project)

# Define service account name and email
SA_NAME="my-natlang-sa"
SA_EMAIL="$SA_NAME@$GOOGLE_CLOUD_PROJECT.iam.gserviceaccount.com"

# Check if service account already exists
if gcloud iam service-accounts list --format="value(email)" | grep -q "$SA_EMAIL"; then
  echo "✅ Service account '$SA_EMAIL' already exists. Skipping creation."
else
  echo "🔧 Creating service account: $SA_NAME"
  gcloud iam service-accounts create "$SA_NAME" \
    --display-name "my natural language service account"
fi

# Check if key file already exists
if [[ -f ~/key.json ]]; then
  echo "✅ Key file '~/key.json' already exists. Skipping key creation."
else
  echo "🔑 Creating key for service account"
  gcloud iam service-accounts keys create ~/key.json \
    --iam-account "$SA_EMAIL"
fi

# SSH into the instance and run the language API command
gcloud compute ssh linux-instance --zone=$ZONE --quiet \
  --command="echo 'gcloud ml language analyze-entities --content=\"Michelangelo Caravaggio, Italian painter, is known for \\\'The Calling of Saint Matthew\\\'.\" > result.json' > run.sh && bash run.sh"
