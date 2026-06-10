# SejongUnivMobile App

Flutter application package for SejongUnivMobile.

## Development

```bash
flutter pub get
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
flutter run
```

Network-backed features require Dart defines:

```bash
flutter run --dart-define-from-file=config/dart_defines.local.json
```

Use `config/dart_defines.example.json` as the key list and keep the local copy
private. It should contain the internal service URLs, Supabase URL, anon key,
table names, and function names.

Do not commit `config/dart_defines.local.json`, `android/key.properties`, or any
keystore/provisioning files.
