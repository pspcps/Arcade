#!/bin/bash

# Prompt the user for API Key
read -rp "🔑 Enter your Google Cloud API Key: " API_KEY

# Create Natural Language API request JSON
cat > nl_request.json <<EOF_CP
{
  "document":{
    "type":"PLAIN_TEXT",
    "content":"With approximately 8.2 million people residing in Boston, the capital city of Massachusetts is one of the largest in the United States."
  },
  "encodingType":"UTF8"
}
EOF_CP

# Call Natural Language API - Analyze Entities
echo "🧠 Calling Cloud Natural Language API..."
curl "https://language.googleapis.com/v1/documents:analyzeEntities?key=${API_KEY}" \
  -s -X POST -H "Content-Type: application/json" \
  --data-binary @nl_request.json > nl_response.json

# Create Speech-to-Text API request JSON
cat > speech_request.json <<EOF_CP
{
  "config": {
      "encoding":"FLAC",
      "languageCode": "en-US"
  },
  "audio": {
      "uri":"gs://cloud-samples-tests/speech/brooklyn.flac"
  }
}
EOF_CP

# Call Speech-to-Text API
echo "🎙️ Calling Cloud Speech-to-Text API..."
curl -s -X POST -H "Content-Type: application/json" \
  --data-binary @speech_request.json \
  "https://speech.googleapis.com/v1/speech:recognize?key=${API_KEY}" > speech_response.json

# Create Python file for Sentiment Analysis using client library
cat > sentiment_analysis.py <<EOF_CP
import argparse
from google.cloud import language_v1

def print_result(annotations):
    score = annotations.document_sentiment.score
    magnitude = annotations.document_sentiment.magnitude

    for index, sentence in enumerate(annotations.sentences):
        sentence_sentiment = sentence.sentiment.score
        print(f"Sentence {index} has a sentiment score of {sentence_sentiment}")

    print(f"Overall Sentiment: score of {score} with magnitude of {magnitude}")
    return 0

def analyze(movie_review_filename):
    client = language_v1.LanguageServiceClient()
    with open(movie_review_filename) as review_file:
        content = review_file.read()

    document = language_v1.Document(content=content, type_=language_v1.Document.Type.PLAIN_TEXT)
    annotations = client.analyze_sentiment(request={"document": document})
    print_result(annotations)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("movie_review_filename", help="The file to analyze.")
    args = parser.parse_args()
    analyze(args.movie_review_filename)
EOF_CP

# Download and extract sample review files
echo "📦 Downloading sentiment samples..."
gsutil cp gs://cloud-samples-tests/natural-language/sentiment-samples.tgz .
gunzip sentiment-samples.tgz
tar -xvf sentiment-samples.tar

# Run the Python script
echo "📊 Running sentiment analysis using client library..."
python3 sentiment_analysis.py reviews/bladerunner-pos.txt
