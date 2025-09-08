
gcloud auth list

sudo apt-get install -y virtualenv

python3 -m venv venv

source venv/bin/activate

pip install --upgrade google-cloud-pubsub

git clone https://github.com/googleapis/python-pubsub.git

cd python-pubsub/samples/snippets

echo $GOOGLE_CLOUD_PROJECT

cat publisher.py

python publisher.py -h

python publisher.py $GOOGLE_CLOUD_PROJECT create MyTopic

python publisher.py $GOOGLE_CLOUD_PROJECT list

python subscriber.py $GOOGLE_CLOUD_PROJECT create MyTopic MySub
