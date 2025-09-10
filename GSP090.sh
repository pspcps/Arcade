assign_projects() {
  echo "Fetching the list of available GCP projects..."
  PROJECT_LIST=$(gcloud projects list --format="value(projectId)")

  echo -n "Please enter the PROJECT_2 ID: "
  read PROJECT_2

  if [[ ! "$PROJECT_LIST" =~ (^|[[:space:]])"$PROJECT_2"($|[[:space:]]) ]]; then
    echo "Error: Invalid project ID. Please enter a valid project ID from the list."
    return 1
  fi

  echo "Selecting a different project for PROJECT_1..."
  PROJECT_1=$(echo "$PROJECT_LIST" | grep -v "^$PROJECT_2$" | head -n 1)

  if [[ -z "$PROJECT_1" ]]; then
    echo "Error: No other project available to assign to PROJECT_1."
    return 1
  fi

  echo "Exporting the selected project IDs as environment variables..."
  export PROJECT_2
  export PROJECT_1

  echo
  echo "PROJECT_1 has been set to: $PROJECT_1"
  echo "PROJECT_2 has been set to: $PROJECT_2"
}

echo "Running the project assignment function..."
assign_projects || exit 1

echo "Configuring gcloud to use project $PROJECT_2..."
gcloud config set project "$PROJECT_2"

echo "Determining the default compute zone for project $PROJECT_2..."
export ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])")

echo "Creating a new VM instance named 'instance2' in zone $ZONE..."
gcloud compute instances create instance2 --zone="$ZONE" --machine-type=e2-medium

echo
echo "You can monitor metrics for project $PROJECT_2 here:"
echo "https://console.cloud.google.com/monitoring/settings/metric-scope?project=$PROJECT_2"

function check_progress {
  while true; do
    echo
    echo -n "Have you created Group 'DemoGroup' (instance) & Uptime check 'DemoGroup uptime check'? (Y/N): "
    read -r user_input
    case "$user_input" in
      [Yy])
        echo
        echo "Great! Proceeding to the next steps..."
        echo
        break
        ;;
      [Nn])
        echo
        echo "Please create the Group named 'DemoGroup' and the Uptime Check, then press Y to continue."
        ;;
      *)
        echo
        echo "Invalid input. Please enter Y or N."
        ;;
    esac
  done
}
check_progress

echo "Generating the monitoring policy JSON file (arcadehelper.json)..."
cat > arcadehelper.json <<EOF_END
{
  "displayName": "Uptime Check Policy",
  "userLabels": {},
  "conditions": [
    {
      "displayName": "VM Instance - Check passed",
      "conditionAbsent": {
        "filter": "resource.type = \"gce_instance\" AND metric.type = \"monitoring.googleapis.com/uptime_check/check_passed\" AND metric.labels.check_id = \"demogroup-uptime-check-f-UeocjSHdQ\"",
        "aggregations": [
          {
            "alignmentPeriod": "300s",
            "crossSeriesReducer": "REDUCE_NONE",
            "perSeriesAligner": "ALIGN_FRACTION_TRUE"
          }
        ],
        "duration": "300s",
        "trigger": {
          "count": 1
        }
      }
    }
  ],
  "alertStrategy": {},
  "combiner": "OR",
  "enabled": true,
  "notificationChannels": [],
  "severity": "SEVERITY_UNSPECIFIED"
}
EOF_END

echo "Creating the monitoring policy using the generated JSON file..."
gcloud alpha monitoring policies create --policy-from-file="arcadehelper.json"
