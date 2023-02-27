#!/bin/bash
source ./utils.sh

download() {
  local operation="Download app"
  
  echo "Starting Download Secured App"
  start_download_time=$(date +%s)

  local headers="$(request_headers)"
  local request="curl -s -w \"%{http_code}\" --location --request GET \
                  --url '$SERVER_URL/api/v1/tasks/$TASK_ID/output?team_id=$TEAM_ID' \
                  $headers \
                  -o '$FINAL_OUTPUT_LOCATION'"
  DOWNLOAD="$(eval $request)"
  validate_response_code "$DOWNLOAD" "$operation" $FINAL_OUTPUT_LOCATION

  printTime $((($(date +%s) - start_download_time))) "Download took: " 
  echo ""
}
