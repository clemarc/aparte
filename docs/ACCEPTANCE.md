# Acceptance ledger — M0–M4

**M4 IMPLEMENTATION CLOSED on 25 September 2026; FORMAL ACCEPTANCE PENDING (D026).** Feasible implementation and local checks are complete; final reproducibility evidence is recorded in PROGRESS and the evidence bundle. Real-device/target gates remain BLOCKED; the owner requested milestone closure, not a waiver of acceptance criteria. A PASS below applies only to its described evidence scope; source review or a unit test is not a pass for real OS behavior. Base's technical-term failure is retained; the selected small model passes the frozen synthetic quality gates.

Environment: Apple M5 Pro, 48 GiB, arm64, macOS 26.6 (25G72), Xcode 27.0 (27A266a), Swift 6.4, SDK 27.0. Target is arm64 macOS 14+. Initial-build CLI preflight: microphone notDetermined; Accessibility/listening/posting false. During 0.4.1 testing the owner reports Microphone and Accessibility granted; the running app state remains unobserved because native inspection fails. Original absent-grant rows below describe the initial evidence, not a new claim that the owner has not granted access. No grants or security settings were changed. Native UI inspection failed (closed pipe; after restart, timeoutReached).

## Foundation and scope

| ID / requirement | Status | Actual evidence |
|---|---|---|
| §1 complete PRD/environment before implementation | PASS | Full PRD read; native toolchain/chip/RAM recorded before app work |
| §1 local Git, preservation, sequential milestones | PASS | Original PRD preserved; local M0/M1/M2/M3/M4 commits; progress/decisions maintained after restart |
| §1 no remote/CI/publication/release credentials/M5 | PASS | No Git remote/workflow; D016's dedicated local-only development signing identity, no release credentials; repository/history audit in final evidence |
| §1.3 source, documentation, evidence bundle | PASS | README and all required docs, frozen fixtures, raw synthetic benchmark evidence |
| §2 native menu bar, Swift/AppKit/SwiftUI, arm64 macOS14 | PASS | Xcode target/shared scheme; Debug and Release builds; arm64 binary and plist target 14.0 |
| §2 normal operation no Dock icon | PASS | LSUIElement/accessory policy; visual verification separately BLOCKED |
| §2 hold-only/default chord/language scope/no deferred features | PASS | Production coordinator, configurable Control–Option–Space, Auto/en/fr; source inspection |
| §2 stable name/bundle/install path | PASS | Aparte.app, display Aparté, dev.aparte.Aparte; local ~/Applications install/signature verified |
| §3 pinned OSS WhisperKit only | PASS | Exact revision/lockfiles; WhisperKit/ArgmaxCore only app engine, no Pro SDK |
| §3 testable modules and reproducible entry points | PASS | build/test/benchmark scripts; generated project committed; clean final-source Debug build and 29 tests, actual small integration and Release runs (evidence/verification.json) |
| §3 scripts fail rather than skip | PASS | Missing prereq exits 2; actual compile/test failures and base benchmark gate returned nonzero during development |
| §3 local signing (D016 supersedes ad-hoc) | PASS | Certificate-backed local development signature, strict/deep verification and cross-version designated-requirement continuity; no Developer ID or release credential |
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
| INS-01 original process/window/field/selection metadata; no surrounding text | PASS | TargetService implementation inspection; process launchDate and PID, CFEqual elements, selection range only. D021 now permits guarded refocus after transcription |
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
| Clipboard one-second delay and slow/custom target consumption | BLOCKED | Conditional restoration task remains for normal insertion, but D022 retains Recovery text; exact target consumption/delayed paste requires real compatibility tests |
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
| MODEL-01 curated verified base/small plus owner-authorized medium/turbo; measured sizes | PASS | Four immutable complete model/tokenizer manifests; all four run on real WhisperKit; installed bytes and measured preparation/memory in MODEL-COMPARISON and BENCHMARKS. D023–D024 amend the original medium deferral. |
| MODEL-02 hashes/config/tokenizers/revision/licences | PASS | Per-file manifest; local SHA-256; third-party source/licence provenance documented |
| MODEL-03 explicit HTTPS/progress/cancel/space/atomic install | PASS | Production downloader success; atomic import/replace/corrupt/cancel/symlink/space unit checks; real cancelled download final report |
| MODEL-04 offline import/delete/one-engine switch and rollback | PASS | Actual offline lifecycle evidence; missing-tokenizer switch preserves current working engine; two-way real switch and inactive deletion |
| MODEL-04 load-failure rollback after unload | PASS | Real Core ML rejected a deliberately invalid model.mil under a derived test-only matching manifest; the previous small engine reloaded and transcribed successfully (model-lifecycle.json) |
| §8 no app-originated ASR network/cold offline/tokenizer fallback | PASS | Offline base/small/medium/turbo full runs and lifecycle; 0 intercepted requests; strict local parser source audit |
| §8 no persistent audio/transcript/snapshot/private fixtures | PASS | App write-path audit; only preferences/models persisted; committed corpus/evidence are synthetic; ignore/history audit |
| §8 honest clipboard/destination/OS memory/privacy limitations | PASS | Onboarding, README, PRIVACY and D008; no “text never leaves” promise |

