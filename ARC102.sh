read -p "Enter your bucket name (e.g. my-image-bucket): " BUCKET
read -p "Enter your Pub/Sub topic name (e.g. image-topic): " TOPIC
read -p "Enter your Cloud Function name (e.g. thumbnailFunction): " FUNCTION
read -p "Enter your region (e.g. us-central1): " REGION

# Start execution
echo "Starting Execution"

PROJECT_ID=$(gcloud config get-value project)
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')
BUCKET_SERVICE_ACCOUNT="${PROJECT_ID}@${PROJECT_ID}.iam.gserviceaccount.com"

# Enable required services
gcloud services enable \
  artifactregistry.googleapis.com \
  cloudfunctions.googleapis.com \
  cloudbuild.googleapis.com \
  eventarc.googleapis.com \
  run.googleapis.com \
  logging.googleapis.com \
  pubsub.googleapis.com

sleep 20

# Grant Eventarc permission to Compute Engine default service account
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
  --role="roles/eventarc.eventReceiver"

sleep 10

# Get KMS service account and grant Pub/Sub publisher role
SERVICE_ACCOUNT="$(gsutil kms serviceaccount -p "$PROJECT_ID")"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${SERVICE_ACCOUNT}" \
  --role="roles/pubsub.publisher"

sleep 10

# Grant IAM Service Account Token Creator role to Pub/Sub service account
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:service-${PROJECT_NUMBER}@gcp-sa-pubsub.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountTokenCreator"

sleep 10

# Grant Pub/Sub Publisher role to bucket service account
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${BUCKET_SERVICE_ACCOUNT}" \
  --role="roles/pubsub.publisher"

sleep 10

# Create the GCS bucket
gsutil mb -l "$REGION" "gs://${BUCKET}"

# Create the Pub/Sub topic
gcloud pubsub topics create "$TOPIC"

# Create index.js
cat > index.js <<'EOF'
"use strict";
const crc32 = require("fast-crc32c");
const { Storage } = require('@google-cloud/storage');
const gcs = new Storage();
const { PubSub } = require('@google-cloud/pubsub');
const imagemagick = require("imagemagick-stream");

exports.thumbnail = (event, context) => {
  const fileName = event.name;
  const bucketName = event.bucket;
  const size = "64x64";
  const bucket = gcs.bucket(bucketName);
  const topicName = "$TOPIC";
  const pubsub = new PubSub();

  if (fileName.search("64x64_thumbnail") === -1) {
    const filename_split = fileName.split('.');
    const filename_ext = filename_split[filename_split.length - 1];
    const filename_without_ext = fileName.substring(0, fileName.length - filename_ext.length);

    if (filename_ext.toLowerCase() === 'png' || filename_ext.toLowerCase() === 'jpg') {
      console.log(`Processing Original: gs://${bucketName}/${fileName}`);
      const gcsObject = bucket.file(fileName);
      const newFilename = filename_without_ext + size + '_thumbnail.' + filename_ext;
      const gcsNewObject = bucket.file(newFilename);
      const srcStream = gcsObject.createReadStream();
      const dstStream = gcsNewObject.createWriteStream();
      const resize = imagemagick().resize(size).quality(90);

      srcStream.pipe(resize).pipe(dstStream);

      return new Promise((resolve, reject) => {
        dstStream
          .on("error", (err) => {
            console.log(`Error: ${err}`);
            reject(err);
          })
          .on("finish", () => {
            console.log(`Success: ${fileName} → ${newFilename}`);
            gcsNewObject.setMetadata({
              contentType: 'image/' + filename_ext.toLowerCase()
            }, () => {});

            pubsub
              .topic(topicName)
              .publisher()
              .publish(Buffer.from(newFilename))
              .then(messageId => {
                console.log(`Message ${messageId} published.`);
              })
              .catch(err => {
                console.error('ERROR:', err);
              });

            resolve();
          });
      });
    } else {
      console.log(`gs://${bucketName}/${fileName} is not an image I can handle`);
    }
  } else {
    console.log(`gs://${bucketName}/${fileName} already has a thumbnail`);
  }
};
EOF

# Replace placeholder with actual topic name
sed -i "17c\  const topicName = '$TOPIC';" index.js

# Create package.json
cat > package.json <<EOF
{
  "name": "thumbnails",
  "version": "1.0.0",
  "description": "Create Thumbnail of uploaded image",
  "scripts": {
    "start": "node index.js"
  },
  "dependencies": {
    "@google-cloud/pubsub": "^2.0.0",
    "@google-cloud/storage": "^5.0.0",
    "fast-crc32c": "1.0.4",
    "imagemagick-stream": "4.1.1"
  },
  "engines": {
    "node": ">=4.3.2"
  }
}
EOF

# Function deployment helper
deploy_function() {
  gcloud functions deploy "$FUNCTION" \
    --gen2 \
    --runtime nodejs20 \
    --trigger-resource "$BUCKET" \
    --trigger-event google.storage.object.finalize \
    --entry-point thumbnail \
    --region="$REGION" \
    --source . \
    --quiet
}

# Deploy function and wait for Cloud Run service
while true; do
  deploy_function

  if gcloud run services describe "$FUNCTION" --region "$REGION" &> /dev/null; then
    echo "Cloud Run service is created."
    break
  else
    echo "Waiting for Cloud Run service to be created..."
    sleep 10
  fi
done

# Download and upload sample image
wget https://storage.googleapis.com/cloud-training/gsp315/map.jpg 
gsutil cp map.jpg "gs://${BUCKET}"

echo "Deployment complete."
