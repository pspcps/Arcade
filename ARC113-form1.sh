    echo -e "${GREEN}${BOLD}⚙️ Setting up Basic Pub/Sub with Scheduler${RESET}"
    
    echo -e "${YELLOW}Enabling Cloud Scheduler API...${RESET}"
    gcloud services enable cloudscheduler.googleapis.com
    
    echo -e "${YELLOW}Creating Pub/Sub topic...${RESET}"
    gcloud pubsub topics create cloud-pubsub-topic
    
    echo -e "${YELLOW}Creating subscription...${RESET}"
    gcloud pubsub subscriptions create 'cloud-pubsub-subscription' --topic=cloud-pubsub-topic
    
    echo -e "${YELLOW}Creating scheduled job...${RESET}"
    gcloud scheduler jobs create pubsub cron-scheduler-job \
        --schedule="* * * * *" --topic=cron-job-pubsub-topic \
        --message-body="Hello World!" --location=$REGION
    
    echo -e "${YELLOW}Pulling messages...${RESET}"
    gcloud pubsub subscriptions pull cron-job-pubsub-subscription --limit 5