## M4 gates and adversarial coverage

| Gate/case group | Status | Evidence / exact blocker |
|---|---|---|
| Quality: EN≤20%, FR≤25%, terms≥80%, no-speech10/10 | PASS | Selected small: 0.64%, 4.87%, 83.33%, 10/10; optional medium 0.43%, 0.85%, 91.67%, 10/10; optional turbo 0.43%, 1.91%, 83.33%, 10/10. Fixed corpus/raw evidence. |
| Base quality (retained comparison) | FAIL | Technical terms 50%; default changed to quality-passing small, not threshold relaxed |
| 30 warm utterances by duration | PASS | Four real Release runs, 10 each duration group, raw decode timings and normalization policy |
| Shortcut→capture≤300ms / release→dispatch2s/5s / visible text | BLOCKED | Microphone/AX/posting/desktop targets absent; decode times cannot substitute |
| Ten consented live dictations | BLOCKED | No live speaker session or microphone grant; no recording collected |
| 59s decode /60s refusal | PASS | Real engine file boundary results; live timer boundary remains BLOCKED |
| 100-session memory/no crash | PASS | Base +0.717%, small +0.035%, medium +0.013%, turbo −0.727% retained RSS; no observed crash/queue growth in sequential engine exercise |
| Fresh model prep/cold load/peak memory/bytes | PASS | BENCHMARKS and raw prepare/memory evidence; actual cold app-to-Ready requires grants |
| Five-minute Ready CPU<1% and no mic | BLOCKED | Permission-free idle process sampled separately; Ready not established |
| Repeats/startup/order/tap-disable/missed-up/conflict | BLOCKED | Deterministic gesture/startup tests PASS; real event tap disable/conflict/missed-up watchdog need grants |
| Escape/cancellation/stale/sleep/lock | BLOCKED | Reducer and real engine cancellation PASS; actual sleep/lock and insertion-preparation timing need desktop |
| App/window/field/caret/type/exit/secure/no-editable | BLOCKED | Implemented conservative guards; target matrix not executed |
| Ambiguous AX/delayed paste/concurrent copy/rich/lazy/quit/crash | BLOCKED | Real clipboard ownership/materialization/timeout tests PASS; AX/target/quit tests blocked |
| Stereo/rates/silence/quiet/59/60/unplug/change | BLOCKED | File conversion and synthetic audio tests PASS; live route/unplug/capture boundaries need device |
| Interrupted/corrupt/space/offline-tokenizer/bad selection/switch/revoke | BLOCKED | Store/engine tests PASS; actual permission revocation and visual model-failure UI remain unexercised; real post-verification Core ML rollback passed |
| Local Release app | PASS | Native 0.4.13 Release build, stable local development signature verified, stable install path and verified small/medium/turbo assets present; historical first ad-hoc build retained in earlier evidence |
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


## 0.4.4 microphone investigation

| Requirement / reported problem | Status | Evidence |
|---|---|---|
| Inspect input without recording or changing settings | PASS | Core Audio default input was built-in, alive, unmuted, volume scalar 0.4297; lid-state read open. This does not establish actual audio delivery |
| Live capture telemetry and distinct result explanations | PASS | Actual engine input-unit device ID/name, tap-derived peak and copied frame duration wired to Setup; Release compiles. No frames/invalid/short/silent/quiet captures receive distinct messages |
| Preserve speech admission thresholds | PASS | New boundary/nonfinite regression verifies diagnostic admission matches existing TranscriptPolicy; 38 tests pass |
| Real ASR still works on local file | PASS | Small model, 3-second synthetic fixture, 0.288-second decode, zero observed outbound requests |
| Fix owner's specific missing-sound instance | BLOCKED | Exact observed test state and live meter result needed; no consented live capture was collected by agent, native UI unavailable. Cause remains unestablished; diagnostics are not proof of a repair |
| Native meter visual behavior / actual microphone frames | BLOCKED | Requires owner-operated recording test; not substituted by file inference or synthetic tests |

