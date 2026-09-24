# Aparté progress — M0–M4

## Current status

**0.4.3 launch visibility fix installed and running.** Owner reported app did not start. Installed 0.4.2 process was already running, signature valid, and a one-second sample showed a normal AppKit main event loop; no Aparté crash report was found. Source opened Settings only on first-ever onboarding and lacked a reopen handler. D014 makes ordinary launch/reopen show Settings, restores minimized windows, and keeps login/service startup quiet. Release build and all 36 regressions passed. Old instance terminated orderly through NSRunningApplication; 0.4.3 build 4 installed with verified ad-hoc signature, opened through Launch Services and observed running 21 seconds later. Evidence: `docs/evidence/startup-fix.json`.

**Next step:** owner verifies the Settings window is visible and continues actual insertion checks. No further implementation approval needed. Clipboard D013 remains included. Visual/reopen/minimize/login and target checks remain BLOCKED by the existing desktop-tool failure; process survival is not visual evidence. M4 is not accepted; no M5 work.

## Previous M4 checkpoint (historical evidence)

Implementation through feasible M0–M4 scope is complete; validation pending. **M4 is not accepted.** No M5 work was started. See ACCEPTANCE for scoped PASS/FAIL/BLOCKED results and HANDOFF for the single human-action checklist and ordered decision review.

Final source checks: 29 tests pass; native Release build passes and is installed at `~/Applications/Aparte.app` with a verified local ad-hoc signature. Public small assets are verified and installed in the managed model directory. No permissions were granted, live audio collected, or security settings changed. An earlier installed candidate launched as a process; desktop visual access failed. Reopen the app to load the final rebuilt bundle.

Current next step: human/external validation in HANDOFF only. Final-source clean archive Debug/unit reproduction and real small integration both passed; evidence/verification.json records source c7fe4bd and installed binary digest. All feasible implementation and verification is complete. Stop at this M4 handoff; do not repeat unchanged external blockers or begin M5.

## Completed checkpoints

- **M0 (f39a371):** Read complete authoritative PRD; measured Apple M5 Pro / 48 GiB / macOS26.6 / Xcode27 / Swift6.4 / SDK27. Created native app/shared scheme, package modules and working scripts. Pinned OSS WhisperKit1.1.0, base/small asset revisions and per-file hashes. Debug and eight tests passed. Real base inference and cold network-denied reload passed before settings expansion. CLI permission preflight: microphone notDetermined, AX/listen/post false.
- **M1 (956d031):** Native bounded in-memory AVAudioEngine capture, proper conversion, hold gesture, first-buffer indicator, cancellation/deadlines, target guard, modifier wait, permission onboarding. Debug and 15 tests passed. Ten-attempt/live-latency gates blocked by grants and consented speaker session; continued independent work.
- **M2 (4b160ad):** Selected-text-only AX path, scoped compatibility adapters, context/selection invalidation, clipboard ownership/restoration and one transient Recovery result. Actual named-pasteboard and separate lazy-owner tests exposed D008: unknown nonempty clipboard cannot safely be proven eager using public metadata; refuse without data access. Actual target catalog remains empty pending real validation. No mock used to enable adapters.
- **M3 (9607b7a):** Settings/rebinding/language, verified HTTPS download/import/delete/atomic replacement/cancel, one-engine switching and rollback, truthful off-by-default SMAppService. Frozen 55-clip corpus, 30 warm timings and 100-session memory runs on both real Release engines. Small passes unchanged quality gates; base fails technical terms (50%), retained in evidence. Small selected as default (D009).
- **M4 candidate (18c64e1 and final hardening):** Release built, signed locally, installed and launched. Real network-denied lifecycle now includes missing-tokenizer refusal, switches both directions, cancellation/retry and post-hash Core ML load failure with successful prior-engine rollback. Real download cancellation preserves installed files and removes staging. Idle 300 s sample averaged 0.0533% CPU; not accepted as Ready evidence. Final review fixed Escape repeat ownership, overlapping audio drains, HTTP downgrade refusal, format-control sanitization, error-state persistence, idle permission refresh, visible Busy status and refusal to read a newer lazy clipboard owner during restoration. 29 regression tests pass.

## Verification and evidence

- Commands: `./scripts/build-local.sh --configuration Debug|Release`; `./scripts/test-local.sh --suite unit|integration`; `./scripts/benchmark-local.sh --manifest Tests/Fixtures/manifest.json`.
- Clean archive of 18c64e1 resolved exact dependencies, built Debug and passed 27 then-existing tests without model assets. Final-source archive c7fe4bd likewise resolved, built Debug and passed all 29 tests with no model assets; actual small integration separately passed (3 s fixture, 0.332 s decode, zero observed URL requests).
- Missing-model/fixture integration and benchmark checks both return 2 with explicit BLOCKED messages. Restricted sandbox hardware inspection now also returns 2 with the diagnostic location, instead of silently exiting.
- Real fixture/model/benchmark/lifecycle/cancel/idle results: `docs/evidence/`. Large local logs, generated audio and weights remain ignored under `artifacts/`.
- Source/history audit found no tracked weights/audio/build artifacts, private absolute paths, credential-pattern matches, remotes or hosted workflows. This is a scoped pattern audit, not proof against all possible secret formats.
- Per-command synthetic local Git author and disabled commit signing avoid owner identity or credentials; no global configuration changed (D005).

## External blockers — do not repeatedly retry unchanged prerequisites

1. Owner reports Microphone/Accessibility granted and setup tests working. Formal live capture/shortcut/cancellation/revocation/device/sleep/lock gates and measured end-to-end latency still need recorded evidence; no current missing grant is inferred.
2. Trusted desktop target interaction and exact-version ten-attempt matrix for TextEdit, Terminal/Claude Code, VS Code, Chrome and Slack. All adapters remain unvalidated.
3. D013 supersedes D008's operational restriction with owner-approved bounded materialization. Real clipboard-to-target consumption/one-second restoration still requires the live matrix.
4. Native UI connection failed closed, then timeout after restart; visual/VoiceOver/onboarding review blocked.
5. macOS14 runtime unavailable; compile target does not establish minimum-OS execution.
6. User-directed login-item approval/login cycle and actual Ready cold-start/five-minute resource sample remain pending.

On resume inspect this file, DECISIONS, ACCEPTANCE and actual Git/artifact state. Continue the next unfinished check without repeating completed milestones. HANDOFF contains the consolidated actions; do not create new features to occupy remaining time.
