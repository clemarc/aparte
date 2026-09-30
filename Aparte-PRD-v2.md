# Aparté
## PRD v2: autonomous implementation through M4

**Date:** 22 September 2026  
**Status:** Original core specification with owner-approved amendments. M4 implementation is closed with formal acceptance pending; M5A public source/build work is complete. The unified UX is implemented in the development candidate; beta launch/update validation remains pending.
**Basis:** Supplied seven-page "Local Whisper Push-to-Talk - macOS App PRD".  
**Authority:** Sections 1-12 and the adopted owner-approved amendments are normative for their implementation checkpoints. Appendix A records the original adversarial review; Appendix B records sources. This document supersedes conflicting requirements in the original. Deferred feature scope is recorded separately in [Post-M5 dictation UX](docs/POST-M5-DICTATION.md); it does not change current acceptance or authorise implementation/publication.

> Build a local, private, native macOS dictation app through M4. M4 produces a locally usable candidate and evidence, with no public repository, hosted CI, Developer ID signing, notarisation or public release. Start M5 only after the owner explicitly authorises the public repository and CI setup. Local compilation and tests begin in M0.

## Owner-approved amendment — 24 September 2026

D013 in `docs/DECISIONS.md` records the owner's approved clipboard/insertion fix after testing. It supersedes only the operational requirement to wait for validated adapters (§2, INS-02/03/05, M2 and related Appendix A wording) and §6's blanket refusal of ordinary lazy data: the five named app adapters may attempt guarded insertion before the real matrix is complete, and snapshots may materialize ordinary foreign data within the existing 500 ms / 8 MiB limits. Explicit promise/lazy-marker formats remain unsupported. No unknown app/control is enabled. No whole-field writes, retries after mutation, synthetic Return, focus restoration or permission bypass are authorized. The original specification below is preserved as history; all actual compatibility and M4 acceptance gates remain required and unpassed checks remain BLOCKED. See D013 for privacy, race and native timeout limitations.

## Owner-approved local signing amendment — 24 September 2026

After diagnosing update-related permission churn, the owner authorized D016: create and reuse a dedicated local development code-signing identity and verify cross-build identity continuity. This supersedes the blanket signing-credentials prohibition only for this local identity. Keep private material outside Git with owner-only access. No release/Developer ID credentials, accounts, trust-root installation, privacy reset, notarisation, publication or M5 work is authorized. See `docs/LOCAL-SIGNING.md`; actual permission continuity remains a real-device acceptance check.

## Owner-approved system-wide insertion amendment — 24 September 2026

D018 records the owner's clarification that dictation should work across the system, including ChatGPT, rather than only in five named applications. Standard accessible editable controls in any foreground app may use the guarded clipboard route without app-name approval. Existing per-app methods remain optional overrides. This supersedes D013/D017's five-app operational gate; it does not mark any app validated or weaken secure/read-only refusal, original context checks, clipboard preservation, no Return or no retry. Custom/inaccessible controls and remote/elevated contexts have no universal compatibility guarantee. The original target matrix remains required validation, now with ChatGPT added as an owner-reported target.

## Owner-approved original-window and Recovery amendments — 24 September 2026

D021 records the owner's request to consult another app while dictating, then have Aparté pull forward the original window and deliver text to the field where recording began. This supersedes §4's blanket invalidation on *switching apps* and prohibition on reactivating the original app. Aparté may request one return to the captured process/window/field after transcription, but insertion still requires proof of the same live process, window, editable field and selection, plus foreground focus and all existing clipboard safeguards. Interactions or changes in the original field still invalidate insertion. If the return cannot be verified promptly, use Recovery. Never paste into the document being consulted or into an unproven background field.

D022 records the owner's request to place a Recovery transcript on the clipboard automatically for manual paste. This intentionally replaces the prior clipboard contents when insertion was not attempted, and retains Aparté's temporary transcript clipboard rather than restoring the old contents after a paste attempt when ownership is still Aparté's. A newer clipboard owner is preserved. The in-app Recovery text still expires after five minutes, but the system clipboard may retain or sync the transcript independently. No automatic second paste, Return, full-field write or bypass of secure controls is authorized. Original §4/§6 clipboard preservation rules remain for the normal guarded paste path; D022 governs the explicit Recovery handoff.

## Owner-approved model comparison expansion — 24 September 2026

D023 adds an optional, verified large-v3-turbo Core ML choice and an in-app comparison using measured Aparté data. D024 records the owner's explicit follow-up to benchmark multilingual medium and add it as an option, superseding MODEL-01's deferral of medium only. Both new entries must use immutable, complete manifests with matching pinned tokenizers, pass real WhisperKit loading/inference and run the existing fixed benchmark gates, recording any failures rather than hiding them. Keep small as the default unless the same measured evidence warrants a change; no model is downloaded during dictation. Tiny, unverified large-v3 and arbitrary model URLs remain deferred. These requests do not authorize M5 or change the existing privacy/permission boundaries.

## Owner-approved unified UX and development identity — 28 September 2026

D031 adds a retained native workspace with **Try it, Processing, Shortcuts and Settings**, capability-based first-open guidance, a compact menu companion and the selected voice-to-text mark. Explicit open/reopen reveals the workspace; login/service startup stays quiet. Try it uses the real capture/transcription path and an app-owned editor; leaving that section or closing the workspace cancels local diagnostics and clears their transient content. External dictation retains its existing lifecycle. Shortcut capture previews a candidate after release and requires explicit Save; Cancel/navigation preserve the saved binding, and detection-only mode reports delivery without recording. The companion reflects actual coordinator state and opens the workspace for recording diagnostics. These presentation changes do not establish live-device acceptance.

