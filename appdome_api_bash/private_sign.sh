#!/bin/bash
source ./appdome_api_bash/status.sh
source ./utils.sh
PRIVATE_SIGN_ACTION='seal'

private_sign_ios() {
  local operation="Sign app"

  echo "Starting iOS Private Signing"
  start_sign_time=$(date +%s)

  local headers="$(request_headers)"
  local provisioning_profiles_entitlements=$(add_provisioning_profiles_entitlements)
  local request="curl -s --request POST \
                  --url '$SERVER_URL/api/v1/tasks?team_id=$TEAM_ID' \
                  $headers \
                  --form action='$PRIVATE_SIGN_ACTION' \
                  --form parent_task_id='$TASK_ID' \
                  $provisioning_profiles_entitlements \
                  --form overrides='$(echo "$SIGN_OVERRIDES")'"
  SIGN="$(eval $request)"
  validate_response_for_errors "$SIGN" $operation
  statusWaiter "$operation"
  echo "Sign took: "
  printTime $((($(date +%s) - start_sign_time)))
  echo ""
}

private_sign_android() {
  local operation="Sign app"
  
  echo "Starting Android Private Signing"
  if [[ -n "$GOOGLE_PLAY_SIGNING" ]]; then
    add_google_play_signing_fingerprint
    if [[ -n "$SIGNING_FINGERPRINT_UPGRADE" ]]; then
      add_sign_overrides "signing_keystore_google_signing_upgrade" "true"
      add_sign_overrides "signing_keystore_google_signing_sha1_key_2nd_cert" "$SIGNING_FINGERPRINT_UPGRADE"
    fi
  else
    add_sign_overrides "signing_sha1_fingerprint" "$SIGNING_FINGERPRINT"
  fi
  start_sign_time=$(date +%s)

  local headers="$(request_headers)"
  local request="curl -s --request POST \
                  --url '$SERVER_URL/api/v1/tasks?team_id=$TEAM_ID' \
                  $headers \
                  --form action='$PRIVATE_SIGN_ACTION' \
                  --form parent_task_id='$TASK_ID' \
                  --form overrides='$(echo "$SIGN_OVERRIDES")'"

  SIGN="$(eval $request)"
  validate_response_for_errors "$SIGN" $operation
  statusWaiter "$operation"
  printTime $((($(date +%s) - start_sign_time))) "Sign took: "
  echo ""
}
