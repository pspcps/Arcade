#!/bin/bash

set -e

# ----------------- CONFIGURATION -----------------

echo "🔍 Fetching project ID..."
PROJECT_ID=$(gcloud config get-value project)
if [[ -z "$PROJECT_ID" ]]; then
  echo "❌ GCP project is not set. Use 'gcloud config set project PROJECT_ID'"
  exit 1
fi

BUCKET_NAME="fancy-store-${PROJECT_ID}"
SCRIPT_NAME="startup-script.sh"

# Ask zone if not set, then derive region
ZONE=$(gcloud config get-value compute/zone 2>/dev/null)
if [[ -z "$ZONE" ]]; then
  read -p "Enter desired compute zone (e.g., europe-west4-c): " ZONE
  gcloud config set compute/zone "$ZONE"
fi
REGION="${ZONE%-*}"

# ----------------- ENABLE APIs -----------------

echo "✅ Enabling required services..."
gcloud services enable compute.googleapis.com
gcloud services enable cloudaicompanion.googleapis.com

# ----------------- CREATE BUCKET -----------------

echo "🪣 Checking/Creating GCS bucket: gs://${BUCKET_NAME}"
if gsutil ls -b "gs://${BUCKET_NAME}" &>/dev/null; then
  echo "✔️ Bucket already exists."
else
  gsutil mb "gs://${BUCKET_NAME}"
fi

# ----------------- CLONE SOURCE -----------------

echo "📁 Cloning repo if not already cloned..."
if [[ ! -d "monolith-to-microservices" ]]; then
  git clone https://github.com/googlecodelabs/monolith-to-microservices.git
fi
cd monolith-to-microservices

echo "⚙️ Running setup.sh (this may take a few minutes)..."
chmod +x setup.sh
./setup.sh

# ----------------- NODE ENV -----------------
# Try loading NVM
if [ -s "$HOME/.nvm/nvm.sh" ]; then
    source "$HOME/.nvm/nvm.sh"
elif [ -s "/usr/share/nvm/init-nvm.sh" ]; then
    source "/usr/share/nvm/init-nvm.sh"
else
    echo "NVM not found. Installing NVM..."
    # Install NVM
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

    # Load NVM after installation
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
fi

# Check if nvm command is available
if ! command -v nvm &> /dev/null; then
    echo "Error: NVM installation failed or not available in PATH."
    exit 1
fi

nvm install --lts

# ----------------- STARTUP SCRIPT -----------------

STARTUP_SCRIPT_PATH="startup-script.sh"
echo "📄 Creating startup script..."

cat <<EOF > "$STARTUP_SCRIPT_PATH"
#!/bin/bash
curl -s "https://storage.googleapis.com/signals-agents/logging/google-fluentd-install.sh" | bash
service google-fluentd restart &
apt-get update
apt-get install -yq ca-certificates git build-essential supervisor psmisc
mkdir /opt/nodejs
curl https://nodejs.org/dist/v16.14.0/node-v16.14.0-linux-x64.tar.gz | tar xvzf - -C /opt/nodejs --strip-components=1
ln -s /opt/nodejs/bin/node /usr/bin/node
ln -s /opt/nodejs/bin/npm /usr/bin/npm
mkdir /fancy-store
gsutil -m cp -r gs://fancy-store-${PROJECT_ID}/monolith-to-microservices/microservices/* /fancy-store/
cd /fancy-store/
npm install
useradd -m -d /home/nodeapp nodeapp
chown -R nodeapp:nodeapp /opt/app || true
cat >/etc/supervisor/conf.d/node-app.conf << APP
[program:nodeapp]
directory=/fancy-store
command=npm start
autostart=true
autorestart=true
user=nodeapp
environment=HOME="/home/nodeapp",USER="nodeapp",NODE_ENV="production"
stdout_logfile=syslog
stderr_logfile=syslog
APP
supervisorctl reread
supervisorctl update
EOF

