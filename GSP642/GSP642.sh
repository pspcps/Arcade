
gcloud auth list

export REGION=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-region])")

export PROJECT_ID=$(gcloud config get-value project)
echo
echo -e "This is your \033[1;33m$REGION\033[0m"
echo
echo -e "\033[1;33mEdit Binary Policy\033[0m \033[1;34mhttps://console.cloud.google.com/firestore/create-database?inv=1&invt=Ab0gLg&project=$DEVSHELL_PROJECT_ID\033[0m"
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

git clone https://github.com/rosera/pet-theory

cd pet-theory/lab01

npm install @google-cloud/firestore

npm install @google-cloud/logging

curl -LO https://raw.githubusercontent.com/pspcps/Arcade/refs/heads/main/GSP642/importTestData.js

npm install faker@5.5.3

curl -LO https://raw.githubusercontent.com/pspcps/Arcade/refs/heads/main/GSP642/createTestData.js

node createTestData 1000
node importTestData customers_1000.csv
npm install csv-parse