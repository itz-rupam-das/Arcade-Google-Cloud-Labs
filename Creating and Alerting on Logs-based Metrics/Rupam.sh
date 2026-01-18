#!/bin/bash
set -Eeuo pipefail

# ===================== COLOR & FORMAT =====================
BLACK_TEXT=$'\033[0;90m'
RED_TEXT=$'\033[0;91m'
GREEN_TEXT=$'\033[0;92m'
YELLOW_TEXT=$'\033[0;93m'
BLUE_TEXT=$'\033[0;94m'
MAGENTA_TEXT=$'\033[0;95m'
CYAN_TEXT=$'\033[0;96m'
WHITE_TEXT=$'\033[0;97m'

BOLD_TEXT=$'\033[1m'
UNDERLINE_TEXT=$'\033[4m'
DIM_TEXT=$'\033[2m'
RESET_FORMAT=$'\033[0m'

START_TIME=$(date +%s)

# ===================== UI UTILITIES ======================
spinner() {
  local pid=$!
  local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  local i=0
  while kill -0 "$pid" 2>/dev/null; do
    i=$(( (i+1) %10 ))
    printf "\r${CYAN_TEXT}${spin:$i:1}${RESET_FORMAT} $1"
    sleep 0.1
  done
  wait "$pid"
  printf "\r${GREEN_TEXT}✔${RESET_FORMAT} $1\n"
}

divider() {
  echo "${DIM_TEXT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET_FORMAT}"
}

fatal() {
  echo -e "\n${RED_TEXT}${BOLD_TEXT}✖ ERROR:${RESET_FORMAT} $1"
  exit 1
}

trap 'fatal "Unexpected failure at line $LINENO"' ERR

clear

# ===================== HEADER =============================
echo "${CYAN_TEXT}${BOLD_TEXT}==================================================================${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}   GOOGLE CLOUD MONITORING & GKE LAB — ITZ RUPAM                 ${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}==================================================================${RESET_FORMAT}"
echo

# ===================== STEP 1 =============================
divider
echo "${YELLOW_TEXT}${BOLD_TEXT}🔧 STEP 1: PROJECT, ZONE & REGION SETUP — ITZ RUPAM${RESET_FORMAT}"

