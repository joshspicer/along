#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
tag=${1:-}
case "$tag" in
  v[0-9]*.[0-9]*.[0-9]*) ;;
  *)
    printf 'Usage: %s vMAJOR.MINOR.PATCH\n' "$0" >&2
    exit 2
    ;;
esac

git -C "$root" diff --quiet
git -C "$root" diff --cached --quiet
commit=$(git -C "$root" rev-parse HEAD)
image="ghcr.io/joshspicer/along-server"

docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg GIT_COMMIT="$commit" \
  --provenance=mode=max \
  --sbom=true \
  --tag "${image}:${tag#v}" \
  --tag "${image}:sha-${commit}" \
  --push "$root/server"

