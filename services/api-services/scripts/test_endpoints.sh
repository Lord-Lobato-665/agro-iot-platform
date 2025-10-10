#!/usr/bin/env bash
set -euo pipefail

# Test script for agro-iot-platform endpoints
# Creates a timestamped log file under ./logs with per-endpoint sections.

BASE_URL="${BASE_URL:-http://localhost:5172}"
LOG_DIR="$(dirname "$0")/../logs"
mkdir -p "$LOG_DIR"
LOGFILE="$LOG_DIR/endpoints-$(date +%Y%m%d_%H%M%S).txt"

USER_EMAIL="${USER_EMAIL:-test+$(date +%s)@example.com}"
USER_PASSWORD="${USER_PASSWORD:-P@ssw0rd123!}"
USER_NAME="${USER_NAME:-Test User}"

JQ_BIN=$(command -v jq || true)

function now() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

function header() {
  echo -e "\n===== $1 =====\n" | tee -a "$LOGFILE"
  echo "timestamp: $(now)" >> "$LOGFILE"
}

function http() {
  # http METHOD PATH [DATA] [TOKEN]
  local METHOD="$1"; shift
  local PATH="$1"; shift
  local DATA="${1:-}"; shift || true
  local TOKEN="${1:-}"; shift || true

  local URL="$BASE_URL$PATH"
  header "$METHOD $URL"

  local AUTH_HEADER=()
  if [[ -n "$TOKEN" && "$TOKEN" != "null" ]]; then
    AUTH_HEADER=( -H "Authorization: Bearer $TOKEN" )
  fi

  local RESP
  if [[ -n "$DATA" ]]; then
    RESP=$(curl -sS -X "$METHOD" "$URL" -H "Content-Type: application/json" "${AUTH_HEADER[@]}" -d "$DATA" -w "\n__HTTP_STATUS__:%{http_code}")
  else
    RESP=$(curl -sS -X "$METHOD" "$URL" "${AUTH_HEADER[@]}" -w "\n__HTTP_STATUS__:%{http_code}")
  fi

  # Split body and status
  local STATUS=$(echo "$RESP" | sed -n '/__HTTP_STATUS__:/p' | sed 's/__HTTP_STATUS__://')
  local BODY=$(echo "$RESP" | sed '/__HTTP_STATUS__:/d')

  echo "HTTP_STATUS: $STATUS" | tee -a "$LOGFILE"

  if [[ -n "$JQ_BIN" ]]; then
    if echo "$BODY" | jq . >/dev/null 2>&1; then
      echo "$BODY" | jq . | tee -a "$LOGFILE"
    else
      echo "$BODY" | tee -a "$LOGFILE"
    fi
  else
    echo "$BODY" | tee -a "$LOGFILE"
  fi

  echo "" >> "$LOGFILE"
  echo "$STATUS"
}

echo "Starting endpoint tests against $BASE_URL"
echo "Logs will be written to: $LOGFILE"

########################################
# 1) Register user (may fail if user exists)
########################################
REG_PAYLOAD=$(jq -n --arg nombre "$USER_NAME" --arg correo "$USER_EMAIL" --arg password "$USER_PASSWORD" --arg telefono "0000000000" '{Nombre: $nombre, Correo: $correo, Password: $password, Telefono: $telefono}')
http POST "/agro/auth/register" "$REG_PAYLOAD" || true

########################################
# 2) Login to get token
########################################
LOGIN_PAYLOAD=$(jq -n --arg correo "$USER_EMAIL" --arg password "$USER_PASSWORD" '{Correo: $correo, Password: $password}')
LOGIN_RESP=$(curl -sS -X POST "$BASE_URL/agro/auth/login" -H "Content-Type: application/json" -d "$LOGIN_PAYLOAD" -w "\n__HTTP_STATUS__:%{http_code}")
LOGIN_STATUS=$(echo "$LOGIN_RESP" | sed -n '/__HTTP_STATUS__:/p' | sed 's/__HTTP_STATUS__://')
LOGIN_BODY=$(echo "$LOGIN_RESP" | sed '/__HTTP_STATUS__:/d')

header "POST $BASE_URL/agro/auth/login"
echo "HTTP_STATUS: $LOGIN_STATUS" | tee -a "$LOGFILE"
if [[ -n "$JQ_BIN" && $(echo "$LOGIN_BODY" | jq . >/dev/null 2>&1; echo $?) -eq 0 ]]; then
  echo "$LOGIN_BODY" | jq . | tee -a "$LOGFILE"
else
  echo "$LOGIN_BODY" | tee -a "$LOGFILE"
fi

# Try to extract token from common locations
TOKEN=$(echo "$LOGIN_BODY" | jq -r '.Token // .token // .accessToken // .data.token // .data.Token // .data.accessToken' 2>/dev/null || true)
if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
  echo "Warning: no token parsed from login response. Protected endpoints will be called without auth." | tee -a "$LOGFILE"
  TOKEN=""
