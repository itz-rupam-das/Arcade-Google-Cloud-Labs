#!/bin/bash

# ==============================================================================
# SCRIPT: deploy-cdn-site.sh
# DESCRIPTION: Provisions a GCS-backed website with CDN and Load Balancing.
# SECURITY: Sets allUsers to ObjectViewer (Read-Only), NOT Admin.
# ==============================================================================

# 1. Error Handling & Formatting
set -e
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Initializing Secure Deployment...${NC}"

# 2. Environment Variables
PROJECT_ID=$(gcloud config get-value project)
TIMESTAMP=$(date +%s)
NEW_BUCKET="static-site-${TIMESTAMP}" # Ensures uniqueness
BACKEND_NAME="backend-site-${TIMESTAMP}"
URL_MAP="website-map-${TIMESTAMP}"
PROXY_NAME="website-proxy-${TIMESTAMP}"
FW_RULE="website-rule-${TIMESTAMP}"

echo -e "--------------------------------------------------"
echo -e "  Target Project : ${GREEN}$PROJECT_ID${NC}"
echo -e "  New Bucket     : ${GREEN}$NEW_BUCKET${NC}"
echo -e "--------------------------------------------------"

# 3. Infrastructure Provisioning
echo -e "\n📦 ${BLUE}Step 1: Creating Storage Bucket...${NC}"
gcloud storage buckets create gs://"$NEW_BUCKET" \
    --location=us-central1 \
    --uniform-bucket-level-access

echo -e "🌐 ${BLUE}Step 2: Configuring Web Settings...${NC}"
gcloud storage buckets update gs://"$NEW_BUCKET" \
    --web-index-page=index.html \
    --web-error-page=error.html

echo -e "🔐 ${BLUE}Step 3: Setting Public Permissions (Read-Only)...${NC}"
gcloud storage buckets add-iam-policy-binding gs://"$NEW_BUCKET" \
    --member="allUsers" \
    --role="roles/storage.objectViewer"

echo -e "⚙️  ${BLUE}Step 4: Creating Backend Bucket with CDN...${NC}"
gcloud compute backend-buckets create "$BACKEND_NAME" \
    --gcs-bucket-name="$NEW_BUCKET" \
    --enable-cdn \
    --cache-mode=CACHE_ALL_STATIC

echo -e "🗺️  ${BLUE}Step 5: Defining URL Map...${NC}"
gcloud compute url-maps create "$URL_MAP" \
    --default-backend-bucket="$BACKEND_NAME"

echo -e "🎯 ${BLUE}Step 6: Creating HTTP Target Proxy...${NC}"
gcloud compute target-http-proxies create "$PROXY_NAME" \
    --url-map="$URL_MAP"

echo -e "🌍 ${BLUE}Step 7: Establishing Global Forwarding Rule...${NC}"
gcloud compute forwarding-rules create "$FW_RULE" \
    --load-balancing-scheme=EXTERNAL \
    --network-tier=PREMIUM \
    --address-region=global \
    --global \
    --target-http-proxy="$PROXY_NAME" \
    --ports=80

# 4. Final Verification
echo -e "\n--------------------------------------------------"
echo -e "✅ ${GREEN}DEPLOYMENT COMPLETE${NC}"
echo -e "🔗 ${BLUE}Your IP Address:${NC} $(gcloud compute forwarding-rules describe "$FW_RULE" --global --format='value(IPAddress)')"
echo -e "--------------------------------------------------"