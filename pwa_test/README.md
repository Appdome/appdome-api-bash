# PWA test scripts (Bash wrapper)

Scripts for testing `appdome_api.sh --pwa` against the live Appdome API. Same cases as
`appdome-api-python/pwa_test`, plus a "both platforms" stage and a probe for `pwa_platform: "both"`.

Behavior being tested (Engineering, 2026-09-30):
1. iOS (`ipa`) works when the request `overrides` include the provisioning profile, base64 encoded.
2. The upload is done when the response's `app` object is returned (`status: active`); `app.id` is the App ID.
3. Short Flow accounts build automatically with the default Playground Fusion Set. Without Short Flow the upload only
   creates the app, and it's built with the regular build API and a chosen Fusion Set.

## Setup

```bash
cd appdome-api-bash/pwa_test
cp env.example.sh env.sh      # or reuse the Python one: export PWA_TEST_ENV=/path/to/python/pwa_test/env.sh
./00_offline_tests.sh         # no API calls, no env.sh needed
./run_matrix.sh --check all   # shows which cases have their required parameters
```

`env.sh` and `results/` are git-ignored. Every run writes its own folder under `results/` (log, request, response,
signed app, Certified Secure). Scripts always pass `--team_id` explicitly and ignore `APPDOME_TEAM_ID`.
`team` means `TEAM_ID_TEST` from `env.sh`; you can also pass a team UUID. `PWA_TEST_VERBOSE=true` adds `--verbose`.

## Stages and required parameters

Every script checks its parameters before calling the API and lists everything missing. `run_matrix.sh` checks
all selected cases first and stops before any API call if one is missing something.

| Stage | Android (`aab`) | iOS (`ipa`) |
|---|---|---|
| 1. Create the PWA app only (`raw-*`, `upload-*`) | `APPDOME_API_KEY`, `PWA_ADDRESS` (`PWA_APP_NAME` optional) | + `IOS_MOBILEPROVISION` |
| 2. Full build, one platform (`full-*`) | stage 1 + `ANDROID_KEYSTORE`, `ANDROID_KEYSTORE_PASS`, `ANDROID_KEYSTORE_ALIAS`, `ANDROID_KEY_PASS` | stage 1 + `IOS_P12`, `IOS_P12_PASSWORD` |
| 3. Both platforms in one run (`both*`) | everything in stage 2 for both platforms | |
| Team cases (`*-team`) | + `TEAM_ID_TEST`; full builds also `FS_ANDROID_TEAM` | + `TEAM_ID_TEST`; full builds also `FS_IOS_TEAM` |

The Fusion Set is only needed when the account has no Short Flow (the team). On a Short Flow account (personal),
stage 1 also starts an automatic build: `upload-*` waits for it, `raw-*` reports its Build ID without waiting.

## Scripts

| Script | What it does |
|---|---|
| `00_offline_tests.sh` | Offline tests with the API stubbed: config validation, request body, overrides merge, iOS profiles, response parsing, Short Flow vs Fusion Set flow, `appdome_api.sh` argument checks |
| `01_raw_pwappload.sh <aab\|ipa\|both> [personal\|team] [--no-profile]` | Calls `/pwappload` with curl, no wrapper code. Reports App ID(s), status and Build ID(s) |
| `02_pwa_upload.sh <aab\|ipa> [personal\|team]` | Stage 1 through the wrapper's `pwa_upload.sh` functions; waits for the Short Flow build if any; checks App ID, `pack_type`, `status` |
| `03_full_flow.sh <aab\|ipa> [personal\|team] [fusion_set_id]` | Stage 2: `appdome_api.sh --pwa` with Diagnostic Logs, Sign on Appdome, download, Certified Secure; checks the outputs and the Certified Secure JSON |
| `04_task_status.sh <build_id> [personal\|team]` | Raw task status |
| `05_both_platforms.sh [personal\|team] [--parallel]` | Stage 3: `03_full_flow.sh` for `aab` and `ipa` in one run, combined summary |
| `run_matrix.sh [--check] <case\|group> ...` | Runs cases or groups and prints a summary with the App and Build IDs |

## Test matrix

| Group | Case | Expected |
|---|---|---|
| | `offline` | All offline tests pass |
| `create` | `raw-aab` / `raw-ipa` | 200, App ID, Build ID if the personal account has Short Flow |
| | `raw-ipa-noprof` | Rejected (4xx). PASS means it was rejected |
| | `raw-aab-team` / `raw-ipa-team` | 200, App ID, **no** Build ID (team has no Short Flow) |
| | `upload-aab` / `upload-ipa` (`-team`) | Wrapper upload: App ID, `pack_type` matches, `status: active`; personal waits for the Short Flow build |
| `probe` | `probe-both` / `probe-both-team` | Informational: ACCEPTED or REJECTED. Answers whether the API takes `pwa_platform: "both"` (with the profile) |
| `full` | `full-aab` / `full-ipa` | Signed app (+ universal .apk for aab) and Certified Secure; Short Flow build |
| | `full-aab-team` / `full-ipa-team` | Built with `FS_ANDROID_TEAM` / `FS_IOS_TEAM` in the team |
| `both` | `both` / `both-team` | `full-aab` and `full-ipa` both pass in one run |

Checks on every full build (from `certified_secure.json`): `app_type` is the platform, `app_id` matches the upload,
`extended_logs` is true, `sign_type` is `OnAppdome`, the team, and the Fusion Set (the Short Flow one, or the one
passed). Info lines show the bundle ID, minimum OS and whether a context step ran (the Bash wrapper has none).

Suggested order:

```bash
./run_matrix.sh offline create          # stage 1, both platforms, personal and team
./run_matrix.sh probe                   # does "both" work in the API?
./run_matrix.sh full                    # stage 2
./run_matrix.sh both                    # stage 3
```

Record the App and Build IDs from the summary in the ticket.

## Notes

- The wrapper builds one platform per run and rejects `pwa_platform: "both"` (the Python wrapper does the same).
  Stage 3 is two runs, one per platform. If `probe-both` is ACCEPTED, the response has one app per platform.
- `full-*-team` checks `extended_logs` on a non-Short-Flow build. The Bash wrapper sends it to the build API as the
  string `"true"` (existing `-bl` behavior), while the Python wrapper sends `true`. This check shows whether the
  server accepts the string.
