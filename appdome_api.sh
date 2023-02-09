#!/bin/bash

source ./appdome_api_bash/parser.sh
source ./appdome_api_bash/upload.sh
source ./appdome_api_bash/build.sh
source ./appdome_api_bash/context.sh
source ./appdome_api_bash/private_sign.sh
source ./appdome_api_bash/sign.sh
source ./appdome_api_bash/auto_dev_sign.sh
source ./appdome_api_bash/download.sh
source ./appdome_api_bash/certified_secure.sh
source ./appdome_api_bash/status.sh

# This script uses curl and jq methods

SERVER_URL='https://fusion.appdome.com'
API_KEY=''
TEAM_ID='personal'
FUSION_SET_ID=''
APP_LOCATION=''
FINAL_OUTPUT_LOCATION=''
APP_FILE_NAME="$(basename -- "$APP_LOCATION")"
SIGN_METHOD=''
PLATFORM=UNKNOWN
BUILD_OVERRIDES="{}"
CONTEXT_OVERRIDES="{}"
SIGN_OVERRIDES="{}"
if [[ -z "$APPDOME_CLIENT_HEADER" ]]; then
  APPDOME_CLIENT_HEADER='Appdome-cli-bash/1.0'
else
  APPDOME_CLIENT_HEADER=$(printenv APPDOME_CLIENT_HEADER)
fi

main() {
  parse_args "$@"
  start_all_process_time=$(date +%s)
  echo "Starting Appdome flow"
  echo ""

  upload
  build
  [[ "$STATUS" == "completed" ]] && context
  [[ "$STATUS" == "completed" ]] && case "$SIGN_METHOD" in
  "$PRIVATE_SIGN_ACTION")
    if [[ $PLATFORM == IOS ]]; then
      private_sign_ios
    else
      private_sign_android
    fi
    ;;
  "$AUTO_DEV_SIGN_ACTION")
    if [[ $PLATFORM == IOS ]]; then
      auto_sign_ios
    else
      auto_sign_android
    fi
    ;;
  "$SIGN_ACTION")
    if [[ $PLATFORM == IOS ]]; then
      sign_ios
    else
      sign_android
    fi
    ;;
  esac

  download
  if [[ -n "$CERTIFICATE_OUTPUT_LOCATION" ]]; then
    download_certified_secure
  fi

  printTime $((($(date +%s) - start_all_process_time))) "Appdome API took: "
}

main "$@"
