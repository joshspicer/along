#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
suffix=$$
network="along-integration-${suffix}"
database="along-integration-db-${suffix}"

cleanup() {
  docker rm -f "$database" >/dev/null 2>&1 || true
  docker network rm "$network" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

docker network create "$network" >/dev/null
docker run --rm -d \
  --name "$database" \
  --network "$network" \
  -e POSTGRES_PASSWORD=along \
  -e POSTGRES_DB=along_test \
  postgres:18-alpine >/dev/null

attempt=0
until docker exec "$database" pg_isready -U postgres -d along_test >/dev/null 2>&1; do
  attempt=$((attempt + 1))
  if [ "$attempt" -ge 30 ]; then
    printf 'PostgreSQL did not become ready\n' >&2
    exit 1
  fi
  sleep 1
done

docker run --rm \
  --network "$network" \
  -e INTEGRATION_DATABASE_URL="postgres://postgres:along@${database}:5432/along_test?sslmode=disable" \
  -v "$root/server:/src" \
  -w /src \
  golang:1.26.5-alpine \
  go test -tags=integration -count=1 ./integration/...

