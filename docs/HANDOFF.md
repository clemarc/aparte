# Aparté M4 local handoff

**Implementation complete through the feasible M0–M4 scope; validation pending. M4 is not accepted.** Version 0.4.8 includes the owner-approved D013 clipboard preservation, D018 system-wide editable-field insertion and D019 guarded ChatGPT focus fallback. No M5 work was started.

## 0.4.8 ChatGPT focus update

The owner retried 0.4.7 and showed that ChatGPT exposed no focused element to either direct AX lookup. Version 0.4.8 asks for the accessibility tree using Electron's documented setter without requiring metadata to advertise it, then looks for one focused standard text control in the active AX window within 96 nodes, 10 levels and 300 ms. If none can be identified, insertion still refuses safely. The signed Release and 41 tests pass; installed 0.4.8 is the only running Aparté. Actual ChatGPT insertion remains BLOCKED pending the owner's retry; no desktop UI tool is available to validate it independently. See D019 and chatgpt-focus.json.

## 0.4.7 system-wide insertion update

The earlier list of “authorised apps” was Aparté's own catalog restriction. It is removed. Standard accessible editable AXTextField, AXTextArea and AXComboBox controls in any foreground app can use guarded clipboard insertion; known app entries are method overrides, and real validation entries remain empty. Its first Electron accessibility preparation required settable metadata. Secure, explicitly disabled/read-only, unknown and inaccessible controls still use Recovery. Release and 41 tests passed. The ordinary signed update used the same designated requirement and no permission changes. An older concurrent Debug copy was closed orderly. The owner's subsequent ChatGPT retry showed the missing-focus failure addressed by 0.4.8. See D018 and system-wide-insertion.json.

## 0.4.6 destination focus update

Owner confirms correct permissions but shows the “no focused text field” Recovery message. That branch follows a non-rejected transcription. The new build queries the foreground app's focused element directly, with guarded system fallback, and resolves/compares original window identity consistently. Unsupported apps now get a named explanation before AX lookup. The same signing identity is retained. Release and 38 tests pass; actual destination success is still pending because the owner has not identified the app/field and native UI inspection is blocked. See D017 and focus-resolution.json.

## 0.4.5 stable signing update

Installed and opened 0.4.5 with a persistent local-only signing certificate (D016). Debug/Release binaries differ but satisfy the same actual designated requirement. Tamper/ad-hoc negatives and all 38 tests pass. Builds fail rather than fall back; installs require compatible identities and a stopped app. The one-time switch from ad-hoc signing was performed explicitly. Private signing material remains outside Git; no trust or TCC changes. See LOCAL-SIGNING.md and stable-signing.json.

Owner action: verify/grant this newly signed app once, then test microphone and permission continuity after a later normal update. Existing enabled checkboxes may belong to the old ad-hoc identity. No live persistence success is claimed yet.

## 0.4.4 microphone diagnostics — reported issue unresolved

The owner reports granted microphone access but missing sound. Read-only device checks found the built-in default input alive/unmuted with nonzero volume; no microphone recording was made. Version 0.4.4 displays actual engine input name, received seconds and a live meter, plus separate no-frames/silent/quiet/ASR-rejection reasons. Release and all 38 tests pass; real file ASR passes. The cause is not established and microphone repair is not claimed. Next: use Start recording, speak, Stop, and report the displayed status and whether the meter moved. D015 explains the unchanged thresholds and transient diagnostics.

## 0.4.3 launch visibility update

The installed app was running but only showed Settings on first onboarding and ignored later reopen requests. Explicit launch/reopen now reveals Settings, restores a minimized window, and preserves quiet login/service startup (D014). Release and all 36 tests passed. Installed and restarted 0.4.3; the new process remained alive after 21 seconds. Actual window visibility still needs owner confirmation because native visual tooling remains unavailable. See startup-fix.json.

## 0.4.2 clipboard update

Supported text fields in TextEdit, Terminal, VS Code, Chrome and Slack can now receive guarded insertion. Ordinary foreign clipboard data is saved/restored within the existing limits, including fast provider-backed data. Unsupported/slow/oversized content still uses Recovery, with a specific reason. A backup after an attempted paste does not mean the paste failed. See D013 and clipboard-fix.json; real target compatibility remains unverified.

