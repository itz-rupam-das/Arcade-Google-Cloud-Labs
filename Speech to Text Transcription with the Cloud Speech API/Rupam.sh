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
  echo "${DIM_TEXT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET_FORMAT}"
}

fatal() {
  echo -e "\n${RED_TEXT}${BOLD_TEXT}✖ ERROR:${RESET_FORMAT} $1"
  exit 1
}

trap 'fatal "Unexpected failure at line $LINENO"' ERR

clear

# ===================== HEADER =============================
echo "${CYAN_TEXT}${BOLD_TEXT}==================================================================${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}        ITZ RUPAM — SPEECH TO TEXT LAB EXECUTION                  ${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}==================================================================${RESET_FORMAT}"
echo

# ===================== TASK 1–3 ===========================
divider
echo "${YELLOW_TEXT}${BOLD_TEXT}🔧 TASK 1–3 : ENGLISH SPEECH TRANSCRIPTION — ITZ RUPAM${RESET_FORMAT}"

cat > prepare_disk.sh <<'EOF'
set -Eeuo pipefail

gcloud services enable apikeys.googleapis.com speech.googleapis.com

gcloud alpha services api-keys create --display-name="awesome" &>/dev/null
sleep 5

KEY_NAME=$(gcloud alpha services api-keys list \
  --filter="displayName=awesome" \
  --format="value(name)")

API_KEY=$(gcloud alpha services api-keys get-key-string "$KEY_NAME" \
  --format="value(keyString)")

cat > request.json <<JSON
{
  "config": {
    "encoding": "FLAC",
    "languageCode": "en-US"
  },
  "audio": {
    "uri": "gs://cloud-samples-data/speech/brooklyn_bridge.flac"
  }
}
JSON

curl -s -X POST \
  -H "Content-Type: application/json" \
  --data-binary @request.json \
  "https://speech.googleapis.com/v1/speech:recognize?key=${API_KEY}" \
  > result.json

cat result.json
EOF

ZONE=$(gcloud compute instances list linux-instance --format='csv[no-heading](zone)')
(gcloud compute scp prepare_disk.sh linux-instance:/tmp --zone="$ZONE" --quiet) &
spinner "Uploading English task to VM"

(gcloud compute ssh linux-instance --zone="$ZONE" --quiet \
  --command="bash /tmp/prepare_disk.sh") &
spinner "English transcription completed"

read -p "CHECK MY PROGRESS DONE TILL TASK 3 (Y/N)? " response
[[ "$response" =~ ^[Yy]$ ]] || fatal "Progress check not confirmed"

# ===================== TASK 4 =============================
divider
echo "${YELLOW_TEXT}${BOLD_TEXT}🌍 TASK 4 : FRENCH SPEECH TRANSCRIPTION — ITZ RUPAM${RESET_FORMAT}"

cat > prepare_disk.sh <<'EOF'
set -Eeuo pipefail

KEY_NAME=$(gcloud alpha services api-keys list \
  --filter="displayName=awesome" \
  --format="value(name)")

API_KEY=$(gcloud alpha services api-keys get-key-string "$KEY_NAME" \
  --format="value(keyString)")

cat > request.json <<JSON
{
  "config": {
    "encoding": "FLAC",
    "languageCode": "fr"
  },
  "audio": {
    "uri": "gs://cloud-samples-data/speech/corbeau_renard.flac"
  }
}
JSON

curl -s -X POST \
  -H "Content-Type: application/json" \
  --data-binary @request.json \
  "https://speech.googleapis.com/v1/speech:recognize?key=${API_KEY}" \
  > result.json

cat result.json
EOF

(gcloud compute scp prepare_disk.sh linux-instance:/tmp --zone="$ZONE" --quiet) &
spinner "Uploading French task to VM"

(gcloud compute ssh linux-instance --zone="$ZONE" --quiet \
  --command="bash /tmp/prepare_disk.sh") &
spinner "French transcription completed"

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
