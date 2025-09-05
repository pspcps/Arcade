#!/bin/bash
set -euo pipefail

PARTNER_PROJECT_ID=$(gcloud config get-value project)
DATASET="demo_dataset"
VIEW_A="authorized_view_a"
VIEW_B="authorized_view_b"

echo "Using Project: $PARTNER_PROJECT_ID"
echo "Creating Authorized Views..."

bq query --use_legacy_sql=false --project_id="$PARTNER_PROJECT_ID" <<EOF
CREATE OR REPLACE VIEW \`${PARTNER_PROJECT_ID}.${DATASET}.${VIEW_A}\` AS
SELECT * FROM \`bigquery-public-data.geo_us_boundaries.zip_codes\` WHERE state_code = 'TX' LIMIT 4000;
EOF
echo " • View A created."

bq query --use_legacy_sql=false --project_id="$PARTNER_PROJECT_ID" <<EOF
CREATE OR REPLACE VIEW \`${PARTNER_PROJECT_ID}.${DATASET}.${VIEW_B}\` AS
SELECT * FROM \`bigquery-public-data.geo_us_boundaries.zip_codes\` WHERE state_code = 'CA' LIMIT 4000;
EOF
echo " • View B created."

