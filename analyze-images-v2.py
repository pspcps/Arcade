import os
import sys
import io
from google.cloud import storage, bigquery, language, vision_v1, translate_v2

# Validate credentials
if 'GOOGLE_APPLICATION_CREDENTIALS' not in os.environ:
    print("GOOGLE_APPLICATION_CREDENTIALS environment variable not set.")
    exit(1)

if not os.path.exists(os.environ['GOOGLE_APPLICATION_CREDENTIALS']):
    print("The service account key file does not exist.")
    exit(1)

# Validate arguments
if len(sys.argv) < 3:
    print("Usage: python3 analyze-images-v2.py [PROJECT_ID] [BUCKET_NAME]")
    exit(1)

project_id = sys.argv[1]
bucket_name = sys.argv[2]

# Initialize clients
storage_client = storage.Client()
bucket = storage_client.bucket(bucket_name)

bq_client = bigquery.Client(project=project_id)
nl_client = language.LanguageServiceClient()
vision_client = vision_v1.ImageAnnotatorClient()
translate_client = translate_v2.Client()

# BigQuery references
dataset_ref = bq_client.dataset('image_classification_dataset')
table_ref = dataset_ref.table('image_text_detail')
table = bq_client.get_table(table_ref)

# Prepare data for BigQuery
rows_for_bq = []

print("Processing image files from GCS...")

for blob in bucket.list_blobs():
    if blob.name.endswith(('.jpg', '.png')):
        content = blob.download_as_bytes()
        image = vision_v1.types.Image(content=content)
        response = vision_client.text_detection(image=image)

        if not response.text_annotations:
            continue

        desc = response.text_annotations[0].description
        locale = response.text_annotations[0].locale or 'und'

        # Save extracted text as .txt in bucket
        txt_blob_name = os.path.splitext(blob.name)[0] + ".txt"
        txt_blob = bucket.blob(txt_blob_name)
        txt_blob.upload_from_string(desc, content_type='text/plain')

        # Translate if not 'ja'
        if locale != 'ja':
            translation = translate_client.translate(desc, target_language='ja')
            translated_text = translation['translatedText']
        else:
            translated_text = desc

        # Append row
        rows_for_bq.append((desc, locale, translated_text, blob.name))
        print(f"Processed: {blob.name}")

# Upload to BigQuery
if rows_for_bq:
    print("Inserting data into BigQuery...")
    errors = bq_client.insert_rows(table, rows_for_bq)
    if errors:
        print("Errors while inserting into BigQuery:", errors)
    else:
        print("Data successfully inserted into BigQuery.")
else:
    print("No image data found to insert.")

print("Image analysis completed.")
