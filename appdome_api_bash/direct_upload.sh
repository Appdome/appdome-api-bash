#!/bin/bash
source ./utils.sh

direct_upload() {
  operation="Direct upload"

  log_info "Starting direct upload"
  start_upload_time=$(date +%s)
  local url="$SERVER_URL/api/v1/upload"
  if [[ -n "$TEAM_ID" && "$TEAM_ID" != "personal" ]]; then
    url="${url}?team_id=${TEAM_ID}"
  fi
  debug_log_request post "$url" "file=$APP_LOCATION"
  APP=$(curl -s -X POST "$url" \
    --header "Authorization: $API_KEY" \
    --header "X-Appdome-Client: $APPDOME_CLIENT_HEADER" \
    -F "file=@${APP_LOCATION}")
  validate_response_for_errors "$APP" "$operation"

  printTime $((($(date +%s) - start_upload_time))) "Upload took: "
  log_info "Upload done. App-id: $(extract_string_value_from_json "$APP" "id")"
}