Processing preserves the pinned models, active-versus-preview selection, language and measured comparisons; D037 adds optional English-only Base and model-specific language choices. Its **Text handling** stage stays **Off · original text**: no provider, credentials, LLM inference, transcript transmission or rewriting is implemented. D033's double-tap gesture is included in D037, while configurable voice commands remain deferred in [Post-M5 dictation UX](docs/POST-M5-DICTATION.md). D034 extends the deferred LLM scope with explicit local/remote model selection, discovery plus manual API IDs, and a beginner [Apple Silicon local setup guide](docs/LOCAL-LLM-SETUP.md) using LM Studio/MLX without Ollama. The LLM picker is separate from speech recognition; the guide does not establish live integration or acceptance.

D032 supersedes local development naming only: default local/CI builds use **Aparte Dew / Aparte Dew.app**, identifier **dev.aparte.Aparte.dew**, install path **~/Applications/Aparte Dew.app**, and separate preferences, login registration and model storage. Beta standard builds retain **Aparté / Aparte.app / dev.aparte.Aparte** and their separate beta signing identity. Reuse the development certificate without migrating data or privacy grants; verify actual permissions independently. M4 acceptance, fresh-Mac beta launch and two-version permission persistence remain outstanding.

D036 records the owner's clarified speech-language expansion in [Post-M5 dictation UX](docs/POST-M5-DICTATION.md). D037 authorises implementation now, together with double-tap recording, Fn / Globe, modifier-only and bare-key bindings, plus one pinned smaller English-only model choice. Auto remains the default, and explicit language choices are checked against the active model before decoding. This is recognition UX, not interface translation or a guarantee of equal quality across languages. Optional LLM text handling remains deferred.

D039 records the owner's request to use both hold to talk and double-tap on the same saved shortcut. This replaces D037's either/or recording-mode picker. A sustained press starts hold recording; two short taps start hands-free recording after the second release; a later tap stops it. See [D039](docs/DECISIONS.md) for timing and legacy-preference migration. Physical keyboard behavior remains an acceptance gate.

## 1. Agent execution contract

### Owner-approved beta distribution amendment — 28 September 2026

The owner asked for stable signing for public beta builds, then instructed implementation. D030 narrowly supersedes §11 M5B's Developer ID prerequisite for this beta path: use a dedicated persistent self-signed beta certificate, local signing/packaging and manual GitHub draft prereleases under `clemarc/aparte`. No paid account, Developer ID, notarisation, certificate trust installation, hosted signing credential or automatic publication is authorized. Release only when deliberately selected; app version bumps and main merges do not publish. Keep M4 validation and fresh-Mac launch/permission-update checks visible and review the concrete artifact/notes before public publication. The original signed/notarised M5B option remains deferred.

Implement M0-M4 in order, continuing without routine design approvals. Resolve implementation details using this specification and record consequential choices in `docs/DECISIONS.md`. Do not substitute a demo or mock implementation for the real audio, transcription or insertion paths.

### 1.1 Authority and boundaries

- Work in the supplied project directory. Create a local Git repository if none exists; preserve existing work. Make local milestone commits where repository policy permits. No remote is needed through M4.
- Build the native app, tests, local scripts, documentation and fixtures. Download public dependencies and approved model assets when the execution environment permits it; do not require an API key or a paid inference service.
- Do not create a public repository, push code, configure hosted workflows, upload recordings, use signing credentials, submit to Apple, or publish releases through M4.
- Do not change macOS security settings or keyboard preferences, bypass privacy prompts, reset TCC automatically, install privileged helpers, or pay for services. The owner grants OS permissions through Apple's UI.
- Do not expand into history, cleanup LLMs, cloud fallback, custom vocabulary, meeting recording, auto-updates or Homebrew packaging. Those are a separate backlog, not M5 deliverables.
- Stop at the M4 handoff. Prepare an M5 readiness checklist, not an active deployment pipeline.

### 1.2 Execution environment and honest completion

For full acceptance, the agent needs an Apple Silicon Mac, Xcode and a logged-in desktop session, plus access to a microphone and the target apps. Record actual chip, RAM, OS, Xcode and SDK versions in M0. macOS 14+ is the product target; do not infer the owner's current hardware from older context.

If the environment lacks macOS/Xcode, continue all feasible implementation and static checks. If a permission, microphone, application login or physical interaction is missing, finish independent work and collect the remaining actions into one concise handoff. Do not repeatedly ask for permission to continue coding. Do not claim compilation, desktop integration or benchmark success without running it.

Track each acceptance item as `PASS`, `FAIL` or `BLOCKED`, with evidence. A mocked test may pass while its corresponding real-device gate remains blocked. "Implementation complete; device validation blocked" is a valid handoff, but is **not M4 accepted**. An agent with the required authorised Mac access should run the available gates itself.

### 1.3 Delivery contract

Deliver the source tree, a reproducible local build, a local `.app` when actually built on macOS, and:

- `README.md`: prerequisites, exact build/run/test commands and first-run walkthrough.
- `docs/DECISIONS.md`: toolchain, exact dependency/model pins, trade-offs and departures.
- `docs/ACCEPTANCE.md`: requirements-to-tests matrix, commands, outcomes and environment.
- `docs/COMPATIBILITY.md`: app/OS versions, insertion method, tested results and limitations.
- `docs/BENCHMARKS.md`: corpus, hardware, model, warm/cold timing and quality results.
- `docs/PRIVACY.md`: network, retention, clipboard and target-app boundaries.
- `docs/HANDOFF.md`: milestone status, known defects, blocked checks and M5 readiness.

Use synthetic or redistributable fixtures. Exclude personal audio, transcripts, model weights, credentials, derived build files and private machine paths from Git.

## 2. Product outcome and fixed scope

Hold a shortcut, speak, release, and insert the resulting text into the same eligible input context. Core transcription works offline after explicit model installation. The first audience is the owner's development workflow: prompts, Slack drafts, notes and commit messages.

