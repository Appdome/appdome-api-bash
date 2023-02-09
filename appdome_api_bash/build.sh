#!/bin/bash
source ./appdome_api_bash/status.sh

build() {
  echo "Starting build"
  start_build_time=$(date +%s)
  if [[ -z "$APP" ]]; then
    echo "invalid arguments - build"
    exit 1
  fi

  local headers="$(request_headers)"
  local request="curl -s --request POST \
                  --url '$SERVER_URL/api/v1/tasks?team_id=$TEAM_ID' \
                  $headers \
                  --form action=fuse \
                  --form fusion_set_id='$FUSION_SET_ID' \
                  --form app_id='$(echo "$APP" | jq -r .id)' \
                  --form overrides='$(echo "$SIGN_OVERRIDES")' |
                  jq -r .task_id"
  
  TASK_ID="$(eval $request)"
  statusWaiter
  printTime $((($(date +%s) - start_build_time))) "Build took: "
  echo "Task-id: $TASK_ID"
  echo ""
}
