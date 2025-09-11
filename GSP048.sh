#!/bin/bash

# Color for messages (optional, minimal use)
YELLOW='\033[0;33m'
NC='\033[0m' 

# Step 1: Create the first script to run on the VM
echo "Creating initial prepare_disk.sh script..."

cat > prepare_disk.sh <<'EOF_END'
# Enable API and create API key
gcloud services enable apikeys.googleapis.com

gcloud alpha services api-keys create --display-name="mazekro" 

KEY_NAME=$(gcloud alpha services api-keys list --format="value(name)" --filter "displayName=mazekro")

API_KEY=$(gcloud alpha services api-keys get-key-string $KEY_NAME --format="value(keyString)")

# Create English speech recognition request
cat > request.json <<EOF
{
    "config": {
        "encoding": "FLAC",
        "languageCode": "en-US"
    },
    "audio": {
        "uri": "gs://cloud-samples-data/speech/brooklyn_bridge.flac"
    }
}
EOF

# Send request and save result
curl -s -X POST -H "Content-Type: application/json" --data-binary @request.json \
"https://speech.googleapis.com/v1/speech:recognize?key=${API_KEY}" > result.json

# Show result
cat result.json
EOF_END

# Step 2: Upload and execute the script on the VM
echo "Uploading and executing script on VM..."

export ZONE=$(gcloud compute instances list linux-instance --format 'csv[no-heading](zone)')

gcloud compute scp prepare_disk.sh linux-instance:/tmp --project=$DEVSHELL_PROJECT_ID --zone=$ZONE --quiet

gcloud compute ssh linux-instance --project=$DEVSHELL_PROJECT_ID --zone=$ZONE --quiet --command="bash /tmp/prepare_disk.sh"

# Step 3: User checkpoint before continuing
read -p "CHECK MY PROGRESS DONE TILL TASK 3 (Y/N)? " response
if [[ "$response" =~ ^[Yy]$ ]]; then
    echo "Proceeding with next steps..."
else
    echo "Please check the progress before proceeding."
    exit 1
fi

# Step 4: Create second script for French audio transcription
echo "Creating follow-up prepare_disk.sh script..."

cat > prepare_disk.sh <<'EOF_END'
KEY_NAME=$(gcloud alpha services api-keys list --format="value(name)" --filter "displayName=mazekro")

API_KEY=$(gcloud alpha services api-keys get-key-string $KEY_NAME --format="value(keyString)")

rm -f request.json

# Create French speech recognition request
cat > request.json <<EOF
{
    "config": {
        "encoding": "FLAC",
        "languageCode": "fr"
    },
    "audio": {
        "uri": "gs://cloud-samples-data/speech/corbeau_renard.flac"
    }
}
EOF

# Send request and save result
curl -s -X POST -H "Content-Type: application/json" --data-binary @request.json \
"https://speech.googleapis.com/v1/speech:recognize?key=${API_KEY}" > result.json

# Show result
cat result.json
EOF_END

# Step 5: Upload and run second script on VM
echo "Uploading second script to VM..."
gcloud compute scp prepare_disk.sh linux-instance:/tmp --project=$DEVSHELL_PROJECT_ID --zone=$ZONE --quiet

echo "Running French transcription on VM..."
gcloud compute ssh linux-instance --project=$DEVSHELL_PROJECT_ID --zone=$ZONE --quiet --command="bash /tmp/prepare_disk.sh"

echo "All tasks completed."
