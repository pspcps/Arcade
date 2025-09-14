echo -n "Enter bucket_name : "
read bucket_name


cat > redact-request.json <<EOF
{
  "item": {
    "value": "Please update my records with the following information:\n Email address: foo@example.com,\nNational Provider Identifier: 1245319599"
  },
  "deidentifyConfig": {
    "infoTypeTransformations": {
      "transformations": [{
        "primitiveTransformation": {
          "replaceWithInfoTypeConfig": {}
        }
      }]
    }
  },
  "inspectConfig": {
    "infoTypes": [{
        "name": "EMAIL_ADDRESS"
      },
      {
        "name": "US_HEALTHCARE_NPI"
      }
    ]
  }
}
EOF


curl -s \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  https://dlp.googleapis.com/v2/projects/$DEVSHELL_PROJECT_ID/content:deidentify \
  -d @redact-request.json -o redact-response.txt

echo
echo "Uploading the de-identified output to your Cloud Storage bucket..."
gsutil cp redact-response.txt gs://$bucket_name


echo
echo
echo
echo " CLICK ON THAT LINK TO OPEN : https://console.cloud.google.com/security/sensitive-data-protection/landing/configuration/templates/deidentify?project=${DEVSHELL_PROJECT_ID}"
echo
echo
echo