| Decision | Required behaviour through M4 |
| --- | --- |
| Platform | macOS 14+, arm64 only; a menu bar app with Swift/AppKit and SwiftUI settings |
| Engine | Open-source WhisperKit through Swift Package Manager; no Pro SDK, account or cloud inference |
| Interaction | One saved shortcut supports hold-to-talk and double-tap start / tap stop; one recording/transcription/insertion transaction at a time |
| Default shortcut | Control-Option-Space; configurable chord, Fn / Globe, modifier-only or bare key subject to actual macOS event delivery and user testing |
| Audio | System default input device; in-memory capture only; maximum 60 seconds |
| Language | Auto or any verified language supported by the active model; default Auto; transcribe in the spoken language, never translate by default |
| Initial model | A pinned multilingual base model; M3 may choose a faster quality-passing default from the curated catalog |
| Insertion | Tested selected-text AX insertion where safe; otherwise controlled clipboard paste for tested targets |
| Retention | No persistent audio or transcript history; one transient recovery result only |
| Launch at login | Off by default; user-controlled registration and truthful status |
| Distribution | Local development `.app` through M4; public repository and CI belong to gated M5 |

Bare letters may consume normal typing while the listener is ready; modifier-only bindings can interfere with ordinary shortcuts. Fn / Globe depends on macOS and keyboard event delivery and must be checked on a real keyboard. Do not change macOS keyboard settings automatically. Do not add a Dock icon during normal operation, steal focus for recording indicators, emit Return, submit a message or execute a command. No per-app auto-newline option in this version.

The app and project name is **Aparté** (owner-selected). Use `Aparte` for Swift modules, Xcode targets, schemes, filenames and the `.app` bundle filename; set the displayed app name to `Aparté`. Use `dev.aparte.Aparte` as the stable local development bundle identifier and `~/Applications/Aparte.app` as the documented local install path. Neither identifier asserts ownership of a public domain. The public repository owner/slug, licence and signing identity remain M5 owner decisions. Do not block local implementation on them. If the bundle identifier changes for distribution, document permission re-grant and settings/model migration.

## 3. Architecture and reproducibility

Use an Xcode macOS app target plus testable Swift modules. Commit the project, shared schemes and resolved package versions. Local scripts must work from a clean checkout without manually editing project settings. Prefer standard Apple frameworks over additional dependencies.

| Component | Responsibility and boundary |
| --- | --- |
| Session coordinator | Serialises state transitions, transaction IDs, cancellation and deadlines |
| Hotkey service | Event tap lifecycle and matched gesture events; never transcribes inside callbacks |
| Audio capture | Input device lifecycle and bounded PCM collection; no disk recording |
| Transcriber | Adapter around the pinned WhisperKit API; local assets, cancellation and error mapping |
| Model manager | Curated asset manifest, explicit download, verification, atomic install and deletion |
| Target/insertion service | Target eligibility, focus validation, AX attempt and paste transaction |
| Pasteboard adapter | Bounded snapshot, ownership checks, write and conditional restoration |
| UI/settings | Status item, non-activating feedback, onboarding, preferences and recovery |

Keep UI mutations on the main actor. Keep model loading, inference, file hashing and downloads off it. The audio tap must do bounded work into owned buffers; no model work, file IO, UI calls or unbounded allocation in the callback. Do not retain an audio buffer past its valid lifetime without copying into owned storage. Keep the event callback short and move work to the coordinator.

WhisperKit is a Core ML implementation, not a wrapper around `whisper.cpp`. Inspect the selected release's actual API and deployment requirements. Link only the needed WhisperKit product. Pin an exact compatible version/revision and commit `Package.resolved`; do not track `main`, assume all generic Whisper model names exist, or silently raise the minimum OS. [S1-S3]

Provide these stable local command entry points; their implementation may wrap `xcodebuild`:

```sh
./scripts/build-local.sh --configuration Debug
./scripts/test-local.sh --suite unit
./scripts/test-local.sh --suite integration
./scripts/benchmark-local.sh --manifest Tests/Fixtures/manifest.json
./scripts/build-local.sh --configuration Release
```

Scripts must fail with useful prerequisites or nonzero test failures, record tool versions, and place results under an ignored `artifacts/` directory. Unit tests require neither a model download nor privacy grants. Integration and benchmark commands must explicitly report missing prerequisites; they must not report skipped integration as success. Dependency resolution may require network; app runtime after installation must not.

The local app must not require an Apple Developer Program membership. Use a documented local/ad-hoc signing route where needed for executable integrity. Distinguish that from Developer ID distribution. Rebuilds may affect permission identity; document recovery instead of promising grant persistence.

## 4. Transaction state and lifecycle

Model the app as explicit states: `NeedsSetup`, `Preparing`, `Ready`, `StartingCapture`, `Recording`, `Transcribing`, `Inserting`, `Recovery` and `Error`. Model installation has its own progress state. Every asynchronous callback carries a transaction or generation ID; stale callbacks cannot update the current session or insert text.

| Event / condition | Required outcome |
| --- | --- |
| Hotkey down in Ready | Capture target identity, check eligibility, then start input; ignore key auto-repeat |
| Input actually starts | Show Recording and elapsed time; the recording indicator must not precede live capture |
| Key released during startup | Cancel startup; do not begin recording after release |
| Main key or a required modifier released | End the hold; stop the microphone once and freeze that audio buffer |
| Valid release | Transcribe the frozen buffer; no microphone remains active during inference |
| Empty, shorter than 250 ms, or no-speech input | No insertion and no clipboard mutation; return Ready with brief feedback |
| Hotkey while busy | Ignore with visible Busy status; do not queue hidden recordings |
| Escape during a transaction | Cancel, close capture, invalidate result and release buffers; cannot undo text already inserted |
| 60-second capture limit | Cancel and discard the recording; show limit reached; do not auto-paste a potentially unintended result |
| Sleep, lock, logout, device loss or tap disable | Cancel active capture/inference, suppress late insertion and clear sensitive buffers |
| Inference exceeds 30 seconds | Cancel/discard the transaction and show a retryable error; do not start a second engine operation until the first has unwound |
| Valid result, target invalid | Hold one recovery result; do not switch apps or paste elsewhere |
| Permission revoked | Stop affected operations and show the relevant recovery action |

