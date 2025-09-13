
# Set text styles
YELLOW=$(tput setaf 3)
BOLD=$(tput bold)
RESET=$(tput sgr0)

gcloud auth list

export ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])")

export REGION=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-region])")

export PROJECT_ID=$(gcloud config get-value project)
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')
gcloud config set compute/region $REGION


gcloud services enable container.googleapis.com \
    cloudbuild.googleapis.com \
    secretmanager.googleapis.com \
    containeranalysis.googleapis.com

gcloud artifacts repositories create my-repository \
  --repository-format=docker \
  --location=$REGION

gcloud container clusters create hello-cloudbuild --num-nodes 1 --region $REGION


curl -sS https://webi.sh/gh | sh 
gh auth login 
gh api user -q ".login"
GITHUB_USERNAME=$(gh api user -q ".login")
git config --global user.name "${GITHUB_USERNAME}"
git config --global user.email "${USER_EMAIL}"
echo ${GITHUB_USERNAME}
echo ${USER_EMAIL}



gh repo create  hello-cloudbuild-app --private 


gh repo create  hello-cloudbuild-env --private


cd ~
mkdir hello-cloudbuild-app

gcloud storage cp -r gs://spls/gsp1077/gke-gitops-tutorial-cloudbuild/* hello-cloudbuild-app

cd ~/hello-cloudbuild-app


export REGION=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-region])")
sed -i "s/us-central1/$REGION/g" cloudbuild.yaml
sed -i "s/us-central1/$REGION/g" cloudbuild-delivery.yaml
sed -i "s/us-central1/$REGION/g" cloudbuild-trigger-cd.yaml
sed -i "s/us-central1/$REGION/g" kubernetes.yaml.tpl

PROJECT_ID=$(gcloud config get-value project)

git init
git config credential.helper gcloud.sh
git remote add google https://github.com/${GITHUB_USERNAME}/hello-cloudbuild-app
git branch -m master
git add . && git commit -m "initial commit"


cd ~/hello-cloudbuild-app

COMMIT_ID="$(git rev-parse --short=7 HEAD)"

gcloud builds submit --tag="${REGION}-docker.pkg.dev/${PROJECT_ID}/my-repository/hello-cloudbuild:${COMMIT_ID}" .

cd ~/hello-cloudbuild-app

git add .

git commit -m "Type Any Commit Message here"

git push google master

cd ~

mkdir workingdir
cd workingdir


ssh-keygen -t rsa -b 4096 -N '' -f id_github -C "${USER_EMAIL}"

gcloud secrets create ssh_key_secret --replication-policy="automatic"

gcloud secrets versions add ssh_key_secret --data-file=id_github


GITHUB_TOKEN=$(gh auth token)

SSH_KEY_CONTENT=$(cat ~/workingdir/id_github.pub)

gh api --method POST -H "Accept: application/vnd.github.v3+json" \
  /repos/${GITHUB_USERNAME}/hello-cloudbuild-env/keys \
  -f title="SSH_KEY" \
  -f key="$SSH_KEY_CONTENT" \
  -F read_only=false

rm id_github*

gcloud projects add-iam-policy-binding ${PROJECT_NUMBER} \
--member=serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com \
--role=roles/secretmanager.secretAccessor

cd ~

gcloud projects add-iam-policy-binding ${PROJECT_NUMBER} \
--member=serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com \
--role=roles/container.developer


mkdir hello-cloudbuild-env
gcloud storage cp -r gs://spls/gsp1077/gke-gitops-tutorial-cloudbuild/* hello-cloudbuild-env


cd hello-cloudbuild-env

export REGION=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-region])")
sed -i "s/us-central1/$REGION/g" cloudbuild.yaml
sed -i "s/us-central1/$REGION/g" cloudbuild-delivery.yaml
sed -i "s/us-central1/$REGION/g" cloudbuild-trigger-cd.yaml
sed -i "s/us-central1/$REGION/g" kubernetes.yaml.tpl

ssh-keyscan -t rsa github.com > known_hosts.github
chmod +x known_hosts.github

git init
git config credential.helper gcloud.sh
git remote add google https://github.com/${GITHUB_USERNAME}/hello-cloudbuild-env
git branch -m master
git add . && git commit -m "initial commit"
git push google master


git checkout -b production

rm cloudbuild.yaml

