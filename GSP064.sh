
# Set text styles
YELLOW=$(tput setaf 3)
BOLD=$(tput bold)
RESET=$(tput sgr0)

gcloud auth list

read -p "${YELLOW}${BOLD}Enter the USERNAME_2: ${RESET}" USERNAME_2

touch sample.txt

gsutil mb gs://$DEVSHELL_PROJECT_ID

gsutil cp sample.txt gs://$DEVSHELL_PROJECT_ID

gcloud projects remove-iam-policy-binding $DEVSHELL_PROJECT_ID --member="user:$USERNAME_2" --role="roles/viewer"

gcloud projects add-iam-policy-binding $DEVSHELL_PROJECT_ID --member="user:$USERNAME_2" --role="roles/storage.objectViewer"