else
  echo "Obtained token (truncated): ${TOKEN:0:20}..." | tee -a "$LOGFILE"
fi

########################################
# 3) Parcela flow: create -> get list -> get single -> update -> delete -> restore
########################################
PARCELA_PAYLOAD=$(jq -n '{name: "Parcela de prueba", description: "Creada por test script"}')
PARCELA_CREATE_STATUS=$(http POST "/agro/parcelas" "$PARCELA_PAYLOAD" "$TOKEN" || true)

# Try to extract parcela id from last response in logfile (best-effort)
PARCELA_ID=""
if [[ -n "$JQ_BIN" ]]; then
  PARCELA_ID=$(echo "$PARCELA_CREATE_STATUS" >/dev/null 2>&1; true)
  # Fallback: search in log file for a JSON id near the create call
  PARCELA_ID=$(grep -A1 "POST $BASE_URL/agro/parcelas" -n "$LOGFILE" 2>/dev/null || true)
fi

# We'll try to parse the ID directly from the create response body using previous function call output saved in log
PARCELA_ID=$(tail -n 200 "$LOGFILE" | jq -r '.[0].id // .id // .data.id // .result.id' 2>/dev/null || true)

# If still empty, try a heuristic: list parcelas and take first id
if [[ -z "$PARCELA_ID" || "$PARCELA_ID" == "null" ]]; then
  LIST_OUT=$(http GET "/agro/parcelas" "" "$TOKEN")
  # LIST_OUT is status; last appended body is in logfile; parse last JSON array/object
  PARCELA_ID=$(tail -n 500 "$LOGFILE" | jq -r '.[0].id // .id // .data[0].id // .data[0]._id // .result[0].id // .result[0]._id' 2>/dev/null || true)
fi

if [[ -n "$PARCELA_ID" && "$PARCELA_ID" != "null" ]]; then
  http GET "/gateway/parcela-detallada/$PARCELA_ID" "" "$TOKEN" || true
  http GET "/agro/parcelas/$PARCELA_ID" "" "$TOKEN" || true
  UPDATE_PAYLOAD=$(jq -n --arg name "Parcela actualizada $(date +%s)" '{name: $name}')
  http PUT "/agro/parcelas/$PARCELA_ID" "$UPDATE_PAYLOAD" "$TOKEN" || true
  http DELETE "/agro/parcelas/$PARCELA_ID" "" "$TOKEN" || true
  http PATCH "/agro/parcelas/$PARCELA_ID/restore" "" "$TOKEN" || true
else
  echo "Could not determine a parcela id; skipping parcela-specific endpoint tests." | tee -a "$LOGFILE"
fi

########################################
# 4) Cultivos
########################################
http GET "/agro/cultivos" "" "$TOKEN" || true
CREAR_CULTIVO_PAYLOAD=$(jq -n '{name: "Cultivo prueba", season: "2025"}')
http POST "/agro/cultivos" "$CREAR_CULTIVO_PAYLOAD" "$TOKEN" || true

########################################
# 5) Users flow: list, get, update, delete, restore
########################################
http GET "/agro/users" "" "$TOKEN" || true
# Try to use self user id from login body
USER_ID=$(echo "$LOGIN_BODY" | jq -r '.user.id // .user._id // .data.user.id // .data.user._id // .id // ._id' 2>/dev/null || true)
if [[ -n "$USER_ID" && "$USER_ID" != "null" ]]; then
  http GET "/agro/users/$USER_ID" "" "$TOKEN" || true
  USER_UPDATE_PAYLOAD=$(jq -n --arg name "Usuario mod $(date +%s)" '{name: $name}')
  http PUT "/agro/users/$USER_ID" "$USER_UPDATE_PAYLOAD" "$TOKEN" || true
  http DELETE "/agro/users/$USER_ID" "" "$TOKEN" || true
  http PATCH "/agro/users/$USER_ID/restore" "" "$TOKEN" || true
else
  echo "No user id available from login; skipping per-user tests." | tee -a "$LOGFILE"
fi

########################################
# 6) Sensores and Lecturas (Node service)
########################################
http GET "/sensores" "" "$TOKEN" || true
SENSOR_PAYLOAD=$(jq -n '{name: "Sensor prueba", type: "temp", unit: "C"}')
http POST "/sensores" "$SENSOR_PAYLOAD" "$TOKEN" || true

http GET "/lecturas" "" "$TOKEN" || true
LECTURA_PAYLOAD=$(jq -n '{sensorId: null, value: 23.5, timestamp: "'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'"}')
http POST "/lecturas" "$LECTURA_PAYLOAD" "$TOKEN" || true

echo "Endpoint tests finished. Logs: $LOGFILE"

echo "Tip: inspect $LOGFILE for per-endpoint responses. If you run on Windows, use Git Bash or WSL to run this script."

chmod +x [test_endpoints.sh](http://_vscodecontentref_/2)
[test_endpoints.sh](http://_vscodecontentref_/3)
