#!/bin/bash

# Prompt user to enter all required values

echo "Please enter the following values correctly:"


read -p "Enter your Google Cloud API Key: " API_KEY
export API_KEY

read -p "Enter filename for Text-to-Speech output (e.g., synthesize-text.txt): " text_to_speech_output_file

read -p "Enter filename for Speech-to-Text request file (e.g., speech-request.json): " speech_to_text_request_file
read -p "Enter filename for Speech-to-Text response file (e.g., speech-response.json): " speech_to_text_response_file

read -p "Enter sentence to translate (e.g., こんにちは): " translation_input_sentence
read -p "Enter filename for translation output file (e.g., translated-text.json): " translation_output_file

read -p "Enter sentence for language detection: " language_detect_input_sentence
read -p "Enter filename for language detection output file (e.g., detect-language.json): " language_detect_output_file

export PROJECT_ID=$(gcloud config get-value project) 


source venv/bin/activate

cat > synthesize-text.json <<EOF
{
    'input': {
        'text': 'Cloud Text-to-Speech API allows developers to include
           natural-sounding, synthetic human speech as playable audio in
           their applications. The Text-to-Speech API converts text or
           Speech Synthesis Markup Language (SSML) input into audio data
           like MP3 or LINEAR16 (the encoding used in WAV files).'
    },
    'voice': {
        'languageCode': 'en-gb',
        'name': 'en-GB-Standard-A',
        'ssmlGender': 'FEMALE'
    },
    'audioConfig': {
        'audioEncoding': 'MP3'
    }
}
EOF

curl -H "Authorization: Bearer "$(gcloud auth application-default print-access-token) \
  -H "Content-Type: application/json; charset=utf-8" \
  -d @synthesize-text.json "https://texttospeech.googleapis.com/v1/text:synthesize" \
  > $text_to_speech_output_file

cat > tts_decode.py <<EOF
import argparse
from base64 import decodebytes
import json
"""
Usage:
        python tts_decode.py --input "synthesize-text.txt" \
        --output "synthesize-text-audio.mp3"
"""
def decode_tts_output(input_file, output_file):
    with open(input_file) as input:
        response = json.load(input)
        audio_data = response['audioContent']
        with open(output_file, "wb") as new_file:
            new_file.write(decodebytes(audio_data.encode('utf-8')))
if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description="Decode output from Cloud Text-to-Speech",
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--input',
                       help='The response from the Text-to-Speech API.',
                       required=True)
    parser.add_argument('--output',
                       help='The name of the audio file to create',
                       required=True)
    args = parser.parse_args()
    decode_tts_output(args.input, args.output)
EOF

python tts_decode.py --input "$text_to_speech_output_file" --output "synthesize-text-audio.mp3"

audio_uri="gs://cloud-samples-data/speech/corbeau_renard.flac"

cat > "$speech_to_text_request_file" <<EOF
{
  "config": {
    "encoding": "FLAC",
    "sampleRateHertz": 44100,
    "languageCode": "fr-FR"
  },
  "audio": {
    "uri": "$audio_uri"
  }
}
EOF

curl -s -X POST -H "Content-Type: application/json" \
    --data-binary @"$speech_to_text_request_file" \
    "https://speech.googleapis.com/v1/speech:recognize?key=${API_KEY}" \
    -o "$speech_to_text_response_file"

sudo apt-get update
sudo apt-get install -y jq

curl "https://translation.googleapis.com/language/translate/v2?target=en&key=${API_KEY}&q=${translation_input_sentence}" > $translation_output_file

response=$(curl -s -X POST \
-H "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
-H "Content-Type: application/json; charset=utf-8" \
-d "{\"q\": \"$translation_input_sentence\"}" \
"https://translation.googleapis.com/language/translate/v2?key=${API_KEY}&source=ja&target=en")
echo "$response" > "$translation_output_file"

decoded_sentence=$(python -c "import urllib.parse; print(urllib.parse.unquote('$language_detect_input_sentence'))")

curl -s -X POST \
  -H "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
  -H "Content-Type: application/json; charset=utf-8" \
  -d "{\"q\": [\"$decoded_sentence\"]}" \
  "https://translation.googleapis.com/language/translate/v2/detect?key=${API_KEY}" \
  -o "$language_detect_output_file"