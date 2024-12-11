#!/bin/bash

validate_inputs() {
  if [[ "$APP_LOCATION" == *".aar" ]]; then
    PLATFORM=ANDROID
  else
    PLATFORM=IOS
  fi

  # validate fusion set arguments
  validate_args "fusion-set-id" "$FUSION_SET_ID"

  # validate api key arguments
  validate_args "API key" "$API_KEY"

  # validate sign arguments
  if [[ $PLATFORM == IOS ]]; then
    if { [ -z "$SIGNING_KEYSTORE" ] && [ -n "$KEYSTORE_PASS" ]; } || { [ -n "$SIGNING_KEYSTORE" ] && [ -z "$KEYSTORE_PASS" ]; }; then
        echo "ERROR: Both keystore and keystore_pass must be specified." >&2
        exit 1
    elif [ -z "$SIGNING_KEYSTORE" ] && [ -z "$KEYSTORE_PASS" ]; then
        echo "INFO: Keystore and keystore_pass weren't supplied. Will continue with private sign."
    else
        validate_args "Signing parameters" "$KEYSTORE_PASS"
        validate_files "Signing" "$SIGNING_KEYSTORE"
    fi
  fi
  # validate api key arguments
  validate_args "Final Output Location" "$FINAL_OUTPUT_LOCATION"
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
  echo "-t    |  --team_id                          Appdome team id (optional)"
  echo "-a    |  --app                              .aar/.zip file (SDK) location (required)"
  echo "-o    |  --output                           Output file for fused and signed SDK after Appdome (required)"
  echo "-co   |  --certificate_output               Output file for Certified Secure pdf (optional)"
  echo "-cj   |  --certificate_json                 Output file for Certified Secure json (optional)"
  echo "-bv   |  --build_overrides                  Path to json file with build overrides (optional)"
  echo "-bl   |  --build_logs                       Build with diagnostic logs (optional)"
  echo "-wol  |  --workflow_output_logs             Enter path to a workflow output logs file (optional)"
  echo "Signing attribute:"
  echo "-k    |  --keystore                         Path to keystore file to use on Appdome iOS signing"
  echo "-kp   |  --keystore_pass                    Password for keystore to use on Appdome iOS signing"
}

parse_args() {
  while true; do
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
    -h | --help)
      help
      exit
      ;;
    -- | *)
      break
      ;;
    esac
  done
  validate_inputs
}