Evidence: `docs/evidence/microphone-diagnostics.json`. No threshold relaxation, input-device switch or permission changes were made.


## 0.4.5 stable local development signing (owner-approved D016)

| Requirement / reported problem | Status | Evidence |
|---|---|---|
| Compatible identity across changed builds | PASS | Actual Debug and Release executables have different SHA-256 hashes, identical certificate-root + bundle-ID requirements, and each passes the other's actual requirement |
| Dedicated local identity reused, not regenerated per build | PASS | Setup rerun reports same public fingerprint; sign/verify succeeds after keychain relock; 0700 directory and 0600 private files |
| Reject tampered/ad-hoc updates | PASS | Real modified resource and ad-hoc-signed copy fail pinned verification; no fallback path in build script |
| Prevent accidental update identity migration | PASS | Default install against old ad-hoc app returned 2 before mutation; explicit authorized migration succeeded. Final installer checks mutual actual designated requirements |
| Prevent replacing a running app | PASS | Post-migration install returned 2 while installed process ran; no bundle replacement attempted. Staging/rollback paths source-reviewed |
| Local Release 0.4.5 build 6 installed and opened | PASS | Strict/deep certificate-backed verification, stable path, successful Launch Services open; installed/running identity checked |
| Existing app behavior regression suite | PASS | 38 tests, zero failures. No speech behavior changes; last real ASR fixture evidence remains 0.4.4 |
| Actual grants persist after later update | BLOCKED | Owner must grant the new identity and test capabilities across another update; cryptographic continuity does not establish stored TCC state |
| No release/security-policy expansion | PASS | Only owner-authorized local development certificate used; no trust-root install, Gatekeeper/TCC reset, Developer ID, account, spending, publication or M5. Temporary keychain search entry removed after signing |

Evidence: `docs/evidence/stable-signing.json`. Earlier ad-hoc signing rows are historical checkpoints; D016 supersedes that implementation. Private key, keychain, unlock secret and temporary exports are outside Git; no private material is included in evidence.


## 0.4.6 focused target discovery follow-up

| Requirement / reported problem | Status | Evidence |
|---|---|---|
| Owner reports corrected permissions after signing update | PASS | User explicitly confirms update has correct permissions; not a formal repeated-update or live ten-attempt matrix |
| Distinguish failed target discovery from failed recording | PASS | Screenshot shows nil-target Recovery reason reached after a non-rejected transcript in Coordinator; no private transcript collected |
| Application-scoped focused element lookup | PASS | TargetService asks the recorded app first, then system convenience fallback, and rejects other PIDs; same lookup used during validation |
| Preserve original window/field/selection protections | PASS | App and field window identities must agree if both available; exact revalidation, PID/launchDate checks and original selection remain; no focus setting or blind Cmd-V |
| Explain unsupported app / missing field / AX timeout | PASS | Transient reason identifies branch/app/error; no titles or surrounding text read/logged |
| Owner's exact destination now inserts successfully | BLOCKED | Await app/field and real retry; source correction does not establish actual external compatibility |

Build/install results are recorded in `docs/evidence/focus-resolution.json`. Original five-app real protocol remains required; no unsupported app is silently enabled.

## 0.4.7 system-wide editable-field insertion

