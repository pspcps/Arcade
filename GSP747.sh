#!/bin/bash

LOG_FILE="$HOME/deploy.log"
REPO_NAME="my_hugo_site"
THEME_REPO="https://github.com/rhazdon/hugo-theme-hello-friend-ng.git"
CLOUD_BUILD_REPO="hugo-website-build-repository"
CLOUD_BUILD_CONNECTION="cloud-build-connection"

echo "🛠️ Starting Hugo + Firebase Deployment..." | tee $LOG_FILE

function handle_error {
  echo "❌ ERROR: $1" | tee -a $LOG_FILE
  exit 1
}

# Create /tmp/installhugo.sh
if [ ! -f /tmp/installhugo.sh ]; then
  echo "📦 Creating installhugo.sh..."
  cat <<'EOF' > /tmp/installhugo.sh
#!/bin/bash
_HUGO_VERSION=0.96.0
curl -L https://github.com/gohugoio/hugo/releases/download/v${_HUGO_VERSION}/hugo_extended_${_HUGO_VERSION}_Linux-64bit.tar.gz | tar -xz -C /tmp/
echo "The Hugo binary is now at /tmp/hugo."
EOF
  chmod +x /tmp/installhugo.sh || handle_error "Failed to make installhugo.sh executable"
fi

# Install Hugo
echo "🚀 Installing Hugo..."
cd ~
/tmp/installhugo.sh >> $LOG_FILE 2>&1 || handle_error "Failed to install Hugo"

# Install dependencies
echo "🔧 Installing Git and GitHub CLI..."
sudo apt-get update >> $LOG_FILE 2>&1
sudo apt-get install -y git gh >> $LOG_FILE 2>&1 || handle_error "Failed to install git or gh"

# Set project vars
echo "🌐 Setting environment variables..."
export PROJECT_ID=$(gcloud config get-value project)
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
export REGION=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-region])")

if [[ -z "$REGION" ]]; then
  echo "⚠️ REGION not detected. Please enter your GCP region (e.g., us-central1): "
  read REGION
  export REGION
fi

# GitHub login
echo "🔐 Logging in to GitHub CLI..."
curl -sS https://webi.sh/gh | sh >> $LOG_FILE 2>&1
gh auth login || handle_error "GitHub auth failed"
GITHUB_USERNAME=$(gh api user -q ".login")
git config --global user.name "${GITHUB_USERNAME}"
git config --global user.email "hugo@blogger.com"

# Remove existing directory if it exists
if [ -d "$HOME/$REPO_NAME" ]; then
  echo "📂 Removing existing directory: $REPO_NAME"
  rm -rf "$HOME/$REPO_NAME"
fi

# Create and clone repo
echo "📁 Creating GitHub repository..."
gh repo create $REPO_NAME --private --confirm >> $LOG_FILE 2>&1 || echo "⚠️ Repo may already exist. Continuing..."
gh repo clone $REPO_NAME >> $LOG_FILE 2>&1 || handle_error "Failed to clone repo"

# Create Hugo site
echo "🧱 Creating Hugo site..."
cd ~
/tmp/hugo new site $REPO_NAME --force >> $LOG_FILE 2>&1 || echo "⚠️ Hugo site may already exist. Continuing..."

# Add theme
cd ~/$REPO_NAME
git clone $THEME_REPO themes/hello-friend-ng >> $LOG_FILE 2>&1 || handle_error "Failed to clone theme"
echo 'theme = "hello-friend-ng"' >> config.toml
sudo rm -rf themes/hello-friend-ng/.git themes/hello-friend-ng/.gitignore >> $LOG_FILE 2>&1

# Initial commit
echo "📤 Performing initial commit..."
git add . && git commit -m "Initial commit" && git push -u origin main >> $LOG_FILE 2>&1 || handle_error "Initial git commit failed"

# Copy cloudbuild.yaml
echo "📄 Adding cloudbuild.yaml..."
cp /tmp/cloudbuild.yaml . || handle_error "Missing cloudbuild.yaml"

# Create connection only if it doesn't exist
echo "🔗 Checking for existing Cloud Build GitHub connection..."
if ! gcloud builds connections describe $CLOUD_BUILD_CONNECTION --region=$REGION >> $LOG_FILE 2>&1; then
  echo "📡 Creating Cloud Build GitHub connection..."
  gcloud builds connections create github $CLOUD_BUILD_CONNECTION --project=$PROJECT_ID --region=$REGION >> $LOG_FILE 2>&1 || handle_error "Connection creation failed"
  echo "🌐 Authorize Cloud Build access:"
  gcloud builds connections describe $CLOUD_BUILD_CONNECTION --region=$REGION | grep actionUri
  read -p "👉 After authorizing in browser, press [Enter] to continue..."
else
  echo "✅ Connection already exists. Skipping creation."
fi

# Create Cloud Build repo
echo "🗃️ Creating Cloud Build repository..."
gcloud builds repositories create $CLOUD_BUILD_REPO \
  --remote-uri="https://github.com/${GITHUB_USERNAME}/${REPO_NAME}.git" \
  --connection=$CLOUD_BUILD_CONNECTION --region=$REGION >> $LOG_FILE 2>&1 || echo "⚠️ Repo may already exist. Continuing..."

# Create trigger
echo "🎯 Creating build trigger..."
gcloud builds triggers create github --name="commit-to-main-branch1" \
   --repository=projects/$PROJECT_ID/locations/$REGION/connections/$CLOUD_BUILD_CONNECTION/repositories/$CLOUD_BUILD_REPO \
   --build-config='cloudbuild.yaml' \
   --service-account=projects/$PROJECT_ID/serviceAccounts/$PROJECT_NUMBER-compute@developer.gserviceaccount.com \
   --region=$REGION \
   --branch-pattern='^main$' >> $LOG_FILE 2>&1 || echo "⚠️ Trigger may already exist. Continuing..."

# Test the pipeline with title update
echo "🧪 Testing Cloud Build pipeline..."
sed -i 's/title = ".*"/title = "Blogging with Hugo and Cloud Build"/' config.toml
git add . && git commit -m "I updated the site title" && git push -u origin main >> $LOG_FILE 2>&1 || handle_error "Failed to trigger build"

# Wait and fetch build status
echo "🕒 Waiting for build to start..."
sleep 20
BUILD_ID=$(gcloud builds list --region=$REGION --format='value(ID)' --filter=$(git rev-parse HEAD))

echo "🔍 Fetching build logs..."
gcloud builds log --region=$REGION $BUILD_ID | tee -a $LOG_FILE

echo "🌐 Fetching Firebase Hosting URL..."
gcloud builds log $BUILD_ID --region=$REGION | grep "Hosting URL" | tee -a $LOG_FILE

echo "✅ Deployment complete. Check your hosting URL above."
echo "📄 Full log saved to: $LOG_FILE"
