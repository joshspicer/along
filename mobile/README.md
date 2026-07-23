# Along mobile

Flutter client for iOS and Android. Flutter 3.44.6 and Dart 3.12.2 are pinned
in `.fvmrc` and `pubspec.yaml`.

```sh
fvm install
fvm flutter pub get
fvm dart run build_runner build
fvm flutter analyze --fatal-infos
fvm flutter test
```

Run against a local API:

```sh
fvm flutter run \
  --dart-define=ALONG_API_BASE_URL=http://localhost:6009 \
  --dart-define=ALONG_DEV_PASSKEY_BASE_URL=https://along-dev.spicer.dev \
  --dart-define=ALONG_APNS_ENVIRONMENT=sandbox \
  --dart-define=ALONG_GIT_COMMIT="$(git rev-parse --short HEAD)"
```

When the API endpoint is not `https://along.spicer.dev`, Along sends only
passkey ceremonies to `https://along-dev.spicer.dev`. Point that associated
HTTPS domain at the same local server and run the server with
`ALONG_DOMAIN=along-dev.spicer.dev`. Ordinary API, sync, and WebSocket traffic
continues to use the local endpoint. The Advanced screen shows both active
endpoints and the passkey relying-party ID.

The app keeps read models, sync cursor, and mutation outbox in Drift. Only the
opaque refresh token and stable installation ID use Keychain/Android encrypted
storage. Native `AuthenticationServices` and Android Credential Manager
bridges perform passkey ceremonies; private key material never enters Dart.

Generated `*.g.dart` and `*.freezed.dart` files are committed so release builds
do not depend on code generation.
