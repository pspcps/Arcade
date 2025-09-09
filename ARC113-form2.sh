
read -p "Enter your GCP region: " LOCATION
export LOCATION

echo
echo "Step 1:Creating Pub/Sub schema using Avro format..."
echo
gcloud pubsub schemas create city-temp-schema \
        --type=avro \
        --definition='{                                             
            "type" : "record",                               
            "name" : "Avro",                                 
            "fields" : [                                     
            { "name" : "city", "type" : "string" },           
            { "name" : "temperature", "type" : "double" },    
            { "name" : "pressure", "type" : "int" },          
            { "name" : "time_position", "type" : "string" }   
        ]                                                    
    }'

echo
echo "Step 2: Creating Pub/Sub topic with JSON message encoding..."
echo
gcloud pubsub topics create temp-topic \
        --message-encoding=JSON \
        --schema=temperature-schema

echo
echo "Step 3: Enabling necessary Google Cloud services..."
echo
gcloud services enable eventarc.googleapis.com
gcloud services enable run.googleapis.com

echo
echo "Step 4: Generating Node.js Cloud Function file..."
echo
cat > index.js <<'EOF_END'
const functions = require('@google-cloud/functions-framework');

functions.cloudEvent('helloPubSub', cloudEvent => {
  const base64name = cloudEvent.data.message.data;

  const name = base64name
    ? Buffer.from(base64name, 'base64').toString()
    : 'World';

  console.log(`Hello, ${name}!`);
});
EOF_END

echo
echo "Step 5: Creating package.json with dependencies..."
echo
cat > package.json <<'EOF_END'
{
  "name": "gcf_hello_world",
  "version": "1.0.0",
  "main": "index.js",
  "scripts": {
    "start": "node index.js",
    "test": "echo \"Error: no test specified\" && exit 1"
  },
  "dependencies": {
    "@google-cloud/functions-framework": "^3.0.0"
  }
}
EOF_END

echo
echo "Step 6: Deploying the Cloud Function..."
echo

deploy_function() {
gcloud functions deploy gcf-pubsub \
  --gen2 \
  --runtime=nodejs22 \
  --region=$LOCATION \
  --source=. \
  --entry-point=helloPubSub \
  --trigger-topic gcf-topic \
  --quiet
}

deploy_success=false

echo "\Deployment Status: Deploying Cloud Function..."
while [ "$deploy_success" = false ]; do
    if deploy_function; then
        echo "✅ Success: Function deployed successfully!"
        deploy_success=true
    else
        echo "Retrying:  20 seconds..."
        sleep 20
    fi
done

echo