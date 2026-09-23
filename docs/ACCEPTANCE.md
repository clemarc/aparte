# Acceptance ledger

PASS requires actual evidence; BLOCKED means missing external prerequisite; FAIL includes not-yet-implemented requirements. Mock/unit evidence never substitutes for OS acceptance. M4 is not accepted.

| Gate | Status | Evidence / next requirement |
|---|---|---|
| PRD read and environment inspected | PASS | PRD sections 1–12/appendices read; macOS 26.6 arm64, Xcode 27/SDK 27, Swift 6.4 |
| M0 native app/build/unit | FAIL | Implementation in progress |
| M0 exact engine/assets, real inference, cold offline reload | FAIL | Upstream inspection in progress |
| M1 capture/gesture/cancel/guard and 10 dictations each TextEdit/Terminal | FAIL | Not yet implemented |
| M2 safe AX/clipboard/recovery and compatibility matrix | FAIL | Not yet implemented |
| M3 settings/model lifecycle and comparative benchmark | FAIL | Not yet implemented |
| M4 full performance/quality/adversarial checks and Release | FAIL | Not yet implemented |
| macOS 14 runtime | BLOCKED | Host is macOS 26.6; no macOS 14 runtime/device supplied |
| Live speech capture quality | BLOCKED | Requires owner-consented 10 live dictations and microphone privacy grant |
| M5 excluded | PASS | No remote/CI/publication/release credentials |

## M0 evidence update
| Requirement | Status | Evidence |
|---|---|---|
| Xcode native arm64 macOS 14 target; menu bar shell | PASS | Debug xcodebuild and codesign verification, launch via open (process checked) |
| Unit entry point without privacy/model requirements | PASS | 8 XCTest tests, zero failures; artifacts/unit-tests.log |
| Exact dependency/model pins | PASS | Package.resolved and Resources/Models.json; downloaded and SHA-256 hashed base/small |
| Real WhisperKit fixture | PASS | artifacts/integration.log; public JFK 11 s, decode 0.860 s |
| Cold offline load | PASS | Process network-denied run, artifacts/offline-cold.json; source audit local tokenizer loader |
| Live OS permissions | BLOCKED | CLI preflight microphone=0, AX/listen/post=false; owner UI action needed |

## M1 evidence update
| Requirement | Status | Evidence |
|---|---|---|
| Native capture/coordinator/hotkey build | PASS | artifacts/build-Debug.log, native app links AVFoundation/ApplicationServices |
| Deterministic startup/release/cancel/stale/busy/gesture policies | PASS | 15 unit tests; actual audio tap timing is a separate blocked check |
| Minimal denied/unrequested permission path | PASS | Public preflight APIs report ungranted; settings compile; no automatic requests |
| Permission UI visual/revoke/restart behavior | BLOCKED | Native UI automation connection closed; owner privacy grants absent |
| 10 live dictations each TextEdit/Terminal; no submission; warm latency | BLOCKED | Microphone/Accessibility/posting grants and live speaker needed |
| Capture start p95 / physical device-route tests | BLOCKED | Actual microphone permission and hardware interaction needed |
