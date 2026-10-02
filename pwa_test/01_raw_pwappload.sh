#!/usr/bin/env bash
# Calls POST /api/v1/pwappload directly with curl — no wrapper code involved.
# Use it to confirm API behavior for Engineering independently of the wrapper.
#
# Usage: 01_raw_pwappload.sh <aab|ipa|both> [personal|team|<team_uuid>] [--no-profile]
#   both          probe: does the API accept pwa_platform "both"? (the provisioning profile is sent, as for ipa)
#   --no-profile  ipa/both only: omit the provisioning profile (expected to fail per Engineering)
#
# Creates the PWA app only. On a Short Flow account the API also starts an automatic build; this script reports
# its Build ID but does not wait for it (04_task_status.sh shows its status).
#
# Exit codes: 0 = accepted, 4 = rejected by the API (HTTP 4xx), 2 = missing parameters, other = network/script error
source "$(dirname "$0")/common.sh"

PLATFORM="${1:?Usage: $0 <aab|ipa|both> [personal|team|<team_uuid>] [--no-profile]}"; check_platform "$PLATFORM" allow_both
TEAM_ARG="${2:-personal}"
NO_PROFILE="${3:-}"
if [[ -n "$NO_PROFILE" ]]; then
  require_vars "raw upload ($PLATFORM, no profile)" create aab "$TEAM_ARG"
else
  require_vars "raw upload ($PLATFORM)" create "$PLATFORM" "$TEAM_ARG"
fi
TEAM="$(resolve_team "$TEAM_ARG")"
start_run "raw_${PLATFORM}_${TEAM_ARG}${NO_PROFILE:+_noprofile}"

BODY="$RUN_DIR/request.json"
NAME=""
if [[ -n "${PWA_APP_NAME:-}" ]]; then NAME=",\"pwa_app_name\":\"$(json_str "$PWA_APP_NAME")\""; fi
OVERRIDES=""
if [[ "$PLATFORM" != "aab" && "$NO_PROFILE" != "--no-profile" ]]; then
  CONTENT="$(base64 < "$IOS_MOBILEPROVISION" | tr -d '\n\r')"
  OVERRIDES=",\"overrides\":{\"provisioning_profile\":[{\"filename\":\"$(json_str "$(basename "$IOS_MOBILEPROVISION")")\",\"content\":\"$CONTENT\"}]}"
fi
printf '{"pwa_address":"%s","pwa_platform":"%s"%s%s}' "$(json_str "$PWA_ADDRESS")" "$PLATFORM" "$NAME" "$OVERRIDES" > "$BODY"
echo "Request body: $(sed -E 's/"content":"[^"]*"/"content":"<base64>"/g' "$BODY")"

echo "team_id: $TEAM"
RESPONSE="$RUN_DIR/response.json"
HTTP_CODE=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
  -X POST "${APPDOME_BASE_URL%/}/api/v1/pwappload?team_id=$TEAM" \
  -H "Authorization: $APPDOME_API_KEY" -H "Content-Type: application/json" \
  --data-binary "@$BODY")
echo "HTTP $HTTP_CODE"
echo "Response saved: $RESPONSE"
record HTTP "$HTTP_CODE"

if [[ "$HTTP_CODE" != 2* ]]; then
  echo "Error response: $(head -c 1000 "$RESPONSE")"
  if [[ "$HTTP_CODE" == 4* ]]; then exit 4; fi   # 4 = rejected by the API (used by run_matrix.sh)
  exit 1
fi

# Quick parse without jq: one value per uploaded platform, in response order.
values() { grep -Eo "\"$1\":(\"[^\"]*\"|true|false)" "$RESPONSE" | sed -E "s/^\"$1\"://; s/\"//g" || true; }
APP_IDS="$(grep -Eo '"app":\{"id":"[^"]*"' "$RESPONSE" | sed -E 's/.*"id":"//; s/"$//' || true)"
PACK_TYPES="$(values pack_type)"
STATUSES="$(values status)"
IS_PWAPP="$(values is_pwapp)"
TASK_IDS="$(values task_id)"
COUNT=$(printf '%s\n' "$APP_IDS" | grep -c . || true)
echo "Uploaded apps: $COUNT"
i=1
while [[ $i -le $COUNT ]]; do
  echo "App ID:     $(printf '%s\n' "$APP_IDS" | sed -n "${i}p")"
  echo "pack_type:  $(printf '%s\n' "$PACK_TYPES" | sed -n "${i}p")   is_pwapp: $(printf '%s\n' "$IS_PWAPP" | sed -n "${i}p")   status: $(printf '%s\n' "$STATUSES" | sed -n "${i}p")"
  i=$((i + 1))
done
if [[ -n "$TASK_IDS" ]]; then
  echo "Build ID(s): $(echo $TASK_IDS)   → automatic build started (Short Flow)"
else
  echo "Build ID:   none      → upload only (no Short Flow); build with 03_full_flow.sh and a Fusion Set"
fi
record APP_IDS "$(echo $APP_IDS)"
record PACK_TYPES "$(echo $PACK_TYPES)"
record BUILD_IDS "$(echo $TASK_IDS)"
if [[ "$COUNT" -eq 0 && -z "$TASK_IDS" ]]; then
  echo "No App ID or Build ID in the response"
  exit 1
fi