| Requirement / reported problem | Status | Evidence |
|---|---|---|
| Remove Aparté's app-name restriction | PASS | Schema 3 catalog makes five known entries method overrides. Generic AXTextField/AXTextArea/AXComboBox route accepts arbitrary bundle IDs with positive editability evidence; three new regression cases in 41 passing tests |
| Retain target and secure-field protections | PASS | Policy refuses secure, disabled, explicitly read-only, unknown-role and unproven-editability controls; TargetService still checks exact PID, window, element, selection and focus before insertion. Native Release compiled; no external runtime safety claim |
| Ask lazy Electron-based apps to expose accessibility tree | PASS | TargetService checks already-granted AX trust and settable AXManualAccessibility before requesting it on activation/recheck/capture; Release compiled. Actual ChatGPT support for this attribute remains unverified |
| Keep existing clipboard preservation and no-retry behavior | PASS | Existing real isolated pasteboard regressions remain in 41 passing tests; Coordinator insertion/restore behavior unchanged. Actual target consumption remains BLOCKED |
| Signed 0.4.7 update | PASS | Release build, 41/41 unit tests, mutual actual designated requirements, strict/deep signature check, ordinary install without migration and Launch Services open. Evidence in system-wide-insertion.json |
| ChatGPT and representative cross-app visible insertion | BLOCKED | No live foreground ChatGPT/paste validation. Native desktop helper still unavailable; owner must try the installed 0.4.7 prompt. Generic eligibility does not establish actual target success |

The prior five-app restriction in the 0.4.2 and 0.4.6 checkpoint rows is historical and superseded by D018. The ten-attempt compatibility matrix, live microphone gates and macOS14 runtime remain pending; **M4 is not accepted**.

## 0.4.8 ChatGPT focus follow-up

| Requirement / reported problem | Status | Evidence |
|---|---|---|
| Diagnose owner's actual 0.4.7 failure | PASS | Owner screenshot: `ChatGPT did not expose a focused input (app: no focused element exposed; system: no focused element exposed)`; this identifies AX focus discovery, not app authorization or proven microphone failure |
| Retry documented accessibility-tree request without unreliable metadata precheck | PASS | TargetService calls AXManualAccessibility setter when already AX-trusted; unsupported setter harmlessly fails; Release compiled. Actual target effect remains unverified |
| Safe fallback within original active window | PASS | Source review: window-level focus first, then one AXFocused standard text control from same PID under 96 nodes/10 levels/300 ms; multiple/missing/overlimit cases refuse. Existing eligibility and context checks still apply; runtime ChatGPT behavior unverified |
| Signed 0.4.8 local update | PASS | Release build, 41/41 unit tests, mutual actual designated requirements, ordinary install, verified single running installed instance. Evidence in chatgpt-focus.json |
| Visible insertion into ChatGPT | BLOCKED | Owner must retry 0.4.8; native desktop helper remains unavailable. Build/tests and the 0.4.7 failure do not prove the fallback succeeds |

No external compatibility target is marked validated; **M4 is not accepted**.

## 0.4.10 Chromium webpage follow-up

| Requirement / reported problem | Status | Evidence |
|---|---|---|
| Distinguish native-control success from webpage-input failure | PASS | Owner reports Claude and Chrome native UI work, whereas inputs inside webpages do not; 0.4.8 ChatGPT Recovery showed an active window but no uniquely focused editable child. This is user evidence of the split, not proof of the exact browser mechanism |
| Request Chromium web accessibility from already trusted Aparté | PASS | TargetService detects the Chromium `icudtl.dat` framework marker in both installed ChatGPT and Chrome bundles, then sends one AXEnhancedUserInterface request per process. Chromium source implements the request with a two-second debounce; Release compiled. Actual target response remains unverified |
| Recent-click fallback identifies a field without blind window paste | PASS | Source review: only a left click from the last ten seconds with no intervening ordinary key can be app-scoped hit-tested; candidate must be a standard editable control in the same active window/PID and pass secure/read-only/context checks again before mutation. Release compiled. Actual browser hit test remains unverified |
| Signed 0.4.10 local update | PASS | Release build, 41/41 unit tests, mutual actual designated requirements, ordinary install and strict/deep signature checks; final process inventory showed only installed 0.4.10. See web-focus.json |
| Exact visible insertion in ChatGPT and Chrome webpage input | BLOCKED | Owner live retry pending. Native desktop helper remains unavailable; unit tests and successful build do not prove web focus or paste consumption |
| Dictate while consulting another app, then deliver to original field | BLOCKED | D021 owner amendment implemented in 0.4.11: one activation/window raise/field-focus request and exact foreground/field/selection revalidation before insertion; live switch-app and browser-field result remain unverified |

The owner can retry web inputs in 0.4.10 after allowing Chromium's accessibility mode to settle. No app is marked compatibility validated and **M4 is not accepted**.

