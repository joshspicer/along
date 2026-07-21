#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
directory="$root/secrets"
umask 077
mkdir -p "$directory"

if [ -e "$directory/postgres_password" ]; then
  printf 'Refusing to overwrite existing files in %s\n' "$directory" >&2
  exit 1
fi

password=$(openssl rand -hex 32)
printf '%s' "$password" >"$directory/postgres_password"
printf 'postgres://along:%s@postgres:5432/along?sslmode=disable' "$password" \
  >"$directory/database_url"
openssl rand -base64 48 | tr -d '\n' >"$directory/jwt_signing_key"
openssl rand -base64 32 | tr -d '\n' >"$directory/push_encryption_key"
printf 'Created local Docker secrets. Add AuthKey.p8 and rclone.conf separately.\n'

