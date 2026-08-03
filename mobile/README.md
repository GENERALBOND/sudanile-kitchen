# Sudanile Kitchen — Mobile

Flutter client for Sudanile Kitchen. Setup, architecture, and full documentation live in the repo root:

- [`../README.md`](../README.md) — project overview, setup instructions, API reference
- [`../documentation/`](../documentation/) — screen-by-screen guide and presentation notes

## Configuration

All secrets (Firebase keys, Google OAuth client ID, API base URL) are injected at
build/run time — nothing is hardcoded in source.

1. Copy `.env.example` to `.env` and fill in real values.
2. Build/run with:

   ```bash
   flutter pub get
   flutter run --dart-define-from-file=.env
   flutter build apk --dart-define-from-file=.env
   ```

For Android **release** builds, the signing keystore passwords must also be present
in the environment (see `android/app/build.gradle.kts`):

```bash
export STORE_PASSWORD=...      # keystore store password
export KEY_PASSWORD=...        # keystore key password
export KEY_STORE_FILE=release.keystore   # optional (defaults to key.properties)
export KEY_ALIAS=sudanile                 # optional (defaults to key.properties)
```

