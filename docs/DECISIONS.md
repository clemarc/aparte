# Decisions

## D001 — Build and toolchain
- Question: reproducible native build without extra developer tooling?
- Adopted: Xcode macOS 14 arm64 app plus local Swift package modules, checked-in project/schemes and lockfile. Use installed Xcode 27/Swift 6.4; ad-hoc local signing, no team.
- Rationale/evidence: host has Xcode/SDK 27 and arm64; PRD requires Xcode app and testable modules.
- Alternatives: generated-only project adds prerequisite; SwiftPM-only executable fails explicit app-target requirement.
- Uncertainty: runtime coverage on macOS 14 unavailable, retain BLOCKED status.
- Affects: build/scripts; change cost low. Final review: no.

## D002 — Safety validation and adapter enablement
- Status: superseded for operational enablement by owner-approved D013 (2026-09-24). Original rationale follows; live acceptance still requires evidence.
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
- Status: superseded for snapshot eligibility by owner-approved D013 (2026-09-24). Historical proof and restoration ownership guard remain relevant.
- Question: how to enforce the PRD's refusal of lazy data without accidentally invoking its provider?
- Adopted conservative interpretation: automatic snapshot accepts an empty clipboard or a matching change-count receipt for an eager write made by this adapter. Unknown nonempty clipboards go to Recovery before data access. Full multi-item representations are preserved for provably eager content.
- Evidence: a separate real AppKit owner process supplied a lazy `NSPasteboardItemDataProvider`. The public `PasteboardGetItemFlavorFlags` returned 0 for its actual string flavor; fetching the data invoked the provider. Implicit system-translated flavors had promised flags but are not owner-supplied data. Both same-process and cross-process tests exposed this. Temporary diagnostics were removed.
- Alternatives: treating flags=0 or a fast provider as proof of eagerness violates the explicit refusal requirement; private APIs are inappropriate. An unsafe override is not provided.
- Conflict/uncertainty: public eager/lazy classification is insufficient on this host. Therefore general externally-owned rich/text/image clipboard happy-path acceptance remains BLOCKED by this OS/API limitation, even though safety tests pass. The app explicitly offers Copy instead. This restricts clipboard automatic insertion significantly; it is not full M2/M4 acceptance.
- Final review additionally found that function-argument evaluation could read a newer owner’s lazy data during restoration. Production now checks ownership before any representation access and again between reads; a separate-owner regression verifies refusal without provider invocation. Residual check-to-read races remain a public-API limitation.
- Affects: clipboard and Terminal/VS Code/Chrome/Slack automatic paste; low implementation change cost if a reliable public method becomes available, high validation importance. Final review: yes, highest impact.
- Earlier M2 helper tests passed full snapshots before this stronger adversarial case exposed the limitation; that evidence is not being presented as full acceptance. Tests now distinguish known eager writes from unknown foreign provenance while retaining strict lazy refusal.

## D009 — M3 model default and fixed quality corpus
- Question: fastest supported model meeting the unchanged quality gates on this reference Mac?
- Adopted: multilingual small is the new-install default. Existing saved base selections remain respected. Base remains available but its technical-term quality gate failed.
- Evidence: same frozen 55 synthetic clips, Auto language, Release adapter. Base EN/FR WER 2.35%/10.81%, terms 50% (FAIL). Small EN/FR WER 0.64%/4.87%, terms 83.33% (PASS). Both reject 10/10 no-speech clips. Small quiet WER 0%; 30 warm decode p50/p95 0.401/0.821 s; 100-session resident growth 0.035%, peak ~803 MiB. These are decode-only results, not insertion latency.
- Alternatives: base is faster but fails the explicit 80% terms gate. Turbo adds download/resource/validation cost without need for an additional quality-passing candidate; left out as optional.
- Assumptions/limitations: corpus uses original CC0 reference text and four installed synthetic voices (two/language); ten ordinary held-out clips plus quiet/noise held-out subsets; thresholds were not tuned on held-out output. Audio generated locally, not redistributed. Natural microphone speech and end-to-end latency remain unvalidated. Final model-selection generalization is provisional until live tests.
- Affects: default preferences, README/benchmarks; very low switching cost, moderate revalidation cost. Final review: yes.

