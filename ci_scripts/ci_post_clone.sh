#!/bin/sh
set -eu

root=${CI_PRIMARY_REPOSITORY_PATH:-$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)}
flutter_root="$HOME/.along-flutter-3.44.6"
if [ ! -x "$flutter_root/bin/flutter" ]; then
  git clone --depth 1 --branch 3.44.6 \
    https://github.com/flutter/flutter.git "$flutter_root"
fi
export PATH="$flutter_root/bin:$PATH"
flutter config --no-analytics
flutter precache --ios

commit=$(git -C "$root" rev-parse --short=12 HEAD)
cat >"$root/mobile/lib/core/config/generated_commit.dart" <<EOF
const generatedGitCommit = '$commit';
EOF

cd "$root/mobile"
flutter pub get
dart run build_runner build
flutter build ios --simulator --no-codesign \
  --dart-define=ALONG_GIT_COMMIT="$commit" \
  --dart-define=ALONG_API_BASE_URL=https://along.spicer.dev

generated_package="$root/mobile/ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift"
if [ ! -f "$generated_package" ]; then
  printf 'Flutter did not generate the iOS plugin Swift package at %s\n' "$generated_package" >&2
  exit 1
fi