After a recognised hotkey down, consume its matching key-up even if the user cancels or changes settings, so the target does not receive an unmatched event. Consume only the bound gesture and Escape during active transactions; pass unrelated keyboard events through. Ignore self-generated paste events. Monitor modifier changes and handle event-tap timeout/removal. If key-up cannot be observed, the recording limit is the final watchdog.

When modifiers remain physically held after release, wait up to two seconds for all shortcut modifiers to clear before posting Cmd-V. Otherwise retain the result for recovery. Never synthesize releases for the user's physically held keys.

Input changing to another app/window/field or user typing/clicking during a transaction invalidates automatic insertion. Observe only the metadata needed for this check; do not retain unrelated keystrokes. Do not reactivate the original app later. Validate again immediately before mutation. This reduces focus races; macOS does not provide an atomic cross-app focus-and-insert transaction.

## 5. Recording and transcription

**AUDIO-01:** Use AVAudioEngine with the current input format, then correctly downmix/resample into the selected engine's input format (normally mono 16 kHz floating point). Support 44.1/48 kHz input fixtures and verify duration/channel handling. Sample-rate conversion must use an appropriate AVAudioConverter conversion path; the basic buffer conversion overload does not perform sample-rate conversion. [S4]

**AUDIO-02:** Request microphone access before the first capture, and never leave the input tap running while Ready. There is no pre-roll, ambient listening or recording during model setup. If startup is slow, show Starting; the user speaks once Recording appears. Handle unavailable/zero-format devices and device changes without crashing. Cancel the current session on route change; use the new default on the next hold.

**ASR-01:** Load/prewarm the selected model before Ready. Show separate download, preparation and readiness states. Cache one loaded engine where practical; handle memory pressure by unloading while idle and showing Preparing before the next session. Core ML compilation caches can exist outside the app-managed model directory. [S3]

**ASR-02:** No incremental insertion. Decode once per completed recording; streaming recognition is deferred unless needed later and separately specified. Use WhisperKit's no-speech handling with a tested audio-energy/speech gate. Calibrate on quiet speech as well as silence; confidence values are not a guarantee of correctness. Reject empty/repetitive failure output using documented thresholds. Do not silently delete uncertain words or paraphrase.

**ASR-03:** Disable transcript/token/audio logging in both app and dependency paths. Output contains no timestamps or special tokens. Preserve Unicode, accents and ordinary punctuation. For this version, replace tabs and line separators with spaces, remove other control characters including ESC, and trim outer whitespace before automatic insertion. No trailing newline and no "smart" rewriting of code, identifiers or prose. If sanitisation produces an empty string, insert nothing.

## 6. Target eligibility and safe insertion

**INS-01:** At hotkey down, record the frontmost process identity and available window/focused-element identity plus selection metadata. Do not collect surrounding document text for prompt context. Before insertion, require the same live process/context and no observed user interaction that invalidated it. If identity or safety cannot be established, use Recovery.

**INS-02:** Refuse automatic insertion into known secure/password fields, read-only controls and unsupported contexts. Check public secure-input/AX capabilities available in the chosen SDK, and validate them on the supported OS. When secure input prevents hotkey observation, report this limitation in troubleshooting; never bypass it. Unknown controls default to Recovery unless covered by a validated compatibility adapter. VM/remote-desktop fields, elevated prompts and password managers are out of scope.

**INS-03:** For a tested editable control, use a settable selected-text attribute to replace only the selection or insert at its caret. Never write `kAXValueAttribute` for the whole field or simulate Select All. Test selection, mid-paragraph insertion, non-BMP Unicode and surrounding rich text. A successful API return is not sufficient evidence of correct app behaviour. [S5]

**INS-04:** Use clipboard paste directly when a target is known not to support safe selected-text insertion. Fall back from AX only when no mutation has been attempted or the failure definitively implies no mutation. After an ambiguous AX error or any dispatched paste, do not automatically try another method: duplication is worse than recoverable uncertainty. Per-character synthetic typing is removed from v1.

**INS-05:** Terminal/Claude Code input uses the validated terminal adapter and a single-line paste. Never post Return or interpret transcribed content as commands. Test in an inert prompt or fixture, not against a destructive command. The app cannot guarantee another program's custom paste handler will never execute text; document target-specific limitations.

### 6.1 Clipboard transaction

1. Revalidate the target and wait for modifier release before touching the clipboard.
2. Snapshot all items and eagerly available representations, with an 8 MiB total cap. Bound snapshot preparation to 500 ms off the UI thread. If any type is unavailable, promised/lazy, oversized or times out, abort automatic paste without modifying the clipboard. Offer explicit Copy instead. Do not reduce a rich clipboard to a plain-string snapshot.
3. Write the transcript as plain text plus a private transaction marker; retain the resulting `changeCount` and payload. Revalidate the target again before posting exactly one Cmd-V. If invalidated before posting, restore conditionally and enter Recovery.
4. For tested paste targets, restore after a one-second compatibility delay only if the marker, expected contents and change count still match this transaction. A newer user/application copy must never be knowingly overwritten. Cancel obsolete restoration tasks.
5. If observation can prove insertion in a test adapter, record `confirmed`. Otherwise record `attempted`, not `confirmed`. There is no general paste-consumed acknowledgement, and an arbitrary delay does not prove success. A slow/custom target that fails the restoration test must use Recovery instead of automatic paste.
6. Release the clipboard snapshot after the transaction. Test empty, text, rich text, image, multi-item and concurrent-copy cases, plus delayed paste and quit/cancel. Attempt conditional restoration on orderly quit; do not promise recovery after a crash or OS termination.

