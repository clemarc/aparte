# Acceptance ledger — M0–M4

**M4 NOT ACCEPTED.** Feasible implementation and local checks are complete; final reproducibility evidence is recorded in PROGRESS and evidence/verification.json. Real-device/target gates are blocked; owner-approved D013 replaces D008's operational clipboard restriction in 0.4.2. A PASS below applies only to its described evidence scope; source review or a unit test is not a pass for real OS behavior. Base's technical-term failure is retained; the selected small model passes the frozen synthetic quality gates.

Environment: Apple M5 Pro, 48 GiB, arm64, macOS 26.6 (25G72), Xcode 27.0 (27A266a), Swift 6.4, SDK 27.0. Target is arm64 macOS 14+. Initial-build CLI preflight: microphone notDetermined; Accessibility/listening/posting false. During 0.4.1 testing the owner reports Microphone and Accessibility granted; the running app state remains unobserved because native inspection fails. Original absent-grant rows below describe the initial evidence, not a new claim that the owner has not granted access. No grants or security settings were changed. Native UI inspection failed (closed pipe; after restart, timeoutReached).

## Foundation and scope

| ID / requirement | Status | Actual evidence |
|---|---|---|
| §1 complete PRD/environment before implementation | PASS | Full PRD read; native toolchain/chip/RAM recorded before app work |
| §1 local Git, preservation, sequential milestones | PASS | Original PRD preserved; local M0/M1/M2/M3/M4 commits; progress/decisions maintained after restart |
| §1 no remote/CI/publication/credentials/M5 | PASS | No Git remote/workflow; ad-hoc local signature only; repository/history audit in final evidence |
| §1.3 source, documentation, evidence bundle | PASS | README and all required docs, frozen fixtures, raw synthetic benchmark evidence |
| §2 native menu bar, Swift/AppKit/SwiftUI, arm64 macOS14 | PASS | Xcode target/shared scheme; Debug and Release builds; arm64 binary and plist target 14.0 |
| §2 normal operation no Dock icon | PASS | LSUIElement/accessory policy; visual verification separately BLOCKED |
| §2 hold-only/default chord/language scope/no deferred features | PASS | Production coordinator, configurable Control–Option–Space, Auto/en/fr; source inspection |
| §2 stable name/bundle/install path | PASS | Aparte.app, display Aparté, dev.aparte.Aparte; local ~/Applications install/signature verified |
| §3 pinned OSS WhisperKit only | PASS | Exact revision/lockfiles; WhisperKit/ArgmaxCore only app engine, no Pro SDK |
| §3 testable modules and reproducible entry points | PASS | build/test/benchmark scripts; generated project committed; clean final-source Debug build and 29 tests, actual small integration and Release runs (evidence/verification.json) |
| §3 scripts fail rather than skip | PASS | Missing prereq exits 2; actual compile/test failures and base benchmark gate returned nonzero during development |
| §3 local ad-hoc signing | PASS | codesign verify strict/deep; Signature=adhoc, no TeamIdentifier |
| M0 real production engine spike | PASS | Public 11 s JFK fixture actual transcription, M0 timings recorded |
| M0 cold offline reload | PASS | Fresh process under network denial; actual text result and preparation/decode timings |
| macOS14 minimum runtime coverage | BLOCKED | No macOS14 device/runtime supplied; deployment target is not runtime evidence |

## Session, capture and ASR

