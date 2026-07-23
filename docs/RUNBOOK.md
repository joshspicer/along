# Operations runbook

## Production prerequisites

- A Linux host with Docker Engine 29+ and Compose v2
- DNS for `along.spicer.dev` pointed at the host, with port 6009 reachable behind a reverse proxy
- PostgreSQL storage on encrypted durable media
- Apple Team ID, APNs key ID, and an APNs `.p8` with push permission
- An age recipient whose private identity is held off-host
- An HTTPS PUT backup gateway in a separate account or failure domain

Generate local secret files with `./scripts/generate-secrets.sh`. Add
`secrets/AuthKey.p8` and `secrets/backup_upload_token` manually. Never copy an age
private identity, Apple key, or signing credential into the repository or image.
Set file mode `0600`.

Before production, replace both `REPLACE_WITH` values under
`deploy/well-known/`, then run:

```sh
./scripts/check-associated-domains.sh
cp .env.example .env
docker compose config --quiet
```

## Deploy and migrate

Pin `ALONG_SERVER_IMAGE` to an immutable version or digest in `.env`; do not
deploy mutable `latest` in production.

```sh
docker compose pull
docker compose run --rm migrate
docker compose up -d postgres api apns
docker compose ps
curl --fail https://along.spicer.dev/health/ready
```

Migrations take a PostgreSQL advisory lock, run transactionally, and are safe to
retry. The API never auto-migrates. Roll out migrations before multiple API
replicas. Add replicas only behind a reverse proxy; PostgreSQL `LISTEN/NOTIFY` propagates
cursor hints while the append-only event log remains the durable source.

The application image runs as UID/GID 65532 with a read-only root filesystem.
Normal API and worker operation does not require a writable filesystem mount.

## Health and observability

- `/health/live` proves the process can serve HTTP.
- `/health/ready` includes a bounded PostgreSQL ping.
- Logs are JSON on stdout and carry request IDs; credentials and tokens are
  redacted.
- Monitor request rate, 5xx responses, readiness, PostgreSQL connections and
  disk, event cursor lag, notification job age/attempts, and backup age.
- Alert if readiness fails twice, unprocessed notification jobs exceed five
  minutes, disk exceeds 80%, or the latest verified off-host backup is older
  than 26 hours.

Push failure never changes product correctness. A deep link only opens the app;
the client always resynchronizes from its durable cursor.

## APNs

The worker reads `/run/secrets/apns_key`, keeps a persistent HTTP/2 connection,
and signs short-lived provider tokens. It permanently removes devices after
APNs `410` or terminal bad-token responses. `429` and `5xx` responses use
bounded exponential backoff. Notification copy contains no names, note text,
timer details, or identifiers.

Rotate an APNs key by placing the new `.p8`, updating `APNS_KEY_ID`, and
recreating only the worker:

```sh
docker compose up -d --force-recreate apns
```

## Backups and restore drills

Run from a scheduler at least daily:

```sh
sudo install -d -m 0700 -o 65532 -g 65532 backups
docker compose --profile operations run --rm backup
```

`pg_dump` output is encrypted with age before upload. The hook sends the
encrypted object by authenticated HTTPS PUT to `BACKUP_UPLOAD_URL`, then applies local retention.
Configure remote-side immutability/versioning separately.

Quarterly, download a backup into `backups/`, provision an empty isolated
database, and run the restore image with the age identity mounted read-only:

```sh
docker compose --profile operations run --rm \
  -e BACKUP_FILE=/backups/along-YYYYMMDDTHHMMSSZ.dump.age \
  -e AGE_IDENTITY_FILE=/run/secrets/age_identity \
  --entrypoint /usr/local/bin/restore.sh backup
```

Never restore over production during a drill. Record recovery point and elapsed
time; targets are RPO 24 hours and RTO 2 hours.

## Incident response and rollback

1. Preserve JSON logs and database evidence without copying token values.
2. Revoke a compromised device, passkey, or session through the account UI.
3. Rotate JWT and push-encryption secrets only with a planned global sign-out
   and push-token re-registration.
4. For refresh-token reuse, the service automatically revokes the entire family.
5. Roll back the API image by digest. Database migrations are forward-only in
   routine operation; restore into a new database for destructive rollback.
6. Confirm `/health/ready`, two-account sync, timer skew, and cursor replay after
   any recovery.