# Upload startup script
gsutil cp "$STARTUP_SCRIPT_PATH" "gs://${BUCKET_NAME}/"

# ----------------- REMOVE NODE_MODULES AND UPLOAD CODE -----------------

cd ~
echo "🧹 Cleaning node_modules to reduce upload size..."
find monolith-to-microservices -type d -name "node_modules" -exec rm -rf {} +

echo "☁️ Uploading project code to GCS..."
gsutil -m cp -r monolith-to-microservices "gs://${BUCKET_NAME}/"

# ----------------- DEPLOY BACKEND INSTANCE -----------------

echo "🖥️ Deploying backend instance..."
gcloud compute instances create backend \
  --zone="${ZONE}" \
  --machine-type=e2-standard-2 \
  --tags=backend \
  --metadata=startup-script-url="https://storage.googleapis.com/${BUCKET_NAME}/${SCRIPT_NAME}" \
  --quiet || echo "⚠️ Backend instance already exists."

BACKEND_IP=$(gcloud compute instances describe backend --zone="$ZONE" --format="get(networkInterfaces[0].accessConfigs[0].natIP)")
echo "🌐 Backend External IP: $BACKEND_IP"

# ----------------- UPDATE .env -----------------

echo "⚙️ Updating .env file with backend IP..."
cd ~/monolith-to-microservices/react-app
sed -i "s|http://.*:8081|http://${BACKEND_IP}:8081|g" .env
sed -i "s|http://.*:8082|http://${BACKEND_IP}:8082|g" .env

# ----------------- REBUILD FRONTEND -----------------

npm install
npm run-script build

# Reupload updated code
cd ~
find monolith-to-microservices -type d -name "node_modules" -exec rm -rf {} +
gsutil -m cp -r monolith-to-microservices "gs://${BUCKET_NAME}/"

# ----------------- DEPLOY FRONTEND INSTANCE -----------------

echo "🖥️ Deploying frontend instance..."
gcloud compute instances create frontend \
  --zone="${ZONE}" \
  --machine-type=e2-standard-2 \
  --tags=frontend \
  --metadata=startup-script-url="https://storage.googleapis.com/${BUCKET_NAME}/${SCRIPT_NAME}" \
  --quiet || echo "⚠️ Frontend instance already exists."

# ----------------- FIREWALL RULES -----------------

echo "🔐 Configuring firewall rules..."

gcloud compute firewall-rules create fw-fe \
  --allow tcp:8080 \
  --target-tags=frontend \
  --quiet || echo "⚠️ Firewall rule fw-fe already exists."

gcloud compute firewall-rules create fw-be \
  --allow tcp:8081-8082 \
  --target-tags=backend \
  --quiet || echo "⚠️ Firewall rule fw-be already exists."


# ----------------- USER CONFIRMATION BEFORE MIG -----------------

echo ""
echo "⚠️  BEFORE CONTINUING..."
echo "This script will STOP and DELETE your existing Compute Engine instances to create Managed Instance Groups (MIGs)."
echo "⚠️  If you have NOT clicked 'Check My Progress' in your lab up to Task 4, you may lose credit."

ATTEMPTS=0
MAX_ATTEMPTS=3

while [[ $ATTEMPTS -lt $MAX_ATTEMPTS ]]; do
  read -p "👉 Have you completed Task 4 and clicked 'Check My Progress'? (y/N): " confirm
  case "$confirm" in
    [yY])
      echo "✅ Great! Proceeding to Task 5 (Managed Instance Groups)..."
      break
      ;;
    [nN]|"")
      ATTEMPTS=$((ATTEMPTS + 1))
      if [[ $ATTEMPTS -lt $MAX_ATTEMPTS ]]; then
        echo "⚠️  Please confirm once you've completed Task 4. Attempt $ATTEMPTS of $MAX_ATTEMPTS."
      else
        echo "❌ Max attempts reached. Please complete Task 4 and re-run the script."
        exit 1
      fi
      ;;
    *)
      echo "❌ Invalid input. Please enter y or n."
      ;;
  esac
