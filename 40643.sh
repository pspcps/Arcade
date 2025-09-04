#!/bin/bash

# Exit if any command fails
set -e

# Colors for styling output
GREEN='\033[1;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
PURPLE='\033[1;35m'
RED='\033[1;31m'
NC='\033[0m' # No Color

echo -e "${CYAN}🔍 Welcome to BigQuery Search Index Demo Script${NC}"

# Prompt for dataset name (default: products)
read -p "📦 Enter dataset name [default: products]: " DATASET
DATASET=${DATASET:-products}

# Prompt for table name (default: products_information)
read -p "📄 Enter table name [default: products_information]: " TABLE_NAME
TABLE_NAME=${TABLE_NAME:-products_information}

# Prompt for search term (default: 22 oz Water Bottle)
read -p "🔍 Enter search term [default: 22 oz Water Bottle]: " SEARCH_TERM
SEARCH_TERM=${SEARCH_TERM:-22 oz Water Bottle}

# Combine full table reference
TABLE="$DATASET.$TABLE_NAME"

# Get current project ID
PROJECT_ID=$(gcloud config get-value project)
BUCKET_NAME="gs://$PROJECT_ID-bucket"

# Construct full CSV path
CSV_PATH="$BUCKET_NAME/products.csv"

# Check if file exists in GCS
if ! gsutil ls "$CSV_PATH" &>/dev/null; then
  echo -e "${YELLOW}⚠️ File not found at $CSV_PATH. Falling back to dataset.csv...${NC}"
  CSV_PATH="$BUCKET_NAME/$DATASET.csv"
fi

echo -e "${GREEN}✅ Using CSV file: $CSV_PATH${NC}"

# Step 1: Load CSV into BigQuery table
echo -e "${CYAN}📥 Loading CSV into BigQuery table: $TABLE...${NC}"
bq load \
  --source_format=CSV \
  --skip_leading_rows=1 \
  --autodetect \
  "$TABLE" \
  "$CSV_PATH"

# Step 2: Create Search Index
echo -e "${CYAN}🔧 Creating search index on table: $TABLE...${NC}"
bq query --use_legacy_sql=false "
CREATE SEARCH INDEX IF NOT EXISTS product_search_index
ON \`$TABLE\` (ALL COLUMNS);
"

# Step 3: Perform Search
echo -e "${CYAN}📡 Running search query for: \"${SEARCH_TERM}\"...${NC}"
bq query --use_legacy_sql=false "
SELECT * FROM \`$TABLE\`
WHERE SEARCH(*, \"$SEARCH_TERM\");
"

# Final Output
echo -e "\n${PURPLE}🎉 Script completed successfully!${NC}"
echo -e "${GREEN}Thanks for watching!${NC}"
echo -e "${YELLOW}💬 Please comment"
echo -e "👍 Please like"
echo -e "📌 Please subscribe${NC}"