## Previous 0.4.1 setup update

The owner reported grants were already enabled but setup remained blocked, and shortcut capture was not displaying the chord. The updated app shows exact readiness blockers, recreates the listener on Recheck, and prepares an installed selected model. A native recorder previews modifiers and chords without competing with the global binding. Start/Stop microphone testing and an app-owned end-to-end text box both use the production audio/WhisperKit path. In-app versus global shortcut delivery is labelled. See D011–D012 and README's Test Setup section.

The owner reports the Setup tests are working. The installed 0.4.3 includes the clipboard change and has been restarted. Owner-reported grants are acknowledged; do not blindly request them again. If still blocked, the status card and permission summary identify what this running build actually sees. Physical UI/live testing remains unverified because the desktop tool connection failed closed. External adapter acceptance is unchanged.

## Delivered

- Native arm64 macOS14+ source, Xcode project/shared scheme, testable modules and exact Swift dependency/model pins.
- Local development certificate-signed Release app at `~/Applications/Aparte.app` and `artifacts/DerivedData/Build/Products/Release/Aparte.app`; signature verified. No Developer ID, notarisation, DMG or public release.
- Verified public multilingual small model installed under `~/Library/Application Support/Aparte/Models/small/` for offline use. Base/small evaluation assets remain ignored in `artifacts/models/`.
- Native capture, WhisperKit inference, guarded target/AX/clipboard paths, transient recovery, configurable hold shortcut/language/model management and truthful launch-at-login controls.
- 41 passing tests including actual named-pasteboard and separate lazy-owner process checks; real offline engine/corpus, model installer, cancellation and model-switch evidence.
- Small passed the fixed synthetic WER, technical-term and no-speech gates. Base failed technical terms, so small is the default. Exact results/raw data and limitations are in BENCHMARKS.

M0 feasible gates passed. M1–M4 implementation continued despite missing permission/desktop prerequisites, as requested. Missing real-device evidence is not converted into acceptance. The final clean-checkout verification result is recorded in `docs/evidence/verification.json` and PROGRESS.

## Important limitations / known behavior

Generic standard editable text controls are eligible across apps; five existing app entries select a method for their known roles. No app has completed the real validation matrix. D013 authorizes bounded foreign-data materialization; fetching it can cause work in its owner/OS. Snapshot reads time out at 500 ms without a paste, but the underlying native call can keep the single worker occupied until it returns. Explicit promise/lazy-marker types remain unsupported. Every representation must fit in 8 MiB; no plain-text-only degradation occurs. Focus/secure-field/ownership checks and no retries remain. Real delayed-target consumption and app/OS compatibility need the matrix below.

No live recording was collected. Quit and reopen any previously running instance to use the final rebuilt bundle. Microphone/Accessibility/posting, real global shortcut delivery, actual insertion correctness, visible indicators, VoiceOver, physical device changes, lock/sleep, launch-at-login cycle and macOS14 runtime have not been accepted. Native UI tooling failed; a helper SIGTRAP/Array.remove(at:) crash and closed pipe were observed on 2026-09-24. Installed app process launch and code builds are evidence of those narrow checks only.

File decode timings are not release-to-insertion latency. Synthetic speech quality is not natural microphone quality. Ordinary clipboard races and custom terminal paste handlers cannot be made atomic by this app. No Return is generated. Check an “Insertion unconfirmed” target before copying a recovery result again.

## Decision review, ordered by impact / uncertainty