| Requirement | Status | Actual evidence |
|---|---|---|
| §4 explicit states, IDs, no stale completion, busy serialization | PASS | SessionMachine tests including visible failure until explicit retry; real engine actor holds lease across await; Coordinator IDs/operation guards |
| §4 release during startup; no late Recording | PASS | Reducer tests; cancellable capture ticket and serial lifecycle queue; physical timing BLOCKED |
| §4 key repeat, either modifier release, matched key-up after cancel/rebind | PASS | Gesture tests, including Escape auto-repeat after cancel; event-tap delivery BLOCKED |
| §4 unrelated input passes; own paste ignored | PASS | Matcher and marker tests/source; native global tap check BLOCKED |
| §4 stop/freeze once before decode; max60 discard; no queued holds | PASS | Bounded capture source review; serialized drains; real 59/60 file boundaries; live capture BLOCKED |
| §4 Escape, stale inference, rapid next session | PASS | 100-session deterministic tests plus real inference cancellation/retry evidence (final lifecycle report) |
| §4 30s inference deadline, no second engine until unwind | PASS | Deadline invalidates ID; callback cancels; actor busy lease; reducer cancellation tests (a real 30s timeout was not induced) |
| §4 sleep/lock/logout/tap-disable/device-change | BLOCKED | Handlers implemented and source-reviewed; actual OS/device exercise needs desktop/grants/hardware |
| §4 target invalidation on focus/caret/type/click | BLOCKED | AX observer/selection/process guard + interaction metadata implemented; live focus races not tested |
| §4 modifiers clear ≤2s; no synthetic releases | PASS | Bounded wait and guard before mutation; generated events are only Cmd-V down/up; physical modifier timing BLOCKED |
| AUDIO-01 true 44.1/48k stereo→mono16k | PASS | AVAudioConverter input-block path; duration and channel amplitude tests |
| AUDIO-02 actual microphone lifecycle/start latency/default route | BLOCKED | No microphone grant/live consent; AVAudioEngine path compiled, no tap exists while idle by construction |
| ASR-01 local verify/prewarm before model readiness, one engine | PASS | Real loads/switches, imported installed files, no first-hold install; memory-pressure handler implemented |
| ASR-01 memory pressure unload in UI | BLOCKED | Source implemented; actual OS pressure notification not induced |
| ASR-02 decode once / energy / no-speech / repetition | PASS | Real 55-clip corpus; 10/10 rejects; quiet WER; documented thresholds D007; no incremental insertion |
| ASR-03 Unicode/accents/no special tokens/control or newlines | PASS | Sanitization and emoji tests; frozen bilingual outputs; .transcribe + skipSpecialTokens/withoutTimestamps |
| ASR-03 no transcript/token/audio logging in production | PASS | Source/dependency audit, logs disabled, benchmark stderr empty; fixture CLI alone emits synthetic results explicitly |

## Target, clipboard and recovery

| Requirement | Status | Actual evidence |
|---|---|---|
| INS-01 original process/window/field/selection metadata; no surrounding text/refocus | PASS | TargetService implementation inspection; process launchDate and PID, CFEqual elements, selection range only |
| INS-01 actual cross-app context race protection | BLOCKED | Requires trusted Accessibility and desktop session/target interaction |
| INS-02 secure/read-only/unknown refusal, secure input public API | BLOCKED | Public IsSecureEventInputEnabled/AX checks compiled; secure/password control behavior requires device exercise |
| INS-03 safe selected-text-only mutation / no whole-field write | PASS | Only kAXSelectedTextAttribute is written; no AXValue/Select All calls in production |
| INS-03 actual selection/mid-paragraph/non-BMP/rich context correctness | BLOCKED | No trusted AX; API return alone explicitly not accepted as evidence |
| INS-04 no retry after ambiguous AX/dispatched paste | PASS | Single mutation branch, no fallback after call, uncertain Recovery retained |
| INS-05 terminal single-line/no Return/no execution | PASS | Sanitizer tests; only keycode9 Cmd-V synthesized; actual terminal behavior BLOCKED |
| Clipboard target/modifier revalidation before touch and dispatch | PASS | Coordinator guards around awaited snapshot and mutation; real target integration BLOCKED |
| Clipboard 8MiB/500ms bounded snapshot/ownership | PASS | Production cap, bounded continuation + one in-flight worker; cap and real named-board tests |
| Clipboard foreign provider policy (owner-amended D013) | PASS | Fast real provider materializes/restores; slow provider times out without mutation or late write; explicit promise formats refuse. Original blanket lazy-refusal criterion superseded by owner authorization |
| Clipboard externally-owned ordinary/rich/image snapshot/restoration | PASS | Separate owner process supplies text/RTF/PNG/multi-item data; original bytes plus additional AppKit encodings preserved/restored after owner exits. Actual target paste consumption remains BLOCKED |
| Clipboard full eager-owned multi-item/rich/image/empty restoration | PASS | Real named-pasteboard production service tests; all representations retained; user's clipboard untouched |
| Clipboard concurrent new copy preserved / snapshot-to-write race | PASS | Real isolated-board tests + marker/content/changeCount checks; newer foreign lazy owner is not read during restoration |
| Clipboard one-second delay and slow/custom target consumption | BLOCKED | Restoration task implemented; exact target consumption/delayed paste requires real compatibility tests |
| Clipboard cancel/orderly quit / crash boundaries | BLOCKED | Conditional restore code present; actual app quit-during-paste needs grants. Crash recovery explicitly not promised |
| Recovery one result / 5min / Copy/View/Discard / expiry | PASS | Implemented observable memory-only result, timer, lock/new-session clearing, explicit-copy tests; visual panel/lock exercise BLOCKED |
| Five target apps ×10 exact happy/safety attempts | BLOCKED | Versions recorded in evidence; five adapters operational under D013, none falsely marked validated; protocol in COMPATIBILITY |

## Settings, models and privacy

