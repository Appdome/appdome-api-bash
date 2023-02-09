#!/bin/bash

get_upload_link() {
  publicLink=$(curl -s --request GET \
    --url "$SERVER_URL/api/v1/upload-link?team_id=$TEAM_ID" \
    --header "Authorization: $API_KEY")
}

upload_to_aws() {
  curl -s -X PUT "$(echo "$publicLink" | jq -r .url)" \
    --header 'Content-Type: application/x-compressed-tar' \
    -T "${APP_LOCATION}"
}

upload_using_link() {
  APP=$(
    curl -s --request POST \
      --url "$SERVER_URL/api/v1/upload-using-link?team_id=$TEAM_ID" \
      --header "Authorization: $API_KEY" \
      --header 'content-type: multipart/form-data' \
      --header "X-Appdome-Client:$APPDOME_CLIENT_HEADER" \
      --form file_name="$APP_FILE_NAME" \
      --form file_app_id="$(echo "$publicLink" | jq -r .file_id)"
  )
}

upload() {
  echo "Starting upload"
  echo ""
  start_upload_time=$(date +%s)
  
  get_upload_link
  upload_to_aws
  upload_using_link
  
  printTime $((($(date +%s) - start_upload_time))) "Upload took: "
  echo "App-id: $(echo "$APP" | jq -r .id)"
  echo ""
}
