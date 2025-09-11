#!/bin/bash

# Retry mechanism for robustness
retry() {
  local retries=1
  local count=0
  local delay=2
  until "$@"; do
    exit_code=$?
    count=$((count + 1))
    if [ $count -lt $retries ]; then
      echo "Command failed. Attempt $count/$retries. Retrying in $delay seconds..."
      sleep $delay
    else
      echo "Command failed after $retries attempts."
      return $exit_code
    fi
  done
}

echo ""
echo "=== Starting Execution ==="
echo ""

# Step 1: Get the Project ID
echo "Step 1: Getting the current GCP Project ID..."
export PROJECT_ID=$(gcloud config get-value project)
echo "Project ID: $PROJECT_ID"
echo ""

# Step 2: Get the Project Number
echo "Step 2: Fetching the Project Number..."
export PROJECT_NUMBER=$(retry gcloud projects describe "$PROJECT_ID" \
  --format="value(projectNumber)")
echo "Project Number: $PROJECT_NUMBER"
echo ""

# Step 3: Create a Tag Key
echo "Step 3: Creating Tag Key 'sensitivity-level'..."
gcloud resource-manager tags keys create sensitivity-level \
  --parent=projects/$PROJECT_NUMBER \
  --description="Sensitivity level tagged as low, moderate, high, and unknown"
echo ""

# Step 4: Get the Tag Key ID
echo "Step 4: Fetching Tag Key ID..."
TAG_KEY_ID=$(retry gcloud resource-manager tags keys list \
  --parent="projects/$PROJECT_NUMBER" \
  --format="value(NAME)")
echo "Tag Key ID: $TAG_KEY_ID"
echo ""

# Step 5: Create Tag Value 'low'
echo "Step 5: Creating Tag Value 'low'..."
gcloud resource-manager tags values create low \
  --parent=$TAG_KEY_ID \
  --description="Tag value to attach to low-sensitivity data"
echo ""

# Step 6: Create Tag Value 'moderate'
echo "Step 6: Creating Tag Value 'moderate'..."
gcloud resource-manager tags values create moderate \
  --parent=$TAG_KEY_ID \
  --description="Tag value to attach to moderate-sensitivity data"
echo ""

# Step 7: Create Tag Value 'high'
echo "Step 7: Creating Tag Value 'high'..."
gcloud resource-manager tags values create high \
  --parent=$TAG_KEY_ID \
  --description="Tag value to attach to high-sensitivity data"
echo ""

# Step 8: Create Tag Value 'unknown'
echo "Step 8: Creating Tag Value 'unknown'..."
retry gcloud resource-manager tags values create unknown \
  --parent=$TAG_KEY_ID \
  --description="Tag value to attach to resources with an unknown sensitivity level"
echo ""


echo "=== Tag Key and Values Setup Complete ==="
echo ""
