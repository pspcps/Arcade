echo "👉 Listing gcloud authenticated accounts..."
gcloud auth list

echo "👉 Setting region from project metadata..."
export REGION=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-region])")

echo "👉 Defining Cloud Run service names..."
export DATASET_SERVICE=netflix-dataset-service
export FRONTEND_STAGING_SERVICE=frontend-staging-service
export FRONTEND_PRODUCTION_SERVICE=frontend-production-service

echo "👉 Setting active project..."
gcloud config set project $(gcloud projects list --format='value(PROJECT_ID)' --filter='qwiklabs-gcp')

echo "👉 Creating Firestore database in region: $REGION"
gcloud firestore databases create --location=$REGION --project=$DEVSHELL_PROJECT_ID

echo "⏳ Waiting for Firestore setup to complete..."
sleep 10

echo "👉 Enabling Cloud Run API..."
gcloud services enable run.googleapis.com

echo "👉 Cloning pet-theory GitHub repository..."
git clone https://github.com/rosera/pet-theory.git

echo "👉 Importing Netflix CSV dataset into Firestore..."
cd pet-theory/lab06/firebase-import-csv/solution
npm install
node index.js netflix_titles_original.csv

echo "👉 Navigating to REST API solution (v0.1)..."
cd ~/pet-theory/lab06/firebase-rest-api/solution-01
npm install

echo "👉 Building and submitting REST API v0.1 to Google Container Registry..."
gcloud builds submit --tag gcr.io/$DEVSHELL_PROJECT_ID/rest-api:0.1 .

echo "👉 Deploying REST API v0.1 to Cloud Run..."
gcloud run deploy $DATASET_SERVICE --image gcr.io/$DEVSHELL_PROJECT_ID/rest-api:0.1 --allow-unauthenticated --max-instances=1 --region=$REGION 

echo "👉 Fetching service URL for REST API v0.1..."
SERVICE_URL=$(gcloud run services describe $DATASET_SERVICE --region=$REGION --format 'value(status.url)')
echo "📡 Dataset Service URL: $SERVICE_URL"

echo "👉 Testing REST API v0.1 with GET request..."
curl -X GET $SERVICE_URL

echo "👉 Navigating to REST API solution (v0.2)..."
cd ~/pet-theory/lab06/firebase-rest-api/solution-02
npm install

echo "👉 Building and submitting REST API v0.2..."
gcloud builds submit --tag gcr.io/$DEVSHELL_PROJECT_ID/rest-api:0.2 .

echo "👉 Deploying REST API v0.2 to Cloud Run..."
gcloud run deploy $DATASET_SERVICE --image gcr.io/$DEVSHELL_PROJECT_ID/rest-api:0.2 --region=$REGION --allow-unauthenticated --max-instances=1

echo "👉 Fetching service URL for REST API v0.2..."
SERVICE_URL=$(gcloud run services describe $DATASET_SERVICE --region=$REGION --format 'value(status.url)')
echo "📡 Dataset Service URL (v0.2): $SERVICE_URL"

echo "👉 Testing REST API v0.2 with GET request (filter: 2019)..."
curl -X GET $SERVICE_URL/2019

echo "👉 Building frontend application..."
npm install && npm run build

echo "👉 Navigating to frontend app directory..."
cd ~/pet-theory/lab06/firebase-frontend

echo "👉 Submitting frontend-staging build..."
gcloud builds submit --tag gcr.io/$DEVSHELL_PROJECT_ID/frontend-staging:0.1 .

echo "👉 Deploying frontend-staging to Cloud Run..."
gcloud run deploy $FRONTEND_STAGING_SERVICE --image gcr.io/$DEVSHELL_PROJECT_ID/frontend-staging:0.1 --platform managed --region=$REGION --max-instances 1 --allow-unauthenticated --quiet

echo "👉 Fetching URL for frontend-staging..."
gcloud run services describe $FRONTEND_STAGING_SERVICE --region=$REGION --format="value(status.url)"

echo "👉 Submitting frontend-production build..."
gcloud builds submit --tag gcr.io/$DEVSHELL_PROJECT_ID/frontend-production:0.1

echo "👉 Deploying frontend-production to Cloud Run..."
gcloud run deploy $FRONTEND_PRODUCTION_SERVICE --image gcr.io/$DEVSHELL_PROJECT_ID/frontend-production:0.1 --platform managed --region=$REGION --max-instances=1 --quiet

echo "✅ All steps completed!"
