#!/usr/bin/env bash
# Runs PWA test cases and prints a summary. Each case keeps its own folder under results/.
# Before running, checks that every selected case has its required parameters in env.sh (and stops if not).
#
# Usage: run_matrix.sh [--check] <case|group> ...
#   --check   only check the required parameters, no API calls
#
# Groups (the three stages, plus the "both" probe):
#   create   Stage 1, PWA app only: raw-aab raw-ipa raw-ipa-noprof raw-aab-team raw-ipa-team
#                                    upload-aab upload-ipa upload-aab-team upload-ipa-team
#   full     Stage 2, full build per platform: full-aab full-ipa full-aab-team full-ipa-team
#   both     Stage 3, both platforms in one run: both both-team
#   probe    pwa_platform "both" sent to the raw API: probe-both probe-both-team
#   all      offline + create + probe + full + both
#
# Cases:
#   offline          offline tests (no API calls, no env.sh needed)
#   raw-<p>[-team]   raw API call with curl (no wrapper code), p = aab | ipa
#   raw-ipa-noprof   raw API, iOS without profile (PASS = the API rejects it with HTTP 4xx)
#   upload-<p>[-team]  create the app through the wrapper's pwa_upload.sh (waits for a Short Flow build)
#   probe-both[-team]  raw API with pwa_platform "both" (ACCEPTED / REJECTED, informational)
#   full-<p>[-team]  appdome_api.sh --pwa: build, Sign on Appdome, download, Certified Secure checks
#   both[-team]      full-aab + full-ipa in one run (05_both_platforms.sh)
# "-team" cases use TEAM_ID_TEST (no Short Flow) and FS_ANDROID_TEAM / FS_IOS_TEAM.
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"

CREATE=(raw-aab raw-ipa raw-ipa-noprof raw-aab-team raw-ipa-team upload-aab upload-ipa upload-aab-team upload-ipa-team)
FULL=(full-aab full-ipa full-aab-team full-ipa-team)
BOTH=(both both-team)
PROBE=(probe-both probe-both-team)

CHECK_ONLY=false
CASES=()
for arg in "$@"; do
  case "$arg" in
    --check) CHECK_ONLY=true ;;
    create) CASES+=("${CREATE[@]}") ;;
    full)   CASES+=("${FULL[@]}") ;;
    both)   CASES+=("${BOTH[@]}") ;;
    probe)  CASES+=("${PROBE[@]}") ;;
    all)    CASES+=(offline "${CREATE[@]}" "${PROBE[@]}" "${FULL[@]}" "${BOTH[@]}") ;;
    *)      CASES+=("$arg") ;;
  esac
done
if [[ ${#CASES[@]} -eq 0 ]]; then
  sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
fi

# case_cmd <case>  → script and arguments
case_cmd() {
  case "$1" in
    offline)          echo "00_offline_tests.sh" ;;
    raw-aab)          echo "01_raw_pwappload.sh aab personal" ;;
    raw-ipa)          echo "01_raw_pwappload.sh ipa personal" ;;
    raw-ipa-noprof)   echo "01_raw_pwappload.sh ipa personal --no-profile" ;;
    raw-aab-team)     echo "01_raw_pwappload.sh aab team" ;;
    raw-ipa-team)     echo "01_raw_pwappload.sh ipa team" ;;
    probe-both)       echo "01_raw_pwappload.sh both personal" ;;
    probe-both-team)  echo "01_raw_pwappload.sh both team" ;;
    upload-aab)       echo "02_pwa_upload.sh aab personal" ;;
    upload-ipa)       echo "02_pwa_upload.sh ipa personal" ;;
    upload-aab-team)  echo "02_pwa_upload.sh aab team" ;;
    upload-ipa-team)  echo "02_pwa_upload.sh ipa team" ;;
    full-aab)         echo "03_full_flow.sh aab personal" ;;
    full-ipa)         echo "03_full_flow.sh ipa personal" ;;
    full-aab-team)    echo "03_full_flow.sh aab team" ;;
    full-ipa-team)    echo "03_full_flow.sh ipa team" ;;
    both)             echo "05_both_platforms.sh personal" ;;
    both-team)        echo "05_both_platforms.sh team" ;;
    *) return 1 ;;
  esac
}

# case_req <case>  → required_vars arguments (stage platform team), empty for offline
case_req() {
  set -- $(case_cmd "$1")
  case "$1" in
    00_*) echo "" ;;
    01_*) if [[ "${4:-}" == "--no-profile" ]]; then echo "create aab $3"; else echo "create $2 $3"; fi ;;
    02_*) echo "create $2 $3" ;;
    03_*) echo "full $2 $3" ;;
    05_*) echo "full both $2" ;;
  esac
}

NEED_ENV=false
for c in "${CASES[@]}"; do
  if ! case_cmd "$c" > /dev/null; then echo "Unknown case: $c (run without arguments for the list)"; exit 2; fi
  [[ "$c" != "offline" ]] && NEED_ENV=true
done

# ---- Preflight: required parameters per case --------------------------------------------------------------------
if [[ "$NEED_ENV" == "true" ]]; then
  # shellcheck disable=SC1091
  source "$DIR/common.sh"
  set +e
  MISSING=0
  echo "Required parameters ($ENV_FILE):"
  for c in "${CASES[@]}"; do
    req="$(case_req "$c")"
    [[ -z "$req" ]] && continue
    missing="$(missing_vars $req)"
    if [[ -n "$missing" ]]; then
      printf '  %-16s MISSING: %s\n' "$c" "$missing"
      MISSING=1
    else
      printf '  %-16s ok (%s)\n' "$c" "$(required_vars $req)"
    fi
  done
  if [[ $MISSING -ne 0 ]]; then echo "Fill in the missing parameters, or leave those cases out."; exit 2; fi
fi
[[ "$CHECK_ONLY" == "true" ]] && exit 0

# ---- Run ------------------------------------------------------------------------------------------------------------
LAST_RUN="$(mktemp "${TMPDIR:-/tmp}/pwa_test_run.XXXXXX")"
export PWA_TEST_LAST_RUN_FILE="$LAST_RUN"
SUMMARY=()
for c in "${CASES[@]}"; do
  echo; echo "################ $c ################"
  : > "$LAST_RUN"
  start=$(date +%s)
  "$DIR"/$(case_cmd "$c"); rc=$?
  case "$c" in
    raw-ipa-noprof) if [[ $rc -eq 4 ]]; then r="PASS (rejected)"; else r="FAIL"; fi ;;
    probe-*)        if [[ $rc -eq 0 ]]; then r="ACCEPTED"; elif [[ $rc -eq 4 ]]; then r="REJECTED (4xx)"; else r="FAIL"; fi ;;
    *)              if [[ $rc -eq 0 ]]; then r="PASS"; else r="FAIL"; fi ;;
  esac
  details=""
  run_dir="$(cat "$LAST_RUN" 2>/dev/null || true)"
  if [[ -n "$run_dir" && -f "$run_dir/result.txt" ]]; then details="$(tr '\n' ' ' < "$run_dir/result.txt")"; fi
  SUMMARY+=("$(printf '%-16s %-15s (%ss)  %s' "$c" "$r" "$(( $(date +%s) - start ))" "$details")")
done
rm -f "$LAST_RUN"

echo; echo "================ Summary ================"
RESULTS="${PWA_TEST_RESULTS:-$DIR/results}"; mkdir -p "$RESULTS"
printf '%s\n' "${SUMMARY[@]}" | tee "$RESULTS/summary_$(date +%Y%m%d_%H%M%S).txt"