done

# ----------------- INSTANCE GROUPS -----------------

echo "🧊 Creating Instance Templates & Managed Instance Groups..."

gcloud compute instances stop frontend --zone="$ZONE" --quiet || true
gcloud compute instances stop backend --zone="$ZONE" --quiet || true

gcloud compute instance-templates create fancy-fe \
  --source-instance=frontend \
  --source-instance-zone="$ZONE" \
  --quiet || echo "⚠️ fancy-fe template may already exist."

gcloud compute instance-templates create fancy-be \
  --source-instance=backend \
  --source-instance-zone="$ZONE" \
  --quiet || echo "⚠️ fancy-be template may already exist."

gcloud compute instances delete backend --zone="$ZONE" --quiet || true

gcloud compute instance-groups managed create fancy-fe-mig \
  --zone="$ZONE" \
  --base-instance-name fancy-fe \
  --size=2 \
  --template=fancy-fe \
  --quiet || echo "⚠️ MIG fancy-fe-mig may already exist."

gcloud compute instance-groups managed create fancy-be-mig \
  --zone="$ZONE" \
  --base-instance-name fancy-be \
  --size=2 \
  --template=fancy-be \
  --quiet || echo "⚠️ MIG fancy-be-mig may already exist."

gcloud compute instance-groups set-named-ports fancy-fe-mig \
  --zone="$ZONE" \
  --named-ports frontend:8080

gcloud compute instance-groups set-named-ports fancy-be-mig \
  --zone="$ZONE" \
  --named-ports orders:8081,products:8082

# ----------------- AUTOHEALING -----------------

echo "💉 Configuring autohealing and health checks..."

gcloud compute health-checks create http fancy-fe-hc \
  --port 8080 \
  --check-interval 30s \
  --timeout 10s \
  --unhealthy-threshold 3 \
  --healthy-threshold 1 \
  --quiet || true

gcloud compute health-checks create http fancy-be-hc \
  --port 8081 \
  --request-path /api/orders \
  --check-interval 30s \
  --timeout 10s \
  --unhealthy-threshold 3 \
  --healthy-threshold 1 \
  --quiet || true

gcloud compute firewall-rules create allow-health-check \
  --allow tcp:8080-8081 \
  --source-ranges 130.211.0.0/22,35.191.0.0/16 \
  --network default \
  --quiet || echo "⚠️ Firewall rule allow-health-check may already exist."

gcloud compute instance-groups managed update fancy-fe-mig \
  --zone="$ZONE" \
  --health-check fancy-fe-hc \
  --initial-delay 300

gcloud compute instance-groups managed update fancy-be-mig \
  --zone="$ZONE" \
  --health-check fancy-be-hc \
  --initial-delay 300

# ----------------

echo ""
echo "⚠️  BEFORE CONTINUING..."
echo ""
echo ""
read -p "👉 Have you completed Task 5 and clicked 'Check My Progress'? (y/N): " confirm


REACT_APP_PATH="$HOME/monolith-to-microservices/react-app"

# Step 1: Create Load Balancer Health Checks
echo "Creating load balancer HTTP health checks..."
gcloud compute http-health-checks create fancy-fe-frontend-hc \
  --request-path / --port 8080

gcloud compute http-health-checks create fancy-be-orders-hc \
  --request-path /api/orders --port 8081

gcloud compute http-health-checks create fancy-be-products-hc \
  --request-path /api/products --port 8082

# Step 2: Create Backend Services
echo "Creating backend services..."
gcloud compute backend-services create fancy-fe-frontend \
  --http-health-checks fancy-fe-frontend-hc \
  --port-name frontend --global

gcloud compute backend-services create fancy-be-orders \
  --http-health-checks fancy-be-orders-hc \
  --port-name orders --global

