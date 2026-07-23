# Passkeys and associated domains

Along is a self-hosted WebAuthn relying party. There are no passwords and no
managed authentication vendor. Native private keys remain in iCloud Keychain,
the Android credential provider, or a hardware authenticator.

## Domain-owner actions

The owner of `along.spicer.dev` and Apple/Google developer accounts must complete these
steps before passkeys work outside development:

1. Keep `ALONG_DOMAIN=along.spicer.dev`. The server derives its public URL,
   WebAuthn RP ID, and HTTPS origin from this value. Never change it after
   launch; existing passkeys are scoped to the RP ID.
2. In Apple Developer Certificates, Identifiers & Profiles, enable **Associated
   Domains** and **Push Notifications** for the explicit App ID
   `com.joshspicer.along`.
3. Set `APPLE_TEAM_ID` to the ten-character Apple Team ID. The API generates
   both `applinks` and `webcredentials` entries.
4. Verify the generated extensionless document at
   `https://along.spicer.dev/.well-known/apple-app-site-association` with
   `Content-Type: application/json`, HTTP 200, no redirect, and a valid public
   certificate. The reverse proxy must handle TLS termination.
5. Keep `applinks:along.spicer.dev` and `webcredentials:along.spicer.dev` in the signed iOS
   entitlements. Regenerate distribution profiles after enabling capabilities.
6. Set `ANDROID_SIGNING_SHA256` to the uppercase SHA-256 fingerprint from
   **Play App Signing**, not a local debug key. The API serves the generated
   document at `/.well-known/assetlinks.json` without a redirect.
7. Enable Credential Manager passkey association for
   `com.joshspicer.along`. Preserve that application ID for every release.
8. Run `./scripts/check-associated-domains.sh` and verify both URLs from an
   external network before submitting builds.

Apple and Android cache association files. Plan hours, not seconds, for a
change to propagate. A staging build needs its own owned domain, RP ID,
application identifier, AASA entry, asset link, and provisioning profile.
Native passkey ceremonies cannot be meaningfully tested against an unassociated
localhost application.

## Ceremony and recovery policy

- Registration and discoverable login require user verification and resident
  credentials.
- Challenges are single-purpose, server-side, five-minute, and atomically
  consumed.
- Access tokens expire after ten minutes. High-entropy refresh tokens rotate in
  serializable transactions; reuse revokes the whole family.
- Public credentials, sessions, and installations are independently revocable.
- Ten recovery codes are shown once. Argon2id hashes are stored; a successful
  code is consumed atomically.
- Adding a replacement passkey after recovery is strongly recommended.
