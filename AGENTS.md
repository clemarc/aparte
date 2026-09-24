# Aparté implementation

Authority: `Aparte-PRD-v2.md` (read completely), including the owner-approved D013 clipboard/insertion and D018 system-wide editable-field amendments recorded in `docs/DECISIONS.md`. Scope: M0–M4 only; no M5, remote, hosted CI, release-signing credentials, notarisation, publication, or paid services. Owner-approved D016 permits a dedicated local-only development signing identity for stable permissions; never commit its private material.

Commands:
- `./scripts/build-local.sh --configuration Debug|Release`
- `./scripts/test-local.sh --suite unit|integration`
- `./scripts/benchmark-local.sh --manifest Tests/Fixtures/manifest.json`

Continue checkpoints without approval. Decide, document, continue. Preserve existing work. On resume read `docs/PROGRESS.md`, `docs/DECISIONS.md`, `docs/ACCEPTANCE.md`, and inspect actual repository state. Finish the next incomplete task; do not restart completed work. Maintain evidence and local milestone commits. External blockers do not block independent implementation. Never pass a real-device gate using a mock, skipped test, or invented result. Do not repeatedly retry unchanged OS permission/hardware blockers. Never collect private recordings/transcripts or commit weights/build outputs. Stop at M4 handoff; distinguish acceptance from pending validation.
