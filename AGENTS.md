# Aparté implementation

Authority: `Aparte-PRD-v2.md` (read completely), including the owner-approved amendments recorded in `docs/DECISIONS.md`. M0–M4 implementation is closed with acceptance pending. The owner authorised M5A public source under `clemarc`, MIT licensing, existing audited history and hosted build/test. Owner-approved D030 adds a separate persistent self-signed beta identity, local packaging and manual GitHub draft prereleases; no release on each version bump. Developer ID credentials, notarisation, hosted signing secrets and automatic publication remain outside this authorisation. D016's development identity remains local-only. Never commit either identity's private material. Keep fresh-Mac downloaded launch and real two-version permission persistence as outstanding gates; signatures do not pass them.

Commands:
- `./scripts/build-local.sh --configuration Debug|Release`
- `./scripts/test-local.sh --suite unit|integration`
- `./scripts/benchmark-local.sh --manifest Tests/Fixtures/manifest.json`

Continue checkpoints without approval. Decide, document, continue. Preserve existing work. On resume read `docs/PROGRESS.md`, `docs/DECISIONS.md`, `docs/ACCEPTANCE.md`, and inspect actual repository state. Finish the next incomplete task; do not restart completed work. Maintain evidence and local milestone commits. External blockers do not block independent implementation. Never pass a real-device gate using a mock, skipped test, or invented result. Do not repeatedly retry unchanged OS permission/hardware blockers. Never collect private recordings/transcripts or commit weights/build outputs. Distinguish build/CI success from real-device acceptance. Keep the M4 handoff and blocked checks visible. CI artifacts are ad-hoc signed development builds, not notarised releases.