## D010 — Layout-independent physical shortcut and local identity
- Adopted: shortcuts persist physical macOS key codes and modifiers; settings label US physical positions and explicitly disclose this. The binding test verifies event delivery without recording; microphone grant is not required. D011–D012 extend it with explicitly labelled local delivery when global capability is unavailable.
- Question: represent configurable chords without promising universal layout/conflict behavior?
- Rationale: physical chord stability is simple and matches CGEvent matching. Reserved/unsupported keys are rejected; matching original key-up remains owned after changes/cancellation.
- Alternatives: character-based matching changes with layout/Option composition; a layout-aware label can be added without changing stored chords.
- Uncertainty: non-US layout and per-app conflict UX requires physical validation. Affects hotkeys/settings; low cost to improve labels, medium to change storage semantics. Status adopted. Final review: yes, lower impact.

## D007 update — M4 review
- Small passed the frozen quiet/no-speech corpus with unchanged thresholds. Natural room-noise/microphone robustness is still unvalidated.
- Sanitization additionally removes Unicode format controls (e.g. bidi overrides) except ZWJ/ZWNJ, preserving emoji/legitimate joiners. A regression test covers this; no visible words are rewritten.

## D011 — Capability-specific setup readiness (0.4.1)
- Question: why should an event-posting preflight prevent microphone diagnostics, shortcut rebinding or creation of a listening/suppressing tap?
- Adopted: model + microphone suffice for explicit in-app audio tests. Global dictation requires microphone, prepared model, Accessibility and a successfully enabled real event tap. Event posting remains checked before the separate clipboard paste operation; selected-text AX and app-owned insertion do not post keyboard events. Recheck reconstructs an idle tap and prepares an installed selected model; app activation/capability changes recheck automatically. Show every missing prerequisite.
- Evidence: user reports Microphone/Accessibility granted but stuck Needs setup. Source had posting preflight as an unconditional gate before even trying the event tap. The recorder also competed with that tap for the current binding. This explains possible failure paths; the precise running-app permission state could not be observed because native inspection failed closed.
- Alternatives: treating all three permissions as mandatory or prompting repeatedly rejected; marking global readiness from a successful local test rejected. No permissions/security settings are changed by code or agent.
- Uncertainty: ad-hoc rebuilds may change TCC identity and require owner re-grant/restart. Real user verification remains required. Affects permissions/coordinator/hotkeys; low implementation change cost, meaningful platform validation cost. Status adopted. Final review: yes.

## D012 — Explicit setup diagnostics and owned test editor
- Question: how to let the user isolate microphone/ASR and shortcut/insertion failures without relying on an unvalidated external target?
- Adopted: user-requested Start/Stop microphone test shares the bounded production capture, cancellation/deadline, speech gate and real WhisperKit engine. A native app-owned editable test box uses the same hold gesture/capture/ASR then exact selected-range insertion, guarded by focus, selection and edit revision. Local shortcut delivery is explicitly labelled when no global tap exists. The test does not enable any external compatibility adapter.
- Alternatives: prerecorded/mock results would not validate the microphone; bypassing external adapter gates would misrepresent compatibility. Separate audio/inference implementations would duplicate lifecycle risks. Test-only button recording is the user's explicit extension to hold-only production dictation, not a general toggle-to-talk mode.
- Privacy: no recordings saved; the diagnostic transcript shares the one Recovery slot. Test editor/result clear on Setup close, lock, quit, explicit clear or five-minute expiry. Closing/cancelling invalidates late completions. Undo is disabled for the test editor. No diagnostic transcript enters logs or evidence.
- Shortcut recorder now owns first responder, handles modifiers and Command equivalents, previews entered keys and suppresses new global gestures only while rebinding; original owned key-up still consumed. This removes dependence on an unverified global permission for rebinding.
- Uncertainty: native UI/live microphone verification blocked by tool transport failure; policy regressions and real file inference are distinct evidence. Affects Setup UI/coordinator/local event handler; moderate change cost. Status adopted. Final review: yes, test scope and retention.

