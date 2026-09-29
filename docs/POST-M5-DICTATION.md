# Post-M5 dictation UX scope

**Updated:** 29 September 2026

**Status:** Deferred feature scope, saved at the owner's request (D033). Resume after the owner's chosen M5/beta release work and an explicit feature implementation request. This document does not authorise starting the features, publishing a release, changing signing identities or passing any outstanding acceptance gate.

## Current foundation

The 0.5.0 development candidate implements D031's unified workspace and menu companion. D032 isolates **Aparte Dew** from the standard **Aparté** beta. Extend these surfaces rather than introducing another settings window or setup flow.

| Surface | Implemented foundation | Planned addition |
| --- | --- | --- |
| Try it | Real microphone check, app-owned editor, temporary results, no history | Exercise the selected recording mode and voice commands; compare original and processed text in memory |
| Processing | Recognition, four pinned models, language, active/preview distinction, Text handling off, insertion explanation | Offer all model-supported speech languages; enable voice commands; configure provider, LLM model, command phrases and per-command prompt enrichment |
| Shortcuts | Chord candidate, explicit Save/Cancel, precise rejection, detection-only mode | Select Hold or Double tap to start / tap to stop; detect the complete selected gesture without audio |
| Settings | Local access, capability recheck, login and diagnostics | Show optional-provider/privacy status; provider readiness must not block ordinary local dictation |
| Menu companion | Actual state, saved shortcut, active model, workspace and Recovery actions | Mode-specific recording guidance and real Formatting/Summarizing state |

Text handling is a placeholder today. All provider, prompt and gesture controls below are planned; no current build is claimed to expose them. Existing M4, UX and beta validation results remain in [ACCEPTANCE](ACCEPTANCE.md).

## Speech recognition language selection

