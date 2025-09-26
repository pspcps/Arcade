#!/bin/bash

# Ask the user to provide a GCP zone
read -p "Enter the GCP zone (e.g., us-central1-a): " ZONE

# Confirm input
echo "Using zone: $ZONE"


# Get current GCP project ID
PROJECT_ID=$(gcloud config get-value project)
echo "Using project: $PROJECT_ID"

# Task 1: Create a Cloud Storage bucket
BUCKET_NAME="${PROJECT_ID}-bucket"
echo "Creating Cloud Storage bucket: $BUCKET_NAME"


gsutil mb -l US gs://$BUCKET_NAME/

# Create a VM instance with an additional disk
gcloud compute instances create my-instance \
    --machine-type=e2-medium \
    --zone=$ZONE \
    --image-project=debian-cloud \
    --image-family=debian-12 \
    --boot-disk-size=10GB \
    --boot-disk-type=pd-balanced \
    --create-disk=size=100GB,type=pd-standard,mode=rw,device-name=additional-disk \
    --tags=http-server

# Create a separate disk
gcloud compute disks create mydisk \
    --size=200GB \
    --zone=$ZONE

# Attach the disk to the instance
gcloud compute instances attach-disk my-instance \
    --disk=mydisk \
    --zone=$ZONE

# Wait for instance to boot
sleep 30

# Create a setup script to install NGINX
cat > prepare_disk.sh <<'EOF'
#!/bin/bash
sudo apt update
sudo apt install nginx -y
sudo systemctl start nginx
EOF

# Upload the setup script to the instance
gcloud compute scp prepare_disk.sh my-instance:/tmp \
    --zone=$ZONE \
    --quiet

# Run the script on the instance
gcloud compute ssh my-instance \
    --zone=$ZONE \
    --quiet \
    --command="bash /tmp/prepare_disk.sh"

echo "Lab execution completed successfully."
