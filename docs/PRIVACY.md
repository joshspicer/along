# Privacy inventory

Along collects only data needed for a private two-person focus space.

| Data | Purpose | Storage |
| --- | --- | --- |
| Display name and stable account ID | Identify the two pair members | PostgreSQL |
| Passkey public credential, counter, transports | Verify WebAuthn assertions | PostgreSQL; no private key or biometric |
| Hashed one-time recovery codes | Account recovery | Argon2id hashes only |
| Hashed refresh tokens and session/device metadata | Session rotation and revocation | PostgreSQL; opaque token in Keychain/Keystore |
| Pair membership and one-time invite hash | Maintain the private pair | PostgreSQL |
| Session timestamps, state, participants | Authoritative focus and Look back | PostgreSQL and local Drift read model |
| Optional note and cheer | User-requested pair communication | PostgreSQL and local Drift read model |
| Encrypted APNs token | Transactional partner notification | AES-GCM ciphertext; plaintext only in worker memory |
| Request ID, route, status, duration | Reliability and abuse response | Structured operational logs |

Along does **not** upload contacts, biometric data, device passcodes, passwords,
precise location, advertising identifiers, browsing history, health data, or
third-party analytics. It has no public profile, feed, score, streak, or
cross-app tracking.

Notification copy is deliberately generic. Notes and names never enter an APNs
payload. Push is optional and not a source of truth.

For App Store privacy labels, declare account identifiers, user content
(optional notes), product interaction (session events), and device identifiers
(installation/APNs token) as linked to the user for app functionality. Declare
no tracking and no data used for advertising. Re-evaluate labels whenever the
schema or SDK inventory changes.

Production policy must define retention and a verified account deletion/export
procedure before public launch. Backups remain encrypted and expire under the
documented retention schedule.

