add_google_play_signing_fingerprint() {
  add_sign_overrides "signing_keystore_use_google_signing" "true"
  add_sign_overrides "signing_keystore_google_signing_sha1_key" "$SIGNING_FINGERPRINT"
}

assign_client_header() {
  if [[ -z "$APPDOME_CLIENT_HEADER" ]]; then
    APPDOME_CLIENT_HEADER='Appdome-cli-bash/1.0'
  else
    APPDOME_CLIENT_HEADER=$(printenv APPDOME_CLIENT_HEADER)
  fi
}

validate_args() {
  args=("$@")
  for ((i = 1; i < $#; i++)); do
    if [[ -z "${args[i]}" ]]; then
      echo "Missing $1 arguments. Exiting.."
      exit 1
    fi
  done
}

validate_files() {
  args=("$@")
  for ((i = 1; i < $#; i++)); do
    if [[ ! -f "${args[i]}" ]]; then
      echo "$1 file: ${args[i]} does not exist."
      exit 1
    fi
  done
}

validate_response_for_errors() {
  if [[ "$1" == *"error"* ]]; then
    echo "$2 failed. Error: $1"
    exit 1
  fi
}

validate_response_code() {
  if [[ "$1" != "200" ]]; then
    echo "$2 failed. Error: $(cat $3)"
    rm $3
    exit 1
  fi
}

request_headers() {
  echo "--header 'Authorization: $API_KEY' \
        --header 'accept: application/json' \
        --header 'content-type: multipart/form-data' \
        --header 'X-Appdome-Client:$APPDOME_CLIENT_HEADER'"
}

request_api_key(){
  echo $API_KEY
}


add_provisioning_profiles_entitlements() {
  provisioning_profiles_entitlements=""
  for i in "${PROVISIONING_PROFILES[@]}"; do
    provisioning_profiles_entitlements="$provisioning_profiles_entitlements --form provisioning_profile='@$i'"
  done
  
  for i in "${ENTITLEMENTS[@]}"; do
    provisioning_profiles_entitlements="$provisioning_profiles_entitlements --form entitlements_files='@$i'"
  done
  echo $provisioning_profiles_entitlements
}

printTime() {
  local SECONDS=$(($1 % 60))
  local -i MINUTES=$1/60
  local -i HOURS=MINUTES/60
  local STR_SECONDS STR_MINUTES STR_HOURS
  if [[ "$SECONDS" -lt 10 ]]; then
    STR_SECONDS=$(echo "0$SECONDS")
  else
    STR_SECONDS="$SECONDS"
  fi
  if [[ "$MINUTES" -lt 10 ]]; then
    STR_MINUTES=$(echo "0$MINUTES")
  else
    STR_MINUTES="$MINUTES"
  fi
  if [[ "$HOURS" -lt 10 ]]; then
    STR_HOURS=$(echo "0$HOURS")
  else
    STR_HOURS="$HOURS"
  fi
  printf "$2$STR_HOURS:$STR_MINUTES:$STR_SECONDS"%s
  echo ""
}

extract_string_value_from_json() {
  local cmd="echo "\$1" | grep -o '\"$2\"\s*:\s*\"[^\"]*' | grep -o '[^\"]*$'"
  echo "$(eval $cmd)"
}

add_sign_overrides() {
  if [[ $SIGN_OVERRIDES == "{}" ]]; then
    SIGN_OVERRIDES="{\"$1\":\"$2\"}"
  else
    SIGN_OVERRIDES=${SIGN_OVERRIDES%?} # Remove last char '}'
    SIGN_OVERRIDES="$(echo "${SIGN_OVERRIDES%%[[:space:]]}")" # Remove white spacing
    SIGN_OVERRIDES="$SIGN_OVERRIDES, \"$1\":\"$2\"}" # Add new key value
  fi
}

add_build_overrides() {
  if [[ $BUILD_OVERRIDES == "{}" ]]; then
    BUILD_OVERRIDES="{\"$1\":\"$2\"}"
  else
    BUILD_OVERRIDES=${BUILD_OVERRIDES%?} # Remove last char '}'
    BUILD_OVERRIDES="$(echo "${BUILD_OVERRIDES%%[[:space:]]}")" # Remove white spacing
    BUILD_OVERRIDES="$BUILD_OVERRIDES, \"$1\":\"$2\"}" # Add new key value
  fi
}

init_certs_pinning() {
  local cert_pinning_zip="$1"
  local certs=()

  if [[ -z "$cert_pinning_zip" || ! -f "$cert_pinning_zip" ]]; then
    echo "No zip file provided or file does not exist."
    return 0
  fi

  local extract_path="${cert_pinning_zip%.*}"  # target directory

  # ── Step A: remove any existing directory first ─────────────────────────────
  if [[ -d "$extract_path" ]]; then
    rm -rf "$extract_path"
    if [[ $? -ne 0 ]]; then
      echo "Failed to remove existing directory: $extract_path" >&2
      return 1
    fi
  fi

  # ── Step B: unzip into a “clean slate” directory ──────────────────────────────
  unzip -q "$cert_pinning_zip" -d "$extract_path"
  if [[ $? -ne 0 ]]; then
    echo "Unzip failed." >&2
    return 1
  fi

  # Now $extract_path is freshly recreated. You can, if you wish, verify:
  if [[ ! -d "$extract_path" ]]; then
    echo "Extraction did not create $extract_path as expected." >&2
    return 1
  fi

  # ── Step C: locate the JSON, parse cert entries ─────────────────────────────
  local json_file
  json_file=$(find "$extract_path" -type f -name "*.json" | head -n 1)
  if [[ -z "$json_file" ]]; then
    echo "No JSON file found in the extracted zip contents."
    return 0
  fi

  while IFS= read -r line; do
    local index file_name
    index=$(echo "$line" | grep -Eo '"[^"]+"' | head -n1 | tr -d '"')
    file_name=$(extract_string_value_from_json "$line" "$index")
    local file_path="$extract_path/$file_name"
    if [[ -f "$file_path" ]]; then
      certs+=("--form 'mitm_host_server_pinned_certs_list['\\''${index}'\\''].value.mitm_host_server_pinned_certs_file_content=@\"${file_path}\"'")
    fi
  done < <(grep -Eo '"[^"]+"\s*:\s*"[^"]+"' "$json_file")

  echo "${certs[@]}"
}

parse_notification_form() {
  local notification_form=""
  if [[ -n "$NOTIFICATION_EMAIL_OVERRIDE" ]]; then
    local notification_json="{\"emails\":$NOTIFICATION_EMAIL_OVERRIDE}"
    notification_form=" --form 'notification_override=\"$(echo "$notification_json" | sed 's/"/\\\"/g')\"'"
  fi
  echo "$notification_form"
}
