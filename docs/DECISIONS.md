# Decisions

## D001 — Build and toolchain
- Question: reproducible native build without extra developer tooling?
- Adopted: Xcode macOS 14 arm64 app plus local Swift package modules, checked-in project/schemes and lockfile. Use installed Xcode 27/Swift 6.4; ad-hoc local signing, no team.
- Rationale/evidence: host has Xcode/SDK 27 and arm64; PRD requires Xcode app and testable modules.
- Alternatives: generated-only project adds prerequisite; SwiftPM-only executable fails explicit app-target requirement.
- Uncertainty: runtime coverage on macOS 14 unavailable, retain BLOCKED status.
- Affects: build/scripts; change cost low. Final review: no.

## D002 — Safety validation and adapter enablement
- Question: how to handle unvalidated cross-app insertion?
- Provisional: automatic insertion enabled only for an adapter/OS range with actual successful compatibility evidence. Implement all required adapters; unsupported/unvalidated contexts preserve one Recovery result.
- Rationale: PRD explicitly requires tested targets and conservative unknown-control behavior; permission absence is not validation.
- Alternatives: blindly allowlist bundle IDs risks content loss; pretending mocked evidence validates OS behavior is disallowed.
- Assumption: real UI grants may be missing. Tests distinguish implemented paths from accepted adapters.
- Affects: insertion/catalog, readiness and human handoff; change cost low (evidence-backed catalog update). Final review: yes, high impact.

## D003 — Exact engine and offline tokenizer
- Adopted: WhisperKit 1.1.0 revision `1e2a163736dfa5a198e637ae44c114e1c6d5cc2d`, only WhisperKit product. Lockfile also pins argument-parser 1.8.2 (CLI-only upstream dependency, not app linked).
- Question: prevent hidden Hub fallback during cold/offline use?
- Approach: override tokenizer loading with public local-file AutoTokenizerWrapper and a small WhisperTokenizer protocol adapter; download=false, logs=.none. No remote loader call in this path.
- Evidence: upstream ModelUtilities.loadTokenizer catches local parse errors then downloads; a download=false model setting alone is insufficient. Public wrapper initializer is internal, so Aparté supplies the protocol bridge. Catalog is multilingual only; word timestamps are disabled.
- Alternative: upstream fallback with cache validation rejected because corruption/races can invoke network. Vendoring/patching entire dependency rejected for maintenance cost.
- Uncertainty: bridge must be verified with real English/French output; inherited modelVariant diagnostics stay at upstream default, unused by Aparté (manifest ID is authoritative). Revisit if upstream exposes a strict local-only initializer.
- Affects: AparteSpeech; medium replacement cost. Final review: yes.

## D004 — Model catalog pins and integrity
- Adopted: Core ML repo `argmaxinc/whisperkit-coreml` revision `0f63a7800b00dd0226abd051b906c246e1907482`, base/small. Tokenizer `openai/whisper-base` revision `e37978b90ca9030d5170a5c07aadb050351a65bb` shared by these multilingual vocabularies.
- Evidence: exact file list/URLs/sizes/SHA-256 in Resources/Models.json; downloaded pinned public assets and computed hashes. Base 149,484,796 bytes; small 489,252,808 bytes. Computed hashes detect corruption, not independent authenticity.
- Alternatives: mutable runtime discovery rejected; turbo deferred until base/small comparative evidence warrants more memory/download scope.
- Assumption: shared base tokenizer fits multilingual small vocabulary, to validate during M3 real inference. Download transfer interrupted once; bounded retry succeeded, partial files never promoted.
- Affects: models/downloader, disk, licensing notices; low-to-medium migration cost. Status adopted. Final review: yes.

## D005 — Local checkpoint identity
- Adopted: per-command Git author `Aparte Local Build Agent <aparte-agent@localhost.invalid>`, signing disabled per local commit only.
- Question: machine has no Git author and requires an unavailable SSH signing key by default.
- Rationale/evidence: first commit failed for both reasons; user authorizes local commits and forbids using release credentials. No global configuration changed.
- Alternatives: inventing owner identity rejected; blocking coding on Git setup unnecessary.
- Affects: local commit metadata, trivially replaceable before any separately authorized publication. Final review: no.
