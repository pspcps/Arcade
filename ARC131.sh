#!/bin/bash

# Prompt for required environment variables if not already set

if [ -z "$API_KEY" ]; then
  read -rp "Enter your Google Cloud API Key: " API_KEY
  export API_KEY
fi

if [ -z "$REQUEST_CP2" ]; then
  read -rp "Enter the path for REQUEST_CP2 JSON file: " REQUEST_CP2
  export REQUEST_CP2
fi

if [ -z "$RESPONSE_CP2" ]; then
  read -rp "Enter the path for RESPONSE_CP2 output file: " RESPONSE_CP2
  export RESPONSE_CP2
fi

if [ -z "$REQUEST_SP_CP3" ]; then
  read -rp "Enter the path for REQUEST_SP_CP3 JSON file: " REQUEST_SP_CP3
  export REQUEST_SP_CP3
fi

if [ -z "$RESPONSE_SP_CP3" ]; then
  read -rp "Enter the path for RESPONSE_SP_CP3 output file: " RESPONSE_SP_CP3
  export RESPONSE_SP_CP3
fi

echo ""
echo "Creating request file for English audio transcription..."

cat > "$REQUEST_CP2" <<EOF
{
  "config": {
    "encoding": "LINEAR16",
    "languageCode": "en-US",
    "audioChannelCount": 2
  },
  "audio": {
    "uri": "gs://spls/arc131/question_en.wav"
  }
}
EOF

echo "Sending transcription request for English audio..."
curl -s -X POST -H "Content-Type: application/json" \
  --data-binary @"$REQUEST_CP2" \
  "https://speech.googleapis.com/v1/speech:recognize?key=$API_KEY" > "$RESPONSE_CP2"

echo "Saved response to: $RESPONSE_CP2"
echo ""

echo "Creating request file for Spanish audio transcription..."

cat > "$REQUEST_SP_CP3" <<EOF
{
  "config": {
    "encoding": "FLAC",
    "languageCode": "es-ES"
  },
  "audio": {
    "uri": "gs://spls/arc131/multi_es.flac"
  }
}
EOF

echo "Sending transcription request for Spanish audio..."
curl -s -X POST -H "Content-Type: application/json" \
  --data-binary @"$REQUEST_SP_CP3" \
  "https://speech.googleapis.com/v1/speech:recognize?key=$API_KEY" > "$RESPONSE_SP_CP3"

echo "Saved response to: $RESPONSE_SP_CP3"
echo ""
