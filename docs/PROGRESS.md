# Progress

Scope: PRD v2 M0–M4, sequential checkpoints. Started 2026-09-23.

## Current checkpoint: M2 hardening, then M3
- Complete PRD read; repository initially contains only PRD, preserved.
- Native environment: arm64, macOS 26.6 (25G72), Xcode 27.0 (27A266a), Swift 6.4, SDK 27.0. Chip/RAM collection in progress.
- Local M0/M1 commits exist; no remote. Pinned source/models available in ignored artifacts.
- Restart instruction received; resumed from actual state without deleting work. Latest additional lazy-provider test exposed same-process framework materialization and implicit translated flavors; resolving with cross-process fixture and declared-type filtering. Benchmark has not run yet; earlier launch attempts failed compilation during this work.

## Plan / next step
1. M0: pin/review WhisperKit and model/tokenizer assets; Xcode app + testable modules, scripts, real fixture and cold offline engine validation; compile early.
2. M1: permission onboarding, hold gesture, bounded audio, serialized cancellation and deadlines, guarded clipboard insertion.
3. M2: validated target adapters, selected-text AX path, full clipboard preservation, transient recovery, adversarial tests.
4. M3: settings, rebinding/language, verified download/import/delete/switch, truthful login status; comparative model measurements.
5. M4: harden, run full feasible gates, Release app, evidence and decision review/human checklist.

## Verification / blockers
- Xcode/Swift present. Sandboxed shell cannot reach network or initialize .git; authorized escalation used for public source fetch/local Git.
- macOS 14 runtime not available here; minimum-OS execution will remain BLOCKED without another runtime.
- Microphone/Accessibility/event-posting status not yet measured. No consented live speech session provided.

## M0 checkpoint — implementation and feasible gates complete
- Created Xcode app target/shared scheme, testable Swift modules, stable scripts, root guidance and lockfiles.
- Chip/RAM: Apple M5 Pro / 48 GiB. Native Debug build passed, local ad-hoc signature verified.
- Eight unit tests pass, including true 44.1/48 kHz stereo conversion. Fixed caught emoji-joiner sanitization defect.
- Real pinned WhisperKit/base inference passed (11 s public JFK fixture, 5.874 s initial preparation, 0.860 s decode). Cold network-denied fresh-process reload executed; raw evidence in artifacts/offline-cold.*.
- Permission preflight: microphone notDetermined (0), AX false, listening false, posting false. Do not retry unchanged privacy blocker or grant on behalf of owner.
- Model pins downloaded and hashed, manifest committed; no weights in Git.
- Next: M1 native services/coordinator and minimal permission UI. Continue immediately; missing real microphone/insertion grants stay BLOCKED.

## M1 checkpoint — implementation complete; device gates blocked
- Native AVAudioEngine capture (preallocated bounded PCM), proper converter, live-buffer indicator, serialized state IDs, hold matcher, modifier wait, Escape, route/sleep/lock cancellation and inference deadline implemented.
- Minimal onboarding/settings UI remains usable without grants; no automatic prompts. Recovery and model controls share groundwork needed by following milestones.
- Native Debug build passes; 15 unit tests pass including stale completion/100 rapid sessions, modifier order, Escape ownership, sanitization and clipboard ownership rules.
- Live TextEdit/Terminal 10-attempt gates and warm release-to-insertion latency BLOCKED by missing microphone/AX/post grants and absent consented speech. Production adapters remain unvalidated, not falsely enabled.
- UI inspection attempted once using native computer-use API; failed `Sky Computer Use native pipe closed before response`. App launch verified by process only; visual/VoiceOver review BLOCKED.
- Next: M2 test real named-pasteboard transactions, strengthen target/recovery paths, document compatibility protocol, then M3 lifecycle/corpus.

## M2 checkpoint
- Safe selected-text AX service and scoped target identities/selection metadata implemented; never reads surrounding text. AX observer plus user input events invalidate focus/caret edits; no reactivation.
- Clipboard service now testable independently and exercised against actual named NSPasteboards. 20 tests pass (five production pasteboard tests included). Newer copies preserved; all eager formats retained; empty/multi-item/rich/image/oversized/promised cases covered. General clipboard untouched by tests.
- One transient five-minute Recovery result retained for unconfirmed attempts; explicit Copy replaces clipboard; no retry path.
- Compatibility protocol and candidate catalog documented. Actual cross-app compatibility stays BLOCKED by grants; tested helper policies are not target acceptance.
- Additional hardening in progress: consult public Pasteboard flavor flags to reject lazy providers before materialization.
- Next checkpoint: M3 model lifecycle verification, settings/rebind/login review, real comparative synthetic corpus benchmarks.

## M2 final feasible checkpoint (after restart)
- 27 tests pass, including a separate real lazy-provider owner process. See D008: public metadata cannot prove foreign AppKit data eagerness. Unknown nonempty clipboard now refuses without materializing or mutating it; eager-owned rich/multi-item restoration is verified.
- General clipboard happy-path gate remains BLOCKED by OS/API proof limitation; all target happy paths remain BLOCKED by privacy grants. No falsely validated adapters.
- Model atomic import/corruption/cancellation/symlink/space tests also pass as M3 groundwork.
- Next/current: M3 Release base/small benchmark and actual model downloader/switch integration, then M4 full review and final evidence.

## M3 checkpoint — feasible implementation/measurements complete
- Settings cover rebind/test, Auto/en/fr, catalog download/import/delete, atomic install/cancel, engine switch with rollback and persisted schema, SMAppService actual status (off unless user registers).
- Production HTTPS downloader completed verified base install; real offline lifecycle check passed missing-tokenizer refusal/working engine preservation, import, switches in both directions, inactive delete; zero URL attempts.
- Fixed 55-clip synthetic corpus and 30 warm cases evaluated on real Release engine; raw evidence committed. Small passes WER/technical/no-speech gates; base fails terms 50%. Chose small default (D009), kept saved selections.
- Both models completed 100 sessions, retained growth below 1%, no crash, 59/60 s file boundaries passed. Live/Ready/insertion timing remains BLOCKED.
- Next: M4 final defect/adversarial review, unit/integration/build scripts, local Release install and complete handoff/evidence. Do not begin M5.
