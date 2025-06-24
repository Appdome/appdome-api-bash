#!/bin/bash

source ./appdome_api_bash/parser.sh
source ./appdome_api_bash/upload.sh
source ./appdome_api_bash/direct_upload.sh
source ./appdome_api_bash/build.sh
source ./appdome_api_bash/context.sh
source ./appdome_api_bash/private_sign.sh
source ./appdome_api_bash/sign.sh
source ./appdome_api_bash/auto_dev_sign.sh
source ./appdome_api_bash/download.sh
source ./appdome_api_bash/status.sh
source ./appdome_api_bash/crashlytics.sh
source ./appdome_api_bash/datadog.sh

SERVER_URL="${APPDOME_SERVER_BASE_URL:-https://fusion.appdome.com}"
API_KEY="${API_KEY_ENV:-}"
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
  case "$SIGN_METHOD" in
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

  download_fused_app
  if [[ -n "$CERTIFICATE_OUTPUT_LOCATION" ]]; then
    download_certified_secure
  fi

  if [[ -n "$CERTIFICATE_JSON_OUTPUT_LOCATION" ]]; then
    download_certified_secure_json_test
  fi

  if statusForObfuscation && [[ -n "$DEOBFUSCATION_SCRIPT_OUTPUT_LOCATION" ]]; then
    download_deobfuscation_script

    # Check for Crashlytics API key before calling upload function
    if [[ -n "$APP_ID" ]]; then
        upload_deobfuscation_mapping_to_crashlytics
    fi
    # Check for DataDog API key before calling upload function
    if [[ -n "$DD_API_KEY" ]]; then
        upload_deobfuscation_mapping_to_datadog
    fi

  fi

  if [[ -n "$SECOND_OUTPUT_FILE" ]]; then
    download_second_output
  fi

  printTime $((($(date +%s) - start_all_process_time))) "Appdome API took: "
}

main "$@"
