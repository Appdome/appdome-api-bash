#!/bin/bash
source ./appdome_api_bash/status.sh
source ./utils.sh

AUTO_DEV_SIGN_ACTION='sign_script'

auto_sign_ios() {
  echo "Starting iOS Auto-DEV Private Signing"
  start_sign_time=$(date +%s)

  local headers="$(request_headers)"
  local provisioning_profiles_entitlements=$(add_provisioning_profiles_entitlements)
  local request="curl -s --request POST \
                  --url '$SERVER_URL/api/v1/tasks?team_id=$TEAM_ID' \
                  $headers \
                  --form action='$AUTO_DEV_SIGN_ACTION' \
                  --form parent_task_id='$TASK_ID' \
                  $provisioning_profiles_entitlements \
                  --form overrides='$(echo "$SIGN_OVERRIDES")'"
  eval $request
  statusWaiter
  printTime $((($(date +%s) - start_sign_time))) "Sign took: "
  echo ""
}

auto_sign_android() {
  echo "Starting Android Auto-DEV Private Signing"
  if [[ -n "$GOOGLE_PLAY_SIGNING" ]]; then
    add_google_play_signing_fingerprint
  else
    SIGN_OVERRIDES=$(echo $SIGN_OVERRIDES | jq '.signing_sha1_fingerprint |= "'"$SIGNING_FINGERPRINT"'"')
  fi
  start_sign_time=$(date +%s)

  local headers="$(request_headers)"
  local request="curl -s --request POST \
                  --url '$SERVER_URL/api/v1/tasks?team_id=$TEAM_ID' \
                  $headers \
                  --form action='$AUTO_DEV_SIGN_ACTION' \
                  --form parent_task_id='$TASK_ID' \
                  --form overrides='$(echo "$SIGN_OVERRIDES")'"

  eval $request
  statusWaiter
  printTime $((($(date +%s) - start_sign_time))) "Sign took: "
  echo ""
}
