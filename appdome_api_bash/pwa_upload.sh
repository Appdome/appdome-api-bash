#!/bin/bash
source ./utils.sh
source ./appdome_api_bash/status.sh

# PWA flow is independent of the Android/iOS binary upload flow (upload.sh / direct_upload.sh).
# Reference: https://apis.appdome.com/reference/post_pwappload
# Behavior (confirmed by Appdome Engineering):
# - The response's app object ("status": "active") means the upload is done; app.id is the App ID.
# - Accounts with the Short Flow license also get an automatic build with the default Playground Fusion Set
#   (named after the app); the response then includes taskId.task_id. Without Short Flow the call only uploads,
#   and the App ID is built with the regular build API and a Fusion Set.
# The request body is JSON (multipart is rejected with 415) and 'overrides' must be a JSON object (a string is
# rejected with 400). Like the rest of this client, no jq is needed: the small JSON helpers below use awk.
PWA_CONFIG_KEYS=(pwa_address pwa_platform pwa_app_name overrides)
PWA_REQUIRED_CONFIG_KEYS=(pwa_address pwa_platform)
# One platform per build: 'aab' (Android) or 'ipa' (iOS, requires provisioning profiles in the overrides).
PWA_PLATFORM_VALUES=(aab ipa)
PWA_PROVISIONING_PROFILE_KEY="provisioning_profile"
# Options that only apply to uploading an app file do not apply to --pwa.
# --build_overrides and --build_logs are sent as the PWA request overrides (and to the build when there is no
# automatic Short Flow build). --fusion_set_id is used only when the account has no Short Flow.
PWA_UNSUPPORTED_OPTIONS=(build_to_test_vendor baseline_profile startup_profile input_mapping cert_pinning_zip
                         direct_upload skip_upload_checksum_call)

PWA_CONFIG_ENTRY_KEYS=()     # config keys other than overrides, in file order
PWA_CONFIG_ENTRY_VALUES=()   # their raw JSON values
PWA_OVERRIDE_KEYS=()         # merged request overrides (raw JSON key / value pairs)
PWA_OVERRIDE_VALUES=()
PWA_PLATFORM=''
PWA_APP_IDS=()
PWA_TASK_IDS=()
PWA_PACK_TYPES=()
PWA_STATUSES=()

# ---------------------------------------------------------------------------------------------------------------------
# Minimal JSON helpers (POSIX awk, works with macOS awk and gawk). Not a full JSON validator: they check structure
# (balanced brackets, quoted keys, key/value separators) which is enough to read the config and the API response.
# ---------------------------------------------------------------------------------------------------------------------

_JSON_AWK_COMMON='
function str_end(s, i,    j, k, m, bs, rest) {
  j = i + 1
  while (1) {
    rest = substr(s, j)
    k = index(rest, "\"")
    if (k == 0) return 0
    k = j + k - 1
    bs = 0; m = k - 1
    while (m > i && substr(s, m, 1) == "\\") { bs++; m-- }
    if (bs % 2 == 0) return k
    j = k + 1
  }
}
function is_ws(c) { return c == " " || c == "\t" || c == "\r" || c == "\n" }
{ s = s $0 "\n" }
'

# Prints the JSON type of $1: object, array, string, scalar or empty.
json_type() {
  printf '%s' "$1" | awk "$_JSON_AWK_COMMON"'
END {
  n = length(s); i = 1
  while (i <= n && is_ws(substr(s, i, 1))) i++
  c = substr(s, i, 1)
  if (i > n) print "empty"
  else if (c == "{") print "object"
  else if (c == "[") print "array"
  else if (c == "\"") print "string"
  else print "scalar"
}'
}

