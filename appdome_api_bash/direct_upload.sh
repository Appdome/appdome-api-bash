#!/bin/bash
source ./utils.sh

direct_upload() {
  operation="Direct upload"

  echo "Starting direct upload"
  echo ""
  start_upload_time=$(date +%s)
  local url="$SERVER_URL/api/v1/upload"
  if [[ -n "$TEAM_ID" && "$TEAM_ID" != "personal" ]]; then
    url="${url}?team_id=${TEAM_ID}"
  fi
  notification_form="$(parse_notification_form)"
  local request="curl -s -X POST \"$url\" \
    --header \"Authorization: $API_KEY\" \
    --header \"X-Appdome-Client: $APPDOME_CLIENT_HEADER\" \
    -F \"file=@${APP_LOCATION}\" \
    $notification_form"
  APP="$(eval $request)"
  validate_response_for_errors "$APP" "$operation"

  printTime $((($(date +%s) - start_upload_time))) "Upload took: "
  echo "App-id: $(extract_string_value_from_json "$APP" "id")"
  echo ""
}
