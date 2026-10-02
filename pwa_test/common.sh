# Shared helpers for the PWA test scripts. Sourced, not run. bash 3.2 (macOS) compatible.
set -euo pipefail

PWA_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WRAPPER_DIR="$(dirname "$PWA_TEST_DIR")"

# PWA_TEST_ENV / PWA_TEST_RESULTS override the env file and results folder (e.g. a second account).
ENV_FILE="${PWA_TEST_ENV:-$PWA_TEST_DIR/env.sh}"
RESULTS_DIR="${PWA_TEST_RESULTS:-$PWA_TEST_DIR/results}"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE — copy env.example.sh to env.sh and fill it in (or set PWA_TEST_ENV)." >&2
  exit 2
fi
# shellcheck disable=SC1090
source "$ENV_FILE"
unset APPDOME_TEAM_ID
APPDOME_BASE_URL="${APPDOME_SERVER_BASE_URL:-https://fusion.appdome.com/}"

# resolve_team <personal|team|uuid>  → prints the team_id value to pass
resolve_team() {
  case "${1:-personal}" in
    personal) echo "personal" ;;
    team)     echo "${TEAM_ID_TEST:?TEAM_ID_TEST is not set in env.sh}" ;;
    *)        echo "$1" ;;
  esac
}

# check_platform <platform> [allow_both]
check_platform() {
  if [[ "$1" == "aab" || "$1" == "ipa" ]]; then return 0; fi
  if [[ "$1" == "both" && "${2:-}" == "allow_both" ]]; then return 0; fi
  echo "Platform must be aab or ipa${2:+ or both} (got '$1')" >&2
  exit 2
}

# ---- Required parameters per stage -----------------------------------------------------------------------------
# required_vars <create|full> <aab|ipa|both> <personal|team|uuid> [fusion_set_id]
#   create : the PWA app only (upload)           → API key, PWA address (+ profile for iOS, + team ID for team)
#   full   : upload, build, sign, download       → create + platform signing (+ team Fusion Set when not given)
required_vars() {
  local stage="$1" platform="$2" team="$3" fs="${4:-}"
  local vars="APPDOME_API_KEY PWA_ADDRESS"
  if [[ "$team" == "team" ]]; then vars="$vars TEAM_ID_TEST"; fi
  if [[ "$platform" != "aab" ]]; then vars="$vars IOS_MOBILEPROVISION"; fi
  if [[ "$stage" == "full" ]]; then
    if [[ "$platform" != "ipa" ]]; then
      vars="$vars ANDROID_KEYSTORE ANDROID_KEYSTORE_PASS ANDROID_KEYSTORE_ALIAS ANDROID_KEY_PASS"
      if [[ "$team" == "team" && -z "$fs" ]]; then vars="$vars FS_ANDROID_TEAM"; fi
    fi
    if [[ "$platform" != "aab" ]]; then
      vars="$vars IOS_P12 IOS_P12_PASSWORD"
      if [[ "$team" == "team" && -z "$fs" ]]; then vars="$vars FS_IOS_TEAM"; fi
    fi
  fi
  echo "$vars"
}

FILE_VARS=" ANDROID_KEYSTORE IOS_P12 IOS_MOBILEPROVISION "

# missing_vars <same args as required_vars>  → prints the missing ones (empty when all are set)
missing_vars() {
  local v value out=""
  for v in $(required_vars "$@"); do
    value="${!v:-}"
    if [[ -z "$value" ]]; then
      out="$out $v"
    elif [[ "$FILE_VARS" == *" $v "* && ! -f "$value" ]]; then
      out="$out $v(file not found: $value)"
    fi
  done
  echo "${out# }"
}

# require_vars <label> <same args as required_vars>  → exits 2 listing every missing parameter
require_vars() {
  local label="$1" missing
  shift
  missing="$(missing_vars "$@")"
  if [[ -n "$missing" ]]; then
    echo "Missing parameters for $label: $missing" >&2
    echo "Set them in $ENV_FILE" >&2
    exit 2
  fi
}

# ---- Runs and results -------------------------------------------------------------------------------------------
# start_run <name>  → creates <results>/<timestamp>_<name>, sets RUN_DIR, tees all output to RUN_DIR/run.log
# PWA_TEST_PARENT_DIR puts the run inside another run's folder (05_both_platforms.sh).
# PWA_TEST_LAST_RUN_FILE receives the run folder path (run_matrix.sh reads result.txt from it).
start_run() {
  RUN_DIR="${PWA_TEST_PARENT_DIR:-$RESULTS_DIR}/$(date +%Y%m%d_%H%M%S)_$1"
  mkdir -p "$RUN_DIR"
  RUN_DIR="$(cd "$RUN_DIR" && pwd)"
  if [[ -n "${PWA_TEST_LAST_RUN_FILE:-}" ]]; then echo "$RUN_DIR" > "$PWA_TEST_LAST_RUN_FILE"; fi
  exec > >(tee -a "$RUN_DIR/run.log") 2>&1
  echo "=== $1 — $(date) ==="
  echo "Results: $RUN_DIR"
}

# record <KEY> <value>  → appends KEY=value to RUN_DIR/result.txt
record() {
  echo "$1=$2" >> "$RUN_DIR/result.txt"
}

json_str() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

# write_pwa_json <aab|ipa> <out_file>
write_pwa_json() {
  {
    printf '{\n  "pwa_address": "%s",\n  "pwa_platform": "%s"' "$(json_str "$PWA_ADDRESS")" "$1"
    if [[ -n "${PWA_APP_NAME:-}" ]]; then printf ',\n  "pwa_app_name": "%s"' "$(json_str "$PWA_APP_NAME")"; fi
    printf '\n}\n'
  } > "$2"
  sed 's/^/  /' "$2"
}

# cert_value <certified_secure.json> <key>  → first value of that key (quotes removed)
cert_value() {
  grep -Eo "\"$2\"[[:space:]]*:[[:space:]]*(\"[^\"]*\"|[^,}[:space:]]+)" "$1" 2>/dev/null | head -n1 \
    | sed -E 's/^"[^"]*"[[:space:]]*:[[:space:]]*//; s/^"//; s/"$//' || true
}

CHECK_FAILS=0
# expect <description> <test command...>
expect() {
  local desc="$1"
  shift
  if "$@"; then
    echo "  [ok]   $desc"
  else
    echo "  [FAIL] $desc"
    CHECK_FAILS=$((CHECK_FAILS + 1))
  fi
}

# note <text>  → informational line in the checks
note() {
  echo "  [info] $1"
}
