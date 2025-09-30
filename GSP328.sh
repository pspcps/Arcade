clear

#!/bin/bash
# Define color variables

BLACK=`tput setaf 0`
RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 3`
BLUE=`tput setaf 4`
MAGENTA=`tput setaf 5`
CYAN=`tput setaf 6`
WHITE=`tput setaf 7`

BG_BLACK=`tput setab 0`
BG_RED=`tput setab 1`
BG_GREEN=`tput setab 2`
BG_YELLOW=`tput setab 3`
BG_BLUE=`tput setab 4`
BG_MAGENTA=`tput setab 5`
BG_CYAN=`tput setab 6`
BG_WHITE=`tput setab 7`

BOLD=`tput bold`
RESET=`tput sgr0`

# Array of color codes excluding black and white
TEXT_COLORS=($RED $GREEN $YELLOW $BLUE $MAGENTA $CYAN)
BG_COLORS=($BG_RED $BG_GREEN $BG_YELLOW $BG_BLUE $BG_MAGENTA $BG_CYAN)

# Pick random colors
RANDOM_TEXT_COLOR=${TEXT_COLORS[$RANDOM % ${#TEXT_COLORS[@]}]}
RANDOM_BG_COLOR=${BG_COLORS[$RANDOM % ${#BG_COLORS[@]}]}

#----------------------------------------------------start--------------------------------------------------#


echo -n "Enter PUBLIC_BILLING_SERVICE: "
read PUBLIC_BILLING_SERVICE

echo -n "Enter FRONTEND_STAGING_SERVICE: "
read FRONTEND_STAGING_SERVICE

echo -n "Enter PRIVATE_BILLING_SERVICE: "
read PRIVATE_BILLING_SERVICE

echo -n "Enter BILLING_SERVICE_ACCOUNT: "
read BILLING_SERVICE_ACCOUNT

echo -n "Enter BILLING_PROD_SERVICE: "
read BILLING_PROD_SERVICE

echo -n "Enter FRONTEND_SERVICE_ACCOUNT: "
read FRONTEND_SERVICE_ACCOUNT

echo -n "Enter FRONTEND_PRODUCTION_SERVICE: "
read FRONTEND_PRODUCTION_SERVICE


echo "${RANDOM_BG_COLOR}${RANDOM_TEXT_COLOR}${BOLD}Starting Execution${RESET}"

# Step 1: Configure Google Cloud environment for the project
echo "${BOLD}${BLUE}Configure Google Cloud environment for the project...${RESET}"
export REGION=$(gcloud compute project-info describe \
--format="value(commonInstanceMetadata.items[google-compute-default-region])")

gcloud config set project \
$(gcloud projects list --format='value(PROJECT_ID)' \
--filter='qwiklabs-gcp')

gcloud config set run/region $REGION

gcloud config set run/platform managed

# Step 2: Clone the Git repository
echo "${BOLD}${CYAN}Cloning repository...${RESET}"
git clone https://github.com/rosera/pet-theory.git && cd pet-theory/lab07

# Step 3: Deploy Billing Staging API
echo "${BOLD}${YELLOW}Deploying Billing Staging API...${RESET}"
cd ~/pet-theory/lab07/unit-api-billing
gcloud builds submit --tag gcr.io/$DEVSHELL_PROJECT_ID/billing-staging-api:0.1
gcloud run deploy $PUBLIC_BILLING_SERVICE --image gcr.io/$DEVSHELL_PROJECT_ID/billing-staging-api:0.1 --quiet

# Step 4: Deploy Frontend Staging
echo "${BOLD}${MAGENTA}Deploying Frontend Staging...${RESET}"
cd ~/pet-theory/lab07/staging-frontend-billing
gcloud builds submit --tag gcr.io/$DEVSHELL_PROJECT_ID/frontend-staging:0.1
gcloud run deploy $FRONTEND_STAGING_SERVICE --image gcr.io/$DEVSHELL_PROJECT_ID/frontend-staging:0.1 --quiet

# Step 5: Update Billing Staging API
echo "${BOLD}${RED}Updating Billing Staging API...${RESET}"
cd ~/pet-theory/lab07/staging-api-billing
gcloud builds submit --tag gcr.io/$DEVSHELL_PROJECT_ID/billing-staging-api:0.2
gcloud run deploy $PRIVATE_BILLING_SERVICE --image gcr.io/$DEVSHELL_PROJECT_ID/billing-staging-api:0.2 --quiet

# Step 6: Create IAM Service Accounts
echo "${BOLD}${GREEN}Creating IAM Service Accounts...${RESET}"
gcloud iam service-accounts create $BILLING_SERVICE_ACCOUNT --display-name "Billing Service Account Cloud Run"

# Step 7: Deploy Billing Production API
echo "${BOLD}${MAGENTA}Deploy Billing Production API...${RESET}"
cd ~/pet-theory/lab07/prod-api-billing
gcloud builds submit --tag gcr.io/$DEVSHELL_PROJECT_ID/billing-prod-api:0.1
gcloud run deploy $BILLING_PROD_SERVICE --image gcr.io/$DEVSHELL_PROJECT_ID/billing-prod-api:0.1 --quiet

# Step 8: Create Frontend IAM Service Account
echo "${BOLD}${MAGENTA}Create Frontend IAM Service Account...${RESET}"
gcloud iam service-accounts create $FRONTEND_SERVICE_ACCOUNT --display-name "Billing Service Account Cloud Run Invoker"

# Step 9: Deploy Frontend Production
echo "${BOLD}${CYAN}Deploying Frontend Production...${RESET}"
cd ~/pet-theory/lab07/prod-frontend-billing
gcloud builds submit --tag gcr.io/$DEVSHELL_PROJECT_ID/frontend-prod:0.1
gcloud run deploy $FRONTEND_PRODUCTION_SERVICE --image gcr.io/$DEVSHELL_PROJECT_ID/frontend-prod:0.1 --quiet

echo
