# Progress

Scope: PRD v2 M0–M4, sequential checkpoints. Started 2026-09-23.

## Current checkpoint: M0
- Complete PRD read; repository initially contains only PRD, preserved.
- Native environment: arm64, macOS 26.6 (25G72), Xcode 27.0 (27A266a), Swift 6.4, SDK 27.0. Chip/RAM collection in progress.
- Local Git initialized; no remote. Public upstream source fetch in progress.

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