## 0.4.11 original-window and Recovery follow-up

| Requirement | Status | Actual evidence |
|---|---|---|
| Original process/window/field/selection captured at shortcut-down | PASS | TargetContext and capture path source review; no surrounding text read |
| Return original window after consulting another app | BLOCKED | Coordinator requests one activation, AX raise and field focus; native Release compiles. macOS may decline; no live app-switch check has run |
| Refuse paste unless same original context is foreground | BLOCKED | Source guards before and after clipboard snapshot; browser and focus race need live verification |
| Fall back promptly when original field cannot be proven | PASS | Two-second deferred timer then Recovery path in Coordinator; no live target result claimed |
| Put Recovery text on clipboard automatically | PASS | D022 implementation; two new real isolated named-pasteboard tests show transcript retained after a pending paste and newer clipboard owner preserved. Actual general-clipboard behavior remains BLOCKED |
| Make clipboard retention/duplicate risk visible | PASS | Recovery panel, Settings privacy text, README and PRIVACY documentation; visual UI review remains BLOCKED |
| Native Release and regression suite | PASS | 0.4.11 Release build and 43/43 unit tests pass; `artifacts/original-target-release.log` and `artifacts/original-target-unit.log` |
| Real offline engine and local install | PASS | Small model transcribed locked 3-second fixture with 0 observed outbound URL requests; 0.4.11 installed at stable path with mutual designated requirements, strict signature and matching binary hash; sole running instance at inspection. See `docs/evidence/original-target.json` |

No live external-app insertion or original-window return is claimed; **M4 is not accepted**.

## 0.4.12 owner-requested model expansion

| Requirement | Status | Actual evidence |
|---|---|---|
| Complete immutable medium and turbo Core ML plus matching tokenizers | PASS | `Resources/Models.json` lists 23 medium / 27 turbo files, exact revision URLs, sizes and SHA-256; local verified manifest sums 1,532,419,576 / 1,641,459,812 bytes. Both imported to managed model folders. |
| Real medium and turbo offline inference | PASS | Production WhisperKit 1.1.0 transcribed the locked 3-second synthetic fixture for each; zero observed outbound URL requests. Medium `artifacts/medium-integration.log`, turbo `artifacts/turbo-integration.log`. |
| Frozen benchmark quality and resources | PASS | Both real Release engines passed 55-clip quality, 30 warm decodes and 100 sequential sessions under network denial. Medium EN/FR WER 0.43%/0.85%, terms 91.67%, 10/10 no speech, warm 8s p95 1.137s, peak whole-process RSS 2.51GB. Turbo 0.43%/1.91%, 83.33%, 10/10, 0.625s, 3.24GB. `docs/evidence/benchmark-{medium,turbo}.jsonl` and summaries. |
| 0.4.12 in-app comparison discoverability | FAIL | Although 0.4.12 bundled all four model entries, the owner could not see small/turbo in the UI; process inventory later found an old 0.4.5 Debug copy running alongside it. The exact viewed window was not observable. D025 changes the model selector and version labelling in 0.4.13. |
| Stable local install and automated regression | PASS | 43/43 unit tests, Release build, mutual old/new designated requirements, ordinary install, matching binary SHA-256 `50062e423b6a5b0738d21fce6fa935d4a26d3d24012e1eec86712db001177841`, strict signature, sole installed Aparté process at inspection. `docs/evidence/model-expansion.json`. |
| French-accented English comparison through live microphone | BLOCKED | The frozen synthetic corpus has no French-accented English. Owner must speak the same English phrase into Setup's Microphone test under small/medium/turbo; no personal audio or transcript collected. |

External insertion, microphone timing/quality and macOS 14 runtime gates remain BLOCKED; **M4 is not accepted**.

## 0.4.13 model-picker and duplicate-app correction

