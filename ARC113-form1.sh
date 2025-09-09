echo "Step 1: Creating a subscription to the topic..."
echo
gcloud pubsub subscriptions create pubsub-subscription-message --topic gcloud-pubsub-topic

echo
echo "Step 2: Publishing a message to the topic..."
echo "Sending message: 'Hello World' to all subscriptions."
echo
gcloud pubsub topics publish gcloud-pubsub-topic --message="Hello World"

echo
echo "Waiting: Allowing some time for processing..."
sleep 10

echo
echo "Step 3: Pulling messages from the subscription..."
echo "Fetching up to 5 messages sent to the topic."
gcloud pubsub subscriptions pull pubsub-subscription-message --limit 5

echo
echo "Step 4: Creating a snapshot of the subscription..."
gcloud pubsub snapshots create pubsub-snapshot --subscription=gcloud-pubsub-subscription
