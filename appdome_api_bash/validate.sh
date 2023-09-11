#!/bin/bash
source "$(dirname "$0")/../utils.sh"




help() {
  # Display Help
  echo "-key  |  --api_key                          Appdome API key (required)"
  echo "-a    |  --app                              Application location (required)"
  echo "-o    |  --output                           Output file location (optional)"
  echo
}

validate_inputs() {
  if [[ "$APP_LOCATION" == *".ipa" ]]; then
    PLATFORM=IOS
  elif [[ "$APP_LOCATION" == *".aab" || "$APP_LOCATION" == *".apk" ]]; then
    PLATFORM=ANDROID
  else
    echo "No application provided. Exiting.."
    exit 1
  fi
}


parse_args() {
  while true; do
    case "$1" in
    -key | --api_key)
      API_KEY="$2"
      shift 2
      ;;
    -a | --app)
      APP_LOCATION="$2"
      APP_FILE_NAME="$(basename -- "$APP_LOCATION")"
      shift 2
      ;;
    -o | --output)
      OUTPUT_LOCATION="$2"
      shift 2
      ;;
    -- | *)
      break
      ;;
    esac
  done
  validate_inputs
}

SERVER_URL="${APPDOME_SERVER_BASE_URL:-https://fusion.appdome.com}"
API_KEY="${API_KEY_ENV:-}"
APP_LOCATION=''
PLATFORM=''
APP_FILE_NAME="$(basename -- "$APP_LOCATION")"

if [[ -z "$APPDOME_CLIENT_HEADER" ]]; then
  APPDOME_CLIENT_HEADER='Appdome-cli-bash/1.0'
else
  APPDOME_CLIENT_HEADER=$(printenv APPDOME_CLIENT_HEADER)
fi
 

validation_upload(){
    local operation="Upload app to validate"
    echo "Uploading App To Validate..."
    start_upload_to_validate_time=$(date +%s)
    local URL="$SERVER_URL/api/v1/validation/upload"
    local headers="$(request_headers)"
    local request="curl -s -w "%{http_code}" --request POST \
     --url "$URL" \
     $headers \
     --form file=@$APP_LOCATION"


    app_id=$(eval $request)

    validate_response_for_errors "$app_id" $operation
    app_id=$(extract_string_value_from_json "$app_id" "id")
    echo "App-id: $app_id"
    echo
    printTime $((($(date +%s) - start_upload_to_validate_time))) "Upload took: "
    validation_status $app_id
}


validation_status(){
    local operation="Validate App"
    echo "Validating App..."

    start_validate_time=$(date +%s)
    local app_id="$1"
    local URL="$SERVER_URL/api/v1/validation/"$app_id"/status" \

    statusWaiter  "$URL" "$(request_headers)" "$operation"
    echo
    printTime $((($(date +%s) - start_validate_time))) "Validation took: "
    echo
}

extract_string_value_from_validate_json() {
  # Remove whitespace characters from the JSON
  json=$(echo "$1" | tr -d '[:space:]')
  # Extract the value of "validation_state"
  validation_state=$(echo "$json" | grep -o "\"$2\":\"[^\"]*" | cut -d':' -f2 | tr -d '"')
  echo "$validation_state"
}

statusWaiter() {
  STATUS_RESPONSE='"validation_state":"active"'
  local URL="$1"
  local headers="$2"
  local request="curl -s --request GET \
                    --url $URL \
                    $headers"
  while [ "$(echo "$STATUS_RESPONSE" | grep -c '"validation_state":"active"')" -gt 0 ]
  do
    echo 
    STATUS_RESPONSE="$(eval "$request")"
    printf '.'
    sleep 1
  done
  echo
  STATUS=$(extract_string_value_from_validate_json "$STATUS_RESPONSE" "validation_state")
  if [[ $STATUS != "completed" ]]; then
    echo "$3 failed"
    echo "Reason: $STATUS_RESPONSE"
    exit 1
  else
    echo "$3 done"
    if [[ -n "$OUTPUT_LOCATION" ]]; then
      local output_file="$OUTPUT_LOCATION"
      touch "$output_file"
      echo "$STATUS_RESPONSE" > "$output_file"
    fi
    print_json "$STATUS_RESPONSE"
  fi
}

print_json() {
    json="$1"

    # Extract the validation_state field
    validation_state=$(echo "$json" | grep -o '"validation_state":"[^"]*' | cut -d':' -f2 | tr -d '"')
    echo
    echo "Appdome Validation Results:"
    echo "--------------------------"
    # Print the validation_state field
    echo "validation_state:$validation_state"

    # Extract and format the messages
    messages=$(echo "$json" | grep -o '"message":"[^"]*' | cut -d':' -f2 | tr -d '"' | sed 's/,/, /g; s/, /,\n/g')
    
    # Print the formatted messages
    echo "$messages"

    # Check and print specific fields if they exist
    print_field_if_exists "build_id"
    print_field_if_exists "app_type"
    print_field_if_exists "app_name"
    print_field_if_exists "app_pack_id"
    print_field_if_exists "app_version"
    print_field_if_exists "app_build_number"
    print_field_if_exists "app_id"
}


# Check if a field exists in the JSON and print it if it does
print_field_if_exists() {
    field_name="$1"
    field_value=$(echo "$json" | grep -o "\"$field_name\":\"[^\"]*" | cut -d':' -f2 | tr -d '"')
    if [ -n "$field_value" ]; then
        echo "$field_name:$field_value"
    fi
}




main() {
    parse_args "$@"
    start_all_process_time=$(date +%s)
    echo "Starting Appdome Validation flow"
    echo "" 
    # Call validation_upload and store the app_id
    validation_upload
    printTime $((($(date +%s) - start_all_process_time))) "Appdome Validate app took: "
    
}


main "$@"