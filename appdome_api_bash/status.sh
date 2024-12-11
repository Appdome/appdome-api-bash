#!/bin/bash
source ./utils.sh

statusWaiter() {
  echo ""
  STATUS="progress"
  local lastDate="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"  # Ensure URL-safe date formatting
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
      local encoded_lastDate=$(urlencode "$lastDate")
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

    STATUS=$(extract_string_value_from_json "$HTTP_BODY" 'status')

    if [[ "$isMessages" == true ]]; then
      local messages_exist=$(echo "$HTTP_BODY" | grep -o '"messages":\[\]')
      if [[ "$messages_exist" != '"messages":[]' ]]; then
        echo "$HTTP_BODY" | grep -o '"text":"[^"]*' | cut -d'"' -f4 | while read -r message_text; do
          echo " - $message_text"
          if [[ -n "$file_path" ]]; then
            echo " - $message_text" >> "$file_path"
          fi
        done
        local newDate=$(echo "$HTTP_BODY" | grep -o '"creation_time":"[^"]*' | cut -d'"' -f4 | tail -n1)
        if [[ -n "$newDate" ]]; then
          lastDate="$newDate"  # Only update lastDate if new messages were found
        fi
      fi
    else
      # If isMessages is false, just print dots
      printf '.'
    fi
    sleep 1
  done

  if [[ "$STATUS" != "completed" ]]; then
    echo "$operation failed"
    local reason=$(extract_string_value_from_json "$HTTP_BODY" 'message')
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

urlencode() {
    local length="${#1}"
    for (( i = 0; i < length; i++ )); do
        local c="${1:i:1}"
        case $c in
            [a-zA-Z0-9.~_-]) printf "$c" ;;
            *) printf '%%%02X' "'$c" ;;
        esac
    done
}

statusForObfuscation() {
  local headers="$(request_headers)"
  if [[ -n $TEAM_ID ]]; then
    local request="curl -s --request GET \
                  --url '$SERVER_URL/api/v1/tasks/$TASK_ID/status?team_id=$TEAM_ID' \
                  $headers"
  else
    local request="curl -s --request GET \
                  --url '$SERVER_URL/api/v1/tasks/$TASK_ID/status' \
                  $headers"
  fi

  local response="$(eval $request)"
  obfuscation_map_exists=$(echo $response | grep -o '"obfuscationMapExists":[^,]*' | grep -o 'true\|false')
  if [[ "$obfuscation_map_exists" == "true" ]]; then
    return 0
  else
    return 1
  fi
}
