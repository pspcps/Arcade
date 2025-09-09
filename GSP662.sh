#!/bin/bash

# Prompt for the zone
read -p "Enter the zone (e.g., us-central1-a): " ZONE

# Extract region from zone
REGION=$(echo $ZONE | sed 's/-[a-z]$//')

# Get the project ID automatically
PROJECT_ID=$(gcloud config get-value project)

# Name variables
FE_INSTANCE="frontend"
BE_INSTANCE="backend"

FE_TEMPLATE="fancy-fe"
BE_TEMPLATE="fancy-be"

FE_MIG="fancy-fe-mig"
BE_MIG="fancy-be-mig"

FE_HC="fancy-fe-hc"
BE_HC="fancy-be-hc"

FE_LB_HC="fancy-fe-frontend-hc"
BE_ORDERS_LB_HC="fancy-be-orders-hc"
BE_PRODUCTS_LB_HC="fancy-be-products-hc"

FE_BACKEND_SERVICE="fancy-fe-frontend"
BE_ORDERS_SERVICE="fancy-be-orders"
BE_PRODUCTS_SERVICE="fancy-be-products"

URL_MAP="fancy-map"
HTTP_PROXY="fancy-proxy"
FORWARDING_RULE="fancy-http-rule"

BUCKET_NAME="fancy-store-$PROJECT_ID"

echo -e "\n--- [1] Stopping existing instances ---"
gcloud compute instances stop $FE_INSTANCE --zone=$ZONE
gcloud compute instances stop $BE_INSTANCE --zone=$ZONE

echo -e "\n--- [2] Creating instance templates ---"
gcloud compute instance-templates create $FE_TEMPLATE \
    --source-instance-zone=$ZONE \
    --source-instance=$FE_INSTANCE

gcloud compute instance-templates create $BE_TEMPLATE \
    --source-instance-zone=$ZONE \
    --source-instance=$BE_INSTANCE

echo -e "\n--- [3] Deleting backend instance to save space ---"
gcloud compute instances delete $BE_INSTANCE --zone=$ZONE --quiet

echo -e "\n--- [4] Creating managed instance groups ---"
gcloud compute instance-groups managed create $FE_MIG \
    --zone=$ZONE --base-instance-name fancy-fe --size 2 --template=$FE_TEMPLATE

gcloud compute instance-groups managed create $BE_MIG \
    --zone=$ZONE --base-instance-name fancy-be --size 2 --template=$BE_TEMPLATE

echo -e "\n--- [5] Setting named ports ---"
gcloud compute instance-groups set-named-ports $FE_MIG --zone=$ZONE --named-ports frontend:8080
gcloud compute instance-groups set-named-ports $BE_MIG --zone=$ZONE --named-ports orders:8081,products:8082

echo -e "\n--- [6] Creating health checks for autohealing ---"
gcloud compute health-checks create http $FE_HC \
    --port 8080 --check-interval 30s --healthy-threshold 1 --timeout 10s --unhealthy-threshold 3

gcloud compute health-checks create http $BE_HC \
    --port 8081 --request-path=/api/orders --check-interval 30s --healthy-threshold 1 --timeout 10s --unhealthy-threshold 3

echo -e "\n--- [7] Creating firewall rule for health checks ---"
gcloud compute firewall-rules create allow-health-check \
    --allow tcp:8080-8081 \
    --source-ranges 130.211.0.0/22,35.191.0.0/16 \
    --network default

echo -e "\n--- [8] Applying health checks to MIGs ---"
gcloud compute instance-groups managed update $FE_MIG --zone=$ZONE --health-check $FE_HC --initial-delay 300
gcloud compute instance-groups managed update $BE_MIG --zone=$ZONE --health-check $BE_HC --initial-delay 300

echo -e "\n--- [9] Creating load balancer health checks ---"
gcloud compute http-health-checks create $FE_LB_HC --request-path / --port 8080
gcloud compute http-health-checks create $BE_ORDERS_LB_HC --request-path /api/orders --port 8081
gcloud compute http-health-checks create $BE_PRODUCTS_LB_HC --request-path /api/products --port 8082

echo -e "\n--- [10] Creating backend services ---"
gcloud compute backend-services create $FE_BACKEND_SERVICE --http-health-checks $FE_LB_HC --port-name frontend --global
gcloud compute backend-services create $BE_ORDERS_SERVICE --http-health-checks $BE_ORDERS_LB_HC --port-name orders --global
gcloud compute backend-services create $BE_PRODUCTS_SERVICE --http-health-checks $BE_PRODUCTS_LB_HC --port-name products --global

echo -e "\n--- [11] Adding backends to backend services ---"
gcloud compute backend-services add-backend $FE_BACKEND_SERVICE \
    --instance-group=$FE_MIG --instance-group-zone=$ZONE --global

gcloud compute backend-services add-backend $BE_ORDERS_SERVICE \
    --instance-group=$BE_MIG --instance-group-zone=$ZONE --global

gcloud compute backend-services add-backend $BE_PRODUCTS_SERVICE \
    --instance-group=$BE_MIG --instance-group-zone=$ZONE --global

echo -e "\n--- [12] Creating URL map and path matchers ---"
gcloud compute url-maps create $URL_MAP --default-service=$FE_BACKEND_SERVICE

gcloud compute url-maps add-path-matcher $URL_MAP \
    --default-service=$FE_BACKEND_SERVICE \
    --path-matcher-name orders \
    --path-rules "/api/orders=$BE_ORDERS_SERVICE,/api/products=$BE_PRODUCTS_SERVICE"

echo -e "\n--- [13] Creating target proxy and forwarding rule ---"
gcloud compute target-http-proxies create $HTTP_PROXY --url-map=$URL_MAP

gcloud compute forwarding-rules create $FORWARDING_RULE \
    --global \
    --target-http-proxy=$HTTP_PROXY \
    --ports=80

echo -e "\n--- [14] Updating .env file in frontend ---"
cd ~/monolith-to-microservices/react-app
LB_IP=$(gcloud compute forwarding-rules list --global --filter="name=$FORWARDING_RULE" --format="value(IP_ADDRESS")")

sed -i "s|REACT_APP_ORDERS_URL=.*|REACT_APP_ORDERS_URL=http://$LB_IP/api/orders|" .env
sed -i "s|REACT_APP_PRODUCTS_URL=.*|REACT_APP_PRODUCTS_URL=http://$LB_IP/api/products|" .env

echo -e "\n--- [15] Rebuilding frontend ---"
npm install && npm run-script build

echo -e "\n--- [16] Copying app to bucket ---"
cd ~
rm -rf monolith-to-microservices/*/node_modules
gsutil -m cp -r monolith-to-microservices gs://$BUCKET_NAME/

echo -e "\n--- [17] Rolling replace to update frontend instances ---"
gcloud compute instance-groups managed rolling-action replace $FE_MIG \
    --zone=$ZONE --max-unavailable 100%

echo -e "\n--- [18] Setting up autoscaling ---"
gcloud compute instance-groups managed set-autoscaling $FE_MIG --zone=$ZONE --max-num-replicas 2 --target-load-balancing-utilization 0.60
gcloud compute instance-groups managed set-autoscaling $BE_MIG --zone=$ZONE --max-num-replicas 2 --target-load-balancing-utilization 0.60

echo -e "\n--- [19] Enabling CDN ---"
gcloud compute backend-services update $FE_BACKEND_SERVICE --enable-cdn --global

echo -e "\n✅ Deployment completed. Access the app at: http://$LB_IP"
