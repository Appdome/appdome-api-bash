#!/usr/bin/env bash
# Stage 1 — creates the PWA app only, through the wrapper's pwa_upload.sh functions (no build request, no signing).
# On a Short Flow account the upload also starts an automatic build; the script waits for it like the wrapper does.
#
# Usage: 02_pwa_upload.sh <aab|ipa> [personal|team|<team_uuid>]
# Required: APPDOME_API_KEY, PWA_ADDRESS; ipa: IOS_MOBILEPROVISION; team: TEAM_ID_TEST
source "$(dirname "$0")/common.sh"

PLATFORM="${1:?Usage: $0 <aab|ipa> [personal|team|<team_uuid>]}"; check_platform "$PLATFORM"
TEAM_ARG="${2:-personal}"
require_vars "create PWA app ($PLATFORM, $TEAM_ARG)" create "$PLATFORM" "$TEAM_ARG"
TEAM="$(resolve_team "$TEAM_ARG")"
start_run "upload_${PLATFORM}_${TEAM_ARG}"

write_pwa_json "$PLATFORM" "$RUN_DIR/pwa.json"
UPLOADS="$RUN_DIR/uploads.txt"

cd "$WRAPPER_DIR"
set +eu
(
  source ./utils.sh
  source ./appdome_api_bash/status.sh
  source ./appdome_api_bash/build.sh
  source ./appdome_api_bash/pwa_upload.sh
  init_server_url
  assign_client_header
  VERBOSE="${PWA_TEST_VERBOSE:-false}"
  init_logging
  API_KEY="$APPDOME_API_KEY"
  TEAM_ID="$TEAM"
  BUILD_OVERRIDES='{}'
  BUILD_KEY=''
  PROVISIONING_PROFILES=()
  if [[ "$PLATFORM" == "ipa" ]]; then PROVISIONING_PROFILES=("$IOS_MOBILEPROVISION"); fi
  init_pwa_config "$RUN_DIR/pwa.json"
  add_pwa_provisioning_profiles
  pwa_build true
  for i in "${!PWA_APP_IDS[@]}"; do
    echo "APP_ID=${PWA_APP_IDS[$i]} BUILD_ID=${PWA_TASK_IDS[$i]} PACK_TYPE=${PWA_PACK_TYPES[$i]} STATUS=${PWA_STATUSES[$i]}"
  done > "$UPLOADS"
)
RC=$?
set -eu

echo
echo "Checks:"
expect "wrapper upload finished (exit $RC)" test "$RC" -eq 0
LINE="$(head -n1 "$UPLOADS" 2>/dev/null || true)"
field() { printf '%s\n' "$LINE" | tr ' ' '\n' | sed -n "s/^$1=//p"; }
APP_ID="$(field APP_ID)"; BUILD_ID="$(field BUILD_ID)"
expect "one uploaded app" test "$(cat "$UPLOADS" 2>/dev/null | grep -c . || true)" -eq 1
expect "App ID returned" test -n "$APP_ID"
expect "pack_type is $PLATFORM" test "$(field PACK_TYPE)" == "$PLATFORM"
expect "app status is active" test "$(field STATUS)" == "active"
if [[ -n "$BUILD_ID" ]]; then
  note "Short Flow: automatic build $BUILD_ID completed (default Playground Fusion Set)"
else
  note "No Short Flow: app created only. Build it with 03_full_flow.sh $PLATFORM $TEAM_ARG <fusion_set_id>"
fi
record APP_ID "$APP_ID"
record BUILD_ID "$BUILD_ID"
[[ $CHECK_FAILS -eq 0 ]]
