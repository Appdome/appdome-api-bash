#!/bin/bash

source ./utils.sh
source ./appdome_api_bash/appdome_test.sh

help() {
  echo "Run Appdome Test (Standard Launch Tests) on a previously built and signed app, or download results for an existing Appdome Test task."
  echo "Apps built via the Build-to-Test flow are not eligible — only regular fuse/build (then sign) apps can run Appdome Test."
  echo
  echo "-key | --api_key                 Appdome API key (required, or APPDOME_API_KEY)"
  echo "-t   | --team_id                 Appdome team id (optional, or APPDOME_TEAM_ID)"
  echo "-tid | --task_id                 Signed build ID to start a test, or an Appdome Test task ID if that test is already running"
  echo "     | --wait                    Poll until the Appdome Test completes. Applies when starting a new test or when --task_id is already running."
  echo "     | --no-wait                 Do not poll for completion (default). When starting a new test, print the Appdome Test task ID and exit."
  echo "-atr | --appdome_test_results    Download Appdome Test Results JSON. Running test: wait then download. "
  echo "                                 Completed test: download immediately. Signed build: start a new test, wait, then download."
  echo "     | --timeout                 Timeout in seconds when waiting for the test to complete. Default is ${WAIT_TIMEOUT_SEC}."
  echo "-v   | --verbose                 Show debug logs"
  echo
}

validate_inputs() {
  reset_validation_errors
  init_api_key_from_env
  init_team_id_from_env
  require_param "--api_key (-key) is required (or set APPDOME_API_KEY environment variable)" "$API_KEY"
  require_param "--task_id (-tid) is required — Appdome Build ID of a built and signed app" "$PARENT_TASK_ID"
  flush_validation_errors
}

parse_args() {
  local UNKNOWN_ARGS=()
  WAIT=false
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
    -tid | --task_id)
      PARENT_TASK_ID="$2"
      shift 2
      ;;
    --wait)
      WAIT=true
      shift 1
      ;;
    --no-wait)
      WAIT=false
      shift 1
      ;;
    -atr | --appdome_test_results)
      APPDOME_TEST_RESULTS="$2"
      shift 2
      ;;
    --timeout)
      WAIT_TIMEOUT_SEC="$2"
      shift 2
      ;;
    -v | --verbose)
      VERBOSE=true
      shift 1
      ;;
    -h | --help)
      help
      exit 0
      ;;
    *)
      UNKNOWN_ARGS+=("$1")
      shift 1
      ;;
    esac
  done
  if [[ ${#UNKNOWN_ARGS[@]} -gt 0 ]]; then
    report_unknown_arguments "${UNKNOWN_ARGS[@]}"
  fi
  init_logging
  validate_inputs
}

init_server_url
API_KEY="${APPDOME_API_KEY:-${API_KEY_ENV:-}}"
TEAM_ID=''
PARENT_TASK_ID=''
TASK_ID=''
APPDOME_TEST_RESULTS=''
WAIT=false

assign_client_header

main() {
  parse_args "$@"
  run_appdome_test
}

main "$@"