gcloud compute backend-services create fancy-be-products \
  --http-health-checks fancy-be-products-hc \
  --port-name products --global

# Step 3: Add Instance Groups to Backend Services
echo "Adding instance groups to backend services..."
gcloud compute backend-services add-backend fancy-fe-frontend \
  --instance-group fancy-fe-mig \
  --instance-group-zone $ZONE --global

gcloud compute backend-services add-backend fancy-be-orders \
  --instance-group fancy-be-mig \
  --instance-group-zone $ZONE --global

gcloud compute backend-services add-backend fancy-be-products \
  --instance-group fancy-be-mig \
  --instance-group-zone $ZONE --global

# Step 4: Create URL Map
echo "Creating URL map and path matchers..."
gcloud compute url-maps create fancy-map \
  --default-service fancy-fe-frontend

gcloud compute url-maps add-path-matcher fancy-map \
  --default-service fancy-fe-frontend \
  --path-matcher-name orders \
  --path-rules "/api/orders=fancy-be-orders,/api/products=fancy-be-products"

# Step 5: Create Target Proxy and Forwarding Rule
echo "Creating HTTP proxy and forwarding rule..."
gcloud compute target-http-proxies create fancy-proxy \
  --url-map fancy-map

gcloud compute forwarding-rules create fancy-http-rule \
  --global \
  --target-http-proxy fancy-proxy \
  --ports 80



echo ""
echo "⚠️  BEFORE CONTINUING..."
echo ""
echo ""
read -p "👉 Have you completed Task 6 1st progress and clicked 'Check My Progress'? (y/N): " confirm


# Step 6: Update .env File with Load Balancer IP
echo "Updating .env file with load balancer IP..."
LB_IP=$(gcloud compute forwarding-rules list --global --filter="name=fancy-http-rule" --format="value(IP_ADDRESS)")
echo "Load Balancer IP: $LB_IP"

ENV_FILE="$REACT_APP_PATH/.env"

if [ -f "$ENV_FILE" ]; then
  sed -i "s|REACT_APP_ORDERS_URL=.*|REACT_APP_ORDERS_URL=http://$LB_IP/api/orders|" "$ENV_FILE"
  sed -i "s|REACT_APP_PRODUCTS_URL=.*|REACT_APP_PRODUCTS_URL=http://$LB_IP/api/products|" "$ENV_FILE"
else
  echo "REACT_APP_ORDERS_URL=http://$LB_IP/api/orders" > "$ENV_FILE"
  echo "REACT_APP_PRODUCTS_URL=http://$LB_IP/api/products" >> "$ENV_FILE"
fi


# Step 7: Rebuild React App
echo "Rebuilding frontend app..."
cd "$REACT_APP_PATH"
npm install && npm run-script build

