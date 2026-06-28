#!/bin/bash
PRIVATE_SIGN_ACTION='seal'
AUTO_DEV_SIGN_ACTION='sign_script'
SIGN_ACTION='sign'

validate_inputs() {
  reset_validation_errors

  require_param "--app (-a) is required — path to .ipa, .apk, or .aab file" "$APP_LOCATION"

  if [[ "$APP_LOCATION" == *".ipa" ]]; then
    PLATFORM=IOS
  elif [[ "$APP_LOCATION" == *".aab" || "$APP_LOCATION" == *".apk" ]]; then
    PLATFORM=ANDROID
  fi

  init_api_key_from_env
  init_team_id_from_env
  init_fusion_set_id_from_env
  require_param "--api_key (-key) is required (or set APPDOME_API_KEY environment variable)" "$API_KEY"
  require_param "--fusion_set_id (-fs) is required (or set APPDOME_IOS_FS_ID / APPDOME_ANDROID_FS_ID environment variable)" "$FUSION_SET_ID"
  require_param "One signing method is required: --sign_on_appdome (-s), --private_signing (-ps), or --auto_dev_private_signing (-adps)" "$SIGN_METHOD"
  require_param "--output (-o) is required — output path for the fused and signed app" "$FINAL_OUTPUT_LOCATION"
  flush_validation_errors

  if [[ "$PLATFORM" == "UNKNOWN" ]]; then
    log_and_exit "App extension must be .ipa, .apk, or .aab (got: $APP_LOCATION)"
  fi

  if [[ -n "$TRUSTED_SIGNING_FINGERPRINTS_FILE" ]] && [[ "$PLATFORM" == "IOS" ]]; then
    log_and_exit "--signing_fingerprint_list is only valid for Android applications"
  fi

  if [[ -n $BUILD_TO_TEST ]] && [[ -n ${BUILD_TO_TEST+x} ]]; then
    case $BUILD_TO_TEST in
      AUTOMATION_BITBAR|AUTOMATION_BROWSERSTACK|AUTOMATION_LAMBDATEST|AUTOMATION_SAUCELABS|AUTOMATION_PERFECTO|AUTOMATION_FIREBASE|AUTOMATION_KATALON|AUTOMATION_KOBITON|AUTOMATION_TOSCA|AUTOMATION_AWS_DEVICE_FARM)
        ;;
      *)
        log_and_exit "Vendor name provided for Build To Test isn't one of the acceptable vendors: $BUILD_TO_TEST"
        ;;
    esac
  fi

  if [[ $PLATFORM == UNKNOWN ]]; then
    if [[ -n "$PROVISIONING_PROFILES" && -z "$SIGNING_FINGERPRINT" && -z "$KEYSTORE_ALIAS" ]]; then
      PLATFORM=IOS
    elif [[ -z "$PROVISIONING_PROFILES" ]] && [[ -n "$SIGNING_FINGERPRINT" || -n "$KEYSTORE_ALIAS" ]]; then
      PLATFORM=ANDROID
    else
      log_and_exit "Please specify the correct platform signing credentials (provisioning profiles for iOS, or signing fingerprint / keystore alias for Android)"
    fi
  fi
  case "$SIGN_METHOD" in
  "$PRIVATE_SIGN_ACTION")
    if [[ $PLATFORM == IOS ]]; then
      if [[ ${#PROVISIONING_PROFILES[@]} -eq 0 ]] || [[ -z "${PROVISIONING_PROFILES[0]}" ]]; then
        log_and_exit "--provisioning_profiles (-pr) is required for iOS private signing"
      fi
      validate_files "Provisioning profile" "${PROVISIONING_PROFILES[@]}"
    else
      # Validate mutual exclusivity of signing_fingerprint_list with signing fingerprint
      if [[ -n "$TRUSTED_SIGNING_FINGERPRINTS_FILE" ]]; then
        if [[ -n "$SIGNING_FINGERPRINT" || -n "$SIGNING_FINGERPRINT_UPGRADE" || -n "$GOOGLE_PLAY_SIGNING" ]]; then
          log_and_exit "--signing_fingerprint_list cannot be used with --google_play_signing, --signing_fingerprint, or --signing_fingerprint_upgrade"
        fi
      else
        require_param "--signing_fingerprint (-cf) is required for Android private signing (or use --signing_fingerprint_list)" "$SIGNING_FINGERPRINT"
        flush_validation_errors
      fi
    fi
    ;;
  "$AUTO_DEV_SIGN_ACTION")
    if [[ $PLATFORM == IOS ]]; then
      validate_files "Provisioning profile" "${PROVISIONING_PROFILES[@]}"
      validate_files "Entitlements" "${ENTITLEMENTS[@]}"
    else
      if [[ -n "$TRUSTED_SIGNING_FINGERPRINTS_FILE" ]]; then
        if [[ -n "$SIGNING_FINGERPRINT" || -n "$SIGNING_FINGERPRINT_UPGRADE" || -n "$GOOGLE_PLAY_SIGNING" ]]; then
          log_and_exit "--signing_fingerprint_list cannot be used with --google_play_signing, --signing_fingerprint, or --signing_fingerprint_upgrade"
        fi
      else
        require_param "--signing_fingerprint (-cf) is required for Android auto-dev signing (or use --signing_fingerprint_list)" "$SIGNING_FINGERPRINT"
        flush_validation_errors
      fi
    fi
    ;;
  "$SIGN_ACTION")
    if [[ $PLATFORM == IOS ]]; then
      require_param "--keystore_pass (-kp) is required for iOS on-Appdome signing" "$KEYSTORE_PASS"
      flush_validation_errors
      validate_files "Provisioning profile" "${PROVISIONING_PROFILES[@]}"
      validate_files "Keystore" "$SIGNING_KEYSTORE"
      validate_files "Entitlements" "${ENTITLEMENTS[@]}"
    else
      require_param "--keystore_pass (-kp) is required for Android on-Appdome signing" "$KEYSTORE_PASS"
      require_param "--keystore_alias (-ka) is required for Android on-Appdome signing" "$KEYSTORE_ALIAS"
      require_param "--key_pass (-kyp) is required for Android on-Appdome signing" "$KEYS_PASS"
      flush_validation_errors
      validate_files "Keystore" "$SIGNING_KEYSTORE"
      if [[ $GOOGLE_PLAY_SIGNING ]]; then
        require_param "--signing_fingerprint (-cf) is required when using --google_play_signing" "$SIGNING_FINGERPRINT"
        flush_validation_errors
        if [[ -n "$SIGNING_FINGERPRINT_UPGRADE" ]] && [[ -z "$SIGNING_FINGERPRINT" ]]; then
          log_and_exit "Base Google signing fingerprint (--signing_fingerprint) is required to use --signing_fingerprint_upgrade"
        fi
      fi
      if [[ -n "$TRUSTED_SIGNING_FINGERPRINTS_FILE" ]]; then
        if [[ -n "$GOOGLE_PLAY_SIGNING" || -n "$SIGNING_FINGERPRINT" || -n "$SIGNING_FINGERPRINT_UPGRADE" ]]; then
          log_and_exit "--signing_fingerprint_list cannot be used with --google_play_signing, --signing_fingerprint, or --signing_fingerprint_upgrade"
        fi
      fi
    fi
    ;;
  esac
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
  echo "       |  --skip_upload_checksum_call        Skip check-by-checksum API call before upload (optional)"
  echo "-t    |  --team_id                          Appdome team id (optional)"
  echo "-a    |  --app                              Application location (required)"
  echo "-o    |  --output                           Output file for fused and signed app after Appdome (required)"
  echo "-so   |  --second_output                    Second_output_app_file (optional)"
  echo "-co   |  --certificate_output               Output file for Certified Secure pdf (optional)"
  echo "-cj   |  --certificate_json                 Output file for Certified Secure json (optional)"
  echo "-dso  |  --deobfuscation_script_output      Output file deobfuscation scripts when building with "Obfuscate App Logic" (optional)"
  echo "-aid  |  --app_id                           App ID in Firebase project (optional)"
  echo "-dd_api_key | --datadog_api_key             Data Dog API_KEY (required for DataDog Deobfuscation) (optional)"
  echo "-baseline_profile | --baseline_profile      baseline profile file to use (optional)"
  echo "-startup_profile | --startup_profile        startup profile file to use (optional)"
  echo "-input_mapping | --input_mapping            input mapping file to use (optional)"
  echo "-cert_zip | --cert_pinning_zip              Path to zip file containing dynamic certificates for certificate pinning (optional)"
  echo "-bv   |  --build_overrides                  Path to json file with build overrides (optional)"
  echo "-bl   |  --build_logs                       Build with diagnostic logs (optional)"
  echo "-cv   |  --context_overrides                Path to json file with context overrides (optional)"
  echo "-sv   |  --sign_overrides                   Path to json file with sign overrides (optional)"
  echo "-btv  |  --build_to_test_vendor             Enter vendor name on which Build to Test will happen (optional)"
  echo "-wol  |  --workflow_output_logs             Enter path to a workflow output logs file (optional)"
  echo "-v    |  --verbose                          Show debug logs (request URLs, validation details)"
  echo
  echo "please use one of the following signing options (one of the three is required)"
  echo "-s    |  --sign_on_appdome                  Sign on Appdome"
  echo "-ps   |  --private_signing                  Sign application manually"
  echo "-adps |  --auto_dev_private_signing         Use a pre-generated signing script for automated local signing"
  echo
  echo "Signing attribute:"
  echo "-k    |  --keystore                         Path to keystore file to use on Appdome iOS and Android signing"
  echo "-pr   |  --provisioning_profiles            Path to iOS provisioning profiles files to use. Can be multiple profiles"
  echo "-entt |  --entitlements                     Path to iOS entitlements plist to use. Can be multiple entitlements files"
  echo "-cf   |  --signing_fingerprint              SHA-1 or SHA-256 final Android signing certificate fingerprint"
  echo "-cfu  |  --signing_fingerprint_upgrade      SHA-1 or SHA-256 Upgraded signing certificate fingerprint for Google Play App Signing"
  echo "-sfp  |  --signing_fingerprint_list         Path to JSON file with trusted signing fingerprints list (mutually exclusive with -gp, -cf, -cfu)"
  echo "-gp   |  --google_play_signing              This Android application will be distributed via the Google Play App Signing program"
  echo "-kp   |  --keystore_pass                    Password for keystore to use on Appdome iOS and Android signing"
  echo "-ka   |  --keystore_alias                   Key alias to use on Appdome Android signing"
  echo "-kyp  |  --key_pass                         Password for both Android and iOS key to use on Appdome Android signing"
  echo
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
    --skip_upload_checksum_call)
      SKIP_UPLOAD_CHECKSUM_CALL=true
      shift 1
      ;;
    -a | --app)
      APP_LOCATION="$2"
      APP_FILE_NAME="$(basename -- "$APP_LOCATION")"
      shift 2
      ;;
    -s | --sign_on_appdome)
      SIGN_METHOD="$SIGN_ACTION"
      shift 1
      ;;
    -ps | --private_signing)
      SIGN_METHOD="$PRIVATE_SIGN_ACTION"
      shift 1
      ;;
    -adps | --auto_dev_private_signing)
      SIGN_METHOD="$AUTO_DEV_SIGN_ACTION"
      shift 1
      ;;
    -k | --keystore)
      SIGNING_KEYSTORE="$2"
      shift 2
      ;;
    -pr | --provisioning_profiles)
      IFS=',' read -r -a PROVISIONING_PROFILES <<< "$2"
      shift 2
      ;;
    -entt | --entitlements)
      IFS=',' read -r -a ENTITLEMENTS <<< "$2"
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
    -wol | --workflow_output_logs)
      WORKFLOW_OUTPUT_LOGS=$2
      shift 2
      ;;
    -dso | --deobfuscation_script_output)
      DEOBFUSCATION_SCRIPT_OUTPUT_LOCATION=$2
      shift 2
      ;;
    -aid | --app_id)
      APP_ID=$2
      shift 2
      ;;
    -dd_api_key | --datadog_api_key)
      DD_API_KEY=$2
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
    -so | --second_output)
      SECOND_OUTPUT_FILE="$2"
      shift 2
      ;;
    -btv | --build_to_test_vendor)
      BUILD_TO_TEST="AUTOMATION_$(echo "$2" | tr '[:lower:]' '[:upper:]')"  # Convert to uppercase and add as prefix
      shift 2
      ;;
    -cv | --context_overrides)
      CONTEXT_OVERRIDES=$(cat "$2")
      shift 2
      ;;
    -sv | --sign_overrides)
      SIGN_OVERRIDES=$(cat "$2")
      shift 2
      ;;
    -cf | --signing_fingerprint)
      SIGNING_FINGERPRINT="$2"
      shift 2
      ;;
    -cfu | --signing_fingerprint_upgrade)
      SIGNING_FINGERPRINT_UPGRADE="$2"
      shift 2
      ;;
    -sfp | --signing_fingerprint_list)
      if [[ ! -f "$2" ]]; then
        log_and_exit "Trusted signing fingerprints file does not exist: $2"
      fi
      TRUSTED_SIGNING_FINGERPRINTS_FILE="$2"
      TRUSTED_SIGNING_FINGERPRINTS=$(cat "$2")
      shift 2
      ;;
    -gp | --google_play_signing)
      GOOGLE_PLAY_SIGNING=true
      shift 1
      ;;
    -kp | --keystore_pass)
      KEYSTORE_PASS="$2"
      shift 2
      ;;
    -baseline_profile | --baseline_profile)
      BASELINE_PROFILE="$2"
      shift 2
      ;;
    -startup_profile | --startup_profile)
      STARTUP_PROFILE="$2"
      shift 2
      ;;
    -input_mapping | --input_mapping)
      INPUT_MAPPING="$2"
      shift 2
      ;;
    -cert_zip | --cert_pinning_zip)
      CERT_ZIP="$2"
      shift 2
      ;;
    -ka | --keystore_alias)
      KEYSTORE_ALIAS="$2"
      shift 2
      ;;
    -kyp | --key_pass)
      KEYS_PASS="$2"
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
  validate_inputs
  log_debug "Parsed arguments: app=$APP_LOCATION fusion_set_id=$FUSION_SET_ID sign_method=$SIGN_METHOD output=$FINAL_OUTPUT_LOCATION"
}
