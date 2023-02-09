#!/bin/bash
download() {
  echo "Starting Download"
  start_download_time=$(date +%s)

  local headers="$(request_headers)"
  local request="curl -s --location --request GET \
                  --url '$SERVER_URL/api/v1/tasks/$TASK_ID/output?team_id=$TEAM_ID' \
                  $headers \
                  -o '$FINAL_OUTPUT_LOCATION'"
  eval $request
  
  printTime $((($(date +%s) - start_download_time))) "Download took: " 
  echo ""
}
