#!/bin/sh
set -eu

: "${DATABASE_URL_FILE:?DATABASE_URL_FILE is required}"
: "${BACKUP_FILE:?BACKUP_FILE is required}"
: "${AGE_IDENTITY_FILE:?AGE_IDENTITY_FILE is required}"

database_url=$(cat "$DATABASE_URL_FILE")
age --decrypt --identity "$AGE_IDENTITY_FILE" "$BACKUP_FILE" |
  pg_restore --clean --if-exists --no-owner --no-privileges \
    --dbname "$database_url"

