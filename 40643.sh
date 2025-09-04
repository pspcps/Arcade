#!/bin/bash

# Exit on error
set -e

# Constants
TABLE="products.products_information"
BUCKET_PATH="gs://qwiklabs-gcp-04-2ca0d3863f4c-bucket/products.csv"
SEARCH_TERM="22 oz Water Bottle"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${CYAN}🚀 Loading CSV data into BigQuery table: ${YELLOW}$TABLE${NC}..."
bq load \
  --source_format=CSV \
  --skip_leading_rows=1 \
  --autodetect \
  "$TABLE" \
  "$BUCKET_PATH"

echo -e "${CYAN}🔍 Creating search index on all columns of table: ${YELLOW}$TABLE${NC}..."
bq query --use_legacy_sql=false "
CREATE SEARCH INDEX product_search_index
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