These are application policies, not an atomic OS guarantee. The pasteboard can change between a check and a write, and other processes can read it during the transaction. Apple's change count supports detecting ownership changes; the general pasteboard also participates in Universal Clipboard. Temporary restoration does not undo other apps' reads or synchronisation. [S6-S7]

### 6.2 Recovery UX

Keep at most one transcript in process memory for five minutes. Provide View, Copy and Discard in a user-opened panel. Explicit Copy intentionally replaces the clipboard and does not restore its former contents. Clear on expiry, lock, quit, discard or the next recording; show that a new recording replaces the pending result. No automatic retry button that pastes into a new target. On uncertain insertion, label it "Insertion unconfirmed - check the target before copying".

## 7. Permissions, settings and models

**PERM-01:** Add a specific microphone usage description. Explain Accessibility for cross-app interaction; check input-listening and posting capabilities for the selected event-tap implementation. Do not present three unconditional permission requests based on the original PRD. Only guide the user to Input Monitoring when the actual tested capture path requires it. Use public trust/preflight APIs and observed failures; record OS-specific results. [S8]

Onboarding must precede first use, not arrive in M4. Provide Open System Settings, Recheck and clear denied/restricted/restart-needed states. Do not repeatedly trigger prompts. Missing insertion permission may allow explicit microphone/ASR diagnostics, but must not show system-wide dictation as Ready. Settings and the status item remain usable when permissions are denied.

**SET-01:** Settings include shortcut, language, model status/selection, explicit download/delete, launch at login, permission status and a diagnostics summary. Provide a binding test and reject reserved/unsupported bindings. Registration success is not proof that no other app conflicts. Persist settings with schema version and safe defaults for unknown/corrupt values.

**SET-02:** Use SMAppService for user-requested launch at login and display actual registration/approval state. Do not silently register, create unrelated launch agents or require successful login registration to transcribe. Test from a stable local install location. [S9]

**MODEL-01:** Start with a curated catalog of multilingual base and small, plus large-v3-turbo only if compatible with the pinned engine and within observed resource limits. Each visible entry must map to a real verified artifact set. Tiny/medium and arbitrary URLs are deferred. Expose measured/manifest disk size, required temporary space and known preparation cost; no universal "1-2.5 GB" claim.

**MODEL-02:** In M0 select an immutable repository revision and file manifest for the base model. Include all required tokenizer/config/model files, sizes, hashes, source and licence provenance. In M3 extend the manifest for supported choices. Use verified upstream checksums when available; otherwise compute and document hashes from the reviewed pinned assets, without pretending that this independently proves authenticity. Runtime does not follow a mutable remote catalog.

**MODEL-03:** Download only after an explicit user action. Use HTTPS, show progress/cancel/retry, check space for partial and installed copies, reject path traversal and invalid/corrupt assets, verify before atomically promoting the directory. Interrupted/cancelled downloads never appear installed. Restarting a download from zero is acceptable; resume is optional. No auto-download fallback during dictation.

**MODEL-04:** Store managed assets under `~/Library/Application Support/Aparte/Models/`. Support importing an already downloaded, matching manifest-backed model directory for offline setup. During model switch, finish/cancel the current transaction before unloading. Commit the new active selection only after load succeeds; on failure return to the previous working model, reloading it if necessary. Do not keep two large engines loaded simply to roll back. Disallow deleting an active model during a session.

## 8. Privacy and error contract

The app performs no audio/transcript network transmission and contains no analytics or cloud inference. Runtime network is limited to explicitly requested model installation. On cold restart with complete local assets, Ready and transcription must work with network unavailable and without attempted remote model/tokenizer resolution.

No audio files, persistent transcript history or clipboard snapshots are written by the app. Release sensitive buffers promptly after use; do not claim secure erasure of Swift/Core ML memory, exclusion from swap, or control over OS crash diagnostics. Diagnostics contain only timings, versions, model identifiers and redacted error codes. Audit verbose dependency paths as well as app logs.

Privacy copy must distinguish **on-device transcription** from the destination: Slack, a browser, a cloud coding tool or the system clipboard may process/sync inserted text. Do not claim text never leaves the machine. No remote support bundle or automatic crash upload.

| Failure | User-visible response and recovery |
| --- | --- |
| Missing microphone/accessibility capability | Specific status and settings guidance; no partial recording/insertion |
| Download cancelled, offline or insufficient disk | Keep existing model intact; retry or import local assets |
| Corrupt/incompatible model | Reject it, identify the affected model and allow removal/redownload |
| Model load/inference failure or timeout | Stop the transaction, release buffers, show retry action; never cloud fallback |
| Device disconnect, sleep or lock | Stop/cancel immediately; no late result insertion |
| Focus changed or clipboard cannot be preserved | Recovery result with explicit Copy/Discard |
| Uncertain insertion | No second attempt; explain how to inspect and recover |
| No speech | Brief "No speech detected" state; no clipboard change |

## 9. Quality and measurement gates

The original universal sub-second promise is replaced with measured targets. The numbers below are **proposed product acceptance thresholds, not published WhisperKit guarantees or measurements**. An agent must report a miss and optimise within scope; it cannot silently relax a gate.

### 9.1 Performance

Use the actual available Apple Silicon Mac as the initial reference and state its full configuration. It does not establish performance on every M1+ machine. Measure 30 warm utterances, ten each around 3, 8 and 15 seconds, after one warm-up; report p50/p95 by duration and overall, with raw timings. Use the default quality-passing model, fixed corpus and normal power mode.

