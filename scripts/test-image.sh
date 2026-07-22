#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
suffix=$$
network="along-image-${suffix}"
database="along-image-db-${suffix}"
api="along-image-api-${suffix}"
image=${ALONG_TEST_IMAGE:-along-server:test-${suffix}}
owns_image=true
if [ -n "${ALONG_TEST_IMAGE:-}" ]; then
  owns_image=false
fi

cleanup() {
  docker rm -f "$api" "$database" >/dev/null 2>&1 || true
  docker network rm "$network" >/dev/null 2>&1 || true
  if [ "$owns_image" = true ]; then
    docker image rm "$image" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT INT TERM

if [ "$owns_image" = true ]; then
  docker build \
    --build-arg GIT_COMMIT="$(git -C "$root" rev-parse HEAD)" \
    -t "$image" "$root/server"
fi
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
  [ "$attempt" -lt 30 ] || exit 1
  sleep 1
done

common_env="
  -e ALONG_ENV=development
  -e ALONG_ALLOW_INSECURE_DEV_KEYS=true
  -e DATABASE_URL=postgres://postgres:along@${database}:5432/along_test?sslmode=disable
  -e WEBAUTHN_RP_ID=localhost
  -e WEBAUTHN_RP_ORIGINS=https://localhost
"

# shellcheck disable=SC2086
docker run --rm --network "$network" --read-only \
  $common_env --entrypoint /app/migrate "$image"

# shellcheck disable=SC2086
docker run --rm -d --name "$api" --network "$network" \
  --read-only $common_env "$image" >/dev/null

attempt=0
until docker exec "$api" wget -q -O - http://127.0.0.1:8080/health/ready >/dev/null 2>&1; do
  attempt=$((attempt + 1))
  if [ "$attempt" -ge 30 ]; then
    docker logs "$api"
    exit 1
  fi
  sleep 1
done

docker exec "$api" wget -q -O - http://127.0.0.1:8080/v1/meta
