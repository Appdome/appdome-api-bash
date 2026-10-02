#!/usr/bin/env bash
# Offline tests for the Bash wrapper's PWA support. No env.sh, network or Appdome account needed:
# the API is stubbed (curl, statusWaiter and build are replaced by shell functions).
# bash 3.2 (macOS) compatible.
#
# Usage: 00_offline_tests.sh
set -o pipefail
# Ignore Appdome settings exported in the calling shell (Fusion Sets, team, key, server): tests set what they need.
unset APPDOME_ANDROID_FS_ID APPDOME_IOS_FS_ID APPDOME_TEAM_ID APPDOME_API_KEY API_KEY_ENV APPDOME_SERVER_BASE_URL \
      APPDOME_CLIENT_HEADER VERBOSE
WRAPPER_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/pwa_offline.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
PASSED=0
FAILED=0

pass() { PASSED=$((PASSED + 1)); echo "  ok    $1"; }
fail() { FAILED=$((FAILED + 1)); echo "  FAIL  $1"; [[ -n "${2:-}" ]] && printf '        %s\n' "$2"; }
assert_eq() { if [[ "$2" == "$3" ]]; then pass "$1"; else fail "$1" "expected: $2 | actual: $3"; fi; }
assert_contains() { if [[ "$3" == *"$2"* ]]; then pass "$1"; else fail "$1" "expected to contain: $2 | actual: $(printf '%s' "$3" | tail -n3)"; fi; }
assert_not_contains() { if [[ "$3" != *"$2"* ]]; then pass "$1"; else fail "$1" "did not expect: $2"; fi; }

# lib <commands...>: runs the commands in a subshell with the wrapper's PWA functions loaded and the API stubbed.
# Stub inputs: MOCK_BODY / MOCK_CODE (pwappload response). Prints stdout+stderr; exit code is the subshell's.
lib() {
  (
    cd "$WRAPPER_DIR" || exit 99
    source ./utils.sh
    source ./appdome_api_bash/status.sh
    source ./appdome_api_bash/build.sh
    source ./appdome_api_bash/pwa_upload.sh
    init_logging
    SERVER_URL="http://127.0.0.1:9"; API_KEY="key"; TEAM_ID="personal"; APPDOME_CLIENT_HEADER="test"
    # Plain assignment: bash 3.2 (macOS) keeps the backslash in "${VAR:-{\}}"
    BUILD_OVERRIDES='{}'
    if [[ -n "${T_BUILD_OVERRIDES:-}" ]]; then BUILD_OVERRIDES="$T_BUILD_OVERRIDES"; fi
    BUILD_KEY="${T_BUILD_KEY:-}"; FUSION_SET_ID="${T_FS:-}"
    PROVISIONING_PROFILES=()
    if [[ -n "${T_PROFILES:-}" ]]; then IFS=',' read -r -a PROVISIONING_PROFILES <<< "$T_PROFILES"; fi
    curl() { printf '%s\n%s' "${MOCK_BODY:-}" "${MOCK_CODE:-200}"; }
    statusWaiter() { echo "WAITED $TASK_ID"; }
    build() { echo "BUILD fs=$FUSION_SET_ID app=$APP"; }
    eval "$*"
  ) 2>&1
}

config() {  # config <name> <json>  → path of a config file
  printf '%s' "$2" > "$TMP/$1.json"
  echo "$TMP/$1.json"
}

printf 'ABC' > "$TMP/one.mobileprovision"        # base64 QUJD
printf 'XYZ' > "$TMP/two profile.mobileprovision" # base64 WFla
AAB="$(config aab '{"pwa_address": "https://example.com", "pwa_platform": "aab"}')"
IPA="$(config ipa '{"pwa_address": "https://example.com", "pwa_platform": "ipa"}')"
APP='{"id":"app-1","pack_type":"aab","is_pwapp":true,"status":"active","metadata":{"list":[{"id":"nested"}]}}'
SHORT_FLOW="[{\"app\":$APP,\"taskId\":{\"task_id\":\"build-1\"}}]"
UPLOAD_ONLY="[{\"app\":$APP}]"