# Prints the direct children of the JSON object or array in $1, one per line: "<key or index><TAB><compact value>".
# Object keys are printed as written in the JSON (without the quotes). Fails on malformed JSON.
json_entries() {
  printf '%s' "$1" | awk "$_JSON_AWK_COMMON"'
END {
  n = length(s); i = 1
  while (i <= n && is_ws(substr(s, i, 1))) i++
  c = substr(s, i, 1)
  if (c == "{") obj = 1; else if (c == "[") obj = 0; else exit 2
  depth = 0; buf = ""; havekey = 0; idx = 0; closed = 0
  for (i = i + 1; i <= n; i++) {
    c = substr(s, i, 1)
    if (c == "\"") {
      k = str_end(s, i)
      if (!k) exit 3
      buf = buf substr(s, i, k - i + 1); i = k
      continue
    }
    if (is_ws(c)) continue
    if (depth == 0) {
      if (obj && c == ":" && !havekey) {
        if (buf !~ /^".*"$/) exit 3
        key = substr(buf, 2, length(buf) - 2); buf = ""; havekey = 1
        continue
      }
      if (c == "," || c == "}" || c == "]") {
        if ((c == "}" && !obj) || (c == "]" && obj)) exit 3
        if (buf == "" && !havekey) {
          if (c == ",") exit 3
          closed = 1; break
        }
        if (buf == "" || (obj && !havekey)) exit 3
        if (obj) print key "\t" buf; else print (idx++) "\t" buf
        buf = ""; havekey = 0
        if (c != ",") { closed = 1; break }
        continue
      }
    }
    if (c == "{" || c == "[") depth++
    else if (c == "}" || c == "]") depth--
    if (depth < 0) exit 3
    buf = buf c
  }
  if (!closed) exit 3
  for (i = i + 1; i <= n; i++) if (!is_ws(substr(s, i, 1))) exit 3
}'
}

# json_get <json> <key or index>... : prints the compact JSON value at that path (last one wins for duplicate keys).
# Returns 1 when the path does not exist or the JSON is malformed.
json_get() {
  local json="$1" key entries k v found
  shift
  for key in "$@"; do
    entries=$(json_entries "$json") || return 1
    found=''
    while IFS=$'\t' read -r k v; do
      [[ -n "$k" && "$k" == "$key" ]] && found="$v"
    done <<< "$entries"
    [[ -z "$found" ]] && return 1
    json="$found"
  done
  printf '%s' "$json"
}

# Decodes a JSON string value ("..." with escapes) to plain text. Non-string values are printed as they are;
# null is printed as an empty string.
json_string_value() {
  local value="$1"
  if [[ "$value" == "null" ]]; then
    return
  fi
  if [[ "$value" != \"*\" ]]; then
    printf '%s' "$value"
    return
  fi
  printf '%s' "${value:1:${#value}-2}" | awk '
{ if (NR > 1) s = s "\n"; s = s $0 }
END {
  out = ""
  while ((k = index(s, "\\")) > 0) {
    out = out substr(s, 1, k - 1)
    c = substr(s, k + 1, 1)
    if (c == "n") out = out "\n"
    else if (c == "t") out = out "\t"
    else if (c == "r") out = out "\r"
    else if (c == "b") out = out "\b"
    else if (c == "f") out = out "\f"
    else if (c == "u") out = out "\\u"
    else out = out c
    s = substr(s, k + 2)
  }
  printf "%s", out s
}'
}

# Escapes plain text for use inside a JSON string.
json_escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | tr -d '\n\r'
}

# True when the JSON value is empty the way Python treats it as false: "", null, false, 0, [], {}.
json_is_falsy() {
  case "$1" in
    ''|'""'|null|false|0|'[]'|'{}') return 0 ;;
  esac
  return 1
}

_pwa_override_set() {
  local key="$1" value="$2" i
  for i in "${!PWA_OVERRIDE_KEYS[@]}"; do
    if [[ "${PWA_OVERRIDE_KEYS[$i]}" == "$key" ]]; then
      PWA_OVERRIDE_VALUES[$i]="$value"
      return
    fi
  done
  PWA_OVERRIDE_KEYS+=("$key")
  PWA_OVERRIDE_VALUES+=("$value")
}

_pwa_override_get() {
  local key="$1" i
  for i in "${!PWA_OVERRIDE_KEYS[@]}"; do
    if [[ "${PWA_OVERRIDE_KEYS[$i]}" == "$key" ]]; then
      printf '%s' "${PWA_OVERRIDE_VALUES[$i]}"
      return 0
    fi
  done
  return 1
}

# Merges the entries of a JSON object into the PWA overrides (later values replace earlier ones, like dict.update).
_pwa_merge_overrides_object() {
  local json="$1" entries k v
  entries=$(json_entries "$json") || return 1
  while IFS=$'\t' read -r k v; do
    [[ -n "$k" ]] && _pwa_override_set "$k" "$v"
  done <<< "$entries"
  return 0
}

