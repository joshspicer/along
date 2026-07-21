#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
if grep -R "REPLACE_WITH" \
  "$root/deploy/well-known/apple-app-site-association" \
  "$root/deploy/well-known/assetlinks.json" >/dev/null; then
  printf 'Associated-domain files still contain REPLACE_WITH placeholders.\n' >&2
  exit 1
fi
python3 -m json.tool \
  "$root/deploy/well-known/apple-app-site-association" >/dev/null
python3 -m json.tool "$root/deploy/well-known/assetlinks.json" >/dev/null