| Requirement | Status | Actual evidence |
|---|---|---|
| PERM-01 usage string and capability-specific onboarding | PASS | Info.plist and settings; no automatic prompt; Input Monitoring guidance only after tap failure |
| PERM-01 actual grant/deny/revoke/restart recovery | BLOCKED | Owner grants and real desktop interaction required; no TCC bypass attempted |
| SET-01 shortcut/language/model/settings/diagnostics schema | PASS | Persisted schema with safe defaults; invalid shortcut tests; user-visible controls built |
| SET-01 actual binding conflict/keyboard layout behavior | BLOCKED | Event-tap grant and physical test needed; physical US key labels disclosed |
| SET-02 SMAppService truthful status/off by default | PASS | No registration outside user-toggle handler; actual status mapping, stable install |
| SET-02 enable/disable/login restart validation | BLOCKED | User-directed Login Items approval and actual login cycle required; not toggled by agent |
| MODEL-01 curated verified base/small; measured sizes | PASS | Immutable catalog/actual bytes; both models run on real engine; optional turbo not added |
| MODEL-02 hashes/config/tokenizers/revision/licences | PASS | Per-file manifest; local SHA-256; third-party source/licence provenance documented |
| MODEL-03 explicit HTTPS/progress/cancel/space/atomic install | PASS | Production downloader success; atomic import/replace/corrupt/cancel/symlink/space unit checks; real cancelled download final report |
| MODEL-04 offline import/delete/one-engine switch and rollback | PASS | Actual offline lifecycle evidence; missing-tokenizer switch preserves current working engine; two-way real switch and inactive deletion |
| MODEL-04 load-failure rollback after unload | PASS | Real Core ML rejected a deliberately invalid model.mil under a derived test-only matching manifest; the previous small engine reloaded and transcribed successfully (model-lifecycle.json) |
| §8 no app-originated ASR network/cold offline/tokenizer fallback | PASS | Offline base/small full runs and lifecycle; 0 intercepted requests; strict local parser source audit |
| §8 no persistent audio/transcript/snapshot/private fixtures | PASS | App write-path audit; only preferences/models persisted; committed corpus/evidence are synthetic; ignore/history audit |
| §8 honest clipboard/destination/OS memory/privacy limitations | PASS | Onboarding, README, PRIVACY and D008; no “text never leaves” promise |

## M4 gates and adversarial coverage

| Gate/case group | Status | Evidence / exact blocker |
|---|---|---|
| Quality: EN≤20%, FR≤25%, terms≥80%, no-speech10/10 | PASS | Selected small: 0.64%, 4.87%, 83.33%, 10/10; fixed corpus and raw evidence |
| Base quality (retained comparison) | FAIL | Technical terms 50%; default changed to quality-passing small, not threshold relaxed |
| 30 warm utterances by duration | PASS | Two real Release runs, 10 each group, raw decode timings and normalization policy |
| Shortcut→capture≤300ms / release→dispatch2s/5s / visible text | BLOCKED | Microphone/AX/posting/desktop targets absent; decode times cannot substitute |
| Ten consented live dictations | BLOCKED | No live speaker session or microphone grant; no recording collected |
| 59s decode /60s refusal | PASS | Real engine file boundary results; live timer boundary remains BLOCKED |
| 100-session memory/no crash | PASS | Base +0.717%, small +0.035% retained RSS; no observed crash/queue growth in sequential engine exercise |
| Fresh model prep/cold load/peak memory/bytes | PASS | BENCHMARKS and raw prepare/memory evidence; actual cold app-to-Ready requires grants |
| Five-minute Ready CPU<1% and no mic | BLOCKED | Permission-free idle process sampled separately; Ready not established |
| Repeats/startup/order/tap-disable/missed-up/conflict | BLOCKED | Deterministic gesture/startup tests PASS; real event tap disable/conflict/missed-up watchdog need grants |
| Escape/cancellation/stale/sleep/lock | BLOCKED | Reducer and real engine cancellation PASS; actual sleep/lock and insertion-preparation timing need desktop |
| App/window/field/caret/type/exit/secure/no-editable | BLOCKED | Implemented conservative guards; target matrix not executed |
| Ambiguous AX/delayed paste/concurrent copy/rich/lazy/quit/crash | BLOCKED | Real clipboard ownership/materialization/timeout tests PASS; AX/target/quit tests blocked |
| Stereo/rates/silence/quiet/59/60/unplug/change | BLOCKED | File conversion and synthetic audio tests PASS; live route/unplug/capture boundaries need device |
| Interrupted/corrupt/space/offline-tokenizer/bad selection/switch/revoke | BLOCKED | Store/engine tests PASS; actual permission revocation and visual model-failure UI remain unexercised; real post-verification Core ML rollback passed |
| Local Release app | PASS | Native Release build, ad-hoc signature verified, stable install path and public small assets present |
| Native visual/accessibility onboarding and indicators | BLOCKED | Computer-use connection closed/timeout; code-based accessible labels are not visual/VoiceOver evidence |
| M0–M4 full acceptance | BLOCKED | Above device/runtime/target/paste-consumption gates; do not label M4 accepted |

