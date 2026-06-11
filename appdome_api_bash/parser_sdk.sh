#!/bin/bash

validate_inputs() {
  reset_validation_errors

  if [[ -z "$APP_LOCATION" ]]; then
    require_param "--app (-a) is required — path to .aar or .zip SDK file" "$APP_LOCATION"
  elif [[ "$APP_LOCATION" == *".aar" ]]; then
    PLATFORM=ANDROID
  else
    PLATFORM=IOS
  fi

  require_param "--api_key (-key) is required (or set APPDOME_API_KEY environment variable)" "$API_KEY"
  require_param "--fusion_set_id (-fs) is required" "$FUSION_SET_ID"
  require_param "--output (-o) is required — output path for the fused SDK" "$FINAL_OUTPUT_LOCATION"
  flush_validation_errors

  if [[ $PLATFORM == IOS ]]; then
    if { [ -z "$SIGNING_KEYSTORE" ] && [ -n "$KEYSTORE_PASS" ]; } || { [ -n "$SIGNING_KEYSTORE" ] && [ -z "$KEYSTORE_PASS" ]; }; then
        log_and_exit "Both --keystore (-k) and --keystore_pass (-kp) must be specified together"
    elif [ -z "$SIGNING_KEYSTORE" ] && [ -z "$KEYSTORE_PASS" ]; then
        log_info "Keystore and keystore_pass weren't supplied. Will continue with private sign."
    else
        validate_files "Keystore" "$SIGNING_KEYSTORE"
    fi
  fi
  if [[ -n "$WORKFLOW_OUTPUT_LOGS" ]]; then
    if [[ -d "$WORKFLOW_OUTPUT_LOGS" ]]; then
      WORKFLOW_OUTPUT_LOGS="$WORKFLOW_OUTPUT_LOGS/workflow.log"
    fi
  fi
}

help() {
  # Display Help
  echo
  echo "-key  |  --api_key                          Appdome API key (required)"
  echo "-fs   |  --fusion_set_id                    Fusion-set-id to use (required)"
  echo "-du   |  --direct_upload                    Upload app directly to Appdome, and not through aws pre-signed url (optional)"
  echo "-t    |  --team_id                          Appdome team id (optional)"
  echo "-a    |  --app                              .aar/.zip file (SDK) location (required)"
  echo "-o    |  --output                           Output file for fused and signed SDK after Appdome (required)"
  echo "-co   |  --certificate_output               Output file for Certified Secure pdf (optional)"
  echo "-cj   |  --certificate_json                 Output file for Certified Secure json (optional)"
  echo "-dso  |  --deobfuscation_script_output      Output file deobfuscation scripts when building with obfuscation (optional)"
  echo "-bv   |  --build_overrides                  Path to json file with build overrides (optional)"
  echo "-bl   |  --build_logs                       Build with diagnostic logs (optional)"
  echo "-wol  |  --workflow_output_logs             Enter path to a workflow output logs file (optional)"
  echo "-v    |  --verbose                          Show debug logs"
  echo "Signing attribute:"
  echo "-k    |  --keystore                         Path to keystore file to use on Appdome iOS signing"
  echo "-kp   |  --keystore_pass                    Password for keystore to use on Appdome iOS signing"
}

parse_args() {
  local UNKNOWN_ARGS=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -key | --api_key)
      API_KEY="$2"
      shift 2
      ;;
    -t | --team_id)
      TEAM_ID="$2"
      shift 2
      ;;
    -fs | --fusion_set_id)
      FUSION_SET_ID="$2"
      shift 2
      ;;
    -du | --direct_upload)
      DIRECT_UPLOAD=true
      shift 1
      ;;
    -a | --app)
      APP_LOCATION="$2"
      APP_FILE_NAME="$(basename -- "$APP_LOCATION")"
      shift 2
      ;;
    -k | --keystore)
      SIGNING_KEYSTORE="$2"
      shift 2
      ;;
    -kp | --keystore_pass)
      KEYSTORE_PASS="$2"
      shift 2
      ;;
    -o | --output)
      FINAL_OUTPUT_LOCATION="$2"
      shift 2
      ;;
    -co | --certificate_output)
      CERTIFICATE_OUTPUT_LOCATION=$2
      shift 2
      ;;
    -cj | --certificate_json)
      CERTIFICATE_JSON_OUTPUT_LOCATION=$2
      shift 2
      ;;
    -dso | --deobfuscation_script_output)
      DEOBFUSCATION_SCRIPT_OUTPUT_LOCATION=$2
      shift 2
      ;;
    -bv | --build_overrides)
      BUILD_OVERRIDES=$(cat "$2")
      shift 2
      ;;
    -bl | --build_logs)
      BUILD_KEY="extended_logs"
      BUILD_VALUE=true
      shift 1
      ;;
    -wol | --workflow_output_logs)
      WORKFLOW_OUTPUT_LOGS=$2
      shift 2
      ;;
    -v | --verbose)
      VERBOSE=true
      shift 1
      ;;
    -h | --help)
      help
      exit
      ;;
    -*)
      UNKNOWN_ARGS+=("$1")
      shift 1
      if [[ $# -gt 0 && "$1" != -* ]]; then
        log_debug "Skipping value for unknown option: $1"
        shift 1
      fi
      ;;
    *)
      log_and_exit "Unexpected argument: $1"
      ;;
    esac
  done
  if [[ ${#UNKNOWN_ARGS[@]} -gt 0 ]]; then
    report_unknown_arguments "${UNKNOWN_ARGS[@]}"
  fi
  init_logging
  log_debug "Parsed arguments: app=$APP_LOCATION fusion_set_id=$FUSION_SET_ID output=$FINAL_OUTPUT_LOCATION"
  validate_inputs
}