1. **D019 / D018 — ChatGPT focus and system-wide editable-field insertion.** Highest current product impact and uncertainty: test ChatGPT 0.4.8 first, then representative controls in other apps. Eligibility and the bounded fallback are easy to narrow; custom inaccessible controls need separate evidence before any change.
2. **D016 — Stable local identity.** Retain the private signing directory and verify real grants survive a later normal update. Signature continuity passes; actual TCC persistence remains pending.
3. **D015 — Missing microphone sound remains unresolved.** The owner test status and meter will distinguish input delivery from recognition. Do not lower thresholds or switch devices without evidence.
4. **D013 — Bounded foreign clipboard reads and supported adapters.** Highest usability/privacy impact and uncertainty. Actual target matrix and one-second consumption timing are the valuable next checks. Catalog eligibility is inexpensive to revise; safe universal atomic paste/restore is unavailable. D002/D008 are superseded for runtime enablement, with their original rationale preserved.
5. **D011 / D012 — Setup readiness and diagnostics.** Owner reports tests working; formal global shortcut/permission-recovery and visual coverage remain incomplete. Changes are localized; retain separate in-app/global labels.
6. **D007 / D009 — Speech gate and small default.** Small passes the frozen synthetic corpus; real quiet/noisy microphone speech remains uncertain. Model switching is easy. Recalibrate on a separate calibration set, retain held-out data and the original gates; do not silently relax thresholds. Base's 50% term result remains a recorded failure.
7. **D003 — Local tokenizer protocol bridge.** It avoids upstream's remote fallback; bilingual and offline tests pass. Revisit when upstream offers a strict local-only public initializer. Replacement is localized but needs repeat offline/tokenizer/inference validation.
8. **D006 — Recovery after attempted insertion.** Conservative “unconfirmed” labeling avoids duplicate retries. Easy UX change, but any automatic retry would require stronger acknowledgement than the OS generally provides.
9. **D010 — Physical shortcut labels.** US physical key names are disclosed; test alternate layouts. Label improvements are inexpensive and do not require changing stored chords.
10. **D014 — Explicit launch visibility.** Low-cost UX change: explicit Open now reveals Settings. Verify minimized/reopened windows and quiet login startup; the actual UI connection remains unavailable.
11. **D001 / D004 — Toolchain and asset pins.** Xcode27 builds a macOS14 target, but minimum-OS runtime is missing. Asset updates require new immutable manifests and full real-engine checks. D005 only affects local author metadata, not product behavior.

## Consolidated remaining human / external actions

- [ ] In installed 0.4.8, click ChatGPT's editable prompt, hold the shortcut, speak, release, and check whether text appears exactly once. If it does not, report the exact Recovery reason and whether the prompt remained focused. Repeat in a disposable TextEdit document to distinguish ChatGPT-specific behavior. The owner reports permissions correct; do not reset/re-grant without a new failure. If microphone trouble recurs, use Setup Start/Stop and its meter. Grant access only if the running build reports it missing; follow Input Monitoring guidance only if the event tap requires it. Do not bypass security or reset TCC.
- [ ] Provide a consented local microphone session: ten short English/French/quiet dictations, no retained recordings. Measure shortcut-to-live-capture p95 and release-to-dispatch/visible-text timings; test default input, startup release, 59/60-second boundary, device unplug/change, missed key-up, permissions revoked, Escape, busy holds, sleep/lock/logout and stale completion.
- [ ] Run the ten-attempt matrix for TextEdit, Terminal/Claude Code, VS Code, Chrome textarea/contenteditable and Slack drafts as described in COMPATIBILITY. Use disposable/inert text, no submission. Validate exact insertion once, selection, Unicode, rich context, focus/caret invalidation, secure/read-only refusal, ambiguous writes, delayed consumers, concurrent clipboard copies and orderly quit. Add validated catalog entries only after evidence passes.
- [ ] Visually review onboarding/status/Recovery, keyboard navigation, contrast and VoiceOver with an available desktop UI connection. Native UI tool failure prevented these checks.
- [ ] If desired, explicitly test launch-at-login registration, approval, disablement and a real login cycle from the stable install. It was left off; no login registration was performed by the agent.
- [ ] Validate on macOS14 hardware/runtime and repeat any target-version-dependent checks there. Perform cold app-to-Ready and a five-minute **Ready** idle/no-microphone sample; the existing permission-free idle measurement is separate.

No routine implementation approval is pending. All remaining check results must update ACCEPTANCE with evidence; do not call this M4 accepted until the blocked gates pass.

## M5 readiness only — not begun

Owner must separately authorize M5 and choose public repository destination, visibility, licence/copyright and approved contents. Before publication, audit tracked files/history for private metadata, credentials and weights; review third-party/model notices. Any history rewrite needs an explicit decision. Only then configure a current pinned macOS/Xcode hosted build reusing local scripts, least privileges and no secrets in PR jobs. Optional public binaries require a separate authorization and Developer ID/notarisation credentials; do not weaken Gatekeeper or present this ad-hoc build as a notarised release.
