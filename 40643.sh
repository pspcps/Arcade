#!/bin/bash

# Exit on error
set -e

# Colors
GREEN='\033[1;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
PURPLE='\033[1;35m'
NC='\033[0m' # No Color

echo -e "${CYAN}🔧 Starting BigQuery Load + Search Index Script...${NC}"

# Prompt for dataset and table name
read -p "📦 Enter BigQuery dataset name [default: products]: " DATASET
DATASET=${DATASET:-products}

read -p "📄 Enter BigQuery table name [default: products_information]: " TABLE
TABLE=${TABLE:-products_information}

# Build full table ref
BQ_TABLE="$DATASET.$TABLE"
BQ_TABLE_BACKTICK="\`$BQ_TABLE\`"

# Get current GCP project ID
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [ -z "$PROJECT_ID" ]; then
  echo -e "${RED}❌ Failed to get GCP project ID. Make sure you're authenticated with gcloud.${NC}"
  exit 1
fi

echo -e "${GREEN}✅ Project ID: $PROJECT_ID${NC}"

# Construct GCS path
GCS_URI="gs://${PROJECT_ID}-bucket/products.csv"

# Check if file exists, fallback to dataset.csv
if ! gsutil ls "$GCS_URI" &>/dev/null; then
  echo -e "${YELLOW}⚠️ File not found: $GCS_URI. Trying fallback: $DATASET.csv${NC}"
  GCS_URI="gs://${PROJECT_ID}-bucket/${DATASET}.csv"
fi

echo -e "${GREEN}📂 Using CSV from: $GCS_URI${NC}"

# Step 1: Load CSV into BigQuery
echo -e "${CYAN}📥 Loading data into BigQuery table: $BQ_TABLE...${NC}"
bq load \
  --source_format=CSV \
  --skip_leading_rows=1 \
  --autodetect \
  "$BQ_TABLE" \
  "$GCS_URI"

# Step 2: Create search index
echo -e "${CYAN}🔍 Creating search index on: $BQ_TABLE...${NC}"
bq query --use_legacy_sql=false "
CREATE SEARCH INDEX IF NOT EXISTS product_search_index
ON $BQ_TABLE_BACKTICK (ALL COLUMNS);
"

# Step 3: Perform search
SEARCH_TERM="22 oz Water Bottle"
echo -e "${CYAN}🔎 Searching for: \"$SEARCH_TERM\"...${NC}"
bq query --use_legacy_sql=false "
SELECT * FROM $BQ_TABLE_BACKTICK
WHERE SEARCH($TABLE, \"$SEARCH_TERM\");
"

# Done!
echo -e "\n${PURPLE}🎉 Script completed successfully!${NC}"
echo -e "${GREEN}Thanks for watching!${NC}"
echo -e "${YELLOW}💬 Please comment"
echo -e "👍 Please like"
echo -e "📌 Please subscribe${NC}"