pwa_overrides_json() {
  local i out='{'
  for i in "${!PWA_OVERRIDE_KEYS[@]}"; do
    [[ "$out" != '{' ]] && out+=','
    out+="\"${PWA_OVERRIDE_KEYS[$i]}\":${PWA_OVERRIDE_VALUES[$i]}"
  done
  printf '%s}' "$out"
}

# Loads the config file overrides. The API reference documents 'overrides' as a string, but the live API rejects a
# JSON string (400) and accepts a JSON object, so string overrides are parsed and sent as an object.
_pwa_load_config_overrides() {
  local value="$1" type
  json_is_falsy "$value" && return
  if [[ "$(json_type "$value")" == "string" ]]; then
    value=$(json_string_value "$value")
    type=$(json_type "$value")
    case "$type" in
      object|array) json_entries "$value" > /dev/null || log_and_exit "PWA config 'overrides' is not valid JSON" ;;
      empty) log_and_exit "PWA config 'overrides' is not valid JSON" ;;
    esac
  fi
  if [[ "$(json_type "$value")" != "object" ]]; then
    log_and_exit "PWA config 'overrides' must be a JSON object"
  fi
  _pwa_merge_overrides_object "$value" || log_and_exit "PWA config 'overrides' is not valid JSON"
}

_pwa_contains() {
  local needle="$1" item
  shift
  for item in "$@"; do
    [[ "$item" == "$needle" ]] && return 0
  done
  return 1
}

