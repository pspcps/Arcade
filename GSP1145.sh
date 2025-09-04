#!/bin/bash

# ----------------------------
# 🎨 Color Functions
# ----------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[1;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

function echo_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

function echo_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

function echo_warn() {
  echo -e "${YELLOW}[WAITING]${NC} $1"
}

function echo_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# ----------------------------
# 🛠️ Setup
# ----------------------------
read -p "Enter the region (e.g., us-east4): " REGION

PROJECT_ID=$(gcloud config get-value project)
if [[ -z "$PROJECT_ID" ]]; then
  echo_error "Failed to get GCP project ID. Is gcloud authenticated?"
  exit 1
fi

# Variables
LAKE_NAME="orders-lake"
LAKE_DISPLAY_NAME="Orders Lake"
ZONE_NAME="customer-curated-zone"
ZONE_DISPLAY_NAME="Customer Curated Zone"
ASSET_NAME="customer-details-dataset"
ASSET_DISPLAY_NAME="Customer Details Dataset"
BQ_DATASET="${PROJECT_ID}.customers"
ASPECT_TYPE_ID="protected-data-aspect"
ASPECT_TYPE_DISPLAY_NAME="Protected Data Aspect"
ASPECT_JSON_FILE="aspect_type.json"

echo_info "Using project: $PROJECT_ID"
echo_info "Using region: $REGION"

# ----------------------------
# 1️⃣ Create Lake
# ----------------------------
echo_info "Creating Dataplex lake..."
gcloud dataplex lakes create $LAKE_NAME \
  --location=$REGION \
  --project=$PROJECT_ID \
  --display-name="$LAKE_DISPLAY_NAME"

# Wait until lake is ACTIVE
echo_warn "Waiting for lake to become ACTIVE..."
ATTEMPTS=0
MAX_ATTEMPTS=20

while true; do
  LAKE_STATE=$(gcloud dataplex lakes describe $LAKE_NAME \
    --location=$REGION \
    --project=$PROJECT_ID \
    --format='value(state)' 2>/dev/null)

  if [[ "$LAKE_STATE" == "ACTIVE" ]]; then
    echo_success "Lake is now ACTIVE."
    break
  fi

  ((ATTEMPTS++))
  if [[ $ATTEMPTS -ge $MAX_ATTEMPTS ]]; then
    echo_error "Lake did not become ACTIVE in time."
    exit 1
  fi

  echo_warn "Lake state: $LAKE_STATE. Retrying in 30 seconds..."
  sleep 30
done

# ----------------------------
# 2️⃣ Create Zone
# ----------------------------
echo_info "Creating curated zone..."
gcloud dataplex zones create $ZONE_NAME \
  --lake=$LAKE_NAME \
  --location=$REGION \
  --project=$PROJECT_ID \
  --display-name="$ZONE_DISPLAY_NAME" \
  --type=CURATED \
  --resource-location-type=SINGLE_REGION

# Wait until zone is ACTIVE
echo_warn "Waiting for zone to become ACTIVE..."
ATTEMPTS=0

while true; do
  ZONE_STATE=$(gcloud dataplex zones describe $ZONE_NAME \
    --lake=$LAKE_NAME \
    --location=$REGION \
    --project=$PROJECT_ID \
    --format='value(state)' 2>/dev/null)

  if [[ "$ZONE_STATE" == "ACTIVE" ]]; then
    echo_success "Zone is now ACTIVE."
    break
  fi

  ((ATTEMPTS++))
  if [[ $ATTEMPTS -ge $MAX_ATTEMPTS ]]; then
    echo_error "Zone did not become ACTIVE in time."
    exit 1
  fi

  echo_warn "Zone state: $ZONE_STATE. Retrying in 30 seconds..."
  sleep 30
done

# ----------------------------
# 3️⃣ Attach BigQuery Dataset as Asset
# ----------------------------
echo_info "Attaching BigQuery dataset as an asset..."
gcloud dataplex assets create $ASSET_NAME \
  --project=$PROJECT_ID \
  --location=$REGION \
  --lake=$LAKE_NAME \
  --zone=$ZONE_NAME \
  --display-name="$ASSET_DISPLAY_NAME" \
  --resource-type=BIGQUERY_DATASET \
  --resource-name=projects/$PROJECT_ID/datasets/customers \
  --discovery-enabled

echo_success "Asset successfully attached."

# ----------------------------
# 4️⃣ Create Aspect Type JSON
# ----------------------------
echo_info "Generating aspect type JSON file..."

cat > $ASPECT_JSON_FILE <<EOF
{
  "displayName": "$ASPECT_TYPE_DISPLAY_NAME",
  "description": "Flags columns with protected data status",
  "template": {
    "fields": [
      {
        "fieldId": "protected_data_flag",
        "displayName": "Protected Data Flag",
        "description": "Indicates if this column contains protected data",
        "dataType": {
          "type": "ENUM",
          "enumValues": ["Yes", "No"]
        },
        "isRequired": true
      }
    ]
  },
  "publicAsset": true
}
EOF

echo_success "Aspect type JSON created: $ASPECT_JSON_FILE"

# ----------------------------
# 5️⃣ Import Aspect Type
# ----------------------------
echo_info "Creating aspect type in Dataplex..."
gcloud dataplex aspect-types import $ASPECT_TYPE_ID \
  --project=$PROJECT_ID \
  --location=$REGION \
  --file=$ASPECT_JSON_FILE

echo_success "Aspect type '$ASPECT_TYPE_ID' created successfully."

# ----------------------------
# ✅ Done
# ----------------------------
echo_success "Script completed successfully!"
echo_info "👉 Proceed to Dataplex Universal Catalog UI to apply aspects to assets or columns."
