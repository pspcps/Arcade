#!/bin/bash

# Ask user for REGION input
read -p "Enter the REGION for Spanner instance (e.g., us-central1): " REGION

echo "Starting Execution..."

# Create first Spanner instance and database
gcloud spanner instances create banking-instance \
  --config=regional-$REGION \
  --description="awesome" \
  --nodes=1

gcloud spanner databases create banking-db --instance=banking-instance

# Create second Spanner instance and database
gcloud spanner instances create banking-instance-2 \
  --config=regional-$REGION \
  --description="awesome" \
  --nodes=2

gcloud spanner databases create banking-db-2 --instance=banking-instance-2

# Create Customer table in first database
gcloud spanner databases ddl update banking-db \
  --instance=banking-instance \
  --ddl="CREATE TABLE Customer (
    CustomerId STRING(36) NOT NULL,
    Name STRING(MAX) NOT NULL,
    Location STRING(MAX) NOT NULL
  ) PRIMARY KEY (CustomerId);"

echo "Congratulations for completing the lab!"
