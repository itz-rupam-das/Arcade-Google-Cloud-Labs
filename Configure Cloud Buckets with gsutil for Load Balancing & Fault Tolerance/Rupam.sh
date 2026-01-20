#!/bin/bash

# --- Color Definitions ---
RE='\033[0;31m'
GR='\033[0;32m'
YL='\033[1;33m'
BL='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BL}🚀 Starting deployment...${NC}"
echo -e "${BL}-----------------------------------${NC}"

# --- Variable Initialization ---
PROJECT_ID=$(gcloud config get-value project)
OLD_BUCKET=${PROJECT_ID}-bucket
NEW_BUCKET=${PROJECT_ID}-new

echo -e "📌 ${YL}Project detected:${NC} $PROJECT_ID"
echo -e "📦 ${YL}Old bucket:${NC}      $OLD_BUCKET"
echo -e "🆕 ${YL}New bucket:${NC}      $NEW_BUCKET"
echo -e "${BL}-----------------------------------${NC}"

# --- Storage Configuration ---
echo -e "🪣  ${GR}Creating new Cloud Storage bucket...${NC}"
gsutil mb gs://$NEW_BUCKET

echo -e "🌐 ${GR}Enabling website configuration (index & error pages)...${NC}"
gsutil web set -m index.html -e error.html gs://$NEW_BUCKET

echo -e "🔓 ${RE}Making bucket public...${NC}"
gsutil iam ch allUsers:roles/storage.admin gs://$NEW_BUCKET

echo -e "🔄 ${GR}Syncing data from old bucket to new bucket...${NC}"
gsutil -m rsync -r gs://$OLD_BUCKET gs://$NEW_BUCKET

# --- Networking & CDN Configuration ---
echo -e "⚙️  ${GR}Creating backend bucket with CDN enabled...${NC}"
gcloud compute backend-buckets create backend-new \
  --gcs-bucket-name=$NEW_BUCKET \
  --enable-cdn

echo -e "🗺️  ${GR}Creating URL map...${NC}"
gcloud compute url-maps create website-map \
  --default-backend-bucket=backend-new

echo -e "🎯 ${GR}Creating HTTP proxy...${NC}"
gcloud compute target-http-proxies create website-proxy \
  --url-map=website-map

echo -e "🌍 ${GR}Creating global forwarding rule on port 80...${NC}"
gcloud compute forwarding-rules create website-rule \
  --global \
  --target-http-proxy=website-proxy \
  --ports=80

echo -e "${BL}-----------------------------------${NC}"
echo -e "✅ ${GR}Deployment completed successfully!${NC}"