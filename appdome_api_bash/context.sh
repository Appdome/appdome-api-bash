#!/bin/bash
source ./appdome_api_bash/status.sh
source ./utils.sh

context() {
  local operation="Context"
  
  echo "Starting Context"
  start_context_time=$(date +%s)

  local headers="$(request_headers)"
  local notification_form="$(parse_notification_form)"
  local request="curl -s --request POST \
                  --url '$SERVER_URL/api/v1/tasks?team_id=$TEAM_ID' \
                  $headers \
                  --form action=context \
                  --form parent_task_id='$TASK_ID' \
                  --form overrides='$(echo "$CONTEXT_OVERRIDES")' \
                  $notification_form"
  CONTEXT="$(eval $request)"
  validate_response_for_errors "$CONTEXT" $operation
  
  printTime $((($(date +%s) - start_context_time))) "Context took: "
  echo ""
}
