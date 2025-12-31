#!/bin/bash
source ./utils.sh

get_upload_link() {
  local operation="Upload app"
  publicLink=$(curl -s --request GET \
    --url "$SERVER_URL/api/v1/upload-link?team_id=$TEAM_ID" \
    --header "Authorization: $API_KEY")

  validate_response_for_errors "$publicLink" $operation
}

upload_to_aws() {
  local operation="Upload app"
  aws_put_response=$(curl -s -X PUT "$(extract_string_value_from_json "$publicLink" "url")" \
    --header 'Content-Type: application/x-compressed-tar' \
    -T "${APP_LOCATION}")

  validate_response_for_errors "$aws_put_response" $operation
}

upload_using_link() {
  local operation="Upload app"
  local notification_form="$(parse_notification_form)"
  local request="curl -s --request POST \
      --url \"$SERVER_URL/api/v1/upload-using-link?team_id=$TEAM_ID\" \
      --header \"Authorization: $API_KEY\" \
      --header 'content-type: multipart/form-data' \
      --header \"X-Appdome-Client:$APPDOME_CLIENT_HEADER\" \
      --form file_name=\"$APP_FILE_NAME\" \
      --form file_app_id=\"$(extract_string_value_from_json "$publicLink" "file_id")\" \
      $notification_form"
  APP="$(eval $request)"
  validate_response_for_errors "$APP" $operation
}

upload() {
  echo "Starting upload"
  echo ""
  start_upload_time=$(date +%s)
  
  get_upload_link
  upload_to_aws
  upload_using_link
  
  printTime $((($(date +%s) - start_upload_time))) "Upload took: "
  echo "App-id: $(extract_string_value_from_json "$APP" "id")"
  echo ""
}
