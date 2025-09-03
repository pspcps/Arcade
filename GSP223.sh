
gcloud auth list

gsutil mb -p $GOOGLE_CLOUD_PROJECT \
    -c standard    \
    -l us \
    gs://$GOOGLE_CLOUD_PROJECT-vcm/

export BUCKET=$GOOGLE_CLOUD_PROJECT-vcm

gsutil -m cp -r gs://spls/gsp223/images/* gs://${BUCKET}

gsutil cp gs://spls/gsp223/data.csv .

sed -i -e "s/placeholder/${BUCKET}/g" ./data.csv

gsutil cp ./data.csv gs://${BUCKET}

echo -e "\033[1;33mOpen this link\033[0m \033[1;34mhttps://console.cloud.google.com/vertex-ai/datasets?project=$DEVSHELL_PROJECT_ID\033[0m"
