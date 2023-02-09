#!/bin/bash
download_certified_secure() {
  echo "Starting Download Certified Secure"
  start_download_time=$(date +%s)

  local headers="$(request_headers)"
  local request="curl -s --location --request GET \
                  --url '$SERVER_URL/api/v1/tasks/$TASK_ID/certificate?team_id=$TEAM_ID' \
                  $headers \
                  -o '$CERTIFICATE_OUTPUT_LOCATION'"
  eval $request

  printTime $((($(date +%s) - start_download_time))) "Download took: "
  echo ""
}