## D013 — Usable guarded insertion and bounded foreign clipboard preservation (0.4.2)
- Question: how to fix every external dictation going to Recovery despite working transcription?
- Status: adopted, owner-approved 2026-09-24 after explanation of the D002/D008 restrictions and proposal to revise them; owner instructed “ok then do the fix for the clipboard now”. This explicitly amends the original PRD's prevalidation enablement gate and prohibition on materializing ordinary lazy clipboard data. It does not pass or weaken the real compatibility acceptance matrix.
- Chosen: enable the five named app adapters for known text roles with existing secure-input, process/window/element/selection, modifier, clipboard ownership and no-retry checks. Keep `enabled` separate from `validated` evidence (the latter remains empty). TextEdit prefers settable selected-text AX; choose clipboard before any mutation if AX is unavailable. Never fall back after an AX attempt. Unsupported apps/roles still use Recovery.
- Clipboard: attempt to preserve every original owner-supplied representation, including ordinary data materialized by its provider, off the UI thread within 500 ms and 8 MiB. Reject explicit promise/lazy marker types, unavailable/oversized data, timeout or ownership change before writing. Ignore only OS-generated translation flavors. Restore after one second only while our marker/text/changeCount still match. Never read a newer owner during restoration. One worker remains occupied until an outstanding native read unwinds; timed-out work cannot write. A single native read may allocate more than 8 MiB before its size can be inspected; the limit bounds the accepted snapshot, not OS allocation. No snapshot/transcript is persisted.
- Rationale/evidence: source inspection found `validated: []` disabled all external apps, and D008 rejected any ordinary clipboard from another owner. The owner confirms setup transcription works but external insertion only enters Recovery. Isolated real AppKit/Carbon tests exercise a separate fast lazy provider, a separate rich/image/multi-item owner, a delayed provider timeout, exact representations restored after the owner exits, concurrent copies and refusal to read a newer lazy owner. These do not establish visible paste consumption in an external app.
- Alternatives: retain Recovery-only behavior (rejected by owner's requested fix); always clobber the clipboard/plain-text-only snapshot (loses copied content); accept any app/control (overbroad scope); claim fast reads prove eagerness (false on this OS); automatic retries (duplicate risk). Explicit Copy remains available for refusals.
- Assumptions/uncertainty: ordinary provider requests can trigger owner/OS work, including Universal Clipboard. Public APIs cannot cancel an in-flight synchronous read or make focus/paste/restore atomic. Real target paste consumption, rich context preservation and slow/custom handlers remain BLOCKED by the native desktop-tool crash, not by an asserted missing owner grant. Known failing target combinations must be removed/scoped in the enabled catalog. Recovery now distinguishes refusal reasons from a backup after a single attempted write; an attempted write remains unconfirmed (D006).
- Affected: compatibility catalog/target service, clipboard service, recovery UI, documentation and policy tests. Changing adapter enablement or eligibility is inexpensive and localized; validating different apps/OS versions is the substantial cost. Final review: yes, highest impact; prioritize actual target tests and one-second paste-consumption timing before revisiting the delay or broadening app support.

## D014 — Explicit launches reveal Settings (0.4.3)
- Question: why does opening Aparté appear to do nothing after first onboarding?
- Status: adopted. The 0.4.2 app was running at the stable installed path with a valid signature. A one-second native process sample showed the main thread waiting normally in AppKit's event loop; no matching crash report was found. Source showed Settings only if `onboardingSeen` was false and did not handle reopen events. This explains a visible entry-point defect, although actual screen state could not be inspected.
- Chosen: ordinary launch shows Settings & Setup; opening an already-running app reveals the retained window and restores it if minimized. Login/service launches identified by public Apple event metadata stay quiet. Keep LSUIElement/accessory behavior and no normal Dock icon. Existing preferences/models are preserved; the obsolete onboardingSeen preference is no longer used as a visibility gate.
- Alternatives: tell the owner only to find the menu bar item (leaves the explicit Open action ineffective); add a persistent Dock icon (violates product scope); delete settings/onboarding state or change TCC (unrelated and unnecessary). A new startup diagnostics subsystem would add scope without addressing the missing handler.
- Assumptions/uncertainty: inferred visibility failure from process/source evidence, not a verified screenshot. Real minimized-window, login-cycle and visual tests remain pending due to the unchanged desktop-tool crash. SDK AERegistry.h documents the login/service launch markers; no private API used.
- Affects: AppDelegate lifecycle and Settings visibility only; low change cost. Final review: yes, low impact; revisit window-on-explicit-launch behavior if owner prefers a different entry point after testing.
