# Prompt the user for the compute zone
read -p "Enter the Compute Engine zone (e.g., us-central1-a): " ZONE

# List current authenticated account
gcloud auth list

# List current configured project
gcloud config list project

# Set environment variable for the project
export GOOGLE_CLOUD_PROJECT=$(gcloud config get-value core/project)

# Create a service account
gcloud iam service-accounts create my-natlang-sa \
  --display-name "my natural language service account"

# Create a service account key
gcloud iam service-accounts keys create ~/key.json \
  --iam-account my-natlang-sa@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com


# SSH into the instance and run the language API command
gcloud compute ssh linux-instance --zone=$ZONE --quiet \
  --command="gcloud ml language analyze-entities --content='Michelangelo Caravaggio, Italian painter, is known for \'The Calling of Saint Matthew\'.' > result.json"
