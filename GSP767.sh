
gcloud auth list

export ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])")

export REGION=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-region])")

export PROJECT_ID=$(gcloud config get-value project)

gcloud config set compute/zone "$ZONE"

gcloud config set compute/region "$REGION"

gcloud container clusters get-credentials hello-demo-cluster --zone "$ZONE"

kubectl scale deployment hello-server --replicas=2

gcloud container clusters resize hello-demo-cluster --node-pool my-node-pool --num-nodes 3 --zone "$ZONE" --quiet

gcloud container node-pools create larger-pool --cluster=hello-demo-cluster --machine-type=e2-standard-2 --num-nodes=1 --zone="$ZONE"

for node in $(kubectl get nodes -l cloud.google.com/gke-nodepool=my-node-pool -o=name); do
  kubectl cordon "$node";
done

for node in $(kubectl get nodes -l cloud.google.com/gke-nodepool=my-node-pool -o=name); do
  kubectl drain --force --ignore-daemonsets --delete-emptydir-data --grace-period=10 "$node";
done

kubectl get pods -o=wide


gcloud container node-pools delete my-node-pool --cluster hello-demo-cluster --zone "$ZONE" --quiet

gcloud container clusters create regional-demo --region=$REGION --num-nodes=1

cat << EOF > pod-1.yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-1
  labels:
    security: demo
spec:
  containers:
  - name: container-1
    image: wbitt/network-multitool
EOF

kubectl apply -f pod-1.yaml

cat << EOF > pod-2.yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-2
spec:
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
          - key: security
            operator: In
            values:
            - demo
        topologyKey: "kubernetes.io/hostname"
  containers:
  - name: container-2
    image: us-docker.pkg.dev/google-samples/containers/gke/hello-app:1.0
EOF

kubectl apply -f pod-2.yaml

sleep 20

kubectl get pod pod-1 pod-2 --output wide

echo
echo $REGION
echo
echo -e "\033[1;33mExamine flow logs\033[0m \033[1;34mhttps://console.cloud.google.com/networking/networks/details/default?project=$DEVSHELL_PROJECT_ID&inv=1&invt=AbzSCA&pageTab=SUBNETS\033[0m"
echo
