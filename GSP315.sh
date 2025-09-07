#!/bin/bash

#----------------------------------------- Start -----------------------------------------#

echo "Starting Execution..."

# Ask the user to provide required variables
read -p "Enter USER_2 (email): " USER_2
export USER_2

read -p "Enter ZONE (e.g. us-central1-a): " ZONE
export ZONE

read -p "Enter TOPIC name: " TOPIC
export TOPIC

read -p "Enter FUNCTION name: " FUNCTION
export FUNCTION

# Derived variables
export REGION="${ZONE%-*}"
export PROJECT_ID=$(gcloud config get-value project)
export BUCKET_NAME="${PROJECT_ID}-bucket"

# Enable required GCP APIs
gcloud services enable \
  artifactregistry.googleapis.com \
  cloudfunctions.googleapis.com \
  cloudbuild.googleapis.com \
  eventarc.googleapis.com \
  run.googleapis.com \
  logging.googleapis.com \
  pubsub.googleapis.com

sleep 10

# Get project number
PROJECT_NUMBER=$(gcloud projects describe "$DEVSHELL_PROJECT_ID" --format='value(projectNumber)')

# Add IAM roles
gcloud projects add-iam-policy-binding "$DEVSHELL_PROJECT_ID" \
  --member="serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
  --role="roles/eventarc.eventReceiver"

sleep 5

SERVICE_ACCOUNT="$(gsutil kms serviceaccount -p $DEVSHELL_PROJECT_ID)"

gcloud projects add-iam-policy-binding "$DEVSHELL_PROJECT_ID" \
  --member="serviceAccount:${SERVICE_ACCOUNT}" \
  --role="roles/pubsub.publisher"

sleep 5

gcloud projects add-iam-policy-binding "$DEVSHELL_PROJECT_ID" \
  --member="serviceAccount:service-${PROJECT_NUMBER}@gcp-sa-pubsub.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountTokenCreator"

sleep 5

# Create GCS bucket
gsutil mb -l "$REGION" "gs://${BUCKET_NAME}"

# Create Pub/Sub topic
gcloud pubsub topics create "$TOPIC"

# Create working directory
mkdir -p thumbnail-function
cd thumbnail-function

# Write index.js
cat > index.js <<'EOF_END'
const functions = require('@google-cloud/functions-framework');
const crc32 = require("fast-crc32c");
const { Storage } = require('@google-cloud/storage');
const gcs = new Storage();
const { PubSub } = require('@google-cloud/pubsub');
const imagemagick = require("imagemagick-stream");

functions.cloudEvent('$FUNCTION_NAME', cloudEvent => {
  const event = cloudEvent.data;
  const fileName = event.name;
  const bucketName = event.bucket;
  const size = "64x64"
  const bucket = gcs.bucket(bucketName);
  const topicName = "$TOPIC_NAME";
  const pubsub = new PubSub();

  if ( fileName.search("64x64_thumbnail") == -1 ) {
    var filename_split = fileName.split('.');
    var filename_ext = filename_split[filename_split.length - 1];
    var filename_without_ext = fileName.substring(0, fileName.length - filename_ext.length );

    if (filename_ext.toLowerCase() == 'png' || filename_ext.toLowerCase() == 'jpg') {
      const gcsObject = bucket.file(fileName);
      let newFilename = filename_without_ext + size + '_thumbnail.' + filename_ext;
      let gcsNewObject = bucket.file(newFilename);
      let srcStream = gcsObject.createReadStream();
      let dstStream = gcsNewObject.createWriteStream();
      let resize = imagemagick().resize(size).quality(90);

      srcStream.pipe(resize).pipe(dstStream);

      return new Promise((resolve, reject) => {
        dstStream
          .on("error", (err) => reject(err))
          .on("finish", () => {
            gcsNewObject.setMetadata({
              contentType: 'image/' + filename_ext.toLowerCase()
            }, () => {});

            pubsub
              .topic(topicName)
              .publisher()
              .publish(Buffer.from(newFilename))
              .then(messageId => console.log(`Published ${messageId}`))
              .catch(err => console.error('ERROR:', err));
          });
      });
    } else {
      console.log(`gs://${bucketName}/${fileName} is not a supported image.`);
    }
  } else {
    console.log(`gs://${bucketName}/${fileName} already has a thumbnail.`);
  }
});
EOF_END

# Replace placeholders
sed -i "8c\functions.cloudEvent('$FUNCTION', cloudEvent => { " index.js
sed -i "18c\  const topicName = '$TOPIC';" index.js

# Create package.json
cat > package.json <<EOF_END
{
  "name": "thumbnails",
  "version": "1.0.0",
  "description": "Create Thumbnail of uploaded image",
  "scripts": {
    "start": "node index.js"
  },
  "dependencies": {
    "@google-cloud/functions-framework": "^3.0.0",
    "@google-cloud/pubsub": "^2.0.0",
    "@google-cloud/storage": "^5.0.0",
    "fast-crc32c": "1.0.4",
    "imagemagick-stream": "4.1.1"
  },
  "engines": {
    "node": ">=4.3.2"
  }
}
EOF_END

# Add pubsub.publisher to Cloud Function's SA
BUCKET_SERVICE_ACCOUNT="${PROJECT_ID}@${PROJECT_ID}.iam.gserviceaccount.com"
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${BUCKET_SERVICE_ACCOUNT}" \
  --role="roles/pubsub.publisher"

# Deploy function
deploy_function() {
    gcloud functions deploy "$FUNCTION" \
    --gen2 \
    --runtime nodejs20 \
    --trigger-resource "$BUCKET_NAME" \
    --trigger-event google.storage.object.finalize \
    --entry-point "$FUNCTION" \
    --region="$REGION" \
    --source . \
    --quiet
}

# Wait until Cloud Run service is created
while true; do
  deploy_function

  if gcloud run services describe "$FUNCTION" --region "$REGION" &> /dev/null; then
    echo "Cloud Run service created successfully."
    break
  else
    echo "Waiting for Cloud Run service to be created..."
    sleep 10
  fi
done

# Upload test image
curl -o map.jpg https://storage.googleapis.com/cloud-training/gsp315/map.jpg
gsutil cp map.jpg "gs://${BUCKET_NAME}/map.jpg"

# Remove IAM binding
gcloud projects remove-iam-policy-binding "$DEVSHELL_PROJECT_ID" \
  --member="user:$USER_2" \
  --role="roles/viewer"

echo "Congratulations! The script has completed."

#------------------------------------------ End ------------------------------------------#
