#!/bin/bash

source ./appdome_api_bash/parser_sdk.sh
source ./appdome_api_bash/upload.sh
source ./appdome_api_bash/direct_upload.sh
source ./appdome_api_bash/build.sh
source ./appdome_api_bash/private_sign.sh
source ./appdome_api_bash/sign.sh
source ./appdome_api_bash/download.sh
source ./appdome_api_bash/status.sh


SERVER_URL="${APPDOME_SERVER_BASE_URL:-https://fusion.appdome.com}"
API_KEY="${API_KEY_ENV:-}"
TEAM_ID='personal'
FUSION_SET_ID=''
APP_LOCATION=''
FINAL_OUTPUT_LOCATION=''
APP_FILE_NAME="$(basename -- "$APP_LOCATION")"
PLATFORM=UNKNOWN
BUILD_OVERRIDES="{}"
SIGN_OVERRIDES="{}"

assign_client_header

main() {
  parse_args "$@"
  start_all_process_time=$(date +%s)
  echo "Starting Appdome flow"
  echo ""

  if [[ "$DIRECT_UPLOAD" == "true" ]]; then
    echo "Uploading app directly to Appdome"
    direct_upload
  else
    upload
  fi
  build

  if [[ $PLATFORM == "IOS" ]]; then
      if [[ -n "$SIGNING_KEYSTORE" ]]; then
          sign_ios
      else
          private_sign_ios
      fi
  fi

  download_fused_app
  if [[ -n "$CERTIFICATE_OUTPUT_LOCATION" ]]; then
    download_certified_secure
  fi

  if [[ -n "$CERTIFICATE_JSON_OUTPUT_LOCATION" ]]; then
    download_certified_secure_json_test
  fi

  printTime $((($(date +%s) - start_all_process_time))) "Appdome API took: "
}

main "$@"