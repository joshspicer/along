# API contract summary

All `/v1` endpoints use JSON over TLS. Protected routes require
`Authorization: Bearer <access-token>`. Mutations require a UUID
`Idempotency-Key` unless they are auth ceremonies or `/v1/sync`.

WebAuthn finish requests carry the raw public-key credential JSON plus
`X-Along-Challenge`, stable `X-Along-Installation-ID`,
`X-Along-Platform`, and `X-Along-Device-Name` headers.

| Method and path | Purpose |
| --- | --- |
| `POST /v1/auth/register/options`, `/finish` | Create stable passkey account |
| `POST /v1/auth/login/options`, `/finish` | Discoverable passkey login |
| `POST /v1/auth/refresh`, `/recover`, `/logout` | Rotate, recover, revoke |
| `/v1/auth/passkeys`, `/sessions`, `/installations` | List/add/revoke auth factors |
| `POST /v1/pair/invites`, `/accept`; `GET /v1/pair` | One-time private pairing |
| `POST /v1/sessions`; `GET /current`, `/v1/sessions` | Start and read focus |
| `POST /v1/sessions/{id}/{join,pause,resume,complete,cancel}` | Versioned transitions |
| `POST /v1/sessions/{id}/{notes,cheers}` | Optional care signals |
| `POST /v1/sync` | Apply up to 100 outbox commands and replay cursor events |
| `GET /v1/ws` | Authenticated pair cursor hints |
| `PUT`, `DELETE /v1/push/device` | Register/revoke APNs installation |

Transition bodies include `expected_version`. Joining adds a member and changes
`open` to `together` without modifying authoritative `started_at` or `ends_at`.
An offline client submits `session.import_solo` only after completion; it can
never expose a joinable room.

Errors always have:

```json
{
  "error": {
    "code": "version_conflict",
    "message": "The session changed on another device. Sync and try again.",
    "request_id": "..."
  }
}
```

Clients branch on stable `code`, not human copy. A version conflict always
requires cursor sync before retry. WebSocket disconnects and push loss never
justify local clock or state authority.

