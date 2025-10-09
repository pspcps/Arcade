#!/bin/bash
# Define color variables

RED=`tput setaf 1`
MAGENTA=`tput setaf 5`


BG_RED=`tput setab 1`
BG_MAGENTA=`tput setab 5`


BOLD=`tput bold`
RESET=`tput sgr0`
#----------------------------------------------------start--------------------------------------------------#


read -p "Please enter the region (e.g., us-central1): " REGION


echo "📍 Using region: $REGION"



echo "${BG_MAGENTA}${BOLD}Starting Execution${RESET}"

cat > main.py <<'EOF_END'
import functions_framework

@functions_framework.http
def hello_http(request):
    """HTTP Cloud Function.
    Args:
        request (flask.Request): The request object.
        <https://flask.palletsprojects.com/en/1.1.x/api/#incoming-request-data>
    Returns:
        The response text, or any set of values that can be turned into a
        Response object using `make_response`
        <https://flask.palletsprojects.com/en/1.1.x/api/#flask.make_response>.
    """
    request_json = request.get_json(silent=True)
    request_args = request.args

    if request_json and 'name' in request_json:
        name = request_json['name']
    elif request_args and 'name' in request_args:
        name = request_args['name']
    else:
        name = 'World'
    return 'Hello {}!'.format(name)
EOF_END

cat > requirements.txt <<'EOF_END'
functions-framework==3.*
EOF_END

gcloud functions deploy cf-demo \
  --gen2 \
  --runtime python313 \
  --entry-point hello_http \
  --source . \
  --region $REGION \
  --trigger-http \
  --allow-unauthenticated \
  --max-instances 5 \
  --quiet

echo "${BG_RED}${BOLD}Congratulations For Completing The Lab !!!${RESET}"

#-----------------------------------------------------end----------------------------------------------------------#