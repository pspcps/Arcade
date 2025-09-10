curl -LO 'https://github.com/tsenart/vegeta/releases/download/v12.12.0/vegeta_12.12.0_linux_386.tar.gz'

tar -xvzf vegeta_12.12.0_linux_386.tar.gz

gcloud logging metrics create CloudFunctionLatency-Logs \
    --project=$DEVSHELL_PROJECT_ID \
    --description="Subscribe to Arcade Helper" \
    --log-filter='resource.type="cloud_run_revision" AND resource.labels.function_name="helloWorld"'