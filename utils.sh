add_google_play_signing_fingerprint() {
  SIGN_OVERRIDES=$(echo $SIGN_OVERRIDES | jq '.signing_keystore_use_google_signing |= "true"')
  SIGN_OVERRIDES=$(echo $SIGN_OVERRIDES | jq '.signing_keystore_google_signing_sha1_key |= "'"$SIGNING_FINGERPRINT"'"')
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

request_headers() {
  echo "--header 'Authorization: $API_KEY' \
        --header 'accept: application/json' \
        --header 'content-type: multipart/form-data' \
        --header 'X-Appdome-Client:$APPDOME_CLIENT_HEADER'"
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
