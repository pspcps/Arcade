#!/bin/bash

# Ask user for REGION
read -rp "Enter your region (e.g., us-central1): " REGION

# Set project ID
PROJECT_ID=$DEVSHELL_PROJECT_ID

# Enable Dataflow service
echo "Enabling Dataflow API..."
gcloud services enable dataflow.googleapis.com


# Create Spanner instance
echo "Creating Spanner instance: banking-ops-instance"
gcloud spanner instances create banking-ops-instance \
  --config=regional-$REGION \
  --description="testing" \
  --nodes=1

# Create database
echo "Creating database: banking-ops-db"
gcloud spanner databases create banking-ops-db --instance=banking-ops-instance

# Create tables
echo "Creating tables..."
gcloud spanner databases ddl update banking-ops-db --instance=banking-ops-instance \
  --ddl="CREATE TABLE Portfolio (
    PortfolioId INT64 NOT NULL,
    Name STRING(MAX),
    ShortName STRING(MAX),
    PortfolioInfo STRING(MAX)
  ) PRIMARY KEY (PortfolioId)"

gcloud spanner databases ddl update banking-ops-db --instance=banking-ops-instance \
  --ddl="CREATE TABLE Category (
    CategoryId INT64 NOT NULL,
    PortfolioId INT64 NOT NULL,
    CategoryName STRING(MAX),
    PortfolioInfo STRING(MAX)
  ) PRIMARY KEY (CategoryId)"

gcloud spanner databases ddl update banking-ops-db --instance=banking-ops-instance \
  --ddl="CREATE TABLE Product (
    ProductId INT64 NOT NULL,
    CategoryId INT64 NOT NULL,
    PortfolioId INT64 NOT NULL,
    ProductName STRING(MAX),
    ProductAssetCode STRING(25),
    ProductClass STRING(25)
  ) PRIMARY KEY (ProductId)"

gcloud spanner databases ddl update banking-ops-db --instance=banking-ops-instance \
  --ddl="CREATE TABLE Customer (
    CustomerId STRING(36) NOT NULL,
    Name STRING(MAX) NOT NULL,
    Location STRING(MAX) NOT NULL
  ) PRIMARY KEY (CustomerId)"

# Insert sample data
echo "Inserting sample data into tables..."
gcloud spanner databases execute-sql banking-ops-db --instance=banking-ops-instance --sql='
INSERT INTO Portfolio (PortfolioId, Name, ShortName, PortfolioInfo)
VALUES 
  (1, "Banking", "Bnkg", "All Banking Business"),
  (2, "Asset Growth", "AsstGrwth", "All Asset Focused Products"),
  (3, "Insurance", "Insurance", "All Insurance Focused Products")'

gcloud spanner databases execute-sql banking-ops-db --instance=banking-ops-instance --sql='
INSERT INTO Category (CategoryId, PortfolioId, CategoryName)
VALUES 
  (1, 1, "Cash"),
  (2, 2, "Investments - Short Return"),
  (3, 2, "Annuities"),
  (4, 3, "Life Insurance")'

gcloud spanner databases execute-sql banking-ops-db --instance=banking-ops-instance --sql='
INSERT INTO Product (ProductId, CategoryId, PortfolioId, ProductName, ProductAssetCode, ProductClass)
VALUES 
  (1, 1, 1, "Checking Account", "ChkAcct", "Banking LOB"),
  (2, 2, 2, "Mutual Fund Consumer Goods", "MFundCG", "Investment LOB"),
  (3, 3, 2, "Annuity Early Retirement", "AnnuFixed", "Investment LOB"),
  (4, 4, 3, "Term Life Insurance", "TermLife", "Insurance LOB"),
  (5, 1, 1, "Savings Account", "SavAcct", "Banking LOB"),
  (6, 1, 1, "Personal Loan", "PersLn", "Banking LOB"),
  (7, 1, 1, "Auto Loan", "AutLn", "Banking LOB"),
  (8, 4, 3, "Permanent Life Insurance", "PermLife", "Insurance LOB"),
  (9, 2, 2, "US Savings Bonds", "USSavBond", "Investment LOB")'

# Download sample CSV file
echo "Downloading customer data file..."
curl -LO https://raw.githubusercontent.com/pspcps/Arcade/refs/heads/main/Customer_List_500.csv


# Create import manifest file
echo "Creating manifest.json..."
cat > manifest.json <<EOF
{
  "tables": [
    {
      "table_name": "Customer",
      "file_patterns": [
        "gs://$PROJECT_ID/Customer_List_500.csv"
      ],
      "columns": [
        {"column_name" : "CustomerId", "type_name" : "STRING" },
        {"column_name" : "Name", "type_name" : "STRING" },
        {"column_name" : "Location", "type_name" : "STRING" }
      ]
    }
  ]
}
EOF

# Create GCS bucket and upload files
echo "Preparing Cloud Storage bucket..."
gsutil mb -l $REGION gs://$PROJECT_ID
gsutil cp Customer_List_500.csv manifest.json gs://$PROJECT_ID

# Create staging folder
touch placeholder.txt
gsutil cp placeholder.txt gs://$PROJECT_ID/tmp/placeholder.txt

# Wait before running Dataflow (optional, depends on context)
echo "Waiting for services to initialize..."
sleep 30

# Launch Dataflow job
echo "Starting Dataflow import job..."
gcloud dataflow jobs run customer-import-job \
  --gcs-location gs://dataflow-templates-$REGION/latest/GCS_Text_to_Cloud_Spanner \
  --region="$REGION" \
  --staging-location gs://$PROJECT_ID/tmp/ \
  --parameters instanceId=banking-ops-instance,databaseId=banking-ops-db,importManifest=gs://$PROJECT_ID/manifest.json

# Update schema after import
echo "Updating schema: adding MarketingBudget to Category table..."
gcloud spanner databases ddl update banking-ops-db --instance=banking-ops-instance \
  --ddl='ALTER TABLE Category ADD COLUMN MarketingBudget INT64'

# Done
echo "✅ Lab completed successfully!"
