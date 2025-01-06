#!/bin/bash
source "utils.sh"

help() {
  # Display Help
  echo "-key   |  --api_key                           Appdome API key (required)"
  echo "-fs    |  --fusion_set_id                     Fusion set id to release (required)"
  echo "-ti    |  --team_id                           The team id that will received the released fusion set (required)"
  echo
}

validate_inputs() {
  if [ -z "$API_KEY" ]; then
    echo "No api key provided. Exiting.."
    exit 1
  elif [ -z "$FUSION_SET_ID" ]; then
    echo "No fusion set id to release provided. Exiting.."
    exit 1
  elif [ -z "$TEAM_ID" ]; then
    echo "No team id provided. Exiting.."
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
    -fs | --fusion_set_id)
      FUSION_SET_ID="$2"
      shift 2
      ;;
    -ti | --team_id)
      TEAM_ID="$2"
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

assign_client_header

release_fusion_set(){
    local operation="Release fustion set"
    local URL="$SERVER_URL/api/v1/release_fs/$FUSION_SET_ID?team_id=$TEAM_ID"

    local request="curl -s --request POST \
                  --url "$URL" \
                  --header 'Authorization: $(request_api_key)' \
                  --header 'Content-Type: application/json' \
                  --header 'X-Appdome-Client:$APPDOME_CLIENT_HEADER' \
                  --header 'accept: application/json'"
  
    NEW_FUSION_SET_ID_RESPONSE="$(eval $request)"
    validate_response_for_errors "$NEW_FUSION_SET_ID_RESPONSE" $operation
    NEW_FUSION_SET_ID=$(extract_string_value_from_json $NEW_FUSION_SET_ID_RESPONSE "new_fusion_set_id")

    validate_response_for_errors "$STATUS_RESPONSE" $operation
    echo "Fusion-set $FUSION_SET_ID was successfully released to team: $TEAM_ID"
    echo "New Fusion-set id: $NEW_FUSION_SET_ID"
}

main() {
    parse_args "$@"
    echo "Releasing fusion-set-id: $FUSION_SET_ID to team: $TEAM_ID"
    echo "" 
    release_fusion_set
}

main "$@"