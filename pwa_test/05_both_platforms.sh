#!/usr/bin/env bash
# Stage 3 — full builds for both platforms from the same PWA in one run: 03_full_flow.sh aab, then ipa.
# The wrapper builds one platform per run (pwa_platform "both" is rejected), so "both" is two runs.
# Each platform keeps its own folder inside this run's folder; a combined summary is printed at the end.
#
# Usage: 05_both_platforms.sh [personal|team|<team_uuid>] [--parallel]
#   --parallel  run both platforms at the same time (each platform's output goes only to its own run.log)
# Required: the full-build parameters for both aab and ipa.
source "$(dirname "$0")/common.sh"

TEAM_ARG="${1:-personal}"
MODE="${2:-}"
require_vars "full build (both platforms, $TEAM_ARG)" full both "$TEAM_ARG"
start_run "both_${TEAM_ARG}"
export PWA_TEST_PARENT_DIR="$RUN_DIR"
unset PWA_TEST_LAST_RUN_FILE

start=$(date +%s)
if [[ "$MODE" == "--parallel" ]]; then
  echo "Running aab and ipa in parallel. Follow: tail -f $RUN_DIR/*/run.log"
  "$PWA_TEST_DIR/03_full_flow.sh" aab "$TEAM_ARG" > /dev/null 2>&1 & P_AAB=$!
  sleep 1   # separate timestamps for the run folders
  "$PWA_TEST_DIR/03_full_flow.sh" ipa "$TEAM_ARG" > /dev/null 2>&1 & P_IPA=$!
  wait "$P_AAB" && R_AAB=0 || R_AAB=$?
  wait "$P_IPA" && R_IPA=0 || R_IPA=$?
else
  echo "################ aab ################"
  "$PWA_TEST_DIR/03_full_flow.sh" aab "$TEAM_ARG" && R_AAB=0 || R_AAB=$?
  echo "################ ipa ################"
  "$PWA_TEST_DIR/03_full_flow.sh" ipa "$TEAM_ARG" && R_IPA=0 || R_IPA=$?
fi

echo
echo "================ Both platforms ($TEAM_ARG, $(( $(date +%s) - start ))s) ================"
summary() {
  local platform="$1" rc="$2" dir result
  dir="$(ls -d "$RUN_DIR"/*_full_"${platform}"_* 2>/dev/null | tail -n1 || true)"
  result="FAIL"; [[ "$rc" -eq 0 ]] && result="PASS"
  printf '%-4s %s  ' "$platform" "$result"
  if [[ -n "$dir" && -f "$dir/result.txt" ]]; then
    tr '\n' ' ' < "$dir/result.txt"
  fi
  echo
  if [[ "$rc" -ne 0 && -n "$dir" ]]; then grep -E '\[FAIL\]|\[ERROR\]' "$dir/run.log" | sed 's/^/       /' | head -n5 || true; fi
}
summary aab "$R_AAB"
summary ipa "$R_IPA"
record AAB "$([[ $R_AAB -eq 0 ]] && echo PASS || echo FAIL)"
record IPA "$([[ $R_IPA -eq 0 ]] && echo PASS || echo FAIL)"
[[ $R_AAB -eq 0 && $R_IPA -eq 0 ]]