| Requirement | Status | Actual evidence |
|---|---|---|
| Identify old copy behind missing model choices | PASS | Two live Aparté processes shared the bundle ID/menu-bar identity: stale project Debug 0.4.5 and installed 0.4.12. The installed bundle's four-entry `Models.json` hash matched source. Old Debug copy closed orderly; no force kill or permission changes. Exact window the owner saw remains unobserved. |
| Make all models directly selectable in Settings | PASS | Source/Release review: a menu-style **Model to compare** picker lists every manifest entry, selected-model actions are immediately underneath, and active model is named. The 0.4.13 installed bundle has Base, Small, Medium and large-v3 turbo. Actual visible UI interaction remains BLOCKED. |
| Distinguish running version and refuse duplicate local installs | PASS | Menu bar title and Settings title derive version from Info.plist; lifecycle script refuses installation while any same-bundle-ID copy runs and has an explicit path-bounded orderly quit for project artifact copies. 0.4.13 installed via ordinary path after closing duplicate. |
| Native Release, regression and stable local install | PASS | 0.4.13 Release build, 43/43 unit tests, mutual designated requirements, strict signature, byte-identical bundled/source model manifest, one installed Aparté process at inspection. `docs/evidence/model-picker.json`. |
| Owner sees Small and large-v3 turbo and can prepare them | BLOCKED | Native desktop UI pipe closed on two attempts; no live picker/Prepare interaction was observed. Owner can test in the installed 0.4.13 Settings window. |

**M4 is not accepted**; model engine/benchmark evidence from 0.4.12 remains valid and unchanged.

## 25 September 2026 closure checkpoint

| Requirement | Status | Actual evidence |
|---|---|---|
| Feasible M0–M4 implementation and local handoff closed | PASS | Owner requested closure after 0.4.13 signed local install; Release/43-unit-test, offline inference/benchmark and documentation evidence already recorded. D026 marks implementation complete without rerunning unchanged checks. |
| Full M4 PRD exit acceptance | BLOCKED | Actual cross-app insertion and clipboard consumption matrix, consented live microphone/timing, native visual/VoiceOver, Ready idle/login and macOS 14 runtime checks remain unverified. No status above was converted to PASS for closure. |

The historical base technical-term FAIL and 0.4.12 model-discoverability FAIL remain recorded; small is the selected quality-passing default and 0.4.13 addresses discoverability in source, with live visual verification still BLOCKED. Continue any future validation against the installed candidate and update this ledger with actual results before claiming M4 accepted.

## M5A public source and hosted build

| Requirement | Status | Actual evidence |
|---|---|---|
| Owner destination, visibility, licence and history choice | PASS | Owner chose personal `clemarc` public repository, MIT and audited existing history; Nearform excluded. D027. |
| Publication audit and exclusion of local files | PASS | `docs/evidence/m5-publication-audit.json`; `output/`, `artifacts/`, weights, audio and signing material excluded. Scope is a pattern/path audit. |
| Local ad-hoc Release build and unit tests | PASS | `./scripts/build-local.sh --configuration Release --signing adhoc` succeeded on Apple Silicon/Xcode 27; strict/deep code signature verified. `./scripts/test-local.sh --suite unit` passed 43/43. Existing local packages/build cache was present, so a clean hosted runner is a separate gate. |
| Local test-command failure propagation | PASS | A temporary `XCTFail("intentional CI failure probe")` in `PolicyTests.testSanitization` made `./scripts/test-local.sh --suite unit` exit nonzero with 1/43 failures. The test file was restored byte-for-byte and the working tree rechecked clean. Hosted CI failure propagation remains a separate gate. |
| Public repository exists under `clemarc` | PASS | GitHub reported `full_name=clemarc/aparte`, `private=false`, default branch `main`; UI showed the public badge and 24 commits after the no-force push. The owner's initial MIT commit remains in the merge ancestry. |
| Default-branch clean-runner workflow | PASS | [Build and test run #1](https://github.com/clemarc/aparte/actions/runs/36150432825) passed on `main` at `675d580` in 3m 28s; arm64 Xcode 27 build and unit job succeeded. `docs/evidence/m5-ci-run1.json`. |
| Pull-request clean-runner workflow | BLOCKED | A PR check must pass before this is claimed. |
| Deliberately failing test makes CI fail | BLOCKED | Verify with an actual failure run, not workflow inspection alone. |
| Development artifact and logs retained seven days | PASS | Successful run #1 exposed `Aparte-development-adhoc-NOT-NOTARISED` and `Aparte-build-and-test-logs`; workflow sets `retention-days: 7`. Actual seven-day expiration was not observed. |
| Branch protection | BLOCKED | Configure after the real CI status check name exists; verify on GitHub. |
| M4 real-device acceptance | BLOCKED | Existing microphone, target-app, UI, Ready/login and macOS 14 gates remain pending above. |
