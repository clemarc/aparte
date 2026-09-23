# Compatibility

Automatic adapters are deliberately disabled until the real target/version protocol below passes. Candidate code is not evidence of successful insertion. `Resources/Compatibility.json` separates candidates from validated exact app/OS versions; unknown controls use Recovery. No whole-field AX writes, Select All, Return, per-character synthesis or automatic method retry exists.

| Target | Candidate method | Runtime result |
|---|---|---|
| TextEdit 1.20 (415) | Settable AXSelectedText only | BLOCKED: Accessibility and posting grants absent |
| Apple Terminal 2.15 (470.2) | Single-line clipboard Cmd-V | BLOCKED: same grants and live speaker required |
| Claude Code 2.1.267 in Terminal | Same terminal adapter, inert prompt only | BLOCKED: CLI installed; inert input session not verified; never launch executable commands from fixtures |
| VS Code 1.138.0 | Clipboard Cmd-V | BLOCKED: Accessibility/posting grants absent |
| Chrome 153.0.8010.53 textarea/contenteditable | Clipboard Cmd-V | BLOCKED: Accessibility/posting grants absent |
| Slack 4.52.155 draft composer | Clipboard Cmd-V, no submission | BLOCKED: permissions and target draft/login validation required |
| macOS 14 | All | BLOCKED: host is macOS 26.6 |

Native UI inspection failed with `Sky Computer Use native pipe closed before response`; after restart it failed with `timeoutReached`. This does not establish a UI or app defect. Process launch succeeded. Versions are recorded in the final environment evidence after inspection.

## Protocol to enable an adapter

Use disposable documents/drafts. Never send a message or test destructive commands. Capture target app version, macOS major.minor, method, produced transcript (synthetic only), exact resulting text and clipboard types/change behavior. Each target needs ten attempts covering: caret at end, caret mid-paragraph, selection replacement, accented French, non-BMP emoji, rich surrounding text, rapid Escape, app switch, window/field switch, and concurrent clipboard copy. Happy paths must insert exactly once without surrounding loss or submission; safety cases must insert nothing. Safety refusal is not a happy-path pass.

Test AX API success against actual visible content; after an ambiguous write, verify no clipboard fallback. For paste, test one-second restoration, including a deliberately slow consumer. Slow/custom consumers that lose text must remain disabled. Terminal must retain text as inert unsubmitted input; a custom paste handler may execute text and is outside Aparté’s guarantee. Remote desktops, password managers and elevated prompts are unsupported.

Only after evidence passes add the exact appVersion/osVersion and tested roles/method to `validated`. Rebuild locally. This is a developer evidence change, not a user override of safety.

## Clipboard limits

Real isolated named-pasteboard tests use the production snapshot/restoration implementation without touching the user's general clipboard. Full target paste/consumption remains an independent gate. Snapshot limit: 8 MiB/500 ms, rejects promised/lazy markers, absent representations, changed ownership or oversized data. Restoration: one second after paste, only matching changeCount/marker/text; newer copies are preserved. No atomic cross-process compare-and-swap or universal paste acknowledgment exists. Orderly quit/cancel tries conditional restoration; crashes cannot guarantee it.

## Discovered clipboard restriction (D008)

On macOS 26.6 a foreign AppKit lazy provider reports public flavor flags=0. The strict refusal test demonstrated that reading it invokes the provider. Automatic paste is therefore restricted to an empty clipboard or a matching receipt for an eager write by Aparté. Other nonempty clipboards use Recovery, even ordinary text. This is a deliberate safety restriction and a **BLOCKED general clipboard compatibility gate**, not a successful happy-path result. Rich/image/multi-item restoration tests cover adapter-owned eager writes only. See D008 for evidence and alternatives.
