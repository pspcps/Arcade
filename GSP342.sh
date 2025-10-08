echo "🚀 Script starting... Please wait!"
echo ""

# Prompt user to input three regions
read -p "Enter CUSTOM_SECURIY_ROLE: " CUSTOM_SECURIY_ROLE
read -p "Enter SERVICE_ACCOUNT: " SERVICE_ACCOUNT
read -p "Enter CLUSTER_NAME: " CLUSTER_NAME
read -p "Enter ZONE: " ZONE

echo ""
echo "⏳ Setting up your GCP environment..."
echo ""

#Task 1:-
echo "📝 Setting compute zone..."
gcloud config set compute/zone $ZONE

echo "🔧 Creating role definition..."
cat > role-definition.yaml <<EOF_END
title: "$CUSTOM_SECURIY_ROLE"
description: "Permissions"
stage: "ALPHA"
includedPermissions:
- storage.buckets.get
- storage.objects.get
- storage.objects.list
- storage.objects.update
- storage.objects.create
EOF_END

echo "👤 Creating service account..."
gcloud iam service-accounts create orca-private-cluster-sa --display-name "Orca Private Cluster Service Account"

echo "🎭 Creating custom role..."
gcloud iam roles create $CUSTOM_SECURIY_ROLE --project $DEVSHELL_PROJECT_ID --file role-definition.yaml

#Task 2:-
echo "👤 Creating main service account..."
gcloud iam service-accounts create $SERVICE_ACCOUNT --display-name "Orca Private Cluster Service Account"

#Task 3:-
echo "🔐 Assigning IAM roles..."
echo "   📊 Adding monitoring.viewer role..."
gcloud projects add-iam-policy-binding $DEVSHELL_PROJECT_ID --member serviceAccount:$SERVICE_ACCOUNT@$DEVSHELL_PROJECT_ID.iam.gserviceaccount.com --role roles/monitoring.viewer

echo "   📈 Adding monitoring.metricWriter role..."
gcloud projects add-iam-policy-binding $DEVSHELL_PROJECT_ID --member serviceAccount:$SERVICE_ACCOUNT@$DEVSHELL_PROJECT_ID.iam.gserviceaccount.com --role roles/monitoring.metricWriter

echo "   📝 Adding logging.logWriter role..."
gcloud projects add-iam-policy-binding $DEVSHELL_PROJECT_ID --member serviceAccount:$SERVICE_ACCOUNT@$DEVSHELL_PROJECT_ID.iam.gserviceaccount.com --role roles/logging.logWriter

echo "   🛡️ Adding custom security role..."
gcloud projects add-iam-policy-binding $DEVSHELL_PROJECT_ID --member serviceAccount:$SERVICE_ACCOUNT@$DEVSHELL_PROJECT_ID.iam.gserviceaccount.com --role projects/$DEVSHELL_PROJECT_ID/roles/$CUSTOM_SECURIY_ROLE

#Task 4:-
echo "🏗️ Creating GKE cluster..."
echo "   This may take a few minutes..."
gcloud container clusters create $CLUSTER_NAME --num-nodes 1 --master-ipv4-cidr=172.16.0.64/28 --network orca-build-vpc --subnetwork orca-build-subnet --enable-master-authorized-networks  --master-authorized-networks 192.168.10.2/32 --enable-ip-alias --enable-private-nodes --enable-private-endpoint --service-account $SERVICE_ACCOUNT@$DEVSHELL_PROJECT_ID.iam.gserviceaccount.com --zone $ZONE

#Task 5:-
echo "🔗 Configuring jumphost and deploying application..."
echo "   Setting up Kubernetes resources..."
gcloud compute ssh --zone "$ZONE" "orca-jumphost" --project "$DEVSHELL_PROJECT_ID" --quiet --command "gcloud config set compute/zone $ZONE && gcloud container clusters get-credentials $CLUSTER_NAME --internal-ip && sudo apt-get install -y google-cloud-sdk-gke-gcloud-auth-plugin && kubectl create deployment hello-server --image=gcr.io/google-samples/hello-app:1.0 && kubectl expose deployment hello-server --name orca-hello-service --type LoadBalancer --port 80 --target-port 8080"

echo ""
echo "✅ Script execution completed!"
