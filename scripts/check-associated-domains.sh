#!/bin/sh
set -eu

domain=${ALONG_DOMAIN:-along.spicer.dev}
apple_team_id=${APPLE_TEAM_ID:-N7C8DEK852}
base_url="https://$domain/.well-known"
directory=$(mktemp -d)
trap 'rm -rf "$directory"' EXIT

curl --fail --silent --show-error --location \
  "$base_url/apple-app-site-association" >"$directory/aasa.json"
curl --fail --silent --show-error --location \
  "$base_url/assetlinks.json" >"$directory/assetlinks.json"

python3 - "$directory/aasa.json" "$directory/assetlinks.json" \
  "$apple_team_id.com.joshspicer.along" "${ANDROID_SIGNING_SHA256:-}" <<'PY'
import json
import sys

aasa_path, assetlinks_path, app_id, android_fingerprints = sys.argv[1:]
with open(aasa_path, encoding="utf-8") as source:
    aasa = json.load(source)
with open(assetlinks_path, encoding="utf-8") as source:
    assetlinks = json.load(source)

apps = aasa.get("webcredentials", {}).get("apps", [])
if app_id not in apps:
    raise SystemExit(f"AASA webcredentials missing {app_id}")
if android_fingerprints and not assetlinks:
    raise SystemExit("assetlinks.json has no Android association statement")
PY

