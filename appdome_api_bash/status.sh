#!/bin/bash
source ./utils.sh

statusWaiter() {
  echo ""
  STATUS="progress"
  local lastDate="$(date -u +"%Y-%m-%dT00:00:00Z")"
  local operation="$1"
  local file_path=$WORKFLOW_OUTPUT_LOGS
  local isMessages=false
  
  if [[ -n "$file_path" ]]; then
    echo "$operation" >> "$file_path"
    echo "" >> "$file_path"
    isMessages=true
  fi

  while [ "$STATUS" = "progress" ]; do
    local base_url="$SERVER_URL/api/v1/tasks/$TASK_ID/status?team_id=$TEAM_ID"

    if [[ "$isMessages" == true ]]; then
      base_url+="&messages=true&lastDate=$lastDate"
    fi
    STATUS_RESPONSE=$(curl -s -w "\n%{http_code}" --request GET \
      --url "$base_url" \
      --header "Authorization: $(request_api_key)" \
      --header "Content-Type: application/json" \
      --header "accept: application/json")

    HTTP_BODY=$(echo "$STATUS_RESPONSE" | sed '$d')
    HTTP_CODE=$(echo "$STATUS_RESPONSE" | tail -n1)

    if [[ "$HTTP_CODE" -ne 200 ]]; then
      echo "Error: Failed to get status from the server. HTTP Code: $HTTP_CODE"
      echo "Response Body: $HTTP_BODY"
      exit 1
    fi

    STATUS=$(echo "$HTTP_BODY" | jq -r '.status')

    if [[ "$isMessages" == true ]]; then
      local messages=$(echo "$HTTP_BODY" | jq -c '.messages[]?')
      if [[ -n "$messages" ]]; then
        echo "$messages" | while read -r message; do
          local message_text=$(echo "$message" | jq -r '.message.text // empty')
          local message_type=$(echo "$message" | jq -r '.message_type')
          local progress_total=$(echo "$message" | jq -r '.message.total // empty')
          local progress_current=$(echo "$message" | jq -r '.message.current // empty')

          if [[ -n "$message_text" ]]; then
            echo " - $message_text"
            if [[ -n "$file_path" ]]; then
              echo " - $message_text" >> "$file_path"
            fi
          fi
        done

        lastDate=$(echo "$HTTP_BODY" | jq -r '.messages | sort_by(.creation_time) | .[-1].creation_time')
      fi
      sleep 1
    else
      printf '.'
      sleep 1
    fi
  done

  if [[ "$STATUS" != "completed" ]]; then
    echo "$operation failed"
    local reason=$(echo "$HTTP_BODY" | jq -r '.message')
    echo "Reason: $reason"
    exit 1
  else
    echo "$operation done"
    if [[ -n "$file_path" ]]; then
      echo "Done $operation" >> "$file_path"
      echo "" >> "$file_path"
    fi
  fi
}

statusForObfuscation() {
  local headers="$(request_headers)"
  local request="curl -s --request GET \
                  --url '$SERVER_URL/api/v1/tasks/$TASK_ID/status?team_id=$TEAM_ID' \
                  $headers"
  local response="$(eval $request)"

  if [[ $(extract_string_value_from_json "$response" 'obfuscationMapExists') == "true" ]]; then
    return 0
  else
    return 1
  fi
}