| Metric | M4 target |
| --- | --- |
| Shortcut event to Recording visible and capture active | p95 at most 300 ms on the reference setup |
| Key release to insertion dispatched | p50 at most 2 seconds; p95 at most 5 seconds for the warm corpus |
| End-to-end visible text | Measure separately in the compatibility apps; disclose paste/AX observation limits |
| Under one second after release | Stretch goal only; do not market as a guarantee |
| Longest supported recording | 60-second boundary cancels safely; a 59-second sample completes within the inference deadline |
| Ready idle resources | No microphone activity, no inference loop; average CPU below 1% of one core over five quiet minutes |

Also report fresh-model preparation, cold app launch, peak memory, installed bytes and 100-session memory behaviour. No crash, unbounded queue growth or monotonic retained-audio growth. After warm-up, investigate retained-memory growth above 10% across the next 100 same-size sessions; allocator caching alone is not automatically a leak. Never put model download/compilation inside a claimed warm latency measurement.

### 9.2 Speech and integration quality

Maintain a fixed, redistributable manifest with reference transcripts: at least 20 English and 20 French speech clips, including ten developer-oriented clips across the two languages; plus ten silence/room-noise clips and five quiet-speech clips. Include multiple speakers where available and disclose corpus limitations. Keep a held-out subset for final validation so threshold tuning does not use all evaluation audio.

Report word error rate per language, with a committed normalisation policy (case/punctuation ignored, accents retained). Proposed M4 gates: English WER at most 20%, French at most 25%, and at least 80% of a fixed list of key technical terms preserved. These modest gates support prompt dictation, not exact voice coding. Code switching and exact code syntax are not guaranteed.

No automatic insertion on any of the ten no-speech clips; quiet speech must be included in the accuracy report to expose an overaggressive silence gate. Validate microphone capture separately from file transcription with ten live short dictations in a consented local test session; do not retain those recordings.

Compatibility targets: TextEdit, Apple Terminal (including a Claude Code input check if installed), VS Code, Chrome plain textarea/contenteditable, and Slack's draft composer. For each, perform ten attempts covering caret insertion, selected-text replacement, Unicode, rapid cancellation and switching focus. Pass means exact insertion of the produced transcript once, no surrounding content loss, no unintended submission, and the documented clipboard outcome. A safety refusal is not a successful happy-path insertion. Mark unavailable apps blocked; do not claim "works everywhere" from TextEdit alone.

### 9.3 Mandatory adversarial cases

- Repeated key-down; release during audio startup; modifiers released in either order; tap disabled; missed key-up; shortcut conflict.
- Escape during capture/inference/insertion preparation; stale completion after cancellation; rapid next session; sleep/lock while busy.
- Switch app/window/field while decoding; move caret/type; target exits; password/secure input; no editable field.
- AX unavailable; AX ambiguous error after possible write; delayed paste; concurrent user copy; rich/image/lazy clipboard; crash/quit before restoration.
- 44.1/48 kHz and stereo conversion; silence, quiet voice, 59/60-second boundaries; device unplugged or changed.
- Interrupted/corrupt download; insufficient disk; unavailable tokenizer while offline; bad model selection; failed switch/rollback; permission revoked.

Test deterministic state/transaction logic with fakes, the real engine using fixtures, and real OS boundaries on a Mac. Network isolation evidence must include both an offline run and inspection for unexpected outbound attempts/logged content; disconnection alone proves resilience, not absence of attempted calls.

## 10. Milestones and acceptance

### M0 - Native foundation and feasibility

Create the project, shared schemes, scripts, modules and menu bar shell. Record toolchain and environment. Integrate the pinned open-source WhisperKit package and a manifest-backed multilingual base model. Run one real fixture through the actual engine when Mac/model access is available; prove cold offline reload before building a large settings UI. Use the same production adapter, not a throwaway `whisper.cpp` spike that cannot validate WhisperKit.

**Exit:** Clean local Debug build and unit-test command pass; menu bar app launches; dependency/model pins and real integration result are recorded. Unsupported environments are explicitly blocked. No remote, CI or distribution credentials.

### M1 - Safe vertical slice

Deliver minimal permission onboarding, default hold shortcut, bounded capture, fixed-model ASR, indicator and controlled clipboard insertion into TextEdit and Terminal. Implement cancellation, target guard, modifier-release handling, no-speech handling and no-newline policy now. Do not postpone these until polish.

**Exit:** Ten consecutive happy-path dictations per target insert once; no Return; denied permissions fail visibly; cancellation/focus changes do not paste; buffer lifecycle and busy behaviour pass tests. First warm latency measurement recorded.

### M2 - Insertion reliability and recovery

Add safe selected-text AX insertion for validated controls, target adapters, clipboard preservation and Recovery. Complete the five-app matrix with actual versions and insertion methods. Test rich text, Unicode, selections, secure fields, ambiguous writes and concurrent clipboard changes.

**Exit:** Compatibility happy paths and adversarial insertion cases pass on available targets. No whole-field writes, duplicate retries, known overwrite of newer clipboard data or automatic insertion into invalidated targets. Missing apps remain blocked evidence, not an implied pass.

### M3 - Settings and model lifecycle

Add rebind, language choices, curated model picker, download/import/delete, safe switching, launch at login and persistent settings. Benchmark supported candidates and select the fastest that meets the quality gates on the reference device; document the selection. Default to the validated base model until comparative evidence exists.

**Exit:** Settings change without code edits; failed downloads/switches preserve the previous installation; offline restart works; launch-at-login status is truthful. No first-hold download or compile masquerading as Ready.

### M4 - Local daily-driver candidate and handoff

Harden lifecycle/errors, finish accessible status and onboarding, run the quality/performance/adversarial matrix and create a local Release `.app` using the documented local signing route. Provide a stable install/run path, limitations and the full evidence bundle. Exclude signing credentials, notarisation, public tags, DMGs and release uploads from this milestone.