- D036 records the owner's clarified request: expand Processing's **Auto / English / French** speech-language selector, not translate the interface. Keep **Auto** as the default; replace the three-item segmented control with a searchable picker of every language supported by the active speech model. Put Auto first, use readable language names and searchable names/codes, and store stable language codes rather than translated display labels.
- The current app passes `language: nil, detectLanguage: true` for Auto and an explicit code with detection disabled for a fixed choice. Auto is not restricted to English/French; `LocalTokenizer.allLanguageTokens` includes the engine's language codes that exist in the installed tokenizer. Fixed selection also supplies the decoder's language prompt. The pinned engine implements this in its detection/prefill paths. [WhisperKit decoding options](https://github.com/argmaxinc/argmax-oss-swift/blob/v1.1.0/Sources/WhisperKit/Core/Configurations.swift).
- Benefit: when the spoken language is known, an explicit choice skips detection and can avoid a wrong-language guess, especially for short or ambiguous recordings. This possible quality benefit is an inference from the decoding behavior, not an Aparté benchmark result. Detection work is avoided, but no measured latency gain or universal accuracy improvement is claimed. A wrong explicit choice can worsen the transcript. For English spoken with a French accent, choose **English**, not French; this is a spoken-language hint, not an accent or British/American spelling setting.
- For separate recordings in different languages, Auto remains convenient. Neither Auto nor fixed selection guarantees reliable language switching within one recording. Keep `task: .transcribe`, preserving the spoken language rather than translating to the UI language or English. This setting remains independent of optional LLM output instructions and saved voice-command phrases.
- Read-only checks of the pinned engine list and local tokenizer/decoder metadata on 29 September 2026 found **100 unique engine codes**, **99 language tokens in Base/Small/Medium**, and **100 in large-v3 turbo**; Cantonese (`yue`) is present only in Turbo's tokenizer. These are model/token compatibility observations, not 99/100-language quality passes. Derive the offered codes from the pinned engine list intersected with the selected model's verified tokenizer and valid decoder vocabulary; do not offer the same unfiltered list for every model or fetch a mutable network catalog.
- Extend preference validation, picker labels, active/preview summaries, and the transcription boundary together. The current `Preferences.decode` accepts only `auto/en/fr`; adding visible choices alone would lose them on restart. Preserve existing settings and separate Dew/standard storage. Validate an explicit code before decoding so a missing token cannot silently become English through the engine's fallback.
- If a model change would remove support for the saved explicit language, explain the mismatch and require Auto or a supported language before activating that combination. Keep the previous working configuration available; do not silently change language or download/switch models during dictation. Keep language selection disabled while a transaction is busy.
- Label support honestly: every verified model-compatible language can be selectable, while measured Aparté quality remains available only where actual evidence exists (currently the English/French corpus). Show concise guidance that recognition quality varies by language and model. No additional language pack or language-specific model download is implied for the existing multilingual models.
- Validation before shipping: enumerate valid codes/tokens, aliases and model-specific exclusions; persist/reload every offered choice; test invalid/stale saved codes and model-switch mismatches; verify Auto detection versus explicit-language prompting and unchanged transcription/cancellation behavior. Run representative redistributable fixtures beyond English/French, including a non-Latin script, and distinguish token-contract checks, fixture quality and real speaker/device evidence. Keep existing M4/beta acceptance gates visible. This checkpoint is documentation only; the current picker remains Auto/English/French.

## Recognition of French-accented English

- The reported issue is wrong words while speaking English with a French accent, not British spelling or translation. Do not introduce an unsupported “accent” selector or promise accent adaptation.
- Use Processing to select Auto or English and the existing Small, Medium or large-v3 turbo choices; use Try it to compare the same owner-spoken phrases. These larger choices are already implemented and benchmarked (D023–D024), so do not repeat model catalog work from the earlier proposal.
- Evaluate real speaker quality using consented, temporary in-memory audio. Keep only aggregate accuracy/timing evidence; collect no private recordings or transcripts. Existing synthetic scores do not validate the owner's accent.
- Keep Small as the safe default until measured evidence supports a deliberate change. Additional models, fine-tuning, custom vocabulary and code-switching guarantees require separate scope.

## Hands-free recording

- Add a recording-mode selector in Shortcuts: **Hold to talk** (existing default) and **Double tap to start / tap to stop**. Use the saved modifier-plus-key chord; this does not add Fn/Globe, modifier-only or bare-key bindings.
- In the new mode, two completed taps start capture; one later tap stops and transcribes. Proposed timing default: at most 350 ms between the first release and the second press. A lone first tap expires without opening the microphone; auto-repeat cannot count as another tap.
- Show Starting until live capture begins, then Recording with elapsed time and the correct stop instruction. A stop during startup cancels; no late microphone start is allowed. Preserve matched key-up ownership and modifier-clear checks before insertion.
- Preserve Escape, 60-second discard, sleep/lock/device/tap-disable cancellation and single-transaction behavior. Busy gestures are ignored; no hidden queue. Detection-only mode exercises the gesture without audio; explicit Start/Stop microphone controls remain available.

## Optional voice-triggered text handling

### Configuration in Processing

- Start disabled. Add separately enabled **Format** and **Summarize** commands, each with configurable trigger phrases. Support both explicit phrases (for example, “Aparté, format this”) and bare keywords (“format”, “summarize”) as the owner requested.
- Recognize enabled phrases only at transcript boundaries, not inside ordinary sentences; matching is deterministic. Remove a recognized command phrase before processing or raw fallback. Make bare-keyword false positives clear in configuration and allow users to disable those aliases.
- **Format** defaults to preserving meaning and technical identifiers while improving punctuation, paragraphs and lists. **Summarize** defaults to a concise paragraph without adding facts. No translation is performed unless deliberately requested through custom instructions.
- Provide separate optional **Additional instructions** editors for Format and Summarize. Append them to a labelled built-in instruction section; show the effective instructions and offer Reset. Users may enrich tone, style, language and terminology without replacing application-enforced insertion/cancellation/privacy controls.
- Use one configured provider/model for both commands initially. Configuration includes API format, API base URL, model identifier and optional API key. Enter a base URL such as `http://127.0.0.1:1234/v1`; the adapter appends its request/discovery routes without duplicating `/v1`. A user-initiated connection test uses a synthetic sample and clearly identifies its destination and selected model.

### LLM model selection and local onboarding

- Require an explicit LLM model for local and remote providers. Endpoint and credentials do not identify which model to use. Keep this picker separate from the existing Whisper speech-model selector, with one selection shared by Format and Summarize initially.
- Provide **Refresh models** through the selected adapter when discovery is supported, plus an always-available **Enter model ID** option for custom servers, aliases, restricted discovery and newly released hosted models. Use the exact API identifier; a display name or download filename is not sufficient. Show known text-generation compatibility when metadata supports it; a list entry alone does not prove generation access or readiness.
- Distinguish available/downloaded/loaded states only when the provider supplies that information. LM Studio's compatible list may include downloaded models under just-in-time loading, so do not label every listed model ready. [LM Studio List Models](https://lmstudio.ai/docs/developer/openai-compat/models).
- Scope saved selection and discovery results to API format and base URL, isolated between Dew and standard. An endpoint/API-format change invalidates prior test readiness and discovered options; credential changes also require retesting. Preserve a saved ID on refresh and mark it unverified if it disappears; allow a manual-ID test because discovery can be incomplete. If generation confirms that the model is unavailable, ask the user to select a replacement rather than silently switching model or provider. Ignore discovery/test responses for superseded configuration.
- Test an actual synthetic transformation with the selected model, rather than treating a successful model list as a successful connection. Unsupported discovery must not prevent manual selection or testing; failed tests must not block ordinary speech dictation. Remote tests identify the destination and possible provider charges and require the existing opt-in.
- Leave local model downloads/loading to the chosen runtime initially. Aparté does not install servers, download LLM weights during dictation or automatically select a cloud fallback. Readiness guidance links to the beginner [Apple Silicon local LLM setup guide](LOCAL-LLM-SETUP.md), using LM Studio with Apple's MLX runtime and no Ollama. The guide is source-reviewed documentation, not live-provider acceptance evidence.

### Provider boundary

- Keep a stable internal request containing command, stripped transcript, built-in instructions and that command's additional instructions. Return text or a typed failure. Do not require all providers to share identical HTTP payloads.
- Support an **OpenAI-compatible Chat Completions** adapter for OpenAI and compatible local/hosted servers, plus a **Claude Messages** adapter for Anthropic's native API. Translate instruction placement, authentication and response parsing in the adapter. Recheck official API contracts and model compatibility when implementing; no model identifier is hard-coded by this scope.
- Allow HTTPS remote endpoints and HTTP loopback endpoints. Local servers may omit an API key. Store secrets in macOS Keychain, separately for Dew and standard builds; keep only credential references in preferences. Never store or print keys in source, logs, diagnostics or exported configuration.
- Enabling a remote provider requires a one-time explanation/opt-in: an enabled spoken command automatically sends the stripped transcript and its instructions to the configured destination. There is no per-request confirmation by default. Audio, clipboard contents, surrounding document text and unrelated keystrokes are excluded.
- Keep recognition on-device. Ordinary dictation with no enabled command performs no provider request and works offline. Local endpoint configuration alone does not prove a server never proxies remotely; verify local inference offline and describe third-party retention honestly.
- Bound request/output size and duration, propagate cancellation, reject redirects and avoid tools, command execution, persistent conversations and automatic retries. Provider failure must not start a cloud fallback or change the speech model.

### Transaction and delivery

- Recognize the command after speech decoding, process it once, then deliver once. Do not insert raw text before requesting a transformation. Preserve the transaction identity throughout ASR, text handling and insertion; late responses cannot affect a newer session.
- Reflect real Formatting/Summarizing status in the workspace and companion. Escape/sleep/lock cancel the whole transaction; cancellation never triggers raw fallback or late insertion.
- On a provider error, timeout, empty/invalid output or unavailable configuration, use the original dictated content **without the command phrase**, as the owner selected. Explain that text handling failed. Apply the normal target guards; if those fail, use Recovery rather than paste elsewhere.
- Preserve D021's single guarded return to the original window and exact field/selection revalidation, plus D022's Recovery clipboard handoff and newer-copy protection. Custom prompts cannot enable whole-field replacement, synthetic Return, a second insertion attempt or secure-field bypass.
- Permit paragraph/list line breaks only where safe multiline insertion is established. Terminal, single-line and unverified multiline contexts use Recovery for transformed multiline output; do not flatten a requested list silently or auto-submit it.
- Keep original and processed text within the same short-lived, memory-only recovery/test result; retain the existing expiry/lock/quit/next-recording cleanup. Leaving Try it clears diagnostics without cancelling an external transaction. The system clipboard and a chosen remote provider may retain text independently.

## Validation and scope boundaries

- Gesture coverage: tap timing boundaries, repeat, modifier order, rebind/cancel ownership, stop during startup, missed events, 60-second limit, busy handling and physical delivery.
- Command coverage: both boundaries and phrase forms, punctuation/case, disabled aliases, normal internal uses of keywords, empty content and ambiguous/multiple commands. Ambiguous input must not launch an unpredictable transformation.
- Provider coverage: adapter payload/authentication/response contracts against a local test server; discovery supported/unsupported/denied, manual IDs/aliases, missing models, unloaded states, selection persistence and configuration changes during refresh/test; Keychain save/replace/delete; endpoint and redirect checks; malformed/oversized/truncated output; errors, timeout, cancellation and stale completions. Synthetic tests must not send private text or incur required paid-service usage.
- Quality/device coverage: real French-accented English comparisons, meaning/identifier preservation for Format, factual summaries, actual local offline processing and configured-provider integration. Unit or synthetic passes are separate from live-provider/device evidence.
- Delivery coverage: original-field return, target changes during processing, no duplicate insertion or Return, clipboard ownership, multiline acceptance/refusal and correct raw fallback. Keep outstanding M4 and beta device gates visible.
- Speech-language coverage: model-specific code/token enumeration, persistence, invalid-code refusal, model-switch compatibility, picker search/layout/accessibility, Auto versus explicit decoding and representative additional-language quality. Model support is separate from measured Aparté quality.
- This is optional text processing, not cloud ASR, autonomous agents with tools, history, background recording or automatic release publication. Provider choice does not change M5 signing/release permissions. Revisit the current privacy copy before shipping any transcript transmission.

## Resume order

1. Read this scope, current PRD amendments, progress and acceptance; inspect the actual branch and implemented UX.
2. Confirm the owner is starting this deferred feature checkpoint. Implement and verify the recording mode independently of providers.
   Speech-language expansion can be a separate owner-started checkpoint before or alongside these features; it does not depend on an LLM provider.
3. Extend Processing's Text handling stage, command policy and provider adapters; run synthetic contract tests before opt-in live integration.
4. Complete real gesture/quality/provider/insertion checks, update privacy and evidence, and deliberately select a release through the existing release process. Do not infer release approval from a version bump or feature completion.
