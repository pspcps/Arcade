#!/bin/bash
set -euo pipefail

# Set text styles
YELLOW=$(tput setaf 3)
BOLD=$(tput bold)
RESET=$(tput sgr0)

echo "Please set the below values correctly"
read -p "${YELLOW}${BOLD}Enter the container_name: ${RESET}" container_name
read -p "${YELLOW}${BOLD}Enter the defective: ${RESET}" defective
read -p "${YELLOW}${BOLD}Enter the non_defective: ${RESET}" non_defective

cat > env_vars.sh <<EOF
export container_name="${container_name}"
export defective="${defective}"
export non_defective="${non_defective}"
EOF

cp env_vars.sh /tmp/env_vars.sh

source env_vars.sh

cat > cp_disk.sh <<'EOF_CP'
#!/bin/bash
set -euo pipefail

source /tmp/env_vars.sh

export PROJECT_ID=$(gcloud config get-value core/project)

export container_registry=gcr.io/ql-shared-resources-test/defect_solution@sha256:776fd8c65304ac017f5b9a986a1b8189695b7abbff6aa0e4ef693c46c7122f4c
export VISERVING_CPU_DOCKER_WITH_MODEL=${container_registry}
export HTTP_PORT=8602
export LOCAL_METRIC_PORT=8603

docker rm -f $container_name 2>/dev/null || true

docker pull ${VISERVING_CPU_DOCKER_WITH_MODEL}
docker run -v /secrets:/secrets --rm -d --name "$container_name" \
  --network="host" \
  -p ${HTTP_PORT}:${HTTP_PORT} \
  -p ${LOCAL_METRIC_PORT}:${LOCAL_METRIC_PORT} \
  -t ${VISERVING_CPU_DOCKER_WITH_MODEL}

docker container ls

gsutil cp gs://cloud-training/gsp895/prediction_script.py .

gsutil mb -p "$PROJECT_ID" gs://${PROJECT_ID} || true
gsutil -m cp gs://cloud-training/gsp897/cosmetic-test-data/*.png \
  gs://${PROJECT_ID}/cosmetic-test-data/

gsutil cp gs://${PROJECT_ID}/cosmetic-test-data/IMG_07703.png .

# Install Python & pip dependencies
sudo apt update -y
sudo apt install -y python3 python3-pip python3-venv

python3 -m venv myvenv
source myvenv/bin/activate
pip install absl-py numpy requests

# Run inference
python3 ./prediction_script.py --input_image_file=./IMG_07703.png --port=8602 --output_result_file="$defective"

gsutil cp gs://${PROJECT_ID}/cosmetic-test-data/IMG_0769.png .
python3 ./prediction_script.py --input_image_file=./IMG_0769.png --port=8602 --output_result_file="$non_defective"
EOF_CP

export ZONE="$(gcloud compute instances list --project=$DEVSHELL_PROJECT_ID --format='value(ZONE)' | head -n 1)"

gcloud compute scp cp_disk.sh /tmp/env_vars.sh lab-vm:/tmp --project=$DEVSHELL_PROJECT_ID --zone=$ZONE --quiet

gcloud compute ssh lab-vm --project=$DEVSHELL_PROJECT_ID --zone=$ZONE --quiet --command="bash /tmp/cp_disk.sh"