PROJECT_ID=$(gcloud info --format='value(config.project)')
ZONE=$(gcloud compute project-info describe \
  --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
REGION=$(gcloud compute project-info describe \
  --format="value(commonInstanceMetadata.items[google-compute-default-region])")

gcloud config set compute/zone "$ZONE" &>/dev/null

echo "${GREEN_TEXT}✔ Project:${RESET_FORMAT} $PROJECT_ID"
echo "${GREEN_TEXT}✔ Zone:${RESET_FORMAT} $ZONE"
echo "${GREEN_TEXT}✔ Region:${RESET_FORMAT} $REGION"

# ===================== STEP 2 =============================
divider
echo "${YELLOW_TEXT}${BOLD_TEXT}☸ STEP 2: CREATING GKE CLUSTER — ITZ RUPAM${RESET_FORMAT}"
(
gcloud container clusters create gmp-cluster --num-nodes=1 --zone "$ZONE"
) &
spinner "GKE cluster created"

# ===================== STEP 3 =============================
divider
echo "${YELLOW_TEXT}${BOLD_TEXT}📊 STEP 3: LOG-BASED METRIC (STOPPED VMS) — ITZ RUPAM${RESET_FORMAT}"
(
gcloud logging metrics create stopped-vm \
  --description="Metric for stopped VMs" \
  --log-filter='resource.type="gce_instance" protoPayload.methodName="v1.compute.instances.stop"'
) &
spinner "Stopped VM metric created"

# ===================== STEP 4 =============================
divider
echo "${YELLOW_TEXT}${BOLD_TEXT}🔔 STEP 4: PUB/SUB NOTIFICATION CHANNEL — ITZ RUPAM${RESET_FORMAT}"

cat > pubsub-channel.json <<EOF
{
  "type": "pubsub",
  "displayName": "awesome",
  "description": "Notification Channel",
  "labels": {
    "topic": "projects/$DEVSHELL_PROJECT_ID/topics/notificationTopic"
  }
}
EOF

(
gcloud beta monitoring channels create \
  --channel-content-from-file=pubsub-channel.json
) &
spinner "Notification channel created"

CHANNEL_ID=$(gcloud beta monitoring channels list \
  --format="value(name)" | head -n 1)

# ===================== STEP 5 =============================
divider
echo "${YELLOW_TEXT}${BOLD_TEXT}🚨 STEP 5: ALERT POLICY (STOPPED VMS) — ITZ RUPAM${RESET_FORMAT}"

cat > stopped-vm-alert-policy.json <<EOF
{
  "displayName": "stopped vm",
  "conditions": [
    {
      "displayName": "Log match",
      "conditionMatchedLog": {
        "filter": "resource.type=\"gce_instance\" protoPayload.methodName=\"v1.compute.instances.stop\""
      }
    }
  ],
  "notificationChannels": ["$CHANNEL_ID"],
  "enabled": true
}
EOF

(
gcloud alpha monitoring policies create \
  --policy-from-file=stopped-vm-alert-policy.json
) &
spinner "Stopped VM alert policy deployed"

# ===================== STEP 6 =============================
divider
echo "${YELLOW_TEXT}${BOLD_TEXT}📦 STEP 6: ARTIFACT REGISTRY — ITZ RUPAM${RESET_FORMAT}"
(
gcloud artifacts repositories create docker-repo \
  --repository-format=docker \
  --location="$REGION" \
  --description="Docker repository"
) &
spinner "Artifact Registry ready"

# ===================== STEP 7 =============================
divider
echo "${YELLOW_TEXT}${BOLD_TEXT}🐳 STEP 7: DOCKER IMAGE SETUP — ITZ RUPAM${RESET_FORMAT}"
(
wget https://storage.googleapis.com/spls/gsp1024/flask_telemetry.zip
unzip -o flask_telemetry.zip
docker load -i flask_telemetry.tar
docker tag gcr.io/ops-demo-330920/flask_telemetry:* \
"$REGION-docker.pkg.dev/$DEVSHELL_PROJECT_ID/docker-repo/flask-telemetry:v1"
docker push "$REGION-docker.pkg.dev/$DEVSHELL_PROJECT_ID/docker-repo/flask-telemetry:v1"
) &
spinner "Docker image pushed"

# ===================== STEP 8 =============================
divider
echo "${YELLOW_TEXT}${BOLD_TEXT}📡 STEP 8: KUBERNETES DEPLOYMENT — ITZ RUPAM${RESET_FORMAT}"

gcloud container clusters get-credentials gmp-cluster &>/dev/null
kubectl create ns gmp-test || true

wget https://storage.googleapis.com/spls/gsp1024/gmp_prom_setup.zip
unzip -o gmp_prom_setup.zip
cd gmp_prom_setup

sed -i "s|<ARTIFACT REGISTRY IMAGE NAME>|$REGION-docker.pkg.dev/$DEVSHELL_PROJECT_ID/docker-repo/flask-telemetry:v1|g" flask_deployment.yaml

kubectl -n gmp-test apply -f flask_deployment.yaml
kubectl -n gmp-test apply -f flask_service.yaml

# ===================== STEP 9 =============================
divider
echo "${YELLOW_TEXT}${BOLD_TEXT}📉 STEP 9: ERROR METRIC & ALERT — ITZ RUPAM${RESET_FORMAT}"

gcloud logging metrics create hello-app-error \
  --description="hello-app errors" \
  --log-filter='severity=ERROR resource.labels.container_name="hello-app"'

sleep 30

cat > hello-alert.json <<EOF
{
  "displayName": "hello app error alert",
  "conditions": [
    {
      "conditionThreshold": {
        "filter": "metric.type=\"logging.googleapis.com/user/hello-app-error\"",
        "comparison": "COMPARISON_GT",
        "thresholdValue": 0
      }
    }
  ],
  "enabled": true
}
EOF

gcloud alpha monitoring policies create --policy-from-file=hello-alert.json

# ===================== CLEANUP ===========================
divider
echo "${YELLOW_TEXT}${BOLD_TEXT}🧹 CLEANUP FILES — ITZ RUPAM${RESET_FORMAT}"
rm -f gsp* arc* shell* || true

# ===================== COMPLETION ========================
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

divider
echo "${GREEN_TEXT}${BOLD_TEXT}=======================================================${RESET_FORMAT}"
echo "${GREEN_TEXT}${BOLD_TEXT}  LAB IS SUCCESSFULLY COMPLETED — CONGRATULATIONS       ${RESET_FORMAT}"
echo "${GREEN_TEXT}${BOLD_TEXT}                    ITZ RUPAM                          ${RESET_FORMAT}"
echo "${GREEN_TEXT}${BOLD_TEXT}=======================================================${RESET_FORMAT}"
echo "${DIM_TEXT}Execution time: ${DURATION}s${RESET_FORMAT}"
divider