echo "JSON helpers"
out="$(lib 'json_entries "{\"a\" : \"x,\\\"y}\" , \"b\":[1,{\"c\":2}], \"e\":{}}"')"
assert_eq "json_entries splits top-level entries" $'a\t"x,\\"y}"\nb\t[1,{"c":2}]\ne\t{}' "$out"
lib 'json_entries "{\"a\":1"' > /dev/null; assert_eq "json_entries rejects unclosed JSON" 3 $?
lib 'json_entries "{\"a\" 1}"' > /dev/null; assert_eq "json_entries rejects a missing colon" 3 $?
assert_eq "json_get follows a path" '"build-1"' "$(lib "json_get '$SHORT_FLOW' 0 taskId task_id")"
assert_eq "json_string_value decodes escapes" 'a "b" \ c' "$(V='"a \"b\" \\ c"' lib 'json_string_value "$V"')"

echo "Config file and request body"
assert_eq "minimal aab body" '{"pwa_address":"https://example.com","pwa_platform":"aab"}' \
  "$(lib "init_pwa_config '$AAB'; pwa_request_body")"
F="$(config upper '{"pwa_address":"https://x","pwa_platform":"AAB","pwa_app_name":"My \"App\""}')"
assert_eq "platform lower-cased, app name kept" '{"pwa_address":"https://x","pwa_platform":"aab","pwa_app_name":"My \"App\""}' \
  "$(lib "init_pwa_config '$F'; pwa_request_body")"
F="$(config empty_name '{"pwa_address":"https://x","pwa_platform":"aab","pwa_app_name":"","overrides":{}}')"
assert_eq "empty values left out of the body" '{"pwa_address":"https://x","pwa_platform":"aab"}' \
  "$(lib "init_pwa_config '$F'; pwa_request_body")"
F="$(config ov '{"pwa_address":"https://x","pwa_platform":"aab","overrides":{"a":1,"n":{"k":[1,2]}}}')"
printf '{"b": "2", "a": 3}' > "$TMP/bv.json"
assert_eq "--build_overrides and --build_logs merged into overrides" \
  '{"pwa_address":"https://x","pwa_platform":"aab","overrides":{"a":3,"n":{"k":[1,2]},"b":"2","extended_logs":true}}' \
  "$(T_BUILD_OVERRIDES="$(cat "$TMP/bv.json")" T_BUILD_KEY=extended_logs lib "init_pwa_config '$F'; pwa_request_body")"
F="$(config ovstr '{"pwa_address":"https://x","pwa_platform":"aab","overrides":"{\"extended_logs\": true}"}')"
assert_eq "string overrides sent as a JSON object" '{"pwa_address":"https://x","pwa_platform":"aab","overrides":{"extended_logs":true}}' \
  "$(lib "init_pwa_config '$F'; pwa_request_body")"
assert_eq "--build_logs alone gives overrides.extended_logs" '{"pwa_address":"https://example.com","pwa_platform":"aab","overrides":{"extended_logs":true}}' \
  "$(T_BUILD_KEY=extended_logs lib "init_pwa_config '$AAB'; pwa_request_body")"
assert_eq "aab sets PLATFORM=ANDROID" ANDROID "$(lib "init_pwa_config '$AAB'; echo \$PLATFORM")"
assert_eq "ipa sets PLATFORM=IOS" IOS "$(lib "init_pwa_config '$IPA'; echo \$PLATFORM")"

echo "iOS provisioning profiles"
assert_eq "ipa: profiles base64 encoded in overrides.provisioning_profile" \
  '{"pwa_address":"https://example.com","pwa_platform":"ipa","overrides":{"provisioning_profile":[{"filename":"one.mobileprovision","content":"QUJD"},{"filename":"two profile.mobileprovision","content":"WFla"}]}}' \
  "$(T_PROFILES="$TMP/one.mobileprovision,$TMP/two profile.mobileprovision" lib "init_pwa_config '$IPA'; add_pwa_provisioning_profiles; pwa_request_body")"
F="$(config ipaprof '{"pwa_address":"https://x","pwa_platform":"ipa","overrides":{"provisioning_profile":[{"filename":"cfg","content":"Q0ZH"}]}}')"
assert_eq "ipa: profile from the config file accepted" \
  '{"pwa_address":"https://x","pwa_platform":"ipa","overrides":{"provisioning_profile":[{"filename":"cfg","content":"Q0ZH"}]}}' \
  "$(lib "init_pwa_config '$F'; add_pwa_provisioning_profiles; pwa_request_body")"
assert_contains "ipa: --provisioning_profiles replace the config profile" '"filename":"one.mobileprovision"' \
  "$(T_PROFILES="$TMP/one.mobileprovision" lib "init_pwa_config '$F'; add_pwa_provisioning_profiles; pwa_request_body")"
out="$(lib "init_pwa_config '$IPA'; add_pwa_provisioning_profiles")"; rc=$?
assert_eq "ipa without profiles exits" 1 $rc
assert_contains "ipa without profiles message" "requires provisioning profiles" "$out"
out="$(T_PROFILES="$TMP/missing.mobileprovision" lib "init_pwa_config '$IPA'; add_pwa_provisioning_profiles")"
assert_contains "missing profile file reported" "Provisioning profile file does not exist" "$out"
assert_eq "aab ignores profiles" '{"pwa_address":"https://example.com","pwa_platform":"aab"}' \
  "$(T_PROFILES="$TMP/one.mobileprovision" lib "init_pwa_config '$AAB'; add_pwa_provisioning_profiles; pwa_request_body")"
assert_eq "profile content redacted in debug logs" '{"overrides":{"provisioning_profile":[{"filename":"a","content":"<base64, 4 chars>"}]}}' \
  "$(lib "_pwa_redacted_body '{\"overrides\":{\"provisioning_profile\":[{\"filename\":\"a\",\"content\":\"QUJD\"}]}}'")"

echo "Config validation (same messages as the Python wrapper)"
check_error() {  # check_error <name> <json> <expected message>
  local f out
  f="$(config "$1" "$2")"
  out="$(lib "init_pwa_config '$f'")"
  assert_contains "$1" "$3" "$out"
}
check_error "unknown keys" '{"pwa_address":"https://x","pwa_platform":"aab","foo":1,"bar":2}' \
  "Unknown keys in PWA config file: foo, bar. Allowed keys: pwa_address, pwa_platform, pwa_app_name, overrides"
check_error "missing keys" '{"pwa_address":"","pwa_app_name":"x"}' "Missing required keys in PWA config file: pwa_address, pwa_platform"
check_error "pwa_platform both rejected (one platform per build)" '{"pwa_address":"https://x","pwa_platform":"both"}' \
  "pwa_platform [both] is not supported. Supported values: aab, ipa"
check_error "invalid JSON" '{"pwa_address":"https://x","pwa_platform":"aab"' "contains invalid JSON"
check_error "not an object" '["a"]' "must contain a JSON object"
check_error "overrides not an object" '{"pwa_address":"https://x","pwa_platform":"aab","overrides":[1]}' "PWA config 'overrides' must be a JSON object"
check_error "overrides invalid JSON string" '{"pwa_address":"https://x","pwa_platform":"aab","overrides":"{bad"}' "PWA config 'overrides' is not valid JSON"
assert_contains "missing config file" "PWA config file does not exist" "$(lib "init_pwa_config '$TMP/none.json'")"

echo "Upload response"
assert_eq "Short Flow response" "app-1 build-1 aab active" \
  "$(lib "parse_pwa_upload_response '$SHORT_FLOW'; echo \${PWA_APP_IDS[0]} \${PWA_TASK_IDS[0]} \${PWA_PACK_TYPES[0]} \${PWA_STATUSES[0]}")"
assert_eq "upload-only response" "app-1 - aab active" \
  "$(lib "parse_pwa_upload_response '$UPLOAD_ONLY'; echo \${PWA_APP_IDS[0]} \${PWA_TASK_IDS[0]:--} \${PWA_PACK_TYPES[0]} \${PWA_STATUSES[0]}")"
assert_eq "published-spec response {task_id}" "build-9" \
  "$(lib "parse_pwa_upload_response '{\"task_id\":\"build-9\"}'; echo \${PWA_TASK_IDS[0]}")"
assert_eq "two platforms in one response" 2 \
  "$(lib "parse_pwa_upload_response '[{\"app\":{\"id\":\"a\"}},{\"app\":{\"id\":\"b\"}}]'; echo \${#PWA_APP_IDS[@]}")"
assert_contains "error response rejected" "Error in PWA upload response" "$(lib "parse_pwa_upload_response '[{\"statusCode\":400}]'")"
assert_contains "non-JSON response rejected" "Error in PWA upload response" "$(lib "parse_pwa_upload_response 'Bad Gateway'")"

echo "Upload and build flow"
out="$(MOCK_BODY="$SHORT_FLOW" lib "init_pwa_config '$AAB'; pwa_upload_and_build; echo TASK=\$TASK_ID")"
assert_contains "Short Flow: waits for the automatic build" "WAITED build-1" "$out"
assert_contains "Short Flow: continues with the automatic build" "TASK=build-1" "$out"
assert_not_contains "Short Flow: no build request" "BUILD fs=" "$out"
out="$(MOCK_BODY="$SHORT_FLOW" T_FS=fs-cli lib "init_pwa_config '$AAB'; pwa_upload_and_build")"
assert_contains "Short Flow: warns that --fusion_set_id was not used" "--fusion_set_id fs-cli was not used" "$out"
out="$(MOCK_BODY="$UPLOAD_ONLY" T_FS=fs-cli lib "init_pwa_config '$AAB'; pwa_upload_and_build")"
assert_contains "upload only: builds the App ID with --fusion_set_id" 'BUILD fs=fs-cli app={"id":"app-1"}' "$out"
out="$(MOCK_BODY="$UPLOAD_ONLY" APPDOME_ANDROID_FS_ID=fs-env lib "init_pwa_config '$AAB'; pwa_upload_and_build")"
assert_contains "upload only: APPDOME_ANDROID_FS_ID used when no --fusion_set_id" "BUILD fs=fs-env" "$out"
out="$(MOCK_BODY="$UPLOAD_ONLY" APPDOME_IOS_FS_ID=fs-ios T_PROFILES="$TMP/one.mobileprovision" lib "init_pwa_config '$IPA'; add_pwa_provisioning_profiles; pwa_upload_and_build")"
assert_contains "upload only: APPDOME_IOS_FS_ID used for ipa" "BUILD fs=fs-ios" "$out"
out="$(MOCK_BODY="$UPLOAD_ONLY" lib "init_pwa_config '$AAB'; pwa_upload_and_build")"; rc=$?
assert_eq "upload only without a Fusion Set exits" 1 $rc
assert_contains "upload only without a Fusion Set prints the App ID" "PWA uploaded (App ID: app-1) but not built" "$out"
out="$(MOCK_BODY='{"statusCode":400,"error":"Bad Request","message":"Invalid request payload input"}' MOCK_CODE=400 lib "init_pwa_config '$AAB'; pwa_upload_and_build")"
assert_contains "HTTP 400 reported" "PWA upload failed. Status code: 400" "$out"
out="$(MOCK_BODY='[{"app":{"id":"a"}},{"app":{"id":"b"}}]' T_FS=fs lib "init_pwa_config '$AAB'; pwa_upload_and_build")"
assert_contains "more than one upload rejected by the full flow" "Expected a single PWA upload, got 2" "$out"

echo "appdome_api.sh arguments"
run_api() { (cd "$WRAPPER_DIR" && bash appdome_api.sh --api_key key "$@" 2>&1); }
SIGN=(--sign_on_appdome --keystore "$TMP/one.mobileprovision" --keystore_pass p --keystore_alias a --key_pass k --output "$TMP/out.aab")
assert_contains "--app and --pwa together rejected" "--app (-a) and --pwa cannot be used together" "$(run_api --pwa "$AAB" --app x.aab "${SIGN[@]}")"
assert_contains "upload-only options rejected with --pwa" \
  "--build_to_test_vendor, --baseline_profile, --startup_profile, --input_mapping, --cert_pinning_zip, --direct_upload, --skip_upload_checksum_call cannot be used with --pwa" \
  "$(run_api --pwa "$AAB" -btv bitbar --baseline_profile b --startup_profile s --input_mapping m --cert_pinning_zip c -du --skip_upload_checksum_call "${SIGN[@]}")"
assert_contains "--app or --pwa required" "--app (-a) or --pwa is required" "$(run_api "${SIGN[@]}")"
out="$(run_api --pwa "$IPA" --sign_on_appdome --keystore "$TMP/one.mobileprovision" --keystore_pass p --output "$TMP/out.ipa")"
assert_contains "ipa --pwa without --provisioning_profiles stops before upload" "requires provisioning profiles" "$out"
assert_not_contains "--fusion_set_id not required with --pwa" "--fusion_set_id (-fs) is required" "$out"
assert_contains "--pwa listed in --help" "--pwa" "$(run_api --help)"

echo
echo "Passed: $PASSED  Failed: $FAILED"
[[ $FAILED -eq 0 ]]
