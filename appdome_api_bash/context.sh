#!/bin/bash
source ./appdome_api_bash/status.sh

context() {
  echo "Starting Context"
  start_context_time=$(date +%s)

  local headers="$(request_headers)"
  local request="curl -s --request POST \
                  --url '$SERVER_URL/api/v1/tasks?team_id=$TEAM_ID' \
                  $headers \
                  --form action=context \
                  --form parent_task_id='$TASK_ID' \
                  --form overrides='$(echo "$CONTEXT_OVERRIDES")'"
  eval $request
  statusWaiter 
  printTime $((($(date +%s) - start_context_time))) "Context took: "
  echo ""
}
