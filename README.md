# Along

Along is a private, pair-scale focus app for making intentional time with one
other person. Either person can begin a 25-minute room immediately; the other
joins the authoritative timer already in progress without an invitation,
waiting room, or clock reset. Completed solo and shared sessions appear
newest-first in **Look back**.

Along is intentionally small. The primary navigation is only **Focus** and
**Look back**. There are no habits, schedules, feeds, scores, streaks,
surveillance, or engagement-pressure mechanics.

## Current status

Along is under active development:

- the Go/PostgreSQL API is deployed at `https://along.spicer.dev`
- production traffic is terminated by Nginx Proxy Manager and forwarded to the
  private Docker service `along:6009`
- iOS and Android clients are implemented in Flutter with local-first storage,
  offline solo sessions, durable sync, WebSockets, passkeys, and recovery codes
- GitHub Actions builds and tests the server, Flutter app, containers, and
  migrations; Xcode Cloud handles signed iOS distribution
- native association endpoints are served by the API at `/.well-known/`

Launch readiness and remaining platform verification are tracked in Linear and
[`docs/RELEASE_CHECKLIST.md`](docs/RELEASE_CHECKLIST.md).

The monorepo contains:

- `mobile/` — Flutter app for iOS and Android
- `server/` — Go collaboration API, WebSocket service, APNs worker, and migrations
- `deploy/` — backup and production-operation assets
- `docs/` — product contract, architecture, privacy, and release guidance

## Local development

### Prerequisites

- Docker Engine 29+ with Compose v2
- Flutter 3.44.6 / Dart 3.12.2 through FVM
- Xcode for iOS simulator builds or Android Studio for Android builds

### Start the service

Copy the environment template, create ignored development secrets, and start
PostgreSQL, migrations, and the API:

```sh
cp .env.example .env
./scripts/generate-secrets.sh
docker compose up --build postgres migrate along
```

The production Compose topology exposes `along:6009` only inside Docker and the
configured Nginx Proxy Manager network. For host/simulator access, add a local
Compose override that publishes `6009:6009`, or run the server directly with a
development `DATABASE_URL`.

Verify the service with:

```sh
curl --fail http://localhost:6009/health/ready
```

### Run the mobile app

```sh
cd mobile
fvm install
fvm flutter pub get
fvm dart run build_runner build
fvm flutter run \
  --dart-define=ALONG_API_BASE_URL=http://localhost:6009 \
  --dart-define=ALONG_APNS_ENVIRONMENT=sandbox
```

Plain localhost is suitable for API, sync, WebSocket, offline, and UI testing.
Native passkeys require an associated HTTPS relying-party domain; they cannot
be meaningfully validated against a localhost origin. See
[`docs/PASSKEYS_AND_DOMAINS.md`](docs/PASSKEYS_AND_DOMAINS.md).

### Validate

```sh
make server-check
make integration-test
make mobile-check
make mobile-test
make docker-build
```

API behavior is summarized in [`docs/API.md`](docs/API.md), with the
machine-readable contract at [`server/openapi.yaml`](server/openapi.yaml).
Production deployment and recovery procedures are in
[`docs/RUNBOOK.md`](docs/RUNBOOK.md).

## Architecture highlights

- self-hosted WebAuthn accounts with short-lived access tokens, rotating opaque
  refresh tokens, revocable devices/passkeys/sessions, and one-time recovery codes
- Drift read models, durable cursor, mutation outbox, idempotent retries, and
  offline solo sessions
- server-authoritative shared timers with expected-version concurrency
- append-only pair events, cursor replay, authenticated WebSockets, and
  PostgreSQL `LISTEN/NOTIFY`
- optional direct APNs worker; push improves discovery but is never required for
  correctness
- multi-stage non-root server image with read-only runtime support

Go is pinned to 1.26.5. Flutter is pinned through FVM to 3.44.6 / Dart 3.12.2.
No credentials or generated build directories belong in source control.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) before proposing changes. Report security
issues privately as described in [docs/SECURITY.md](docs/SECURITY.md).

## License

Along is licensed under the [GNU Affero General Public License version 3](LICENSE).
