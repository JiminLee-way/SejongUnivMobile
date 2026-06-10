# SejongUnivMobile

Flutter Android/iOS app for Sejong University mobile workflows.

## Public Source Policy

This repository intentionally excludes:

- `wiki/`, private implementation notes, and raw API captures
- `.env`, `local.properties`, `key.properties`, keystores, provisioning profiles
- service base URLs, Supabase project URL/key values, and other deploy-time
  configuration
- build artifacts such as APK/AAB/IPA files

Runtime configuration is injected with Dart defines:

```bash
cd app
flutter pub get
flutter run --dart-define-from-file=config/dart_defines.local.json
```

Copy `app/config/dart_defines.example.json` to a local ignored file and fill it
with internal service URLs, Supabase URL/key, table names, Edge Function names,
and RPC names.
Builds work the same way:

```bash
flutter build apk --debug --dart-define-from-file=config/dart_defines.local.json
```

## Internal APKs

For day-to-day internal testing, use the GitHub Actions workflow
`Android internal APK`. It builds a debug-signed APK and uploads it as an
Actions artifact. No release signing key is committed or required.

Configure repository secrets for connected internal builds:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SEJONG_API_BASE_URL`, `SEJONG_WEB_BASE_URL`, `UCHECK_API_BASE_URL`
- `LIBSEAT_BASE_URL`, `SJPT_BASE_URL`, `HAPPYDORM_BASE_URL`
- `ANDROID_STORE_URL`
- `UCHECK_USER_AGENT`, `UCHECK_CLIENT_VERSION`, `UCHECK_DEVICE_MODEL`
- `UCHECK_AES_IV`, `UCHECK_DAILY_KEY_SALT`
- every `SUPABASE_TABLE_*`, `SUPABASE_FUNCTION_*`, and `SUPABASE_RPC_*` key
  shown in `app/config/dart_defines.example.json`
- `SENTRY_DSN` (optional)

Release signing stays outside the repository. Local release builds can copy
`app/android/key.properties.template` to `app/android/key.properties` and point
it at a private keystore. CI release signing should use a protected GitHub
Environment or the Play Console/Firebase distribution pipeline.

The public Android network security config does not pin the cleartext attendance
host because the host itself is injected outside this repository. A private
release channel can replace that config with a host-pinned variant.

## Local Checks

```bash
cd app
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
```
