#!/bin/bash

set -e

# Ask user for App Engine region
read -p "Enter the App Engine region (e.g., europe-west4): " region

echo "You entered deployment reason: $reason"
echo "You selected App Engine region: $region"
echo "Starting deployment process..."

# Step 1: Clone the sample app repository
echo "Cloning sample app repository..."
gsutil -m cp -r gs://spls/gsp067/python-docs-samples .

# Navigate to app directory
cd python-docs-samples/appengine/standard_python3/hello_world

# Step 2: Update python version in app.yaml from python37 to python39
echo "Updating python version in app.yaml..."
sed -i "s/python37/python39/g" app.yaml

# Step 3: Update requirements.txt to add specified packages
echo "Updating requirements.txt..."
cat > requirements.txt <<EOF
Flask==1.1.2
itsdangerous==2.0.1
Jinja2==3.0.3
werkzeug==2.0.1
EOF

# Step 3.5: Write deployment reason into a file
echo "Writing deployment reason into deployment_reason.txt..."
echo "Deployment reason: $reason" > deployment_reason.txt

# Step 4: Install python3-venv and setup virtual environment
echo "Installing python3-venv and creating virtual environment..."
sudo apt update -y
sudo apt install python3-venv -y

# Create virtual environment
python3 -m venv myvenv

# Activate virtual environment
source myvenv/bin/activate

# Step 5: Run local Flask app (in background)
echo "Starting Flask app locally..."
flask --app main run &

# Give some time for server to start
sleep 5

echo "Flask app is running locally on port 5000."
echo "Use Cloud Shell web preview on port 5000 to preview the app."

# Step 6: Deploy app to App Engine with user-provided region
echo "Creating App Engine app (if not already created) in region: $region ..."
gcloud app create --region=$region || echo "App Engine app already exists."

echo "Deploying app to App Engine..."
gcloud app deploy --quiet

# Step 7: Open the deployed app in browser
echo "Opening the deployed app in your browser..."
gcloud app browse

echo "Deployment completed for reason: $reason"
