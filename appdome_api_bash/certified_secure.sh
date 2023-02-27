#!/bin/bash
source ./utils.sh

download_certified_secure() {
  local operation="Download Certified Secure"
  
  echo "Starting Download Certified Secure"
  start_download_time=$(date +%s)

  local headers="$(request_headers)"
  local request="curl -s -w \"%{http_code}\" --location --request GET \
                  --url '$SERVER_URL/api/v1/tasks/$TASK_ID/certificate?team_id=$TEAM_ID' \
                  $headers \
                  -o '$CERTIFICATE_OUTPUT_LOCATION'"
  DOWNLOAD="$(eval $request)"
  validate_response_code "$DOWNLOAD" "$operation" $CERTIFICATE_OUTPUT_LOCATION

  printTime $((($(date +%s) - start_download_time))) "Download took: "
  echo ""
}
