# Fetch zone of existing VM named 'lab-vm'
export ZONE=$(gcloud compute instances list --filter="name=lab-vm" --format="value(zone)")
echo "Detected VM zone: $ZONE"

# Fetch current project ID
export GOOGLE_CLOUD_PROJECT=$(gcloud config get-value core/project)

# Create an API key (or use an existing one)
export API_KEY=$(gcloud services api-keys create --display-name="natural-language-api-key" --project=$GOOGLE_CLOUD_PROJECT --format="value(keyString)")
echo "Generated API Key: $API_KEY"

# SSH into the VM and execute the remote script
gcloud compute ssh lab-vm --zone=$ZONE --quiet --command \
"curl -LO curl -LO https://raw.githubusercontent.com/pspcps/Arcade/refs/heads/main/ARC130-1.sh && \
chmod +x ARC130-1.sh && \
API_KEY=$API_KEY ./ARC130-1.sh"
