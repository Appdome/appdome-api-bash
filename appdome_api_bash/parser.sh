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
    exit 0
  fi

  if [[ $PLATFORM == UNKNOWN ]]; then
    if [[ -n "$PROVISIONING_PROFILES" && -z "$SIGNING_FINGERPRINT" && -z "$KEYSTORE_ALIAS" ]]; then
      PLATFORM=IOS
    elif [[ -z "$PROVISIONING_PROFILES" ]] && [[ -n "$SIGNING_FINGERPRINT" || -n "$KEYSTORE_ALIAS" ]]; then
      PLATFORM=ANDROID
    else
      echo "Missing signing inputs. Exiting.."
      exit 0
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
      validate_args "Provisioning profile" "$PROVISIONING_PROFILES"
    else
      validate_args "Signing Fingerprint" "$SIGNING_FINGERPRINT"
    fi
    ;;
  "$AUTO_DEV_SIGN_ACTION")
    if [[ $PLATFORM == IOS ]]; then
      validate_args "Signing parameters" "$PROVISIONING_PROFILES" "$ENTITLEMENTS"
    else
      validate_args "Signing Fingerprint" "$SIGNING_FINGERPRINT"
    fi
    ;;
  "$SIGN_ACTION")
    if [[ $PLATFORM == IOS ]]; then
      validate_args "Signing parameters" "$PROVISIONING_PROFILES" "$SIGNING_KEYSTORE" "$ENTITLEMENTS" "$KEYSTORE_PASS"
    else
      validate_args "Signing parameters" "$SIGNING_KEYSTORE" "$KEYSTORE_PASS" "$KEYSTORE_ALIAS" "$KEYS_PASS"
    fi
    ;;
  esac

  # validate api key arguments
  validate_args "Final Output Location" "$FINAL_OUTPUT_LOCATION"
}

help() {
  # Display Help
  echo
  echo "-key | --api_key                           Appdome API key"
  echo "-f | --fusion_set_id                       Fusion-set-id to use"
  echo "-t | --team_id                             Appdome team id"
  echo "-l | --app                                 Application location"
  echo "-o | --output                              Output file for fused and signed app after Appdome"
  echo "-co | --certificate_output                 Output file for Certified Secure pdf"
  echo "-bv | --build_overrides                    Path to json file with build overrides"
  echo "-cv | --context_overrides                  Path to json file with context overrides"
  echo "-sv | --sign_overrides                     Path to json file with sign overrides"
  echo "-bv | --build_overrides                    Path to json file with build overrides"
  echo
  echo "please use one of the following signing options"
  echo "-s | --sign_on_appdome                     Sign on Appdome"
  echo "-ps | --private_signing                    Sign application manually"
  echo "-adps | --auto_dev_private_signing         Use a pre-generated signing script for automated local signing"
  echo
  echo "Signing attribute:"
  echo "-k | --keystore                            Path to keystore file to use on Appdome iOS and Android signing"
  echo "-pr | --provisioning_profiles              Path to iOS provisioning profiles files to use. Can be multiple profiles"
  echo "-entt | --entitlements                     Path to iOS entitlements plist to use. Can be multiple entitlements files"
  echo "-cf | --signing_fingerprint                SHA-1 or SHA-256 final Android signing certificate fingerprint"
  echo "-gp | --google_play_signing                This Android application will be distributed via the Google Play App Signing program"
  echo "-kp | --keystore_pass                      Password for keystore to use on Appdome iOS and Android signing"
  echo "-ka | --keystore_alias                     Key alias to use on Appdome Android signing"
  echo "-kyp | --key_pass                          Password for the key to use on Appdome Android signing"
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
    -f | --fusion_set_id)
      FUSION_SET_ID="$2"
      shift 2
      ;;
    -l | --app)
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
    -bv | --build_overrides)
      BUILD_OVERRIDES=$(cat "$2")
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
