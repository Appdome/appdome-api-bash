#!/bin/bash
source ./appdome_api_bash/status.sh
source ./utils.sh

AUTO_DEV_SIGN_ACTION='sign_script'

auto_sign_ios() {
  local operation="Sign app"
  
  echo "Starting iOS Auto-DEV Private Signing"
  start_sign_time=$(date +%s)
  if [ ${#ENTITLEMENTS[@]} -gt 0 ]; then
    add_sign_overrides "manual_entitlements_matching" "true"
  fi

  local headers="$(request_headers)"
  local provisioning_profiles_entitlements=$(add_provisioning_profiles_entitlements)
  local request="curl -s --request POST \
                  --url '$SERVER_URL/api/v1/tasks?team_id=$TEAM_ID' \
                  $headers \
                  --form action='$AUTO_DEV_SIGN_ACTION' \
                  --form parent_task_id='$TASK_ID' \
                  $provisioning_profiles_entitlements \
                  --form overrides='$(echo "$SIGN_OVERRIDES")'"
  SIGN="$(eval $request)"
  validate_response_for_errors "$SIGN" $operation
  statusWaiter "$operation"
  printTime $((($(date +%s) - start_sign_time))) "Sign took: "
  echo ""
}

auto_sign_android() {
  local operation="Sign app"

  echo "Starting Android Auto-DEV Private Signing"
  if [[ -n "$GOOGLE_PLAY_SIGNING" ]]; then
    add_google_play_signing_fingerprint
  else
    add_sign_overrides "signing_sha1_fingerprint" "$SIGNING_FINGERPRINT"
  fi
  start_sign_time=$(date +%s)

  local headers="$(request_headers)"
  local request="curl -s --request POST \
                  --url '$SERVER_URL/api/v1/tasks?team_id=$TEAM_ID' \
                  $headers \
                  --form action='$AUTO_DEV_SIGN_ACTION' \
                  --form parent_task_id='$TASK_ID' \
                  --form overrides='$(echo "$SIGN_OVERRIDES")'"

  SIGN="$(eval $request)"
  validate_response_for_errors "$SIGN" $operation
  statusWaiter "$operation"
  printTime $((($(date +%s) - start_sign_time))) "Sign took: "
  echo ""
}
