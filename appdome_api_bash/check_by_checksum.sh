#!/bin/bash

source ./utils.sh

sha256_checksum() {
  local file_path="$1"
  local checksum=""

  if [[ ! -f "$file_path" ]]; then
    log_debug "Cannot compute checksum: file not found: $file_path"
    return 1
  fi

  if command -v sha256sum >/dev/null 2>&1; then
    checksum=$(sha256sum "$file_path" 2>/dev/null | awk '{print $1}')
  elif command -v shasum >/dev/null 2>&1; then
    checksum=$(shasum -a 256 "$file_path" 2>/dev/null | awk '{print $1}')
  elif command -v openssl >/dev/null 2>&1; then
    checksum=$(openssl dgst -sha256 "$file_path" 2>/dev/null | awk '{print $NF}')
  fi

  if [[ -z "$checksum" || ${#checksum} -ne 64 ]]; then
    log_info "Unable to compute SHA-256 checksum, proceeding with standard upload"
    return 1
  fi

  echo "$checksum"
  return 0
}

get_existing_app_id() {
  if [[ "$SKIP_UPLOAD_CHECKSUM_CALL" == "true" ]]; then
    log_info "Skipping check-by-checksum API call before upload"
    return 1
  fi

  local checksum
  checksum=$(sha256_checksum "$APP_LOCATION") || return 1

  log_info "Checking for existing app with checksum [$checksum]"

  local url="$SERVER_URL/api/v1/apps/check-by-checksum?team_id=$TEAM_ID"
  debug_log_request post "$url" "checksum=$checksum"

  local response http_body http_code
  response=$(curl -s -w "\n%{http_code}" --request POST \
    --url "$url" \
    --header "Authorization: $API_KEY" \
    --header "Content-Type: application/json" \
    --header "X-Appdome-Client: $APPDOME_CLIENT_HEADER" \
    --data "{\"checksum\":\"$checksum\"}" 2>/dev/null) || {
    log_debug "Check-by-checksum request failed, proceeding with standard upload"
    return 1
  }

  http_body=$(echo "$response" | sed '$d')
  http_code=$(echo "$response" | tail -n1)

  if [[ "$http_code" == "404" ]]; then
    log_debug "Check-by-checksum API not available, proceeding with standard upload"
    return 1
  fi

  if [[ "$http_code" != "200" ]]; then
    log_debug "Check-by-checksum returned HTTP $http_code, proceeding with standard upload"
    return 1
  fi

  log_debug "Check-by-checksum response: $http_body"

  if echo "$http_body" | grep -q '"exists"[[:space:]]*:[[:space:]]*true'; then
    local app_id
    app_id=$(extract_string_value_from_json "$http_body" "app_id")
    if [[ -n "$app_id" ]]; then
      echo "$app_id"
      return 0
    fi
  fi

  return 1
}

set_app_from_existing_id() {
  local existing_app_id="$1"
  APP="{\"id\":\"$existing_app_id\"}"
  log_info "Found existing app by checksum. App id: $existing_app_id"
}

try_use_existing_app_by_checksum() {
  local existing_app_id
  existing_app_id=$(get_existing_app_id) || return 1
  if [[ -z "$existing_app_id" ]]; then
    return 1
  fi
  set_app_from_existing_id "$existing_app_id"
  return 0
}
