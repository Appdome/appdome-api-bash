#!/bin/bash
source ./utils.sh
source ./appdome_api_bash/check_by_checksum.sh

get_upload_link() {
  local operation="Upload app"
  local url="$SERVER_URL/api/v1/upload-link?team_id=$TEAM_ID"
  debug_log_request get "$url"
  publicLink=$(curl -s --request GET \
    --url "$url" \
    --header "Authorization: $API_KEY" \
    --header "X-Appdome-Client: $APPDOME_CLIENT_HEADER")

  log_debug "Upload link response: $(_truncate_value "$publicLink")"
  validate_response_for_errors "$publicLink" $operation
}

upload_to_aws() {
  local operation="Upload app"
  local aws_url
  aws_url=$(extract_string_value_from_json "$publicLink" "url")
  if [[ -z "$aws_url" ]]; then
    log_and_exit "Error in upload link response: $(_truncate_value "$publicLink")"
  fi
  debug_log_request put "$aws_url" "file=$APP_LOCATION"
  aws_put_response=$(curl -s -X PUT "$aws_url" \
    --header 'Content-Type: application/x-compressed-tar' \
    -T "${APP_LOCATION}")

  validate_response_for_errors "$aws_put_response" $operation
}

upload_using_link() {
  local operation="Upload app"
  local file_id
  file_id=$(extract_string_value_from_json "$publicLink" "file_id")
  if [[ -z "$file_id" ]]; then
    log_and_exit "Error in upload link response: $(_truncate_value "$publicLink")"
  fi
  local url="$SERVER_URL/api/v1/upload-using-link?team_id=$TEAM_ID"
  debug_log_request post "$url" "file_name=$APP_FILE_NAME"
  APP=$(
    curl -s --request POST \
      --url "$url" \
      --header "Authorization: $API_KEY" \
      --header 'content-type: multipart/form-data' \
      --header "X-Appdome-Client:$APPDOME_CLIENT_HEADER" \
      --form file_name="$APP_FILE_NAME" \
      --form file_app_id="$file_id"
  )
  validate_response_for_errors "$APP" $operation
  local app_id
  app_id=$(extract_string_value_from_json "$APP" "id")
  if [[ -z "$app_id" ]]; then
    log_and_exit "Error in upload response: $(_truncate_value "$APP")"
  fi
}

upload() {
  log_info "Starting upload"
  start_upload_time=$(date +%s)

  if try_use_existing_app_by_checksum; then
    printTime $((($(date +%s) - start_upload_time))) "Upload took: "
    log_info "Upload done. App-id: $(extract_string_value_from_json "$APP" "id")"
    return
  fi

  get_upload_link
  upload_to_aws
  upload_using_link
  
  printTime $((($(date +%s) - start_upload_time))) "Upload took: "
  log_info "Upload done. App-id: $(extract_string_value_from_json "$APP" "id")"
}
