#!/bin/bash

set -e

# === Get partner project ID from gcloud config
PARTNER_PROJECT_ID=$(gcloud config get-value project)

echo "Using Partner Project: $PARTNER_PROJECT_ID"

# === Prompt for customer project IDs
read -p "Enter Customer A project ID: " CUSTOMER_A_PROJECT_ID
read -p "Enter Customer B project ID: " CUSTOMER_B_PROJECT_ID

# === Auto-fetch current gcloud user (Customer A)
CUSTOMER_A_USER_EMAIL=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
echo "Detected Customer A user: $CUSTOMER_A_USER_EMAIL"

# === Prompt for Customer B user email
read -p "Enter Customer B user email: " CUSTOMER_B_USER_EMAIL

# === Hardcoded values
DATASET="demo_dataset"
VIEW_A="authorized_view_a"
VIEW_B="authorized_view_b"

# === Create authorized view for Customer A (TX)
echo "Creating view for Customer A (TX)..."
bq query --use_legacy_sql=false --project_id="$PARTNER_PROJECT_ID" <<EOF
CREATE OR REPLACE VIEW \`${PARTNER_PROJECT_ID}.${DATASET}.${VIEW_A}\` AS
SELECT * FROM \`bigquery-public-data.geo_us_boundaries.zip_codes\`
WHERE state_code = 'TX'
LIMIT 4000;
EOF

# === Create authorized view for Customer B (CA)
echo "Creating view for Customer B (CA)..."
bq query --use_legacy_sql=false --project_id="$PARTNER_PROJECT_ID" <<EOF
CREATE OR REPLACE VIEW \`${PARTNER_PROJECT_ID}.${DATASET}.${VIEW_B}\` AS
SELECT * FROM \`bigquery-public-data.geo_us_boundaries.zip_codes\`
WHERE state_code = 'CA'
LIMIT 4000;
EOF

# === Grant access to Customer A user for View A
echo "Granting Customer A user access to view A..."
bq add-iam-policy-binding "${PARTNER_PROJECT_ID}:${DATASET}.${VIEW_A}" \
  --member="user:${CUSTOMER_A_USER_EMAIL}" \
  --role="roles/bigquery.dataViewer"

# === Grant access to Customer B user for View B
echo "Granting Customer B user access to view B..."
bq add-iam-policy-binding "${PARTNER_PROJECT_ID}:${DATASET}.${VIEW_B}" \
  --member="user:${CUSTOMER_B_USER_EMAIL}" \
  --role="roles/bigquery.dataViewer"

# === Authorize the views to access source dataset
echo "Authorizing views to access dataset..."
bq update --source \
  --view "${PARTNER_PROJECT_ID}.${DATASET}.${VIEW_A}" \
  "${PARTNER_PROJECT_ID}:${DATASET}"

bq update --source \
  --view "${PARTNER_PROJECT_ID}.${DATASET}.${VIEW_B}" \
  "${PARTNER_PROJECT_ID}:${DATASET}"

echo "✅ Authorized views created and shared successfully."
