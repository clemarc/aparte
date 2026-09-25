# Aparté implementation

Authority: `Aparte-PRD-v2.md` (read completely), including the owner-approved amendments recorded in `docs/DECISIONS.md`. M0–M4 implementation is closed with acceptance pending. The owner authorised M5A public source under `clemarc`, MIT licensing, existing audited history and hosted build/test. M5B public binaries, Developer ID credentials, notarisation and automatic release publication remain outside this authorisation. Owner-approved D016 permits a dedicated local-only development signing identity for stable permissions; never commit its private material.

Commands:
- `./scripts/build-local.sh --configuration Debug|Release`
- `./scripts/test-local.sh --suite unit|integration`
- `./scripts/benchmark-local.sh --manifest Tests/Fixtures/manifest.json`

Continue checkpoints without approval. Decide, document, continue. Preserve existing work. On resume read `docs/PROGRESS.md`, `docs/DECISIONS.md`, `docs/ACCEPTANCE.md`, and inspect actual repository state. Finish the next incomplete task; do not restart completed work. Maintain evidence and local milestone commits. External blockers do not block independent implementation. Never pass a real-device gate using a mock, skipped test, or invented result. Do not repeatedly retry unchanged OS permission/hardware blockers. Never collect private recordings/transcripts or commit weights/build outputs. Distinguish build/CI success from real-device acceptance. Keep the M4 handoff and blocked checks visible. CI artifacts are ad-hoc signed development builds, not notarised releases.
