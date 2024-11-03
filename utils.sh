add_google_play_signing_fingerprint() {
  add_sign_overrides "signing_keystore_use_google_signing" "true"
  add_sign_overrides "signing_keystore_google_signing_sha1_key" "$SIGNING_FINGERPRINT"
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
