# Aparté M4 local handoff

**Implementation complete through the feasible M0–M4 scope; validation pending. M4 is not accepted.** The candidate deliberately restricts automatic clipboard insertion where safe eager-data snapshotting cannot be proved (D008). No M5 work was started.

## Delivered

- Native arm64 macOS14+ source, Xcode project/shared scheme, testable modules and exact Swift dependency/model pins.
- Local ad-hoc Release app at `~/Applications/Aparte.app` and `artifacts/DerivedData/Build/Products/Release/Aparte.app`; signature verified. No Developer ID, notarisation, DMG or public release.
- Verified public multilingual small model installed under `~/Library/Application Support/Aparte/Models/small/` for offline use. Base/small evaluation assets remain ignored in `artifacts/models/`.
- Native capture, WhisperKit inference, guarded target/AX/clipboard paths, transient recovery, configurable hold shortcut/language/model management and truthful launch-at-login controls.
- 29 passing tests including actual named-pasteboard and separate lazy-owner process checks; real offline engine/corpus, model installer, cancellation and model-switch evidence.
- Small passed the fixed synthetic WER, technical-term and no-speech gates. Base failed technical terms, so small is the default. Exact results/raw data and limitations are in BENCHMARKS.

M0 feasible gates passed. M1–M4 implementation continued despite missing permission/desktop prerequisites, as requested. Missing real-device evidence is not converted into acceptance. The final clean-checkout verification result is recorded in `docs/evidence/verification.json` and PROGRESS.

## Important limitations / known behavior

Automatic adapter catalog is empty until each exact app/OS version passes the real protocol. Thus this installed candidate normally delivers a transcription through Recovery after grants/model readiness, rather than claiming untested cross-app insertion works. A valid target adapter alone would not remove the clipboard restriction below.

D008: macOS 26.6 returns ordinary public flavor metadata for a foreign lazy AppKit provider. The strict test proved fetching it invokes the provider. Unknown nonempty clipboards therefore cause Recovery without reading their data. Automatic paste is limited to empty or proven eager-owned clipboards. This limits common clipboard workflows and blocks the general rich/text/image clipboard happy-path gate. There is no unsafe override.

No live recording was collected. Quit and reopen any previously running instance to use the final rebuilt bundle. Microphone/Accessibility/posting, real global shortcut delivery, actual insertion correctness, visible indicators, VoiceOver, physical device changes, lock/sleep, launch-at-login cycle and macOS14 runtime have not been accepted. Native UI tooling failed (closed connection, then timeout). Installed app process launch and code builds are evidence of those narrow checks only.

File decode timings are not release-to-insertion latency. Synthetic speech quality is not natural microphone quality. Ordinary clipboard races and custom terminal paste handlers cannot be made atomic by this app. No Return is generated. Check an “Insertion unconfirmed” target before copying a recovery result again.

## Decision review, ordered by impact / uncertainty

1. **D008 — Clipboard proof restriction.** Highest usability impact. Preserve strict refusal until a reliable public eager-data proof is available or the owner explicitly revises the PRD. The guard is easy to change, but removing it without evidence reintroduces the demonstrated lazy-provider failure.
2. **D002 — Adapter enablement.** Automatic insertion is disabled for unvalidated versions. Highest-value next work is the ten-attempt real matrix. Enabling a verified entry is a small catalog change; no unsafe user toggle exists.
3. **D007 / D009 — Speech gate and small default.** Small passes the frozen synthetic corpus; real quiet/noisy microphone speech remains uncertain. Model switching is easy. Recalibrate on a separate calibration set, retain held-out data and the original gates; do not silently relax thresholds. Base's 50% term result remains a recorded failure.
4. **D003 — Local tokenizer protocol bridge.** It avoids upstream's remote fallback; bilingual and offline tests pass. Revisit when upstream offers a strict local-only public initializer. Replacement is localized but needs repeat offline/tokenizer/inference validation.
5. **D006 — Recovery after attempted insertion.** Conservative “unconfirmed” labeling avoids duplicate retries. Easy UX change, but any automatic retry would require stronger acknowledgement than the OS generally provides.
6. **D010 — Physical shortcut labels.** US physical key names are disclosed; test alternate layouts. Label improvements are inexpensive and do not require changing stored chords.
7. **D001 / D004 — Toolchain and asset pins.** Xcode27 builds a macOS14 target, but minimum-OS runtime is missing. Asset updates require new immutable manifests and full real-engine checks. D005 only affects local author metadata, not product behavior.

## Consolidated remaining human / external actions

- [ ] Open the stable app and review Settings & Setup. Grant Microphone and Accessibility through macOS; only follow Input Monitoring guidance if the actual event tap requires it. Recheck; quit/reopen if grants require it. Do not bypass security or reset TCC.
- [ ] Provide a consented local microphone session: ten short English/French/quiet dictations, no retained recordings. Measure shortcut-to-live-capture p95 and release-to-dispatch/visible-text timings; test default input, startup release, 59/60-second boundary, device unplug/change, missed key-up, permissions revoked, Escape, busy holds, sleep/lock/logout and stale completion.
- [ ] Run the ten-attempt matrix for TextEdit, Terminal/Claude Code, VS Code, Chrome textarea/contenteditable and Slack drafts as described in COMPATIBILITY. Use disposable/inert text, no submission. Validate exact insertion once, selection, Unicode, rich context, focus/caret invalidation, secure/read-only refusal, ambiguous writes, delayed consumers, concurrent clipboard copies and orderly quit. Add validated catalog entries only after evidence passes.
- [ ] Resolve D008's public-API clipboard limitation or explicitly retain the Recovery-only restriction. This is an OS/API limitation, not a missing macOS privacy grant; granting more permissions alone does not fix it.
- [ ] Visually review onboarding/status/Recovery, keyboard navigation, contrast and VoiceOver with an available desktop UI connection. Native UI tool failure prevented these checks.
- [ ] If desired, explicitly test launch-at-login registration, approval, disablement and a real login cycle from the stable install. It was left off; no login registration was performed by the agent.
- [ ] Validate on macOS14 hardware/runtime and repeat any target-version-dependent checks there. Perform cold app-to-Ready and a five-minute **Ready** idle/no-microphone sample; the existing permission-free idle measurement is separate.

No routine implementation approval is pending. All remaining check results must update ACCEPTANCE with evidence; do not call this M4 accepted until the blocked gates pass.

## M5 readiness only — not begun

Owner must separately authorize M5 and choose public repository destination, visibility, licence/copyright and approved contents. Before publication, audit tracked files/history for private metadata, credentials and weights; review third-party/model notices. Any history rewrite needs an explicit decision. Only then configure a current pinned macOS/Xcode hosted build reusing local scripts, least privileges and no secrets in PR jobs. Optional public binaries require a separate authorization and Developer ID/notarisation credentials; do not weaken Gatekeeper or present this ad-hoc build as a notarised release.
