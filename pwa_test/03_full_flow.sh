#!/usr/bin/env bash
# Stage 2 — full build for one platform through appdome_api.sh --pwa:
# upload → build (Short Flow automatic build, or the Fusion Set) → Sign on Appdome → download → Certified Secure.
# Diagnostic Logs (-bl) are on. Checks the outputs and the Certified Secure JSON at the end.
#
# Usage: 03_full_flow.sh <aab|ipa> [personal|team|<team_uuid>] [fusion_set_id]
#   fusion_set_id  Used only when the upload is not auto-built (no Short Flow).
#                  Defaults to FS_ANDROID_TEAM / FS_IOS_TEAM for "team".
# Required: create-stage parameters + aab: ANDROID_KEYSTORE, ANDROID_KEYSTORE_PASS, ANDROID_KEYSTORE_ALIAS,
#           ANDROID_KEY_PASS; ipa: IOS_P12, IOS_P12_PASSWORD, IOS_MOBILEPROVISION; team: FS_ANDROID_TEAM / FS_IOS_TEAM
source "$(dirname "$0")/common.sh"

PLATFORM="${1:?Usage: $0 <aab|ipa> [personal|team|<team_uuid>] [fusion_set_id]}"; check_platform "$PLATFORM"
TEAM_ARG="${2:-personal}"
FS_ID="${3:-}"
require_vars "full build ($PLATFORM, $TEAM_ARG)" full "$PLATFORM" "$TEAM_ARG" "$FS_ID"
TEAM="$(resolve_team "$TEAM_ARG")"
if [[ -z "$FS_ID" && "$TEAM_ARG" == "team" ]]; then
  if [[ "$PLATFORM" == "aab" ]]; then FS_ID="${FS_ANDROID_TEAM:-}"; else FS_ID="${FS_IOS_TEAM:-}"; fi
fi
start_run "full_${PLATFORM}_${TEAM_ARG}"

write_pwa_json "$PLATFORM" "$RUN_DIR/pwa.json"
CERT_PDF="$RUN_DIR/certified_secure.pdf"
CERT_JSON="$RUN_DIR/certified_secure.json"
ARGS=(--api_key "$APPDOME_API_KEY" --team_id "$TEAM" --pwa "$RUN_DIR/pwa.json" --build_logs --sign_on_appdome)
if [[ -n "$FS_ID" ]]; then ARGS+=(--fusion_set_id "$FS_ID"); fi
if [[ "$PLATFORM" == "aab" ]]; then
  OUT="$RUN_DIR/signed.aab"
  SECOND="$RUN_DIR/universal.apk"
  ARGS+=(--keystore "$ANDROID_KEYSTORE" --keystore_pass "$ANDROID_KEYSTORE_PASS"
         --keystore_alias "$ANDROID_KEYSTORE_ALIAS" --key_pass "$ANDROID_KEY_PASS" --second_output "$SECOND")
else
  OUT="$RUN_DIR/signed.ipa"
  SECOND=""
  ARGS+=(--keystore "$IOS_P12" --keystore_pass "$IOS_P12_PASSWORD" --provisioning_profiles "$IOS_MOBILEPROVISION")
fi
ARGS+=(--output "$OUT" --certificate_output "$CERT_PDF" --certificate_json "$CERT_JSON")
if [[ "${PWA_TEST_VERBOSE:-false}" == "true" ]]; then ARGS+=(--verbose); fi

cd "$WRAPPER_DIR"
set +e
bash appdome_api.sh "${ARGS[@]}" 2>&1 | tee "$RUN_DIR/wrapper.log"
RC=${PIPESTATUS[0]}
set -e

APP_ID="$(grep -Eo 'App ID: [0-9a-f-]{36}' "$RUN_DIR/wrapper.log" | head -n1 | sed 's/App ID: //' || true)"
SHORT_FLOW_ID="$(grep -Eo 'Automatic build started .*Build ID: [0-9a-f-]{36}' "$RUN_DIR/wrapper.log" | grep -Eo '[0-9a-f-]{36}$' || true)"

echo
echo "Checks:"
expect "appdome_api.sh finished (exit $RC)" test "$RC" -eq 0
expect "App ID returned by the upload" test -n "$APP_ID"
expect "signed $PLATFORM downloaded" test -s "$OUT"
if [[ -n "$SECOND" ]]; then expect "universal apk downloaded (second output)" test -s "$SECOND"; fi
expect "Certified Secure PDF downloaded" test -s "$CERT_PDF"
expect "Certified Secure JSON downloaded" test -s "$CERT_JSON"
if [[ -s "$CERT_JSON" ]]; then
  BUILD_ID="$(cert_value "$CERT_JSON" build_id)"
  CERT_FS="$(cert_value "$CERT_JSON" fusion_set_id)"
  expect "certificate app_type is $PLATFORM" test "$(cert_value "$CERT_JSON" app_type)" == "$PLATFORM"
  expect "certificate app_id matches the upload" test "$(cert_value "$CERT_JSON" app_id)" == "$APP_ID"
  expect "Diagnostic Logs on (extended_logs true)" test "$(cert_value "$CERT_JSON" extended_logs)" == "true"
  expect "signed on Appdome (sign_type OnAppdome)" test "$(cert_value "$CERT_JSON" sign_type)" == "OnAppdome"
  if [[ "$TEAM" != "personal" ]]; then
    expect "built in team $TEAM" test "$(cert_value "$CERT_JSON" team_id)" == "$TEAM"
  fi
  if [[ -n "$SHORT_FLOW_ID" ]]; then
    note "Short Flow: automatic build with Fusion Set $CERT_FS ($(cert_value "$CERT_JSON" fusion_set_name))"
    expect "certificate build_id is the Short Flow build" test "$BUILD_ID" == "$SHORT_FLOW_ID"
  else
    expect "built with Fusion Set $FS_ID" test "$CERT_FS" == "$FS_ID"
  fi
  note "bundle_id $(cert_value "$CERT_JSON" bundle_id), min OS $(cert_value "$CERT_JSON" min_sdk_version), release_type $(cert_value "$CERT_JSON" release_type)"
  note "build client: $(cert_value "$CERT_JSON" build_external_api_plugin_name); context step run: $(cert_value "$CERT_JSON" is_context_api_call) (the Bash wrapper has no context step)"
  record BUILD_ID "$BUILD_ID"
  record FUSION_SET_ID "$CERT_FS"
fi
record APP_ID "$APP_ID"
record SHORT_FLOW "$([[ -n "$SHORT_FLOW_ID" ]] && echo yes || echo no)"
echo
echo "Outputs:"; ls -la "$RUN_DIR"
[[ $CHECK_FAILS -eq 0 ]]
