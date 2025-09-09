#!/bin/bash

echo "Starting Execution"

# Prompt user for required inputs
read -p "Enter VPC name: " VPC_NAME
read -p "Enter Subnet A name: " SUBNET_A
read -p "Enter Subnet B name: " SUBNET_B
read -p "Enter Firewall Rule 1 name (e.g., allow-ssh): " FWL_1
read -p "Enter Firewall Rule 2 name (e.g., allow-rdp): " FWL_2
read -p "Enter Firewall Rule 3 name (e.g., allow-icmp): " FWL_3
read -p "Enter Zone 1 (e.g., us-central1-a): " ZONE_1
read -p "Enter Zone 2 (e.g., us-east1-b): " ZONE_2

# Derived values
export REGION_1=${ZONE_1%-*}
export REGION_2=${ZONE_2%-*}
export VM_1=us-test-01
export VM_2=us-test-02

# Create VPC
gcloud compute networks create $VPC_NAME \
    --project=$DEVSHELL_PROJECT_ID \
    --subnet-mode=custom \
    --mtu=1460 \
    --bgp-routing-mode=regional

# Create subnets
gcloud compute networks subnets create $SUBNET_A \
    --project=$DEVSHELL_PROJECT_ID \
    --region=$REGION_1 \
    --network=$VPC_NAME \
    --range=10.10.10.0/24 \
    --stack-type=IPV4_ONLY

gcloud compute networks subnets create $SUBNET_B \
    --project=$DEVSHELL_PROJECT_ID \
    --region=$REGION_2 \
    --network=$VPC_NAME \
    --range=10.10.20.0/24 \
    --stack-type=IPV4_ONLY

# Create firewall rules
gcloud compute firewall-rules create $FWL_1 \
    --project=$DEVSHELL_PROJECT_ID \
    --network=$VPC_NAME \
    --direction=INGRESS \
    --priority=1000 \
    --action=ALLOW \
    --rules=tcp:22 \
    --source-ranges=0.0.0.0/0 \
    --target-tags=all

gcloud compute firewall-rules create $FWL_2 \
    --project=$DEVSHELL_PROJECT_ID \
    --network=$VPC_NAME \
    --direction=INGRESS \
    --priority=65535 \
    --action=ALLOW \
    --rules=tcp:3389 \
    --source-ranges=0.0.0.0/24 \
    --target-tags=all

gcloud compute firewall-rules create $FWL_3 \
    --project=$DEVSHELL_PROJECT_ID \
    --network=$VPC_NAME \
    --direction=INGRESS \
    --priority=1000 \
    --action=ALLOW \
    --rules=icmp \
    --source-ranges=0.0.0.0/24 \
    --target-tags=all

# Create VM instances
gcloud compute instances create $VM_1 \
    --project=$DEVSHELL_PROJECT_ID \
    --zone=$ZONE_1 \
    --subnet=$SUBNET_A \
    --tags=allow-icmp

gcloud compute instances create $VM_2 \
    --project=$DEVSHELL_PROJECT_ID \
    --zone=$ZONE_2 \
    --subnet=$SUBNET_B \
    --tags=allow-icmp

sleep 10

# Get external IP of VM_2
export EXTERNAL_IP2=$(gcloud compute instances describe $VM_2 \
    --zone=$ZONE_2 \
    --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

echo "External IP of $VM_2: $EXTERNAL_IP2"

# Ping test from VM_1
gcloud compute ssh $VM_1 \
    --zone=$ZONE_1 \
    --project=$DEVSHELL_PROJECT_ID \
    --quiet \
    --command="ping -c 3 $EXTERNAL_IP2 && ping -c 3 $VM_2.$ZONE_2"

echo "Congratulations For CompletiLab !!!"
