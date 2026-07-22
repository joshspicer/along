#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$root/mobile"
git -C "$root" diff --quiet
git -C "$root" diff --cached --quiet
commit=$(git -C "$root" rev-parse --short=12 HEAD)

fvm dart format --output=none --set-exit-if-changed lib test
fvm flutter analyze --fatal-infos
fvm flutter test
fvm flutter build appbundle --release \
  --dart-define=ALONG_GIT_COMMIT="$commit" \
  --dart-define=ALONG_API_BASE_URL=https://along.spicer.dev
fvm flutter build ipa --release --no-codesign \
  --dart-define=ALONG_GIT_COMMIT="$commit" \
  --dart-define=ALONG_API_BASE_URL=https://along.spicer.dev

printf 'Unsigned release artifacts are ready for owner signing and upload.\n'
