# Along

Along is a private, pair-scale focus app. Either person can begin a 25-minute
room immediately; the other joins the authoritative timer already in progress.
Completed solo and shared sessions appear newest-first in **Look back**.

The monorepo contains:

- `mobile/` — Flutter app for iOS and Android
- `server/` — Go collaboration API, WebSocket service, APNs worker, and migrations
- `deploy/` — reverse-proxy config and production-operation assets
- `docs/` — product contract, architecture, privacy, and release guidance

There are intentionally no habits, schedules, feeds, scores, streaks,
surveillance, or engagement-pressure mechanics.

## Local development

Copy `.env.example` to `.env`, use development-only identifiers, and create
local secrets:

```sh
./scripts/generate-secrets.sh
docker compose up --build postgres migrate along
```

The API is available at `http://localhost:6009`. See
[`docs/RUNBOOK.md`](docs/RUNBOOK.md) for setup and operations.

Native passkeys require an owned HTTPS relying-party domain. See
[`docs/PASSKEYS_AND_DOMAINS.md`](docs/PASSKEYS_AND_DOMAINS.md) before device
testing. API behavior is summarized in [`docs/API.md`](docs/API.md), with the
machine-readable contract at `server/openapi.yaml`.

Go is pinned to 1.26.5. Flutter is pinned through FVM to 3.44.6 / Dart 3.12.2.
No credentials or generated build directories belong in source control.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) before proposing changes. Report security
issues privately as described in [docs/SECURITY.md](docs/SECURITY.md).

## License

Along is licensed under the [GNU Affero General Public License version 3](LICENSE).
