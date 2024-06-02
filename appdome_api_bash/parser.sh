#!/bin/bash
PRIVATE_SIGN_ACTION='seal'
AUTO_DEV_SIGN_ACTION='sign_script'
SIGN_ACTION='sign'

validate_inputs() {
  if [[ "$APP_LOCATION" == *".ipa" ]]; then
    PLATFORM=IOS
  elif [[ "$APP_LOCATION" == *".aab" || "$APP_LOCATION" == *".apk" ]]; then
    PLATFORM=ANDROID
  else
    echo "No application provided. Exiting.."
    exit 1
  fi

  if [[ -n $BUILD_TO_TEST ]] && [[ -n ${BUILD_TO_TEST+x} ]]; then
    case $BUILD_TO_TEST in
      AUTOMATION_BITBAR|AUTOMATION_BROWSERSTACK|AUTOMATION_LAMBDATEST|AUTOMATION_SAUCELABS)
        ;;
      *)
        echo "Vendor name provided for Build To Test isn't one of the acceptable vendors: $BUILD_TO_TEST"
        exit 1  # Exit the script with a non-zero status code
        ;;
    esac
  fi

  if [[ $PLATFORM == UNKNOWN ]]; then
    if [[ -n "$PROVISIONING_PROFILES" && -z "$SIGNING_FINGERPRINT" && -z "$KEYSTORE_ALIAS" ]]; then
      PLATFORM=IOS
    elif [[ -z "$PROVISIONING_PROFILES" ]] && [[ -n "$SIGNING_FINGERPRINT" || -n "$KEYSTORE_ALIAS" ]]; then
      PLATFORM=ANDROID
    else
      echo "Missing signing inputs. Exiting.."
      exit 1
    fi
  fi

  # validate fusion set arguments
  validate_args "fusion-set-id" "$FUSION_SET_ID"

  # validate api key arguments
  validate_args "API key" "$API_KEY"

  # validate sign arguments
  validate_args "Sign method" "$SIGN_METHOD"
  case "$SIGN_METHOD" in
  "$PRIVATE_SIGN_ACTION")
    if [[ $PLATFORM == IOS ]]; then
      validate_files "Provisioning profile" ${PROVISIONING_PROFILES[@]}
    else
      validate_args "Signing Fingerprint" "$SIGNING_FINGERPRINT"
    fi
    ;;
  "$AUTO_DEV_SIGN_ACTION")
    if [[ $PLATFORM == IOS ]]; then
      validate_files "Signing" ${PROVISIONING_PROFILES[@]} ${ENTITLEMENTS[@]}
    else
      validate_args "Signing Fingerprint" "$SIGNING_FINGERPRINT"
    fi
    ;;
  "$SIGN_ACTION")
    if [[ $PLATFORM == IOS ]]; then
      validate_args "Signing parameters" "$KEYSTORE_PASS"
      validate_files "Signing" ${PROVISIONING_PROFILES[@]} "$SIGNING_KEYSTORE" ${ENTITLEMENTS[@]}
    else
      validate_args "Signing parameters" "$KEYSTORE_PASS" "$KEYSTORE_ALIAS" "$KEYS_PASS"
      validate_files "Signing" "$SIGNING_KEYSTORE"
    fi
    ;;
  esac

  # validate api key arguments
  validate_args "Final Output Location" "$FINAL_OUTPUT_LOCATION"
}

help() {
  # Display Help
  echo
  echo "-key  |  --api_key                          Appdome API key (required)"
  echo "-fs   |  --fusion_set_id                    Fusion-set-id to use (required)"
  echo "-t    |  --team_id                          Appdome team id (optional)"
  echo "-a    |  --app                              Application location (required)"
  echo "-o    |  --output                           Output file for fused and signed app after Appdome (required)"
  echo "-so   |  --second_output                     Second_output_app_file (optional)"
  echo "-co   |  --certificate_output               Output file for Certified Secure pdf (optional)"
  echo "-dso  |  --deobfuscation_script_output      Output file deobfuscation scripts when building with "Obfuscate App Logic" (optional)"
  echo "-aid  |  --app_id                           App ID in Firebase project (optional)"
  echo "-bv   |  --build_overrides                  Path to json file with build overrides (optional)"
  echo "-bl   |  --build_logs                       Build with diagnostic logs (optional)"
  echo "-cv   |  --context_overrides                Path to json file with context overrides (optional)"
  echo "-sv   |  --sign_overrides                   Path to json file with sign overrides (optional)"
  echo "-btv  |  --build_to_test_vendor             Enter vendor name on which Build to Test will happen (optional)"
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
  echo "-gp   |  --google_play_signing              This Android application will be distributed via the Google Play App Signing program"
  echo "-kp   |  --keystore_pass                    Password for keystore to use on Appdome iOS and Android signing"
  echo "-ka   |  --keystore_alias                   Key alias to use on Appdome Android signing"
  echo "-kyp  |  --key_pass                         Password for both Android and iOS key to use on Appdome Android signing"
  echo
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
      PROVISIONING_PROFILES=(${2//,/ })
      shift 2
      ;;
    -entt | --entitlements)
      ENTITLEMENTS=(${2//,/ })
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
    -dso | --deobfuscation_script_output)
      DEOBFUSCATION_SCRIPT_OUTPUT_LOCATION=$2
      shift 2
      ;;
    -aid | --app_id)
      APP_ID=$2
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
    -gp | --google_play_signing)
      GOOGLE_PLAY_SIGNING=true
      shift 1
      ;;
    -kp | --keystore_pass)
      KEYSTORE_PASS="$2"
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
