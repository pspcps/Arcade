LAB_MODEL="gemini-2.0-flash-001"

echo "Enter REGION:"
read -r REGION
echo

echo "Region set to: $REGION"

export REGION
ID="$(gcloud projects list --format='value(PROJECT_ID')"
echo
echo "Project ID: $ID"
echo
echo "Using Model: $LAB_MODEL"
echo
echo "Generating SendChatwithoutStream.py..."

cat > SendChatwithoutStream.py <<EOF
from google import genai
from google.genai.types import HttpOptions, ModelContent, Part, UserContent

import logging
from google.cloud import logging as gcp_logging

# Initialize GCP logging
gcp_logging_client = gcp_logging.Client()
gcp_logging_client.setup_logging()

client = genai.Client(
    vertexai=True,
    project='${ID}',
    location='${REGION}',
    http_options=HttpOptions(api_version="v1")
)
chat = client.chats.create(
    model="${LAB_MODEL}",
    history=[
        UserContent(parts=[Part(text="Hello")]),
        ModelContent(
            parts=[Part(text="Great to meet you. What would you like to know?")],
        ),
    ],
)
response = chat.send_message("What are all the colors in a rainbow?")
logging.info(f'Received response 1: {response.text}')
print(response.text)

response = chat.send_message("Why does it appear when it rains?")
logging.info(f'Received response 2: {response.text}')
print(response.text)
EOF

echo "Executing SendChatwithoutStream.py..."
/usr/bin/python3 /home/student/SendChatwithoutStream.py
sleep 5

echo
echo "Generating SendChatwithStream.py..."

cat > SendChatwithStream.py <<EOF
from google import genai
from google.genai.types import HttpOptions

import logging
from google.cloud import logging as gcp_logging

# Initialize GCP logging
gcp_logging_client = gcp_logging.Client()
gcp_logging_client.setup_logging()

client = genai.Client(
    vertexai=True,
    project='${ID}',
    location='${REGION}',
    http_options=HttpOptions(api_version="v1")
)
chat = client.chats.create(model="${LAB_MODEL}")
response_text = ""

logging.info("Sending streaming prompt...")
print("Streaming response:")
for chunk in chat.send_message_stream("What are all the colors in a rainbow?"):
    print(chunk.text, end="")
    response_text += chunk.text
print()
logging.info(f"Received full streaming response: {response_text}")
EOF

echo "Executing SendChatwithStream.py..."
/usr/bin/python3 /home/student/SendChatwithStream.py
sleep 5
