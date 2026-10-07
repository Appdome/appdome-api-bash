#!/bin/bash
source ./appdome_api_bash/status.sh
source ./appdome_api_bash/download.sh
source ./utils.sh

start_appdome_test() {
  local operation="Start Appdome Test"
  log_info "Starting Appdome Test"
  local url="$SERVER_URL/api/v1/tasks?team_id=$TEAM_ID"
  local headers="$(request_headers)"
  local request="curl -s --request POST \
                  --url '$url' \
                  $headers \
                  --form action=appdome_test \
                  --form parent_task_id='$PARENT_TASK_ID'"
  debug_log_request post "$url" "action=appdome_test parent_task_id=$PARENT_TASK_ID"
  local response
  response="$(eval $request)"
  validate_response_for_errors "$response" "$operation"
  TASK_ID=$(extract_string_value_from_json "$response" "task_id")
  if [[ -z "$TASK_ID" ]]; then
    log_and_exit "$operation failed. Could not parse task_id from response: $(_truncate_value "$response")"
  fi
  log_info "Appdome Test started. Task-id: $TASK_ID"
}

run_appdome_test() {
  TASK_ID="$PARENT_TASK_ID"
  local headers="$(request_headers)"
  local status_response
  status_response=$(eval "curl -s --request GET --url '$SERVER_URL/api/v1/tasks/$TASK_ID/status?team_id=$TEAM_ID' $headers")
  validate_response_for_errors "$status_response" "Get task status"
  local current_status
  current_status=$(extract_string_value_from_json "$status_response" 'status')

  if [[ "$current_status" == "error" ]]; then
    local message
    message=$(extract_string_value_from_json "$status_response" 'message')
    if [[ -z "$message" ]]; then
      message="$status_response"
    fi
    log_and_exit "Task not completed successfully. Response: $message"
  fi

  if [[ "$current_status" == "progress" ]]; then
    log_info "Appdome Test is already running."
    if [[ "$WAIT" == "true" || -n "$APPDOME_TEST_RESULTS" ]]; then
      if [[ -n "$APPDOME_TEST_RESULTS" ]]; then
        log_info "Waiting for it to finish before downloading results."
      fi
      statusWaiter "Appdome Test"
      if [[ -n "$APPDOME_TEST_RESULTS" ]]; then
        download "Download Appdome Test results" \
          "--url '$SERVER_URL/api/v1/tasks/$TASK_ID/appdome-test-result?team_id=$TEAM_ID'" \
          "$APPDOME_TEST_RESULTS"
      fi
    fi
    return
  fi

  if [[ "$current_status" == "completed" && -n "$APPDOME_TEST_RESULTS" ]]; then
    directory=$(dirname "$APPDOME_TEST_RESULTS")
    if [[ -n "$directory" && "$directory" != "." && ! -d "$directory" ]]; then
      mkdir -p "$directory"
    fi
    local result_code
    result_code=$(eval "curl -s -w \"%{http_code}\" --location --request GET \
      --url '$SERVER_URL/api/v1/tasks/$TASK_ID/appdome-test-result?team_id=$TEAM_ID' \
      $headers \
      -o '$APPDOME_TEST_RESULTS'")
    if [[ "$result_code" == "200" ]]; then
      log_info "Downloaded output file to $APPDOME_TEST_RESULTS"
      return
    fi
    rm -f "$APPDOME_TEST_RESULTS"
  fi

  start_appdome_test

  if [[ "$WAIT" == "true" || -n "$APPDOME_TEST_RESULTS" ]]; then
    statusWaiter "Appdome Test"
  fi

  if [[ -n "$APPDOME_TEST_RESULTS" ]]; then
    download "Download Appdome Test results" \
      "--url '$SERVER_URL/api/v1/tasks/$TASK_ID/appdome-test-result?team_id=$TEAM_ID'" \
      "$APPDOME_TEST_RESULTS"
  fi
}
