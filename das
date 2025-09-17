
# Environment Setup
echo "Retrieving project details..."
export ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo "$ZONE" | cut -d '-' -f 1-2)
export PROJECT_ID=$(gcloud config get-value project)
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')

echo "Project ID: $PROJECT_ID"
echo "Project Number: $PROJECT_NUMBER"
echo "Zone: $ZONE"
echo "Region: $REGION"
echo

# Service Enablement
echo "▬▬▬▬▬▬▬▬▬ ENABLING SERVICES ▬▬▬▬▬▬▬▬▬"
echo "Enabling Artifact Registry API..."
gcloud services enable artifactregistry.googleapis.com
echo "✅ Artifact Registry API enabled successfully!"
echo

# Repository Setup
echo "▬▬▬▬▬▬▬▬▬ REPOSITORY SETUP ▬▬▬▬▬▬▬▬▬"
echo "Cloning Java Docs Samples repository..."
git clone https://github.com/GoogleCloudPlatform/java-docs-samples
cd java-docs-samples/container-registry/container-analysis
echo "✅ Repository cloned successfully!"
echo

# Maven Repository Creation
echo "▬▬▬▬▬▬▬▬▬ MAVEN REPOSITORY CREATION ▬▬▬▬▬▬▬▬▬"
echo "Creating container-dev-java-repo..."
gcloud artifacts repositories create container-dev-java-repo \
    --repository-format=maven \
    --location=$REGION \
    --description="Java package repository for Container Dev Workshop"
echo "✅ Maven repository created successfully!"

echo "Describing repository..."
gcloud artifacts repositories describe container-dev-java-repo \
    --location=$REGION
echo "✅ Repository details displayed!"
echo

# Remote Repository Setup
echo "▬▬▬▬▬▬▬▬▬ REMOTE REPOSITORY SETUP ▬▬▬▬▬▬▬▬▬"
echo "Creating Maven Central cache..."
gcloud artifacts repositories create maven-central-cache \
    --project=$PROJECT_ID \
    --repository-format=maven \
    --location=$REGION \
    --description="Remote repository for Maven Central caching" \
    --mode=remote-repository \
    --remote-repo-config-desc="Maven Central" \
    --remote-mvn-repo=MAVEN-CENTRAL
echo "✅ Maven Central cache created successfully!"
echo

# Virtual Repository Configuration
echo "▬▬▬▬▬▬▬▬▬ VIRTUAL REPOSITORY SETUP ▬▬▬▬▬▬▬▬▬"
echo "Creating policy.json file..."
cat > ./policy.json << EOF
[
  {
    "id": "private",
    "repository": "projects/${PROJECT_ID}/locations/$REGION/repositories/container-dev-java-repo",
    "priority": 100
  },
  {
    "id": "central",
    "repository": "projects/${PROJECT_ID}/locations/$REGION/repositories/maven-central-cache",
    "priority": 80
  }
]
EOF
echo "✅ Policy file created successfully!"

echo "Creating virtual Maven repository..."
echo "This may take a few moments..."
gcloud artifacts repositories create virtual-maven-repo \
    --project=${PROJECT_ID} \
    --repository-format=maven \
    --mode=virtual-repository \
    --location=$REGION \
    --description="Virtual Maven Repo" \
    --upstream-policy-file=./policy.json
echo "✅ Virtual Maven repository created successfully!"
echo
