#!/bin/bash

set -e

echo "🔐 Automating BigQuery Authorized Views Setup"

# === Auto-detect Partner Project ID
PARTNER_PROJECT_ID=$(gcloud config get-value project 2>/dev/null)

if [ -z "$PARTNER_PROJECT_ID" ]; then
  echo "❌ No GCP project set. Run: gcloud config set project <your-project-id>"
  exit 1
fi

echo "👉 Using Partner Project: $PARTNER_PROJECT_ID"

# === Ask for Customer Projects
read -p "🔸 Enter Customer A project ID: " CUSTOMER_A_PROJECT_ID
read -p "🔸 Enter Customer B project ID: " CUSTOMER_B_PROJECT_ID

# === Ask for Customer Emails
read -p "✉️  Enter Customer A user email: " CUSTOMER_A_USER_EMAIL
read -p "✉️  Enter Customer B user email: " CUSTOMER_B_USER_EMAIL

# === Hardcoded Config
DATASET="demo_dataset"
VIEW_A="authorized_view_a"
VIEW_B="authorized_view_b"

echo ""
echo "🚀 Creating Authorized Views..."

# View A - TX
bq query --use_legacy_sql=false --project_id="$PARTNER_PROJECT_ID" <<EOF
CREATE OR REPLACE VIEW \`${PARTNER_PROJECT_ID}.${DATASET}.${VIEW_A}\` AS
SELECT * FROM \`bigquery-public-data.geo_us_boundaries.zip_codes\`
WHERE state_code = 'TX'
LIMIT 4000;
EOF

# View B - CA
bq query --use_legacy_sql=false --project_id="$PARTNER_PROJECT_ID" <<EOF
CREATE OR REPLACE VIEW \`${PARTNER_PROJECT_ID}.${DATASET}.${VIEW_B}\` AS
SELECT * FROM \`bigquery-public-data.geo_us_boundaries.zip_codes\`
WHERE state_code = 'CA'
LIMIT 4000;
EOF

echo ""
echo "🔐 Granting BigQuery Data Viewer access to users..."

# Grant Customer A access to view A
bq add-iam-policy-binding "${PARTNER_PROJECT_ID}:${DATASET}.${VIEW_A}" \
  --member="user:${CUSTOMER_A_USER_EMAIL}" \
  --role="roles/bigquery.dataViewer"

# Grant Customer B access to view B
bq add-iam-policy-binding "${PARTNER_PROJECT_ID}:${DATASET}.${VIEW_B}" \
  --member="user:${CUSTOMER_B_USER_EMAIL}" \
  --role="roles/bigquery.dataViewer"

echo ""
echo "🔗 Authorizing views to access dataset..."

# Authorize the views to access the source dataset (if needed, depending on structure)
bq update --source --view "${PARTNER_PROJECT_ID}.${DATASET}.${VIEW_A}" "${PARTNER_PROJECT_ID}:${DATASET}"
bq update --source --view "${PARTNER_PROJECT_ID}.${DATASET}.${VIEW_B}" "${PARTNER_PROJECT_ID}:${DATASET}"

echo ""
echo "✅ Authorized Views setup complete."
echo "   • View A: ${PARTNER_PROJECT_ID}.${DATASET}.${VIEW_A} (TX)"
echo "   • View B: ${PARTNER_PROJECT_ID}.${DATASET}.${VIEW_B} (CA)"
