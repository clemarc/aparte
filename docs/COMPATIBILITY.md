# Compatibility

Version 0.4.2 enables guarded insertion for the five supported app adapters under owner-approved D013. Operational `enabled` entries in `Resources/Compatibility.json` are separate from `validated` evidence, which remains empty. Unknown apps/roles use Recovery. Enabled does not mean the real ten-attempt matrix passed. No whole-field AX writes, Select All, Return, per-character synthesis or retry after mutation exists.

| Target (last inventoried version) | Enabled method / roles | Validation |
|---|---|---|
| TextEdit 1.20 (415) | Settable AXSelectedText with selection metadata; otherwise clipboard chosen before mutation. AXTextArea/AXTextField | BLOCKED: live target interaction unavailable |
| Apple Terminal 2.15 (470.2) | Single-line clipboard Cmd-V. AXTextArea | BLOCKED: live target interaction unavailable |
| Claude Code 2.1.267 in Terminal | Terminal adapter, inert input only | BLOCKED: inert session not verified; never submit executable commands from fixtures |
| VS Code 1.138.0 | Clipboard Cmd-V. AXTextArea/AXTextField | BLOCKED: live target interaction unavailable |
| Chrome 153.0.8010.53 | Clipboard Cmd-V. AXTextArea/AXTextField | BLOCKED: textarea/contenteditable behavior unverified |
| Slack 4.52.155 | Clipboard Cmd-V. AXTextArea/AXTextField | BLOCKED: draft composer/login and live target interaction unverified |
| macOS 14 | Same scope | BLOCKED: host is macOS 26.6 |

The owner reports Microphone/Accessibility granted and Setup tests working. Do not assume missing grants from historical CLI evidence. Native desktop testing remains blocked: SkyComputerUseService crashed with SIGTRAP in Array.remove(at:) on 2026-09-24, and its replacement still returned a closed pipe. No new grant or repeated unchanged tool retry is needed for implementation.

Version 0.4.6 resolves AXFocusedUIElement on the foreground application first, retaining a PID-checked system-wide fallback. App/window/field identities are revalidated through the same path; conflicting window metadata refuses insertion. App-specific failure reasons distinguish unsupported app, absent focus, timeout and window inconsistency. The owner confirms permissions are correct but the exact failing app/field is still awaited; this lookup change is not live target acceptance.

## Protocol to validate an adapter

Use disposable documents/drafts. Never send a message or test destructive commands. Capture target app version, macOS major.minor, method, produced transcript (synthetic only), exact resulting text and clipboard types/change behavior. Each target needs ten attempts covering: caret at end, caret mid-paragraph, selection replacement, accented French, non-BMP emoji, rich surrounding text, rapid Escape, app switch, window/field switch, and concurrent clipboard copy. Happy paths must insert exactly once without surrounding loss or submission; safety cases must insert nothing. Safety refusal is not a happy-path pass.

Test AX API success against actual visible content; after an ambiguous write, verify no clipboard fallback. For paste, test one-second restoration, including a deliberately slow consumer. Slow/custom consumers that lose text must be disabled or scoped out of `enabled`. Terminal must retain text as inert unsubmitted input; a custom paste handler may execute text and is outside Aparté’s guarantee. Remote desktops, password managers and elevated prompts are unsupported.

Only after evidence passes add the exact appVersion/osVersion and tested roles/method to `validated`. Keep operational entries appropriately scoped when failures are found. Recovery retains one backup after attempted insertion because the OS does not acknowledge consumption; its reason distinguishes attempted paste from refusal. Check the target before manually copying again.

## Clipboard behavior and evidence

D013 supersedes D008's empty/known-eager-only restriction. Snapshots may request ordinary foreign provider data. All original representations must be preserved within 8 MiB/500 ms; explicit promise/lazy-marker formats, absent data, oversized contents, timeout or ownership change refuse automatic paste. The limit bounds accepted snapshot bytes, not the peak allocation of an individual native read. A timed-out native read cannot be cancelled; one worker stays busy until it unwinds, and late completion cannot write.

Real isolated named-pasteboard tests exercise a separate foreign owner of text/RTF/PNG/multiple items, a fast lazy provider, and a slow provider. Original bytes plus extra AppKit text encodings are retained and restored after the owner process exits. Additional tests cover empty boards, concurrent new copies, snapshot-to-write races, unsupported promise formats and oversized data. They never touch the user's general clipboard and do not post paste events to a real app. See `docs/evidence/clipboard-fix.json` for final results.

Restoration occurs one second after dispatch, only with matching changeCount/marker/text; newer copies are preserved and not read. No atomic cross-process compare-and-swap or universal paste acknowledgment exists. Orderly quit/cancel tries conditional restoration; crashes cannot guarantee it. Provider reads may trigger work in another app or Universal Clipboard. Full target paste/consumption remains an independent BLOCKED gate.
