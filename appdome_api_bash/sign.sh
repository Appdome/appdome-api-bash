#!/bin/bash
source ./appdome_api_bash/status.sh
source ./utils.sh

SIGN_ACTION='sign'

sign_ios() {
  local operation="Sign app"
  echo "Starting iOS Signing On Appdome"
  start_sign_time=$(date +%s)
  add_sign_overrides "signing_p12_password" "$KEYSTORE_PASS"
  if [ ${#ENTITLEMENTS[@]} -gt 0 ]; then
    add_sign_overrides "manual_entitlements_matching" "true"
  fi
  local headers="$(request_headers)"
  local provisioning_profiles_entitlements=$(add_provisioning_profiles_entitlements)
  local request="curl -s --request POST \
                  --url '$SERVER_URL/api/v1/tasks?team_id=$TEAM_ID' \
                  $headers \
                  --form 'action=$SIGN_ACTION' \
                  --form 'parent_task_id=$TASK_ID' \
                  --form 'signing_p12_content=@$SIGNING_KEYSTORE' \
                  $provisioning_profiles_entitlements \
                  --form 'overrides=\"$(echo $SIGN_OVERRIDES | sed 's/"/\\\"/g')\"'"
  SIGN="$(eval $request)"
  validate_response_for_errors "$SIGN" $operation
  statusWaiter "$operation"
  printTime $((($(date +%s) - start_sign_time))) "Sign took: "
  echo ""
}

sign_android() {
  local operation="Sign app"
  
  echo "Starting Android Signing On Appdome"
  if [[ -n "$GOOGLE_PLAY_SIGNING" ]]; then
    add_google_play_signing_fingerprint
  fi
  add_sign_overrides "signing_keystore_password" "$KEYSTORE_PASS"
  add_sign_overrides "signing_keystore_alias" "$KEYSTORE_ALIAS"
  add_sign_overrides "signing_keystore_key_password" "$KEYS_PASS"
  start_sign_time=$(date +%s)

  local headers="$(request_headers)"
  local request="curl -s --request POST \
                  --url '$SERVER_URL/api/v1/tasks?team_id=$TEAM_ID' \
                  $headers \
                  --form action='$SIGN_ACTION' \
                  --form parent_task_id='$TASK_ID' \
                  --form signing_keystore='@$SIGNING_KEYSTORE' \
                  --form overrides='$(echo "$SIGN_OVERRIDES")'"

  SIGN="$(eval $request)"
  validate_response_for_errors "$SIGN" $operation
  statusWaiter "$operation"
  printTime $((($(date +%s) - start_sign_time))) "Sign took: "
  echo
}