## 0.4.1 owner-testing follow-up

| Requirement / reported problem | Status | Evidence |
|---|---|---|
| Readiness/recheck explains exact missing step and retries actual tap/model | PASS | Capability-specific production checks; four new policy regressions included in 33 passing tests. Posting checked only on paste; no permission bypass |
| Fix owner's specific stuck setup instance | BLOCKED | Code failure paths fixed; owner reports grants but native inspection of running process failed closed. Requires reopen/recheck in installed 0.4.1 |
| Shortcut recorder previews modifiers/chord and avoids global consumption | PASS | Native first responder with pre-menu local capture; global matcher bypass only for new gestures while rebinding; key-up preservation regression passes; Debug/Release compile |
| Actual shortcut entry/key delivery on owner's desktop | BLOCKED | Native tool transport failed; physical retest required |
| Start/Stop real microphone test and visible local transcript | PASS | Shared production capture/inference path, 60s cancel/30s deadline and stale-ID guards; explicit controls compiled; no mock output |
| End-to-end owned text box with focus/selection protection | PASS | Production native NSTextView selected-range insertion; revision/UTF-16/focus policy regressions pass. In-app route labelled separately from global tap |
| Live microphone and visual UI behavior of new tests | BLOCKED | No recording collected by agent; owner must use the new controls. File inference/unit success is not live evidence |
| Temporary test results clear on close/lock/quit/expiry | PASS | Shared Recovery slot plus explicitly transient test editor; cancellation and cleanup paths source-reviewed. Actual window/lock exercise remains BLOCKED |

Evidence for this patch is `docs/evidence/setup-fix.json`; the earlier verification.json remains the previous source checkpoint. M4 acceptance remains pending, and no external adapter was enabled by these diagnostics.


## 0.4.2 owner-approved clipboard/insertion fix

| Requirement / reported problem | Status | Evidence |
|---|---|---|
| Supported apps no longer all disabled by empty validated catalog | PASS | Shipping catalog has five enabled adapters; real validation metadata remains empty. Two catalog regressions verify roles/unknown apps/schema/methods/version scopes |
| Preserve ordinary clipboard from other apps | PASS | Real separate-process fast lazy and rich/image/multi-item cases, plus foreign ordinary text; exact bytes and complete round-trip snapshot checked |
| 500 ms / 8 MiB refusal and late-read safety | PASS | 1.5-second provider returns timeout under 1.2-second test tolerance, board unchanged; second read refused while busy, newer copy survives late unwind. Oversize and promise errors checked explicitly |
| Newer lazy clipboard owner untouched on restoration | PASS | Separate provider is not invoked after ownership changes |
| Recovery explains refusal versus attempted paste | PASS | Coordinator supplies specific reasons; panel displays them; no automatic retry after AX or paste attempt; native UI compile |
| Real target visible insertion, consumption and preservation | BLOCKED | Native desktop helper crash/closed pipe; isolated pasteboards and catalog checks do not substitute for the target matrix |
| Release 0.4.2, build 3 | PASS | Native Release build succeeded; install/signature evidence in clipboard-fix.json |

Owner reports the Setup tests work; no private recording or transcript was collected. The earlier setup-fix.json and verification.json remain historical checkpoints. Current patch evidence is `docs/evidence/clipboard-fix.json`. Full M4 acceptance remains pending.


## 0.4.3 explicit launch/reopen follow-up

| Requirement / reported problem | Status | Evidence |
|---|---|---|
| Distinguish process launch failure from invisible menu-bar app | PASS | Installed 0.4.2 already running; signature valid; native one-second sample main thread waits normally in AppKit event loop; no matching crash report found |
| Explicit Open reveals Settings after prior onboarding | PASS | AppDelegate ordinary-launch and reopen handlers implemented; retained window deminiaturized; Release compilation passed. Actual visual behavior tracked separately |
| Preserve quiet login/service startup and no normal Dock icon | PASS | Public Apple event markers guard initial window; existing accessory/LSUIElement behavior preserved. Actual login cycle remains BLOCKED |
| Release 0.4.3 build 4 installs and launches | PASS | Orderly quit of old process; install strict/deep signature verification; Launch Services open succeeded; installed process alive after 21 seconds |
| Existing regression suite | PASS | 36 tests, zero failures; no tests removed; clipboard change retained |
| User-visible window, minimize/reopen and login-cycle validation | BLOCKED | Existing native desktop-tool crash; process check and source inspection do not establish visual correctness |

See `docs/evidence/startup-fix.json`. No microphone input, permission changes or private transcript collection occurred during this check.
