# Actual measurements

Reference: Apple M5 Pro, 48 GiB RAM, macOS 26.6 (25G72), Xcode 27.0 (27A266a), SDK 27.0, Swift 6.4. Power mode 0 on AC/battery (normal), as recorded by `pmset -g custom`. No settings changed. This does not establish performance on other Apple Silicon Macs.

WhisperKit 1.1.0 revision and exact model/tokenizer pins are in `Package.resolved`, `Resources/Models.json` and D003–D004. Measurements use the production adapter, Release optimization, Auto language, one loaded engine and no network. Two complete runs are retained in `docs/evidence/benchmark-{base,small}.jsonl` and corresponding `.summary.json`.

## Corpus and quality

55 frozen synthetic clips: 20 English, 20 French (10 developer-oriented across both languages), 5 quiet clips and 10 silence/seeded-noise clips. Original CC0 reference text; Samantha/Daniel and Thomas/Amélie local voices. No personal audio. The 10 ordinary held-out clips plus held-out quiet/noise subsets were specified before evaluation; no thresholds were adjusted using those results. Waveform hashes, exact texts, split, voice and duration are in `Tests/Fixtures/manifest.json`. Generated audio is not redistributed. Limitations: synthetic voices, low-level synthetic noise, no accents beyond these voices, no microphone/channel noise or natural-speaker evidence. Code switching/exact syntax are not guaranteed.

Normalization: NFC, lowercase, punctuation becomes whitespace (including apostrophes), retain accents, no number expansion; word-level Levenshtein aggregated by reference-word count. Overall language WER includes quiet speech; quiet is also reported separately. Terms are the fixed 12 occurrences in 10 developer clips, compared under the same normalization. Raw output is synthetic fixture output only.

| Metric / threshold | Base | Small |
|---|---:|---:|
| English WER ≤20% | 2.35% PASS | 0.64% PASS |
| French WER ≤25% | 10.81% PASS | 4.87% PASS |
| Held-out English WER | 0% | 0% |
| Held-out French WER | 20.49% | 10.66% |
| Quiet WER | 3.61% | 0% |
| Technical terms ≥80% | 50% **FAIL** | 83.33% PASS |
| No speech: 10/10 rejected | 10 PASS | 10 PASS |

Small is the fastest tested candidate meeting all frozen-corpus quality thresholds (D009). Base is faster but fails a mandatory quality gate. Turbo was optional and not added. Small becomes the default for new settings; saved choices remain respected. Natural speech quality is still BLOCKED pending ten consented live dictations.

## Performance

Each model warmed once before evaluation; the separately recorded warm set has 30 utterances (10 around each 3/8/15-second group). Raw actual clip durations are retained; synthetic speech is padded to group duration where shorter. No download, model load or compilation is included in decode timing.

| Warm file decode | Base p50 / p95 (s) | Small p50 / p95 (s) |
|---|---:|---:|
| ~3 seconds, n=10 | 0.092 / 0.109 | 0.224 / 0.287 |
| ~8 seconds, n=10 | 0.154 / 0.218 | 0.401 / 0.533 |
| ~15 seconds, n=10 | 0.233 / 0.347 | 0.612 / 0.893 |
| Overall, n=30 | 0.154 / 0.322 | 0.401 / 0.821 |

These are **decode-only**. Shortcut-to-capture p95 ≤300 ms, release-to-dispatch p50 ≤2 s / p95 ≤5 s, and observed visible-text latency are BLOCKED by microphone/AX permissions and real target sessions. No end-to-end subsecond claim is made.

| Other actual measurements | Base | Small |
|---|---:|---:|
| Installed bytes (manifest) | 149,484,796 | 489,252,808 |
| Preparation in fresh Release process (includes hashing/prewarm/load) | 6.187 s | 18.334 s |
| Peak process RSS | 318,291,968 bytes | 841,826,304 bytes |
| RSS first→last across next 100 same-size sessions | 308,510,720→310,722,560 | 742,899,712→743,161,856 |
| Retained RSS change | +0.717% | +0.035% |

No crash or unbounded queue was observed in these sequential real-engine sessions. Growth is below the 10% investigation threshold; this does not prove absence of all leaks or real capture-buffer leaks. Separate 59-second input completed within 30 seconds for both models (exact timings in raw records); 60-second input was rejected by the production transcriber. Actual microphone timer/device boundaries remain blocked.

Initial M0 fresh-model base preparation was 5.874 s with a public upstream JFK fixture (11 s); decode 0.860 s. A fresh-process network-denied reload then prepared in 5.869 s and decoded in 0.257 s. Core ML caches persist externally, so these are not a promise of first-install speed on every Mac. Cold app-to-Ready launch and five-minute **Ready** idle CPU cannot be accepted without privacy grants.

## Offline and logging evidence

Both full benchmark processes ran under `(deny network*)` and a URLProtocol request interceptor: **0 observed outbound URL requests**, stderr empty. The source audit confirms local-only tokenizer parsing (no Hub fallback) and disabled WhisperKit logs. The offline lifecycle check imported verified assets, rejected a missing tokenizer without a request, preserved the working engine, switched both directions and deleted an inactive model. See `docs/evidence/model-lifecycle.json`.

Process network denial proves offline operation; the interceptor and inspected production call path provide separate evidence about attempted requests. This is scoped to the exercised paths, not a proof about arbitrary future dependency changes.
