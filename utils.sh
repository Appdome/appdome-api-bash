VERBOSE="${VERBOSE:-false}"
_LOG_LEVEL_INFO=1
_LOG_LEVEL_DEBUG=2
_CURRENT_LOG_LEVEL=$_LOG_LEVEL_INFO
VALIDATION_ERRORS=()

init_logging() {
  if [[ "$VERBOSE" == "true" ]]; then
    _CURRENT_LOG_LEVEL=$_LOG_LEVEL_DEBUG
  else
    _CURRENT_LOG_LEVEL=$_LOG_LEVEL_INFO
  fi
}

_log() {
  local level="$1"
  local level_num="$2"
  shift 2
  if (( level_num > _CURRENT_LOG_LEVEL )); then
    return
  fi
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  local caller="${BASH_SOURCE[2]##*/}:${BASH_LINENO[1]}"
  echo "[$timestamp] [$level] [$caller] $*" >&2
}

log_info() { _log "INFO" $_LOG_LEVEL_INFO "$@"; }
log_debug() { _log "DEBUG" $_LOG_LEVEL_DEBUG "$@"; }
log_warn() { _log "WARNING" $_LOG_LEVEL_INFO "$@"; }
log_error() { _log "ERROR" $_LOG_LEVEL_INFO "$@"; }

log_and_exit() {
  log_error "$@"
  exit 1
}

