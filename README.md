# Along

Along is a private, pair-scale focus app. Either person can begin a 25-minute
room immediately; the other joins the authoritative timer already in progress.
Completed solo and shared sessions appear newest-first in **Look back**.

The monorepo contains:

- `mobile/` — Flutter app for iOS and Android
- `server/` — Go collaboration API, WebSocket service, APNs worker, and migrations
- `deploy/` — Caddy and production-operation assets
- `docs/` — product contract, architecture, privacy, and release guidance

There are intentionally no habits, schedules, feeds, scores, streaks,
surveillance, or engagement-pressure mechanics.

## Local development

Copy `.env.example` to `.env`, use development-only values, then run:

```sh
docker compose up --build
```

The API is available through Caddy at `https://localhost` (development
certificate) and directly at `http://localhost:8080`. See
[`docs/RUNBOOK.md`](docs/RUNBOOK.md) for setup and operations.

Go is pinned to 1.26.5. Flutter is pinned through FVM to 3.44.6 / Dart 3.12.2.
No credentials or generated build directories belong in source control.

