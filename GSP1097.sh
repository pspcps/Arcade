gcloud auth list

export ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])")

export REGION=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-region])")

export PROJECT_ID=$(gcloud config get-value project)

gcloud config set compute/zone "$ZONE"

gcloud config set compute/region "$REGION"

gcloud spanner databases create finance \
  --instance=bitfoon-dev \
  --ddl="CREATE TABLE Account (
            AccountId BYTES(16) NOT NULL,
            CreationTimestamp TIMESTAMP NOT NULL OPTIONS (allow_commit_timestamp=true),
            AccountStatus INT64 NOT NULL,
            Balance NUMERIC NOT NULL
         ) PRIMARY KEY (AccountId);"


ACCOUNT_IDS=("ACCOUNTID11123" "ACCOUNTID12345" "ACCOUNTID24680" "ACCOUNTID135791")

for ID in "${ACCOUNT_IDS[@]}"; do
  echo "Inserting AccountId: $ID"
  ENCODED_ID=$(echo -n "$ID" | base64)
  gcloud spanner databases execute-sql finance \
    --instance=bitfoon-dev \
    --sql="INSERT INTO Account (AccountId, CreationTimestamp, AccountStatus, Balance) VALUES (FROM_BASE64('$ENCODED_ID'), PENDING_COMMIT_TIMESTAMP(), 1, 22);"
done


gcloud spanner databases ddl update finance \
  --instance=bitfoon-dev \
  --ddl="CREATE CHANGE STREAM AccountUpdateStream FOR Account(AccountStatus, Balance);"


bq --location="$REGION" mk --dataset "$PROJECT_ID:changestream"

echo
echo -e "\033[1;33mCreate a Dataflow\033[0m \033[1;34mhttps://console.cloud.google.com/dataflow/createjob?inv=1&invt=Ab2T9A&project=$DEVSHELL_PROJECT_ID\033[0m"
echo

while true; do
    echo -ne "\e[1;93mDo you Want to proceed? (Y/n): \e[0m"
    read confirm
    case "$confirm" in
        [Yy]) 
            echo -e "\e[34mRunning the command...\e[0m"
            break
            ;;
        [Nn]|"") 
            echo "Operation canceled."
            break
            ;;
        *) 
            echo -e "\e[31mInvalid input. Please enter Y or N.\e[0m" 
            ;;
    esac
done


while true; do
  JOB_STATE=$(gcloud dataflow jobs list \
    --region="$REGION" \
    --filter="name=change-stream-pipeline" \
    --format="value(state)")

  if [[ "$JOB_STATE" == "Running" ]]; then
    echo "Dataflow job is running."
    break
  else
    echo -e "Waiting for job to start."
    sleep 10
  fi
done


ACCOUNT_ID="ACCOUNTID98765"
ENCODED_ID=$(echo -n "$ACCOUNT_ID" | base64)
gcloud spanner databases execute-sql finance \
  --instance=bitfoon-dev \
  --sql="INSERT INTO Account (
           AccountId,
           CreationTimestamp,
           AccountStatus,
           Balance
         ) VALUES (
           FROM_BASE64('$ENCODED_ID'),
           PENDING_COMMIT_TIMESTAMP(),
           1,
           22
         );"


TARGET_ID="ACCOUNTID11123"
ENCODED_TARGET=$(echo -n "$TARGET_ID" | base64)
BALANCES=(255 300 500 600)

for BALANCE in "${BALANCES[@]}"; do
  gcloud spanner databases execute-sql finance \
    --instance=bitfoon-dev \
    --sql="UPDATE Account
           SET CreationTimestamp = PENDING_COMMIT_TIMESTAMP(),
               AccountStatus = 4,
               Balance = $BALANCE
           WHERE AccountId = FROM_BASE64('$ENCODED_TARGET');"
  echo "Updated balance to $BALANCE"
  sleep 1
done

echo
echo -e "\033[1;33mGo to BigQuery\033[0m \033[1;34mhttps://console.cloud.google.com/bigquery?referrer=search&inv=1&invt=Ab2T9A&project==$DEVSHELL_PROJECT_ID&ws=!1m0\033[0m"
echo