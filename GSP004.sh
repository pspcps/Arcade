#!/bin/bash

# Prompt user to enter the compute zone
read -p "Enter ZONE: " ZONE

# Export ZONE and derive REGION from it
export ZONE=$ZONE
export REGION="${ZONE%-*}"

# Set the compute zone and region in gcloud config
gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION

# Create a compute instance named 'gcelab'
gcloud compute instances create gcelab --zone $ZONE --machine-type e2-standard-2

# Create a persistent disk named 'mydisk' with size 200GB
gcloud compute disks create mydisk --size=200GB --zone $ZONE

# Attach the newly created disk to the 'gcelab' instance
gcloud compute instances attach-disk gcelab --disk mydisk --zone $ZONE

# Create a script to format and mount the attached disk on the instance
cat > prepare_disk.sh <<'EOF_END'
ls -l /dev/disk/by-id/

sudo mkdir /mnt/mydisk

sudo mkfs.ext4 -F -E lazy_itable_init=0,lazy_journal_init=0,discard /dev/disk/by-id/scsi-0Google_PersistentDisk_persistent-disk-1

sudo mount -o discard,defaults /dev/disk/by-id/scsi-0Google_PersistentDisk_persistent-disk-1 /mnt/mydisk
EOF_END

# Copy the script to the 'gcelab' instance
gcloud compute scp prepare_disk.sh gcelab:/tmp --project=$DEVSHELL_PROJECT_ID --zone=$ZONE --quiet

# SSH into the instance and execute the disk preparation script
gcloud compute ssh gcelab --project=$DEVSHELL_PROJECT_ID --zone=$ZONE --quiet --command="bash /tmp/prepare_disk.sh"

# Notify that the lab is complete
echo "Lab Completed Successfully."
