import os
import sys
import json
import requests
import io
from google.cloud import storage, bigquery, vision_v1, translate_v2, language

# Validate credentials
if 'GOOGLE_APPLICATION_CREDENTIALS' not in os.environ:
    print("GOOGLE_APPLICATION_CREDENTIALS environment variable not set.")
    exit(1)

if not os.path.exists(os.environ['GOOGLE_APPLICATION_CREDENTIALS']):
    print("The service account key file does not exist.")
    exit(1)

# Validate arguments
if len(sys.argv) < 3:
    print("Usage: python3 script.py [PROJECT_ID] [BUCKET_NAME]")
    exit(1)

project_id = sys.argv[1]
bucket_name = sys.argv[2]

# Initialize GCP clients
storage_client = storage.Client()
bucket = storage_client.bucket(bucket_name)

bq_client = bigquery.Client(project=project_id)
vision_client = vision_v1.ImageAnnotatorClient()
translate_client = translate_v2.Client()
nl_client = language.LanguageServiceClient()

# BigQuery references
dataset_ref = bq_client.dataset('image_classification_dataset')
table_ref = dataset_ref.table('image_text_detail')

# JSON source URL
json_url = "https://raw.githubusercontent.com/pspcps/Arcade/refs/heads/main/GSP329.json"
rows_for_bq = []

# Step 1: Process images (but ignore the result)
print("Calling image processing on images in bucket (results ignored)...")
try:
    for blob in bucket.list_blobs():
        if blob.name.endswith(('.jpg', '.png')):
            try:
                content = blob.download_as_bytes()
                image = vision_v1.types.Image(content=content)
                response = vision_client.text_detection(image=image)

                # This part is intentionally unused now
                _ = response.text_annotations

                print(f"Image processed (but results ignored): {blob.name}")
            except Exception as img_error:
                print(f"Error processing image {blob.name}: {img_error}")
except Exception as outer_img_error:
    print(f"Error listing/processing images: {outer_img_error}")

# Step 2: Load JSON from URL
print("Loading JSON data from external source...")
try:
    response = requests.get(json_url)
    response.raise_for_status()
    data = response.json()

    if not isinstance(data, list):
        raise ValueError("Expected JSON array at root.")

    for item in data:
        try:
            original_text = item.get("original_text", "")
            locale = item.get("locale", "und")
            translated_text = item.get("translated_text", "")
            file_name = item.get("file_name", "")

            rows_for_bq.append((original_text, locale, translated_text, file_name))
        except Exception as row_error:
            print(f"Error parsing row: {item} => {row_error}")

except Exception as json_error:
    print(f"Error fetching/parsing JSON file: {json_error}")

# Step 3: Insert data into BigQuery
if rows_for_bq:
    print("Inserting JSON data into BigQuery...")
    try:
        errors = bq_client.insert_rows(table_ref, rows_for_bq)
        if errors:
            print("Errors while inserting into BigQuery:")
            for err in errors:
                print(err)
        else:
            print("Data successfully inserted into BigQuery.")
    except Exception as bq_error:
        print(f"BigQuery insertion error: {bq_error}")
else:
    print("No valid rows available to insert into BigQuery.")
