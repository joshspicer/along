#!/bin/sh
set -eu

: "${DATABASE_URL_FILE:?DATABASE_URL_FILE is required}"
: "${BACKUP_AGE_RECIPIENT:?BACKUP_AGE_RECIPIENT is required}"
: "${BACKUP_UPLOAD_URL:?BACKUP_UPLOAD_URL is required}"

database_url=$(cat "$DATABASE_URL_FILE")
stamp=$(date -u +%Y%m%dT%H%M%SZ)
output="/backups/along-${stamp}.dump.age"

pg_dump --format=custom --no-owner --no-privileges "$database_url" |
  age --recipient "$BACKUP_AGE_RECIPIENT" --output "$output"

case "$BACKUP_UPLOAD_URL" in
  https://*) ;;
  *)
    printf 'BACKUP_UPLOAD_URL must use HTTPS\n' >&2
    exit 1
    ;;
esac

upload_url="${BACKUP_UPLOAD_URL%/}/$(basename "$output")"
if [ -n "${BACKUP_UPLOAD_TOKEN_FILE:-}" ]; then
  curl --fail --silent --show-error --retry 5 \
    -H "Authorization: Bearer $(cat "$BACKUP_UPLOAD_TOKEN_FILE")" \
    --upload-file "$output" "$upload_url"
else
  curl --fail --silent --show-error --retry 5 \
    --upload-file "$output" "$upload_url"
fi

find /backups -type f -name 'along-*.dump.age' \
  -mtime "+${BACKUP_RETENTION_DAYS:-7}" -delete
printf 'Encrypted backup uploaded: %s\n' "$(basename "$output")"
