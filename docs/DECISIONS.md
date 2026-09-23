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

## D006 — Recovery for attempted writes
- Question: whether API return or Cmd-V dispatch proves insertion.
- Adopted: record an attempted write and keep the one transient recovery result with “Insertion unconfirmed — check the target before copying.” No automatic retry or alternate mutation path. Even AX errors do not fall back.
- Evidence: AX success is not app-level evidence; paste offers no acknowledgement. PRD prioritizes avoiding duplicates over silent retry.
- Alternative: assuming success and discarding all recovery loses a recoverable result; automatic fallback can duplicate text.
- Assumption: validated adapter happy paths still need visual evidence; the app cannot generally confirm. Affects coordinator/recovery; low change cost. Final review: yes.

## D007 — Speech gate and Unicode
- Provisional: 250 ms minimum, RMS >= 0.001 (-60 dBFS), Whisper no-speech 0.6 with low log probability, compression ratio >2.4 or four repeated 1–8-word phrases (at least 12 words) rejects the entire result.
- Rationale: conservative energy floor preserves quiet speech; no per-word deletion/paraphrasing. Must calibrate against training-only quiet/noise clips and report held-out quality.
- Alternative: aggressive energy gating risks quiet-speaker rejection; energy alone cannot identify speech.
- Unicode: remove Unicode Cc control codes and map line/tab separators to spaces, retain Cf joiners needed for emoji. Unit evidence caught Foundation controlCharacters removing emoji joiners and the implementation was fixed.
- Affects speech accuracy/insertion; easy thresholds to revisit, medium quality-validation cost. Final review: yes, high uncertainty until corpus validation.

## D008 — Lazy clipboard proof on macOS 26.6
- Question: how to enforce the PRD's refusal of lazy data without accidentally invoking its provider?
- Adopted conservative interpretation: automatic snapshot accepts an empty clipboard or a matching change-count receipt for an eager write made by this adapter. Unknown nonempty clipboards go to Recovery before data access. Full multi-item representations are preserved for provably eager content.
- Evidence: a separate real AppKit owner process supplied a lazy `NSPasteboardItemDataProvider`. The public `PasteboardGetItemFlavorFlags` returned 0 for its actual string flavor; fetching the data invoked the provider. Implicit system-translated flavors had promised flags but are not owner-supplied data. Both same-process and cross-process tests exposed this. Temporary diagnostics were removed.
- Alternatives: treating flags=0 or a fast provider as proof of eagerness violates the explicit refusal requirement; private APIs are inappropriate. An unsafe override is not provided.
- Conflict/uncertainty: public eager/lazy classification is insufficient on this host. Therefore general externally-owned rich/text/image clipboard happy-path acceptance remains BLOCKED by this OS/API limitation, even though safety tests pass. The app explicitly offers Copy instead. This restricts clipboard automatic insertion significantly; it is not full M2/M4 acceptance.
- Affects: clipboard and Terminal/VS Code/Chrome/Slack automatic paste; low implementation change cost if a reliable public method becomes available, high validation importance. Final review: yes, highest impact.
- Earlier M2 helper tests passed full snapshots before this stronger adversarial case exposed the limitation; that evidence is not being presented as full acceptance. Tests now distinguish known eager writes from unknown foreign provenance while retaining strict lazy refusal.
