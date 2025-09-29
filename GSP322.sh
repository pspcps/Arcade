
# Set text styles
YELLOW=$(tput setaf 3)
BOLD=$(tput bold)
RESET=$(tput sgr0)

echo "Please set the below values correctly"
read -p "${YELLOW}${BOLD}Enter the IAP_NETWORK_TAG: ${RESET}" IAP_NETWORK_TAG
read -p "${YELLOW}${BOLD}Enter the INTERNAL_NETWORK_TAG: ${RESET}" INTERNAL_NETWORK_TAG
read -p "${YELLOW}${BOLD}Enter the HTTP_NETWORK_TAG: ${RESET}" HTTP_NETWORK_TAG


# Export variables after collecting input
export IAP_NETWORK_TAG INTERNAL_NETWORK_TAG HTTP_NETWORK_TAG

gcloud auth list


export ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])")


gcloud compute firewall-rules delete open-access --quiet


gcloud compute instances start bastion --zone=$ZONE --project=$DEVSHELL_PROJECT_ID


gcloud compute firewall-rules create ssh-ingress --allow=tcp:22 --source-ranges 35.235.240.0/20 --target-tags $IAP_NETWORK_TAG --network acme-vpc


gcloud compute instances add-tags bastion --tags=$IAP_NETWORK_TAG --zone=$ZONE
 

gcloud compute firewall-rules create http-ingress --allow=tcp:80 --source-ranges 0.0.0.0/0 --target-tags $HTTP_NETWORK_TAG --network acme-vpc
 

gcloud compute instances add-tags juice-shop --tags=$HTTP_NETWORK_TAG --zone=$ZONE
 

gcloud compute firewall-rules create internal-ssh-ingress --allow=tcp:22 --source-ranges 192.168.10.0/24 --target-tags $INTERNAL_NETWORK_TAG --network acme-vpc
 

gcloud compute instances add-tags juice-shop --tags=$INTERNAL_NETWORK_TAG --zone=$ZONE
 


timeout 45 gcloud compute ssh bastion --zone=$ZONE --project=$DEVSHELL_PROJECT_ID --quiet --command="gcloud compute ssh juice-shop --zone=$ZONE --internal-ip --quiet"

