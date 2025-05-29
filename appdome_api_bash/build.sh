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

  URL="$SERVER_URL/api/v1/tasks?team_id=$TEAM_ID"

  if [[ -n $BUILD_KEY ]]; then	
  	add_build_overrides $BUILD_KEY $BUILD_VALUE
  fi

if [[ -n $BUILD_TO_TEST ]] && [[ -n ${BUILD_TO_TEST+x} ]]; then
    add_build_overrides "build_to_test_vendor" "$BUILD_TO_TEST"
    URL="$SERVER_URL/api/v1/build-to-test?team_id=$TEAM_ID"
    local operation="Build app to test"
  fi
  local headers="$(request_headers)"
  local request="curl -s --request POST \
                  --url "$URL" \
                  $headers \
                  --form action=fuse \
                  --form fusion_set_id='$FUSION_SET_ID' \
                  --form app_id='$(extract_string_value_from_json "$APP" "id")'"
  if [[ -n "$BASELINE_PROFILE" && -f "$BASELINE_PROFILE" ]]; then
    request+=" --form baseline_profile=@\"$BASELINE_PROFILE\""
  fi
  # Add overrides
  request+=" --form overrides='$(echo "$BUILD_OVERRIDES")'"
  # Add certificate pinning files if provided
  if [[ -n "$CERT_ZIP" ]]; then
    certs=$(init_certs_pinning "$CERT_ZIP")
    request+=" $certs"
  fi
  TASK_ID="$(eval $request)"
  validate_response_for_errors "$TASK_ID" $operation
  TASK_ID=$(extract_string_value_from_json $TASK_ID "task_id")
  statusWaiter $operation
  printTime $((($(date +%s) - start_build_time))) "Build took: "
  echo "Task-id: $TASK_ID"
  echo ""
}
