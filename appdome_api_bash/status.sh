#!/bin/bash

statusWaiter() {
  echo ""
  STATUS="progress"
  while [ X"$STATUS" = X"progress" ]
  do
    local headers="$(request_headers)"
    local request="curl -s --request GET \
                    --url '$SERVER_URL/api/v1/tasks/$TASK_ID/status?team_id=$TEAM_ID' \
                    $headers |
                    jq -r '.status'"
    STATUS="$(eval $request)"
    sleep 1
    printf '.'
  done
  echo " done"
}