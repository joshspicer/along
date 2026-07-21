#!/bin/sh
set -eu

: "${DATABASE_URL_FILE:?DATABASE_URL_FILE is required}"
: "${BACKUP_AGE_RECIPIENT:?BACKUP_AGE_RECIPIENT is required}"
: "${BACKUP_RCLONE_REMOTE:?BACKUP_RCLONE_REMOTE is required}"

export RCLONE_CONFIG=/run/secrets/rclone_config
database_url=$(cat "$DATABASE_URL_FILE")
stamp=$(date -u +%Y%m%dT%H%M%SZ)
output="/backups/along-${stamp}.dump.age"

pg_dump --format=custom --no-owner --no-privileges "$database_url" |
  age --recipient "$BACKUP_AGE_RECIPIENT" --output "$output"
rclone copyto "$output" "${BACKUP_RCLONE_REMOTE%/}/$(basename "$output")"

find /backups -type f -name 'along-*.dump.age' \
  -mtime "+${BACKUP_RETENTION_DAYS:-7}" -delete
printf 'Encrypted backup uploaded: %s\n' "$(basename "$output")"