**Exit:** M0-M3 gates plus section 9 pass; no known content-loss, duplicate-insertion, unintended-submission, background-recording or app-originated transcript-upload defect. Exercise the app on macOS 14 and the actual primary development OS if different; missing minimum-OS runtime coverage is a blocked acceptance item. Hand off the local build and actual results. If real-device checks cannot run or thresholds fail, hand off implementation and exact blockers; do not label M4 accepted. Stop before M5.

## 11. M5 - Public repository and hosted build, explicitly gated

M5 starts only when the owner says they are ready and supplies/chooses the repository destination and public licence. Its required scope is **public source plus automated build/test**, not feature expansion. Do not require a paid Apple membership merely to open-source or compile.

### M5A: repository and CI

1. Confirm owner/name, public visibility, licence/copyright and approved contents. Scan tracked files and Git history for secrets, personal fixtures, model weights and private metadata. Any history rewrite requires a separate concrete decision; never silently publish sensitive history.
2. Prepare the repository contents, README, licence, third-party/model notices and contribution instructions. Create/push the public repository only under the owner's M5 authorisation.
3. Add GitHub Actions using a currently available explicit macOS runner and selected Xcode version; use an arm64 runner for real arm64 WhisperKit inference. Reuse the local scripts rather than creating a second build system. Set timeouts, cancellation and least-privilege permissions; pin third-party actions to reviewed commit SHAs.
4. On pushes/PRs, resolve locked dependencies, build and run unit tests; run fixture integration where assets and runner permit. Do not make real microphone, privacy prompts or interactive desktop tests a PR-runner gate. Preserve the real-Mac checklist for releases.
5. Keep untrusted PR jobs secret-free and read-only. Do not execute PR-controlled code with privileged `pull_request_target` context. Cache dependencies with OS/toolchain/lockfile keys; do not hide missing model/license prerequisites behind stale caches. [S10]
6. Upload a development build and test reports with explicit retention and "not notarised" labelling. Produce useful logs without sensitive contents. A clean runner must pass and a deliberately failing test must make CI fail.

**M5A exit:** Authorised public repository exists; default-branch and PR builds pass from a clean runner; contributor commands match CI; branch protection is configured where available and authorised; missing real-device evidence remains visible. No public binary release is implied.

### M5B: optional signed distribution

Only proceed if the owner also authorises public binaries and supplies Developer ID/notarisation access. Enable and validate Hardened Runtime and required audio entitlement, sign the app, create the chosen archive/DMG, notarise, staple and check Gatekeeper behaviour on a clean Mac. Apple requires the relevant Developer ID signing and hardened-runtime setup for notarisation. [S11-S12]

Keep signing secrets in an approved protected release environment; restrict release jobs to authorised tags/manual dispatches from trusted code, never forks/PRs. Review the concrete artifact and release notes before the final authorised publish action. If credentials or Apple membership are absent, finish M5A and mark M5B deferred. Do not weaken Gatekeeper or present an unsigned artifact as a signed release.

## 12. Ready-to-use implementation prompt

> Implement sections 1-10 of this PRD through M4 in the supplied local project. Begin by checking the execution environment and creating the requirement/evidence ledger. Make routine engineering decisions yourself, record them, and continue across milestones without asking for milestone-by-milestone approval. Use the real native macOS and open-source WhisperKit paths; pin dependencies and assets. Run local build/tests from M0. Prioritise cancellation, no content loss, no duplicate insertion and honest privacy boundaries. When real OS/hardware access is missing, complete independent implementation and record the specific blocked validation; never invent passing results. Deliver the source, locally built app if available, scripts and evidence bundle. Do not create a public repository, push, configure hosted CI, use release credentials, notarise or publish. Stop with the M4 handoff. M5 is a separate explicitly authorised task.

## Appendix A. Adversarial review of the original

Severity: **Critical** risks lost content, unintended disclosure/action or an impossible delivery contract. **High** prevents reliable acceptance or core use. **Medium** creates avoidable scope or support risk. These are specification findings; no implementation was available to inspect.

