#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
image=${GO_IMAGE:-golang:1.26.5-alpine}

docker run --rm -v "$root/server:/src" -w /src "$image" sh -eu -c '
  unformatted=$(gofmt -l .)
  if [ -n "$unformatted" ]; then
    printf "Files need gofmt:\n%s\n" "$unformatted" >&2
    exit 1
  fi
  go vet ./...
  go test -coverprofile=coverage.out ./...
'

