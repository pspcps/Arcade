#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get active project ID
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [[ -z "$PROJECT_ID" ]]; then
  echo -e "${RED}❌ GCP Project ID not found. Please configure it with 'gcloud init'.${NC}"
  exit 1
fi

# Prompt user for dataset (default: products)
read -p "📦 Enter BigQuery Dataset Name [default: products]: " DATASET
DATASET=${DATASET:-products}

# Prompt user for table name (default: products_information)
read -p "📄 Enter Table Name [default: products_information]: " TABLE_NAME
TABLE_NAME=${TABLE_NAME:-products_information}

# Full BigQuery table reference
TABLE="$DATASET.$TABLE_NAME"

# Try to locate CSV file in GCS bucket automatically
BUCKET_PATH="gs://${PROJECT_ID}-bucket"
PRIMARY_CSV="$BUCKET_PATH/products.csv"
FALLBACK_CSV="$BUCKET_PATH/${DATASET}.csv"

echo -e "${CYAN}🔍 Looking for CSV file in GCS bucket: ${YELLOW}$BUCKET_PATH${NC}"

if gsutil ls "$PRIMARY_CSV" &>/dev/null; then
  CSV_PATH="$PRIMARY_CSV"
  echo -e "${GREEN}✅ Found: $CSV_PATH${NC}"
elif gsutil ls "$FALLBACK_CSV" &>/dev/null; then
  CSV_PATH="$FALLBACK_CSV"
  echo -e "${GREEN}✅ Found: $CSV_PATH${NC}"
else
  echo -e "${RED}❌ No CSV file found at $PRIMARY_CSV or $FALLBACK_CSV${NC}"
  exit 1
fi

# Set default search term
SEARCH_TERM="22 oz Water Bottle"

echo -e "${CYAN}🚀 Loading CSV data into BigQuery table: ${YELLOW}$TABLE${NC}..."
bq load \
  --source_format=CSV \
  --skip_leading_rows=1 \
  --autodetect \
  "$TABLE" \
  "$CSV_PATH"

echo -e "${CYAN}🔍 Creating search index on all columns of table: ${YELLOW}$TABLE${NC}..."
bq query --use_legacy_sql=false "
CREATE SEARCH INDEX IF NOT EXISTS product_search_index
ON $TABLE (ALL COLUMNS);
"

echo -e "${CYAN}📦 Running search query for: ${YELLOW}\"$SEARCH_TERM\"${NC}..."
bq query --use_legacy_sql=false "
SELECT * FROM $TABLE
WHERE SEARCH($TABLE, \"$SEARCH_TERM\");
"

echo -e "${GREEN}✅ Script completed successfully.${NC}"
sleep 1

# 🎉 YouTube-style outro
echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}🎉 ${GREEN}Thanks for watching!${NC}"
echo -e "${RED}❤️ Please Like"
echo -e "💬 Please Comment"
echo -e "📢 Please Subscribe${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
