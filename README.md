# Appdome Bash Client Library
Bash client library for interacting with https://fusion.appdome.com/ tasks API.

`appdome_api.sh` contains the whole flow of a task from upload to download.

All APIs are documented in https://apis.appdome.com/docs.

## Requirements
- curl

**Note:** For Linux (Debian based) You can install the requirements with `apt-get install curl`.

**Note:** For MAC You can install the requirements with `brew install curl`.

## Basic Flow Usage
**Note:** Passing overrides for any action is by using json file for example build_overrides.json

**Note:** For multiple provisioning profiles or/and entitlements - please use ',' as a separator with no spaces. example: `--entitlements entt1.plist,entt2.plist`

## Examples
#### Android Example:

```bash
./appdome_api.sh \
--api_key <api key> \
--fusion_set_id <fusion-set-id> \
--team_id <team-id> \
--app <apk/aab file> \
--sign_on_appdome \
--keystore <keystore file> \
--keystore_pass <keystore password> \
--keystore_alias <key alias> \
--key_pass <key password> \
--output <output apk/aab> \
--certificate_output <output certificate pdf> \
--deobfuscation_script_output <output deobfuscation script zip>
--build_overrides <json_file_path> \
--context_overrides <json_file_path> \
--sign_overrides <json_file_path>
--baseline_profile <zip file for build with baseline profile>
--cert_pinning_zip <zip file containing dynamic certificates>
--google_play_signing <This Android application will be distributed via the Google Play App Signing program>
--signing_fingerprint <SHA-1 or SHA-256 final Android signing certificate fingerprint>
--signing_fingerprint_upgrade <SHA-1 or SHA-256 Upgraded signing certificate fingerprint for Google Play App Signing>
```

#### Android SDK Example:

```bash
./appdome_api_sdk.sh \
--api_key <api key> \
--fusion_set_id <fusion-set-id> \
--team_id <team-id> \
--app <aar> \
--output <output aar> \
--certificate_output <output certificate pdf> \
--build_overrides <json_file_path> 
```

#### iOS Example:

```bash
./appdome_api.sh \
--api_key <api key> \
--fusion_set_id <fusion-set-id> \
--team_id <team-id> \
--app <ipa file> \
--sign_on_appdome \
--keystore <p12 file> \
--keystore_pass <p12 password> \
--provisioning_profiles <provisioning profile file>,<another provisioning profile file if needed> \
--entitlements <entitlements file>,<another entitlements file if needed> \
--output <output ipa> \
--certificate_output <output certificate pdf> \
--build_overrides <json_file_path> \
--context_overrides <json_file_path> \
--sign_overrides <json_file_path>
--cert_pinning_zip <zip file containing dynamic certificates>
```

#### iOS SDK Example:

```bash
./appdome_api_sdk.sh \
--api_key <api key> \
--fusion_set_id <fusion-set-id> \
--team_id <team-id> \
--app <zip file> \
--keystore <keystore file> \ # only needed for sign on Appdome
--keystore_pass <keystore password> \ # only needed for sign on Appdome
--output <output zip> \
--certificate_output <output certificate pdf> \
--build_overrides <json_file_path> 
```

## Signing Fingerprint List (Android only)

The `--signing_fingerprint_list` (or `-sfp`) option allows you to specify a list of signing fingerprints for Android signing. This is useful when you need to support multiple signing certificates.

**Usage:**
```bash
--signing_fingerprint_list <path_to_json_file>
```

**JSON File Format:**
The JSON file should contain an array of fingerprint objects. Each object must include:
- `SHA`: The SHA-1 or SHA-256 certificate fingerprint (required)
- `TrustedStoreSigning`: true/false Indicates whether the certificate fingerprint is used for store submissions (e.g., Google Play). (Optional; defaults to false)

**Example JSON file (`fingerprints.json`):**
```json
[
  {
    "SHA": "E71186B4D94016F0A3F2A68DF5BC75D27CA307663C6DFDE5923084486D43150E",
    "TrustedStoreSigning": false
  },
  {
    "SHA": "857444B499AAABF7DF388DEA89CC2DA0258273B7C1B091866FA1267E8AA3495D",
    "TrustedStoreSigning": true
  },
  {
    "SHA": "C11E39F29C946A6408E5C5EA65D94FCB05C0DB302B43E6A8ABCB01256257442A",
    "TrustedStoreSigning": true
  }
]
```

**Important Notes:**
- The `--signing_fingerprint_list` option cannot be used together with:
  - `--signing_fingerprint` (`-cf`)
  - `--signing_fingerprint_upgrade` (`-cfu`)
  - `--google_play_signing` (`-gp`)
- This option is available for Android signing operations.


# Update Certificate Pinning

To update certificate pinning, you need to bundle your certificates and mapping file into a ZIP archive and pass it to your build command.

## What to include

- **Certificate files** (one per host), in any of these formats:  
  - `.cer`  
  - `.crt`  
  - `.pem`  
  - `.der`  
  - `.zip`  
- **JSON mapping file** (e.g. `pinning.json`), with entries like:
  ```json
  {
    "api.example.com": "api_cert.pem",
    "auth.example.com": "auth_cert.crt"
  }
## How to run
Gather all certificate files and pinning.json into a single certs_bundle.zip.
Invoke your build with:

your-build-command --cert_pinning_zip=/path/to/certs_bundle.zip
