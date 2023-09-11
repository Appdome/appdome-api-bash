#!/bin/bash
source ./utils.sh

statusWaiter() {
  echo ""
  STATUS="progress"
  while [ X"$STATUS" = X"progress" ]
  do
    local headers="$(request_headers)"
    local request="curl -s --request GET \
                    --url '$SERVER_URL/api/v1/tasks/$TASK_ID/status?team_id=$TEAM_ID' \
                    $headers"
    STATUS_RESPONSE="$(eval $request)"
    STATUS=$(extract_string_value_from_json $STATUS_RESPONSE "status")
    sleep 1
    printf '.'
  done

  if [[ $STATUS != "completed" ]]; then
    echo "$1 failed"
    local reason=$(extract_string_value_from_json $STATUS "message")
    echo "Reason: $STATUS_RESPONSE"
    exit 1
  else
    echo "$1 done"
  fi
}