#!/bin/bash

source ./utils.sh
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
source ./appdome_api_bash/appdome_test.sh

init_server_url
API_KEY="${APPDOME_API_KEY:-${API_KEY_ENV:-}}"
TEAM_ID=''
FUSION_SET_ID=''
APP_LOCATION=''
FINAL_OUTPUT_LOCATION=''
APP_FILE_NAME="$(basename -- "$APP_LOCATION")"
SIGN_METHOD=''
PLATFORM=UNKNOWN
BUILD_OVERRIDES="{}"
CONTEXT_OVERRIDES="{}"
SIGN_OVERRIDES="{}"
APPDOME_TEST=false
WAIT=false
APPDOME_TEST_RESULTS=''


assign_client_header

main() {
  parse_args "$@"
  start_all_process_time=$(date +%s)
  log_info "Starting Appdome flow"
 
  if [[ "$DIRECT_UPLOAD" == "true" ]]; then
    log_info "Uploading app directly to Appdome"
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

  if [[ -n "$FINAL_OUTPUT_LOCATION" ]]; then
    download_fused_app
  fi
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

  if [[ "$APPDOME_TEST" == "true" ]]; then
    _appdome_test
  fi

  printTime $((($(date +%s) - start_all_process_time))) "Appdome API took: "
}

_appdome_test() {
  PARENT_TASK_ID="$TASK_ID"
  start_appdome_test
  if [[ "$WAIT" == "true" || -n "$APPDOME_TEST_RESULTS" ]]; then
    statusWaiter "Appdome Test"
  fi
  if [[ -n "$APPDOME_TEST_RESULTS" ]]; then
    download "Download Appdome Test results" \
      "--url '$SERVER_URL/api/v1/tasks/$TASK_ID/appdome-test-result?team_id=$TEAM_ID'" \
      "$APPDOME_TEST_RESULTS"
  fi
}

main "$@"
