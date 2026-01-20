#!/bin/bash

# --- Color Palettes ---
BLU='\033[0;34m'
GRN='\033[0;32m'
YLW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# --- The Spinner Function ---
# This runs a process in the background and shows a spinning animation
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

clear
echo -e "${BLU}=======================================${NC}"
echo -e "${BLU}🚀  GCP ULTRA-DEPLOYMENT INITIALIZED  🚀${NC}"
echo -e "${BLU}=======================================${NC}"

# --- Setup Variables ---
PROJECT_ID=$(gcloud config get-value project)
OLD_BUCKET=${PROJECT_ID}-bucket
NEW_BUCKET=${PROJECT_ID}-new

echo -e "📌 ${YLW}Project:${NC} $PROJECT_ID"
echo -e "📦 ${YLW}Source:${NC}  $OLD_BUCKET"
echo -e "🆕 ${YLW}Target:${NC}  $NEW_BUCKET"
echo -e "${BLU}---------------------------------------${NC}"

# --- Execution with Spinners ---

echo -ne "🪣  Creating New Bucket...          "
gsutil mb gs://$NEW_BUCKET > /dev/null 2>&1 &
spinner $!
echo -e "${GRN}DONE${NC}"

echo -ne "🌐 Configuring Web Pages...         "
gsutil web set -m index.html -e error.html gs://$NEW_BUCKET > /dev/null 2>&1 &
spinner $!
echo -e "${GRN}DONE${NC}"

echo -ne "🔓 Applying Public Permissions...   "
gsutil iam ch allUsers:roles/storage.admin gs://$NEW_BUCKET > /dev/null 2>&1 &
spinner $!
echo -e "${RED}OPEN${NC}"

echo -ne "🔄 Syncing Data Assets...           "
gsutil -m rsync -r gs://$OLD_BUCKET gs://$NEW_BUCKET > /dev/null 2>&1 &
spinner $!
echo -e "${GRN}SYNCED${NC}"

echo -ne "⚙️  Enabling CDN Backend...          "
gcloud compute backend-buckets create backend-new --gcs-bucket-name=$NEW_BUCKET --enable-cdn > /dev/null 2>&1 &
spinner $!
echo -e "${GRN}ACTIVE${NC}"

echo -ne "🗺️  Mapping URL Paths...             "
gcloud compute url-maps create website-map --default-backend-bucket=backend-new > /dev/null 2>&1 &
spinner $!
echo -e "${GRN}MAPPED${NC}"

echo -ne "🎯 Setting HTTP Proxy...            "
gcloud compute target-http-proxies create website-proxy --url-map=website-map > /dev/null 2>&1 &
spinner $!
echo -e "${GRN}TARGETED${NC}"

echo -ne "🌍 Finalizing Forwarding Rules...   "
gcloud compute forwarding-rules create website-rule --global --target-http-proxy=website-proxy --ports=80 > /dev/null 2>&1 &
spinner $!
echo -e "${GRN}LIVE${NC}"

echo -e "${BLU}---------------------------------------${NC}"
echo -e "✅ ${GRN}DEPLOYMENT SUCCESSFUL!${NC}"
echo -e "${BLU}=======================================${NC}"