# Fails when an option that only applies to uploading an app file is combined with --pwa.
validate_pwa_unsupported_options() {
  local used=() name value
  for name in "${PWA_UNSUPPORTED_OPTIONS[@]}"; do
    case "$name" in
      build_to_test_vendor) value="$BUILD_TO_TEST" ;;
      baseline_profile) value="$BASELINE_PROFILE" ;;
      startup_profile) value="$STARTUP_PROFILE" ;;
      input_mapping) value="$INPUT_MAPPING" ;;
      cert_pinning_zip) value="$CERT_ZIP" ;;
      direct_upload) value="$DIRECT_UPLOAD" ;;
      skip_upload_checksum_call) value="$SKIP_UPLOAD_CHECKSUM_CALL" ;;
    esac
    [[ -n "$value" ]] && used+=("--$name")
  done
  if [[ ${#used[@]} -gt 0 ]]; then
    local joined
    joined=$(printf ', %s' "${used[@]}")
    log_and_exit "${joined:2} cannot be used with --pwa"
  fi
}

# Loads and validates the PWA config json file, merges --build_overrides and --build_logs into its overrides
# (like the build step does) and sets PLATFORM from pwa_platform.
# Example: {"pwa_address": "https://example.com", "pwa_platform": "aab", "pwa_app_name": "My App", "overrides": {}}
init_pwa_config() {
  local config_file="$1" config type entries k v unknown=() missing=() key value
  if [[ ! -f "$config_file" ]]; then
    log_and_exit "PWA config file does not exist: $config_file"
  fi
  config=$(cat "$config_file")
  type=$(json_type "$config")
  case "$type" in
    object)
      entries=$(json_entries "$config") || log_and_exit "PWA config file $config_file contains invalid JSON"
      ;;
    array)
      json_entries "$config" > /dev/null || log_and_exit "PWA config file $config_file contains invalid JSON"
      log_and_exit "PWA config file $config_file must contain a JSON object"
      ;;
    empty)
      log_and_exit "PWA config file $config_file contains invalid JSON"
      ;;
    *)
      log_and_exit "PWA config file $config_file must contain a JSON object"
      ;;
  esac

  PWA_CONFIG_ENTRY_KEYS=()
  PWA_CONFIG_ENTRY_VALUES=()
  PWA_OVERRIDE_KEYS=()
  PWA_OVERRIDE_VALUES=()
  local config_overrides=''
  while IFS=$'\t' read -r k v; do
    [[ -z "$k" ]] && continue
    if ! _pwa_contains "$k" "${PWA_CONFIG_KEYS[@]}"; then
      _pwa_contains "$k" ${unknown[@]+"${unknown[@]}"} || unknown+=("$k")
      continue
    fi
    if [[ "$k" == "overrides" ]]; then
      config_overrides="$v"
      continue
    fi
    local i replaced=false
    for i in "${!PWA_CONFIG_ENTRY_KEYS[@]}"; do
      if [[ "${PWA_CONFIG_ENTRY_KEYS[$i]}" == "$k" ]]; then
        PWA_CONFIG_ENTRY_VALUES[$i]="$v"
        replaced=true
      fi
    done
    if [[ "$replaced" == false ]]; then
      PWA_CONFIG_ENTRY_KEYS+=("$k")
      PWA_CONFIG_ENTRY_VALUES+=("$v")
    fi
  done <<< "$entries"

  if [[ ${#unknown[@]} -gt 0 ]]; then
    local unknown_list allowed_list
    unknown_list=$(printf ', %s' "${unknown[@]}")
    allowed_list=$(printf ', %s' "${PWA_CONFIG_KEYS[@]}")
    log_and_exit "Unknown keys in PWA config file: ${unknown_list:2}. Allowed keys: ${allowed_list:2}"
  fi
  for key in "${PWA_REQUIRED_CONFIG_KEYS[@]}"; do
    value=$(pwa_config_value "$key")
    json_is_falsy "$value" && missing+=("$key")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    local missing_list
    missing_list=$(printf ', %s' "${missing[@]}")
    log_and_exit "Missing required keys in PWA config file: ${missing_list:2}"
  fi

  value=$(json_string_value "$(pwa_config_value pwa_platform)")
  PWA_PLATFORM=$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')
  if ! _pwa_contains "$PWA_PLATFORM" "${PWA_PLATFORM_VALUES[@]}"; then
    local supported
    supported=$(printf ', %s' "${PWA_PLATFORM_VALUES[@]}")
    log_and_exit "pwa_platform [$value] is not supported. Supported values: ${supported:2}"
  fi
  _pwa_config_set pwa_platform "\"$PWA_PLATFORM\""

  _pwa_load_config_overrides "$config_overrides"
  if [[ -n "$BUILD_OVERRIDES" && "$BUILD_OVERRIDES" != "{}" ]]; then
    if [[ "$(json_type "$BUILD_OVERRIDES")" != "object" ]] || ! _pwa_merge_overrides_object "$BUILD_OVERRIDES"; then
      log_and_exit "--build_overrides must be a json file with a JSON object"
    fi
  fi
  if [[ -n "$BUILD_KEY" ]]; then
    _pwa_override_set "extended_logs" "true"
  fi

  if [[ "$PWA_PLATFORM" == "ipa" ]]; then
    PLATFORM=IOS
  else
    PLATFORM=ANDROID
  fi
}

pwa_config_value() {
  local key="$1" i
  for i in "${!PWA_CONFIG_ENTRY_KEYS[@]}"; do
    if [[ "${PWA_CONFIG_ENTRY_KEYS[$i]}" == "$key" ]]; then
      printf '%s' "${PWA_CONFIG_ENTRY_VALUES[$i]}"
      return 0
    fi
  done
  return 1
}

_pwa_config_set() {
  local key="$1" value="$2" i
  for i in "${!PWA_CONFIG_ENTRY_KEYS[@]}"; do
    if [[ "${PWA_CONFIG_ENTRY_KEYS[$i]}" == "$key" ]]; then
      PWA_CONFIG_ENTRY_VALUES[$i]="$value"
      return
    fi
  done
}

encode_provisioning_profile() {
  local profile_path="$1" content
  content=$(base64 < "$profile_path" | tr -d '\n\r')
  printf '{"filename":"%s","content":"%s"}' "$(json_escape "$(basename -- "$profile_path")")" "$content"
}

# iOS (ipa) PWA uploads require the provisioning profile(s) in the overrides:
# {"provisioning_profile": [{"filename": "X.mobileprovision", "content": "<base64>"}]}
# Profiles given with --provisioning_profiles replace any already in the config. No-op for aab.
add_pwa_provisioning_profiles() {
  if [[ "$PWA_PLATFORM" != "ipa" ]]; then
    return
  fi
  local profiles=() profile value
  for profile in ${PROVISIONING_PROFILES[@]+"${PROVISIONING_PROFILES[@]}"}; do
    [[ -n "$profile" ]] && profiles+=("$profile")
  done
  if [[ ${#profiles[@]} -gt 0 ]]; then
    validate_files "Provisioning profile" "${profiles[@]}"
    value='['
    for profile in "${profiles[@]}"; do
      [[ "$value" != '[' ]] && value+=','
      value+=$(encode_provisioning_profile "$profile")
    done
    _pwa_override_set "$PWA_PROVISIONING_PROFILE_KEY" "$value]"
  fi
  value=$(_pwa_override_get "$PWA_PROVISIONING_PROFILE_KEY")
  if json_is_falsy "$value"; then
    log_and_exit "iOS PWA (pwa_platform ipa) requires provisioning profiles. Use --provisioning_profiles (-pr)"
  fi
}

pwa_request_body() {
  local i value body='{'
  for i in "${!PWA_CONFIG_ENTRY_KEYS[@]}"; do
    value="${PWA_CONFIG_ENTRY_VALUES[$i]}"
    json_is_falsy "$value" && continue
    [[ "$body" != '{' ]] && body+=','
    body+="\"${PWA_CONFIG_ENTRY_KEYS[$i]}\":$value"
  done
  if [[ ${#PWA_OVERRIDE_KEYS[@]} -gt 0 ]]; then
    [[ "$body" != '{' ]] && body+=','
    body+="\"overrides\":$(pwa_overrides_json)"
  fi
  printf '%s}' "$body"
}

# Keeps base64 provisioning profiles out of the debug log.
_pwa_redacted_body() {
  printf '%s' "$1" | awk '
{ s = s $0 }
END {
  out = ""
  while (match(s, /"content":"[^"]*"/)) {
    out = out substr(s, 1, RSTART - 1) "\"content\":\"<base64, " (RLENGTH - 12) " chars>\""
    s = substr(s, RSTART + RLENGTH)
  }
  printf "%s", out s
}'
}

# Fills PWA_APP_IDS / PWA_TASK_IDS / PWA_PACK_TYPES / PWA_STATUSES, one entry per uploaded platform.
# The task ID is empty when no automatic build was started (account without Short Flow).
# Short Flow:    [{"app": {"id": ..., "pack_type": "aab", "status": "active", ...}, "taskId": {"task_id": ...}}]
# Upload only:   [{"app": {"id": ..., "pack_type": "aab", "status": "active", ...}}]
# The published spec documents {"task_id": ...}, which is also accepted.
parse_pwa_upload_response() {
  local response="$1" type items item idx app app_id task_id
  PWA_APP_IDS=()
  PWA_TASK_IDS=()
  PWA_PACK_TYPES=()
  PWA_STATUSES=()
  type=$(json_type "$response")
  if [[ "$type" == "array" ]]; then
    items=$(json_entries "$response") || log_and_exit "Error in PWA upload response: $(_truncate_value "$response")"
  elif [[ "$type" == "object" ]]; then
    items="0"$'\t'"$response"
  else
    log_and_exit "Error in PWA upload response: $(_truncate_value "$response")"
  fi
  while IFS=$'\t' read -r idx item; do
    [[ -z "$idx" ]] && continue
    if [[ "$(json_type "$item")" != "object" ]]; then
      log_and_exit "Error in PWA upload response: $(_truncate_value "$response")"
    fi
    app=$(json_get "$item" app) || app='{}'
    [[ "$(json_type "$app")" != "object" ]] && app='{}'
    app_id=$(json_string_value "$(json_get "$app" id)")
    task_id=$(json_string_value "$(json_get "$item" taskId task_id)")
    if [[ -z "$task_id" ]]; then
      task_id=$(json_string_value "$(json_get "$item" task_id)")
    fi
    if [[ -z "$app_id" && -z "$task_id" ]]; then
      log_and_exit "Error in PWA upload response: $(_truncate_value "$response")"
    fi
    PWA_APP_IDS+=("$app_id")
    PWA_TASK_IDS+=("$task_id")
    PWA_PACK_TYPES+=("$(json_string_value "$(json_get "$app" pack_type)")")
    PWA_STATUSES+=("$(json_string_value "$(json_get "$app" status)")")
  done <<< "$items"
  if [[ ${#PWA_APP_IDS[@]} -eq 0 ]]; then
    log_and_exit "Error in PWA upload response: $(_truncate_value "$response")"
  fi
}

# Uploads the PWA. When the account's Short Flow starts an automatic build, waits for it ($1 = true).
pwa_build() {
  local wait="${1:-false}" operation="PWA upload"
  local url="$SERVER_URL/api/v1/pwappload?team_id=$TEAM_ID"
  local body body_file response http_body http_code i
  log_info "Preparing PWA upload for [$(json_string_value "$(pwa_config_value pwa_address)")] ($PWA_PLATFORM)"
  start_upload_time=$(date +%s)

  body=$(pwa_request_body)
  body_file=$(mktemp "${TMPDIR:-/tmp}/appdome_pwa_body.XXXXXX") || log_and_exit "Cannot create a temporary file"
  printf '%s' "$body" > "$body_file"
  debug_log_request post "$url" "body=$(_truncate_value "$(_pwa_redacted_body "$body")" 2000)"
  response=$(curl -s -w "\n%{http_code}" --request POST \
    --url "$url" \
    --header "Authorization: $API_KEY" \
    --header "accept: application/json" \
    --header "Content-Type: application/json" \
    --header "X-Appdome-Client: $APPDOME_CLIENT_HEADER" \
    --data-binary "@$body_file")
  rm -f "$body_file"
  http_body=$(printf '%s' "$response" | sed '$d')
  http_code=$(printf '%s' "$response" | tail -n1)
  if [[ "$http_code" != "200" && "$http_code" != "204" ]]; then
    log_and_exit "$operation failed. Status code: $http_code. Response: $(_truncate_value "$http_body")"
  fi
  log_debug "PWA upload response: $(_truncate_value "$http_body")"
  parse_pwa_upload_response "$http_body"
  printTime $((($(date +%s) - start_upload_time))) "Upload took: "

  for i in "${!PWA_APP_IDS[@]}"; do
    log_info "PWA upload done. App ID: ${PWA_APP_IDS[$i]}. Type: ${PWA_PACK_TYPES[$i]}. Status: ${PWA_STATUSES[$i]}"
    if [[ -n "${PWA_STATUSES[$i]}" && "${PWA_STATUSES[$i]}" != "active" ]]; then
      log_warn "PWA app status is [${PWA_STATUSES[$i]}], expected [active]"
    fi
    if [[ -z "${PWA_TASK_IDS[$i]}" ]]; then
      log_info "No automatic build started (Short Flow not enabled on this account). Build the App ID with a Fusion Set using the regular build flow."
      continue
    fi
    log_info "Automatic build started (Short Flow, default Playground Fusion Set). Build ID: ${PWA_TASK_IDS[$i]}"
    if [[ "$wait" == "true" ]]; then
      TASK_ID="${PWA_TASK_IDS[$i]}"
      statusWaiter "Build app"
      log_info "PWA build ${PWA_TASK_IDS[$i]} finished."
    fi
  done
}

# Uploads the PWA and sets TASK_ID to the Build ID for the rest of the flow (sign, download).
# Short Flow accounts: the upload is built automatically (default Playground Fusion Set) and --fusion_set_id is
# ignored. Otherwise the App ID is built with --fusion_set_id (or APPDOME_ANDROID_FS_ID / APPDOME_IOS_FS_ID).
pwa_upload_and_build() {
  pwa_build true
  if [[ ${#PWA_APP_IDS[@]} -ne 1 ]]; then
    log_and_exit "Expected a single PWA upload, got ${#PWA_APP_IDS[@]}: ${PWA_APP_IDS[*]}"
  fi
  local app_id="${PWA_APP_IDS[0]}" task_id="${PWA_TASK_IDS[0]}"
  if [[ -n "$task_id" ]]; then
    if [[ -n "$FUSION_SET_ID" ]]; then
      log_warn "--fusion_set_id $FUSION_SET_ID was not used: Short Flow built the app automatically with the default Playground Fusion Set"
    fi
    TASK_ID="$task_id"
    log_info "PWA upload and build finished."
    return
  fi

  init_fusion_set_id_from_env
  if [[ -z "$FUSION_SET_ID" ]]; then
    log_and_exit "PWA uploaded (App ID: $app_id) but not built: this account has no automatic Short Flow build. Pass --fusion_set_id (or set the platform Fusion Set environment variable) and run again, or build App ID $app_id with a Fusion Set using the Appdome build API"
  fi
  APP="{\"id\":\"$app_id\"}"
  log_info "Building PWA App ID $app_id with Fusion Set $FUSION_SET_ID"
  build
}
