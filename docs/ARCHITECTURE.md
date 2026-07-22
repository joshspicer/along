# Architecture

## Trust boundaries

The Flutter client is local-first but untrusted. PostgreSQL is authoritative
for accounts, pair membership, shared timers, event order, refresh-token
families, and delivery jobs. Every write derives account identity from a
short-lived signed access token and checks pair membership in the same
transaction.

## Data flow

1. A mutation is written to the Drift outbox with a stable UUID idempotency key.
2. `POST /v1/sync` atomically applies commands and returns pair events after the
   durable cursor.
3. The client reduces those events into Drift read models and advances its
   cursor in one local transaction.
4. An authenticated pair WebSocket carries cursor hints only. Reconnect always
   replays through `/v1/sync`.
5. PostgreSQL `LISTEN/NOTIFY` fans out commit-visible event cursors between API
   instances.

Session commands require `expected_version`. The state machine is
`open → together → paused → completed`, with `cancelled` and `expired` terminal
states. Authoritative timestamps make timer rendering independent of sockets
and push.

## Authentication

Accounts are self-hosted and passkey-first. WebAuthn challenges are
single-purpose and short-lived. Access tokens are signed and short-lived.
Opaque refresh tokens rotate atomically; replay revokes the whole family.
Recovery codes are printable once and stored only as slow hashes. Credentials,
sessions, and installations are independently revocable.

