#!/bin/bash
source ./appdome_api_bash/status.sh
source ./utils.sh

build() {
  local operation="Build app"
  echo "Starting build"
  start_build_time=$(date +%s)
  if [[ -z "$APP" ]]; then
    echo "invalid arguments - build"
    exit 1
  fi

  if [[ -n $BUILD_KEY ]]; then	
  	add_build_overrides $BUILD_KEY $BUILD_VALUE
  fi
  local headers="$(request_headers)"
  local request="curl -s --request POST \
                  --url '$SERVER_URL/api/v1/tasks?team_id=$TEAM_ID' \
                  $headers \
                  --form action=fuse \
                  --form fusion_set_id='$FUSION_SET_ID' \
                  --form app_id='$(extract_string_value_from_json "$APP" "id")' \
                  --form overrides='$(echo "$BUILD_OVERRIDES")'"
  
  TASK_ID="$(eval $request)"
  validate_response_for_errors "$TASK_ID" $operation
  TASK_ID=$(extract_string_value_from_json $TASK_ID "task_id")
  statusWaiter $operation
  printTime $((($(date +%s) - start_build_time))) "Build took: "
  echo "Task-id: $TASK_ID"
  echo ""
}