# Step 8: Copy app to Cloud Storage
echo "Uploading frontend app to Cloud Storage..."
cd ~
rm -rf monolith-to-microservices/*/node_modules
gsutil -m cp -r monolith-to-microservices "gs://$BUCKET_NAME/"

# Step 9: Trigger Rolling Restart on Frontend MIG
echo "Rolling restart of frontend managed instance group..."
gcloud compute instance-groups managed rolling-action replace fancy-fe-mig \
    --zone="$ZONE" --max-unavailable=100%

echo "✅ Load balancer setup completed successfully."


echo ""
echo "⚠️  BEFORE CONTINUING..."
echo ""
echo ""
read -p "👉 Have you completed Task 6 2nd progress and clicked 'Check My Progress'? (y/N): " confirm

# -------------------------------
# Configurable variables
# -------------------------------


FRONTEND_INSTANCE="frontend"
FRONTEND_MIG="fancy-fe-mig"
BACKEND_MIG="fancy-be-mig"
NEW_TEMPLATE_NAME="fancy-fe-new"
FRONTEND_SERVICE_NAME="fancy-fe-frontend"

echo "🛠️ Starting autoscaling setup and frontend update..."

# -------------------------------
# Task 7: Set Autoscaling Policies
# -------------------------------

echo "🚀 Enabling autoscaling on frontend MIG..."
gcloud compute instance-groups managed set-autoscaling $FRONTEND_MIG \
  --zone=$ZONE \
  --max-num-replicas=2 \
  --target-load-balancing-utilization=0.60

echo "🚀 Enabling autoscaling on backend MIG..."
gcloud compute instance-groups managed set-autoscaling $BACKEND_MIG \
  --zone=$ZONE \
  --max-num-replicas=2 \
  --target-load-balancing-utilization=0.60

# -------------------------------
# Task 7: Enable Cloud CDN
# -------------------------------

echo "🌐 Enabling Cloud CDN for frontend service..."
gcloud compute backend-services update $FRONTEND_SERVICE_NAME \
  --enable-cdn --global

# -------------------------------
# Task 8: Update Instance Template
# -------------------------------

echo "💻 Changing machine type of instance '$FRONTEND_INSTANCE' to e2-small..."
gcloud compute instances set-machine-type $FRONTEND_INSTANCE \
  --zone=$ZONE \
  --machine-type=e2-small

echo "🧱 Creating new instance template from updated instance..."
gcloud compute instance-templates create $NEW_TEMPLATE_NAME \
  --region=$REGION \
  --source-instance=$FRONTEND_INSTANCE \
  --source-instance-zone=$ZONE

echo "🔁 Rolling out new template to frontend MIG..."
gcloud compute instance-groups managed rolling-action start-update $FRONTEND_MIG \
  --zone=$ZONE \
  --version template=$NEW_TEMPLATE_NAME

# -------------------------------
# Wait for the rollout to complete
# -------------------------------

echo "⏳ Waiting for rollout to stabilize..."
sleep 40

FRONTEND_INSTANCE="frontend"
FRONTEND_MIG="fancy-fe-mig"
BACKEND_MIG="fancy-be-mig"
NEW_TEMPLATE_NAME="fancy-fe-new"
FRONTEND_SERVICE_NAME="fancy-fe-frontend"
GCS_BUCKET="gs://fancy-store-$PROJECT_ID"

echo "🛠️ Starting full deployment automation..."


echo ""
echo "⚠️  BEFORE CONTINUING..."
echo ""
echo ""
read -p "👉 Have you completed Task 7. (Scale Compute Engine) and clicked 'Check My Progress'? (y/N): " confirm

# ---------------------------------------
# Update Homepage Content
# ---------------------------------------

echo "📝 Updating homepage content..."
cd ~/monolith-to-microservices/react-app/src/pages/Home || {
  echo "❌ Directory not found. Are you in the right environment?"
  # exit 1
}

if [ -f index.js.new ]; then
  mv index.js.new index.js && echo "✅ Homepage updated successfully."
else
  echo "⚠️ index.js.new not found. Skipping homepage update."
fi

# ---------------------------------------
# Build React App and Push to GCS
# ---------------------------------------

echo "📦 Installing and building React app..."
cd ~/monolith-to-microservices/react-app || {
  echo "❌ React app directory not found!"
  # exit 1
}

npm install && npm run-script build

echo "🧹 Cleaning up node_modules..."
cd ~
rm -rf monolith-to-microservices/*/node_modules

echo "☁️ Copying project files to GCS bucket..."
gsutil -m cp -r monolith-to-microservices $GCS_BUCKET

# ---------------------------------------
# Force Rolling Replace of MIG Instances
# ---------------------------------------

echo "🔄 Forcing rolling replace of frontend MIG instances..."
gcloud compute instance-groups managed rolling-action replace $FRONTEND_MIG \
  --zone=$ZONE \
  --max-unavailable=100%

echo "🎉 Deployment complete! Click 'Check my progress' to verify."
