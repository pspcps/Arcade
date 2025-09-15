

gcloud auth list

export ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])")

export REGION=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-region])")

export PROJECT_ID=$(gcloud config get-value project)
export PROJECT_NUMBER=$(gcloud projects describe "${PROJECT_ID}" --format="value(projectNumber)")

cat > deidentify-template.json <<EOF_CP
{
  "deidentifyTemplate": {
    "deidentifyConfig": {
      "recordTransformations": {
        "fieldTransformations": [
          {
            "fields": [
              { "name": "ssn" },
              { "name": "email" }
            ],
            "primitiveTransformation": {
              "replaceConfig": {
                "newValue": { "stringValue": "[redacted]" }
              }
            }
          },
          {
            "fields": [{ "name": "message" }],
            "infoTypeTransformations": {
              "transformations": [
                {
                  "primitiveTransformation": {
                    "replaceWithInfoTypeConfig": {}
                  }
                }
              ]
            }
          }
        ]
      }
    },
    "displayName": "De-identify Credit Card Numbers"
  },
  "locationId": "global",
  "templateId": "us_ccn_deidentify"
}
EOF_CP

sleep 10

curl -X POST -s \
-H "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
-H "Content-Type: application/json" \
-d @deidentify-template.json \
"https://dlp.googleapis.com/v2/projects/$DEVSHELL_PROJECT_ID/locations/global/deidentifyTemplates"


export TEMPLATE_ID=$(curl -s \
--request GET \
--url "https://dlp.googleapis.com/v2/projects/$DEVSHELL_PROJECT_ID/locations/global/deidentifyTemplates/us_ccn_deidentify" \
--header "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
--header "Content-Type: application/json" \
| jq -r '.name')



cat > job-configuration.json << EOM
{
  "jobId": "us_ccn_deidentify",
  "inspectJob": {
    "actions": [
      {
        "deidentify": {
          "fileTypesToTransform": ["TEXT_FILE", "IMAGE", "CSV", "TSV"],
          "transformationDetailsStorageConfig": {
            "table": {
              "projectId": "$DEVSHELL_PROJECT_ID",
              "datasetId": "cs_transformations",
              "tableId": "deidentify_ccn"
            }
          },
          "transformationConfig": {
            "structuredDeidentifyTemplate": "$TEMPLATE_ID"
          },
          "cloudStorageOutput": "gs://$DEVSHELL_PROJECT_ID-car-owners-transformed"
        }
      }
    ],
    "inspectConfig": {
      "infoTypes": [
        { "name": "ADVERTISING_ID" },
        { "name": "AGE" },
        { "name": "CREDIT_CARD_NUMBER" },
        { "name": "EMAIL_ADDRESS" },
        { "name": "PERSON_NAME" },
        { "name": "US_SOCIAL_SECURITY_NUMBER" }
      ],
      "minLikelihood": "POSSIBLE"
    },
    "storageConfig": {
      "cloudStorageOptions": {
        "filesLimitPercent": 100,
        "fileTypes": ["TEXT_FILE", "IMAGE", "CSV", "TSV"],
        "fileSet": {
          "url": "gs://$DEVSHELL_PROJECT_ID-car-owners/**"
        }
      }
    }
  }
}
EOM

sleep 15


curl -s \
  -X POST \
  -H "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
  -H "Content-Type: application/json" \
  "https://dlp.googleapis.com/v2/projects/$DEVSHELL_PROJECT_ID/dlpJobs" \
  -d @job-configuration.json

gcloud resource-manager tags keys create SPII \
    --parent=projects/$PROJECT_NUMBER \
    --description="Flag for sensitive personally identifiable information (SPII)"


TAG_KEY_ID=$(gcloud resource-manager tags keys list --parent="projects/${PROJECT_NUMBER}" --format="value(NAME)")


gcloud resource-manager tags values create Yes \
    --parent=$TAG_KEY_ID \
    --description="Contains sensitive personally identifiable information (SPII)"

gcloud resource-manager tags values create No \
    --parent=$TAG_KEY_ID \
    --description="Does not contain sensitive personally identifiable information (SPII)"


echo""

echo -e "\033[1;33mOpen IAM settings\033[0m \033[1;34mhttps://console.cloud.google.com/iam-admin/iam?referrer=search&invt=AbuhmQ&project=$DEVSHELL_PROJECT_ID\033[0m"

echo""

echo -e "\033[1;33mOpen BigQuery Studio\033[0m \033[1;34mhttps://console.cloud.google.com/bigquery?invt=AbuhmQ&project=$DEVSHELL_PROJECT_ID\033[0m"

echo""

echo -e "\033[1;33mOpen Vertex AI Workbench\033[0m \033[1;34mhttps://console.cloud.google.com/vertex-ai/workbench/instances?invt=AbuhmQ&project=$DEVSHELL_PROJECT_ID\033[0m"

echo""
