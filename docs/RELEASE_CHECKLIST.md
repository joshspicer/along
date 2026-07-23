# Release checklist

## Every release

- [ ] Product still has only Focus and Look back as primary destinations.
- [ ] No habit, schedule, score, streak, surveillance, feed, or pressure
      mechanic was introduced.
- [ ] `go test -race ./...` and tagged PostgreSQL integration tests pass.
- [ ] Flutter format, analysis, tests, Android build, and unsigned iOS simulator
      build pass on Flutter 3.44.6 / Dart 3.12.2.
- [ ] Production image passes migration/read-only smoke test and Trivy scan.
- [ ] Generated Drift/Freezed files match source.
- [ ] Schema changes have a forward migration and restore implications reviewed.
- [ ] Privacy inventory and store labels still match code and dependencies.
- [ ] Dynamic Type, VoiceOver/TalkBack, reduced motion, dark theme, offline
      completion, reconnect replay, and partner join are manually exercised.
- [ ] Joining preserves `started_at` and `ends_at`; two devices show <250 ms
      corrected skew.
- [ ] Push denial and push outage do not affect discovery or correctness.
- [ ] Recovery, passkey/session/device revocation, and refresh reuse are tested.
- [ ] AASA/assetlinks return 200 JSON without redirects and contain production
      owner identifiers.
- [ ] Latest off-host encrypted backup is verified; restore drill is current.
- [ ] Commit hash appears in Settings and server `/v1/meta`.

## Mobile store handoff

- [ ] App Store Connect name is `Along: Focus Together`, product name is
      `Along Focus Together`, and SKU is `along-focus-together-ios-2026`.
- [ ] Increment `version`/build number and generate unsigned artifacts with the
      manual workflow or `scripts/release-mobile.sh`.
- [ ] Owner signs with distribution credentials outside the repository.
- [ ] Confirm production API URL and APNs environment compile defines.
- [ ] Upload screenshots tested with large text and both themes.
- [ ] Complete export-compliance answer: app uses only exempt standard
      encryption (`ITSAppUsesNonExemptEncryption = NO`).
- [ ] Stage rollout and monitor crash-free sessions, sync latency, timer skew,
      push acceptance, and readiness.

## Server handoff

- [ ] Publish a semantic, immutable multi-architecture image with provenance and
      SBOM using `release-server.yml` or `scripts/release-server.sh`.
- [ ] Deploy migration job, then API and worker.
- [ ] Verify health, synthetic pair start/join/complete, cursor replay, and APNs.
- [ ] Record image digest and rollback digest in the change ticket.
