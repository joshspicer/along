# Security model

## Primary controls

- Native, user-verified WebAuthn passkeys; no password database
- Short-lived HS256 access tokens with validated issuer, audience, expiry,
  session, installation, and current revocation state
- Opaque 256-bit rotating refresh tokens stored as SHA-256 hashes; serializable
  rotation and family-wide replay response
- Argon2id recovery-code hashes and atomic one-time use
- Account-owned pair membership checked in every collaboration transaction
- Expected versions plus serializable writes and UUID idempotency keys
- Append-only pair events and transactionally created push jobs
- APNs tokens encrypted with AES-256-GCM and never logged
- Request-size limits, route/IP rate limits, secure headers, JSON errors,
  non-root containers, read-only filesystems, and isolated Docker secrets

The client is untrusted. Drift is a responsive cache and outbox, not an
authorization boundary. Shared time derives from server timestamps. WebSockets
carry only cursor hints; `/v1/sync` replays committed events.

## Secret rotation

- APNs keys can rotate without session impact.
- Database credentials require recreating database clients and dependent
  services.
- JWT key rotation currently causes a deliberate global access-token refresh;
  retain the previous deployment until the ten-minute access window passes.
- Push-encryption-key rotation requires re-registering tokens or a staged
  re-encryption migration.

Report vulnerabilities privately through GitHub Security Advisories. Do not put
credentials, real user content, or exploit details in a public issue.