wget https://raw.githubusercontent.com/pspcps/Arcade/refs/heads/main/GSP1077/env-cloudbuild.yaml

mv env-cloudbuild.yaml cloudbuild.yaml


export REGION=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-region])")
sed -i "s/REGION-/$REGION/g" cloudbuild.yaml
sed -i "s/GITHUB-USERNAME/${GITHUB_USERNAME}/g" cloudbuild.yaml

git add .

git commit -m "Create cloudbuild.yaml for deployment"

git checkout -b candidate

git push google production

git push google candidate


cd ~/hello-cloudbuild-app
ssh-keyscan -t rsa github.com > known_hosts.github
chmod +x known_hosts.github


git add .
git commit -m "Adding known_host file."
git push google master


rm cloudbuild.yaml


wget https://raw.githubusercontent.com/pspcps/Arcade/refs/heads/main/GSP1077/app-cloudbuild.yaml


mv app-cloudbuild.yaml cloudbuild.yaml


export REGION=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-region])")
sed -i "s/REGION/$REGION/g" cloudbuild.yaml
sed -i "s/GITHUB-USERNAME/${GITHUB_USERNAME}/g" cloudbuild.yaml

git add cloudbuild.yaml


git commit -m "Trigger CD pipeline"


git push google master




 export PROJECT_ID=$(gcloud config get-value project)
 export PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')

CB_P4SA="service-${PROJECT_NUMBER}@gcp-sa-cloudbuild.iam.gserviceaccount.com"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${CB_P4SA}" \
  --role="roles/secretmanager.admin"





echo ""

echo "Click this link to create trigger: ""${YELLOW}${BOLD}"https://console.cloud.google.com/cloud-build/triggers?project=$DEVSHELL_PROJECT_ID"${RESET}" 

echo ""


#  gcloud builds connections create github cloud-build-connection \
#   --project="${PROJECT_ID}" \
#   --region="${REGION}" ||  "⚠️ Connection might already exist"


# # Wait for user
# read -p "👉 After authorizing in browser, press [Enter] to continue..."

#  gcloud builds repositories create "${CLOUD_BUILD_REPO}" \
#   --remote-uri="https://github.com/${GITHUB_USERNAME}/${REPO_NAME}.git" \
#   --connection="cloud-build-connection" \
#   --region="${REGION}" ||  "⚠️ Repository might already exist"

#  gcloud builds triggers create github \
#   --name="hello-cloudbuild-deploy" \
#   --repository="projects/${PROJECT_ID}/locations/${REGION}/connections/cloud-build-connection/repositories/${CLOUD_BUILD_REPO}" \
#   --region="${REGION}" \
#   --branch-pattern="^candidate$" \
#   --build-config="cloudbuild.yaml" \
#   --service-account="projects/${PROJECT_ID}/serviceAccounts/${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"




# # Function to create repo and trigger
# create_repo_and_trigger() {
#   local REPO_NAME=$1
#   local TRIGGER_NAME=$2
#   local branchNaame=$3

#   echo "Creating Cloud Build repository for $REPO_NAME..."
#   gcloud builds repositories create "${REPO_NAME}" \
#     --remote-uri="https://github.com/${GITHUB_USERNAME}/${REPO_NAME}.git" \
#     --connection="cloud-build-connection" \
#     --region="${REGION}" || echo "⚠️ Repository $CLOUD_BUILD_REPO might already exist"

#   echo "Creating Cloud Build trigger '$TRIGGER_NAME'..."
#   gcloud builds triggers create github \
#     --name="${TRIGGER_NAME}" \
#     --repository="projects/${PROJECT_ID}/locations/${REGION}/connections/cloud-build-connection/repositories/${REPO_NAME}" \
#     --region="${REGION}" \
#     --branch-pattern="${branchNaame}" \
#     --build-config="cloudbuild.yaml" \
#     --service-account="projects/${PROJECT_ID}/serviceAccounts/${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" || echo "⚠️ Trigger $TRIGGER_NAME might already exist"
# }

# # Create for hello-cloudbuild-app
# create_repo_and_trigger "$REPO_NAME_APP" "hello-cloudbuild" ".*"

# # Create for hello-cloudbuild-env
# create_repo_and_trigger "$REPO_NAME_ENV" "hello-cloudbuild-deploy" "^candidate$"
