#!/bin/bash
source ./utils.sh

download_fused_app() {
  local operation="Download app"
  local url="--url '$SERVER_URL/api/v1/tasks/$TASK_ID/output?team_id=$TEAM_ID'"
  download "$operation" "$url" "$FINAL_OUTPUT_LOCATION"
}

download_deobfuscation_script() {
  local operation="Download deobfuscation script"
  local url="--url '$SERVER_URL/api/v1/tasks/$TASK_ID/output?team_id=$TEAM_ID&action=deobfuscation_script'"
  download "$operation" "$url" "$DEOBFUSCATION_SCRIPT_OUTPUT_LOCATION"
}

download_certified_secure() {
  local operation="Download Certified Secure"
  local url="--url '$SERVER_URL/api/v1/tasks/$TASK_ID/certificate?team_id=$TEAM_ID'"
  download "$operation" "$url" "$CERTIFICATE_OUTPUT_LOCATION"
}

download_second_output() {
  local operation="Download Second Output"
  local url="--url '$SERVER_URL/api/v1/tasks/$TASK_ID/output?team_id=$TEAM_ID&action=sign_second_output'"
  download "$operation" "$url" "$SECOND_OUTPUT_FILE"
}

download() {
  echo "Starting $1"
  start_download_time=$(date +%s)

  local headers="$(request_headers)"
  local request="curl -s -w \"%{http_code}\" --location --request GET \
                  $2 \
                  $headers \
                  -o '$3'"
  DOWNLOAD="$(eval $request)"
  validate_response_code "$DOWNLOAD" "$1" $3

  printTime $((($(date +%s) - start_download_time))) "$1 took: " 
  echo ""
}