debug_log_request() {
  local request_type="${1:-post}"
  shift
  local url="$1"
  shift
  local extra=""
  while [[ $# -gt 0 ]]; do
    extra+=" $1"
    shift
  done
  log_debug "About to ${request_type} ${url}${extra}"
}

_truncate_value() {
  local value="$1"
  local max_len="${2:-500}"
  if [[ ${#value} -gt $max_len ]]; then
    echo "${value:0:max_len} ...'"
  else
    echo "$value"
  fi
}

require_param() {
  local message="$1"
  local value="$2"
  if [[ -z "$value" ]]; then
    VALIDATION_ERRORS+=("$message")
  fi
}

flush_validation_errors() {
  if [[ ${#VALIDATION_ERRORS[@]} -eq 0 ]]; then
    return
  fi
  log_error "Validation failed:"
  for err in "${VALIDATION_ERRORS[@]}"; do
    log_error "  - $err"
  done
  log_error "Run with --help for usage information."
  exit 1
}

reset_validation_errors() {
  VALIDATION_ERRORS=()
}

# Long option names (without leading dashes) for typo suggestions
APPDOME_API_KNOWN_OPTIONS=(
  api_key team_id fusion_set_id direct_upload app
  sign_on_appdome private_signing auto_dev_private_signing
  keystore provisioning_profiles entitlements output
  certificate_output certificate_json workflow_output_logs
  deobfuscation_script_output app_id datadog_api_key
  build_overrides build_logs second_output build_to_test_vendor
  context_overrides sign_overrides signing_fingerprint
  signing_fingerprint_upgrade signing_fingerprint_list google_play_signing
  keystore_pass baseline_profile startup_profile input_mapping
  cert_pinning_zip keystore_alias key_pass verbose help
)

_normalize_option_name() {
  local name="$1"
  name="${name#-}"
  name="${name#-}"
  echo "$name"
}

suggest_similar_option() {
  local unknown="$1"
  local name
  name=$(_normalize_option_name "$unknown")

  for opt in "${APPDOME_API_KNOWN_OPTIONS[@]}"; do
    if [[ "$opt" == "$name" ]]; then
      return 0
    fi
    local diff=$(( ${#opt} - ${#name} ))
    if [[ $diff -ge 1 && $diff -le 3 && "${opt:0:${#name}}" == "$name" ]]; then
      echo "--$opt"
      return 0
    fi
    if [[ $diff -ge 1 && $diff -le 3 && "${name:0:${#opt}}" == "$opt" ]]; then
      echo "--$opt"
      return 0
    fi
  done
}

report_unknown_arguments() {
  local -a unknown=("$@")
  log_error "Unknown argument(s):"
  for arg in "${unknown[@]}"; do
    local suggestion
    suggestion=$(suggest_similar_option "$arg")
    if [[ -n "$suggestion" ]]; then
      log_error "  - $arg (did you mean $suggestion?)"
    else
      log_error "  - $arg"
    fi
  done
  log_error "Run with --help for the list of valid options."
  exit 1
}

add_google_play_signing_fingerprint() {
  add_sign_overrides "signing_keystore_use_google_signing" "true"
  add_sign_overrides "signing_keystore_google_signing_sha1_key" "$SIGNING_FINGERPRINT"
}

assign_client_header() {
  if [[ -z "$APPDOME_CLIENT_HEADER" ]]; then
    APPDOME_CLIENT_HEADER='Appdome-cli-bash/1.0'
  else
    APPDOME_CLIENT_HEADER=$(printenv APPDOME_CLIENT_HEADER)
  fi
}

validate_args() {
  local param_name="$1"
  shift
  local missing=()
  for value in "$@"; do
    if [[ -z "$value" ]]; then
      missing+=("$param_name")
    fi
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    if [[ ${#missing[@]} -eq 1 ]]; then
      log_and_exit "Missing required parameter: $param_name"
    else
      log_and_exit "Missing required parameters: $param_name (${#missing[@]} values required)"
    fi
  fi
}

validate_files() {
  local label="$1"
  shift
  for file_path in "$@"; do
    if [[ -z "$file_path" ]]; then
      continue
    fi
    if [[ ! -f "$file_path" ]]; then
      log_and_exit "$label file does not exist: $file_path"
    fi
    log_debug "$label file validated: $file_path"
  done
}

validate_response_for_errors() {
  if [[ "$1" == *"error"* ]]; then
    log_and_exit "$2 failed. Response: $(_truncate_value "$1")"
  fi
}

validate_response_code() {
  if [[ "$1" != "200" ]]; then
    local response_body
    response_body=$(cat "$3")
    log_and_exit "$2 failed. Status code: $1. Response: $(_truncate_value "$response_body")"
    rm -f "$3"
  fi
}

request_headers() {
  echo "--header 'Authorization: $API_KEY' \
        --header 'accept: application/json' \
        --header 'content-type: multipart/form-data' \
        --header 'X-Appdome-Client:$APPDOME_CLIENT_HEADER'"
}

request_api_key(){
  echo $API_KEY
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

extract_string_value_from_json() {
  local cmd="echo "\$1" | grep -o '\"$2\"\s*:\s*\"[^\"]*' | grep -o '[^\"]*$'"
  echo "$(eval $cmd)"
}

add_sign_overrides() {
  if [[ $SIGN_OVERRIDES == "{}" ]]; then
    SIGN_OVERRIDES="{\"$1\":\"$2\"}"
  else
    SIGN_OVERRIDES=${SIGN_OVERRIDES%?} # Remove last char '}'
    SIGN_OVERRIDES="$(echo "${SIGN_OVERRIDES%%[[:space:]]}")" # Remove white spacing
    SIGN_OVERRIDES="$SIGN_OVERRIDES, \"$1\":\"$2\"}" # Add new key value
  fi
}

add_build_overrides() {
  if [[ $BUILD_OVERRIDES == "{}" ]]; then
    BUILD_OVERRIDES="{\"$1\":\"$2\"}"
  else
    BUILD_OVERRIDES=${BUILD_OVERRIDES%?} # Remove last char '}'
    BUILD_OVERRIDES="$(echo "${BUILD_OVERRIDES%%[[:space:]]}")" # Remove white spacing
    BUILD_OVERRIDES="$BUILD_OVERRIDES, \"$1\":\"$2\"}" # Add new key value
  fi
}
init_certs_pinning() {
  local cert_pinning_zip="$1"
  local certs=()

  if [[ -z "$cert_pinning_zip" || ! -f "$cert_pinning_zip" ]]; then
    echo "No zip file provided or file does not exist."
    return 0
  fi

  local extract_path="${cert_pinning_zip%.*}"  # target directory

  # ── Step A: remove any existing directory first ─────────────────────────────
  if [[ -d "$extract_path" ]]; then
    rm -rf "$extract_path"
    if [[ $? -ne 0 ]]; then
      echo "Failed to remove existing directory: $extract_path" >&2
      return 1
    fi
  fi

  # ── Step B: unzip into a “clean slate” directory ──────────────────────────────
  unzip -q "$cert_pinning_zip" -d "$extract_path"
  if [[ $? -ne 0 ]]; then
    echo "Unzip failed." >&2
    return 1
  fi

  # Now $extract_path is freshly recreated. You can, if you wish, verify:
  if [[ ! -d "$extract_path" ]]; then
    echo "Extraction did not create $extract_path as expected." >&2
    return 1
  fi

  # ── Step C: locate the JSON, parse cert entries ─────────────────────────────
  local json_file
  json_file=$(find "$extract_path" -type f -name "*.json" | head -n 1)
  if [[ -z "$json_file" ]]; then
    echo "No JSON file found in the extracted zip contents."
    return 0
  fi

  while IFS= read -r line; do
    local index file_name
    index=$(echo "$line" | grep -Eo '"[^"]+"' | head -n1 | tr -d '"')
    file_name=$(extract_string_value_from_json "$line" "$index")
    local file_path="$extract_path/$file_name"
    if [[ -f "$file_path" ]]; then
      certs+=("--form 'mitm_host_server_pinned_certs_list['\\''${index}'\\''].value.mitm_host_server_pinned_certs_file_content=@\"${file_path}\"'")
    fi
  done < <(grep -Eo '"[^"]+"\s*:\s*"[^"]+"' "$json_file")

  echo "${certs[@]}"
}

add_trusted_signing_fingerprints_to_overrides() {
  local json_content="$1"
  if [[ -z "$json_content" ]]; then
    return
  fi

  # Escape the JSON for embedding in SIGN_OVERRIDES
  # Remove newlines and extra whitespace, keeping the JSON structure intact
  local escaped_json=$(echo "$json_content" | tr -d '\n' | tr -d '\t' | sed 's/  */ /g')

  if [[ $SIGN_OVERRIDES == "{}" ]]; then
    SIGN_OVERRIDES="{\"trusted_signing_fingerprint_list\":$escaped_json}"
  else
    SIGN_OVERRIDES=${SIGN_OVERRIDES%?} # Remove last char '}'
    SIGN_OVERRIDES="$(echo "${SIGN_OVERRIDES%%[[:space:]]}")" # Remove white spacing
    SIGN_OVERRIDES="$SIGN_OVERRIDES, \"trusted_signing_fingerprint_list\":$escaped_json}" # Add new key value
  fi
}