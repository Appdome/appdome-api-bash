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
--build_overrides <json_file_path> \
--context_overrides <json_file_path> \
--sign_overrides <json_file_path>
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
```
