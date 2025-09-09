
echo "Starting Execution"

# Step 1: Set Compute Zone & Region
echo "Setting Compute Zone & Region"
export ZONE=$(gcloud compute project-info describe \
--format="value(commonInstanceMetadata.items[google-compute-default-zone])")

export REGION=$(gcloud compute project-info describe \
--format="value(commonInstanceMetadata.items[google-compute-default-region])")

gcloud config set compute/zone $ZONE

gcloud config set compute/region $REGION

function set_regions {
    while true; do
        echo
        echo -n "Enter your REGION_2: "
        read -r REGION_2

        echo
        echo -n "Enter your REGION_3: "
        read -r REGION_3

        if [[ -z "$REGION_2" || -z "$REGION_3" ]]; then
            echo
            echo "Neither REGION_2 nor REGION_3 can be empty. Please enter valid values."
            echo
        else
            export REGION_2="$REGION_2"
            export ZONE_3="$ZONE_3"
            echo
            echo "REGION_2 set to $REGION_2"
            echo "REGION_3 set to $REGION_3"
            echo
            break
        fi
    done
}

# Call function to get input from user
set_regions

# Step 2: Creating Custom Network
echo "Creating Custom Network"
gcloud compute networks create taw-custom-network --subnet-mode custom

# Step 3: Creating Subnet in Region 1
echo "Creating Subnet in $REGION"
gcloud compute networks subnets create subnet-$REGION \
   --network taw-custom-network \
   --region $REGION \
   --range 10.0.0.0/16

# Step 4: Creating Subnet in Region 2
echo "Creating Subnet in $REGION_2"
gcloud compute networks subnets create subnet-$REGION_2 \
   --network taw-custom-network \
   --region $REGION_2 \
   --range 10.1.0.0/16

# Step 5: Creating Subnet in Region 3
echo "Creating Subnet in $REGION_3"
gcloud compute networks subnets create subnet-$REGION_3 \
   --network taw-custom-network \
   --region $REGION_3 \
   --range 10.2.0.0/16

# Step 6: Listing Subnets
echo "Listing Subnets"
gcloud compute networks subnets list \
   --network taw-custom-network

# Step 7: Creating Firewall Rule for HTTP Traffic
echo "Creating Firewall Rule for HTTP Traffic"
gcloud compute firewall-rules create nw101-allow-http \
--allow tcp:80 --network taw-custom-network --source-ranges 0.0.0.0/0 \
--target-tags http

# Step 8: Creating Firewall Rule for ICMP Traffic
echo "Creating Firewall Rule for ICMP Traffic"
gcloud compute firewall-rules create "nw101-allow-icmp" --allow icmp --network "taw-custom-network" --target-tags rules

# Step 9: Creating Firewall Rule for Internal Traffic
echo "Creating Firewall Rule for Internal Traffic"
gcloud compute firewall-rules create "nw101-allow-internal" --allow tcp:0-65535,udp:0-65535,icmp --network "taw-custom-network" --source-ranges "10.0.0.0/16","10.2.0.0/16","10.1.0.0/16"

# Step 10: Creating Firewall Rule for SSH Traffic
echo "Creating Firewall Rule for SSH Traffic"
gcloud compute firewall-rules create "nw101-allow-ssh" --allow tcp:22 --network "taw-custom-network" --target-tags "ssh"

# Step 11: Creating Firewall Rule for RDP Traffic
echo "Creating Firewall Rule for RDP Traffic"
gcloud compute firewall-rules create "nw101-allow-rdp" --allow tcp:3389 --network "taw-custom-network"

echo