| ID / severity | Original reference and adversarial challenge | Resolution in this PRD |
| --- | --- | --- |
| R01 Critical | p6 M4 exits with a public release and signed/notarised DMG. How can an autonomous local agent finish without a public repo or credentials? | M4 is local; public repository/build is M5A; credential-dependent release is separate M5B. Sections 1, 10-11. |
| R02 Critical | p4 proposes setting the focused element's value. What prevents replacing a whole draft or losing rich formatting? | Selected-text insertion only in verified adapters; whole-value mutation forbidden. Section 6. |
| R03 Critical | pp2-3 say insert at the currently focused cursor. What if the user switches to a terminal/password field during decoding? | Capture target identity, invalidate on interaction/focus changes, revalidate and recover; no refocus. Sections 4, 6. |
| R04 Critical | p6 says save and restore the clipboard. What if the user copies an image meanwhile, or the target reads the paste late? | Bounded full snapshot, ownership checks, tested delay, no overwrite of known newer data, explicit limits. Section 6.1. |
| R05 Critical | pp1,4 call the app private while using a shared clipboard and cloud destination apps. Does "no data leaves" survive Universal Clipboard? | Restrict promise to app-originated transmission and local ASR; explain system/destination boundaries. Section 8. |
| R06 High | pp1,3 promise sub-second final text without a model, corpus, Mac or warm/cold distinction. Can this claim fail on an M1 or first load? | Measured latency gates, warm/cold separation and a stretch goal; no invented benchmarks. Section 9. |
| R07 High | pp2-4 conflate event observation, suppression, posting and three mandatory grants. What happens when a grant is missing or revoked? | Capability-specific onboarding, early in M1, tested on real OS; deny/revoke states. Section 7. |
| R08 High | pp2-4 omit session state and cancellation. What if key-up is lost, capture starts after release, or an old task finishes late? | Explicit transaction states, IDs, deadlines, watchdog and cancellation. Section 4. |
| R09 High | p3 allows terminal auto-newline as a later variation. Can dictation execute a shell command or send a message? | No Return, no control characters or multiline automatic paste; no command interpretation. Sections 2, 5-6. |
| R10 High | pp3-4 offer multiple insertion fallbacks. What if AX writes but times out and then paste also runs? | At most one potentially mutating path; ambiguous outcomes recover without retry. Section 6. |
| R11 High | pp3-4 list model names without exact assets, integrity, tokenizer paths or API pins. Can the agent build a model picker whose choices do not load offline? | Curated immutable manifests, actual artifact validation and offline restart gate. Sections 3, 7. |
| R12 High | p4 implies WhisperKit is a wrapper equivalent to whisper.cpp and recommends a different-engine spike on p7. Does that validate the production integration? | Native WhisperKit adapter and real fixture spike in M0; exact product/API verification. Sections 3, 10. |
| R13 High | pp3,6 postpone onboarding/errors and omit hallucinations on silence. Could the MVP hang or paste fabricated speech? | Minimal onboarding and no-speech/cancellation handling in M1; negative corpus. Sections 4-5, 9-10. |
| R14 High | p6 says "works in top 5 apps" without versions, trial counts or evidence. Can all tests pass using mocks? | Named compatibility matrix, real OS checks and PASS/FAIL/BLOCKED ledger. Sections 1, 9. |
| R15 High | p4 only says buffer AVAudioEngine audio. How are sample rate, channels, device change and memory bounds handled? | Explicit conversion, bounded capture, route-change cancellation and fixtures. Section 5. |
| R16 Medium | pp3,6 bundle all model sizes, cleanup, history and Homebrew into the roadmap. How does an agent know when to stop? | Narrow curated models; optional features removed from M0-M5 completion criteria. Sections 1-2, 7, 11. |
| R17 Medium | p5 gives fixed CI runner/pricing claims and treats build, signing and release as one pipeline. What if credentials or a runner are unavailable? | Revalidate runner/toolchain at M5; build-only CI succeeds independently of signing. Section 11. |
| R18 Medium | pp2,7 leave default shortcut, language, licence, exact platform and launch behaviour ambiguous. Which choices require the owner now? | Implementation defaults fixed; public identity/licence deferred; hardware measured rather than assumed. Sections 1-2, 7, 11. |

### Residual limitations to carry into the handoff

- No universal, atomic text insertion or clipboard restoration API is assumed. Tested adapters and conservative recovery reduce, but cannot eliminate, external-app races.
- Speech quality, first-load cost and hotkey latency remain unmeasured until implementation on a real reference Mac. The new thresholds are a proposed product contract.
- An autonomous code agent cannot grant macOS privacy permissions or manufacture missing hardware access. These are explicit environment prerequisites, not reasons to stop all implementation.
- macOS 14 is the intended deployment minimum. Until exercised there, report minimum-OS runtime validation as blocked, even if the project compiles with that target.
- M4 preserves local daily-driver scope. Public licence, repository identity and optional paid distribution remain owner-controlled M5 decisions.

## Appendix B. Sources and verification notes

Reviewed 22 September 2026. Primary sources support the platform observations below; the safety policies, default values and acceptance thresholds in this PRD are design recommendations. Apple symbol pages expose limited text to web retrieval, so the implementing agent must confirm exact signatures and permission behaviour in its selected SDK and on-device. Do not treat linked mutable `main` source as the implementation pin.

- **S1:** [Argmax open-source Swift SDK / WhisperKit](https://github.com/argmaxinc/argmax-oss-swift). Current upstream repository and distinction between OSS and Pro offerings.
- **S2:** [Package manifest](https://github.com/argmaxinc/argmax-oss-swift/blob/main/Package.swift). Product/deployment/toolchain inspection; verify the selected pinned release separately.
- **S3:** [WhisperKit configuration source](https://github.com/argmaxinc/argmax-oss-swift/blob/main/Sources/WhisperKit/Core/Configurations.swift). Model/download/prewarm controls, compilation-cache notes and decode/logging options.
- **S4:** [Apple TN3136: sample-rate conversions](https://developer.apple.com/documentation/technotes/tn3136-avaudioconverter-performing-sample-rate-conversions). Correct AVAudioConverter conversion path.
- **S5:** [Apple selected-text attribute](https://developer.apple.com/documentation/applicationservices/kaxselectedtextattribute) and [AXUIElementSetAttributeValue](https://developer.apple.com/documentation/applicationservices/1460434-axuielementsetattributevalue). API reference; app-specific insertion behaviour still requires tests.
- **S6:** [Apple NSPasteboard changeCount](https://developer.apple.com/documentation/appkit/nspasteboard/changecount). Ownership-change tracking.
- **S7:** [Apple NSPasteboard](https://developer.apple.com/documentation/appkit/nspasteboard). General pasteboard and Universal Clipboard boundary.
- **S8:** [Apple listen-event preflight](https://developer.apple.com/documentation/coregraphics/cgpreflightlisteneventaccess()) and [post-event preflight](https://developer.apple.com/documentation/coregraphics/cgpreflightposteventaccess()). Verify with AX trust checks and the actual event-tap implementation on-device.
- **S9:** [Apple SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice). Login registration API.
- **S10:** [GitHub Actions secure use](https://docs.github.com/en/actions/reference/security/secure-use). Least privilege, pinned actions and untrusted-code boundaries.
- **S11:** [Apple notarisation guidance](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).
- **S12:** [Apple resolving notarisation issues](https://developer.apple.com/documentation/security/resolving-common-notarization-issues). Developer ID signing requirements.

The supplied PDF is the source for original-page references in Appendix A. This review does not reproduce its unsupported competitor-pricing, blanket App Store incompatibility or CI-cost claims.
