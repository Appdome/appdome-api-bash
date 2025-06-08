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

**Note:**
To update certificate pinning, you need to provide a ZIP file containing the SSL certificates and a JSON mapping file.
This ZIP file should be specified using the `--cert_pinning_zip` option in your command.

Gather all of your SSL certificates and the mapping JSON file into a single ZIP archive.
Inside the ZIP, include:
One certificate file per host (e.g. api_cert.pem, auth_cert.pem, etc.)
A JSON file (e.g. pinning.json) that maps each hostname to its certificate filename, for example:
```json
{
  "api.example.com": "api_cert.pem",
  "auth.example.com": "auth_cert.pem"
}
```
Send us the ZIP archive. We’ll extract it and apply the certificate pinning for each host.
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