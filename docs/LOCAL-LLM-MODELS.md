# Choosing a local LLM: model, memory and response time

**Updated:** 29 September 2026

**Status:** Advisory recommendations for the deferred text-handling feature and independent local chat. No LLM was downloaded or benchmarked for this guide. These choices do not change Aparté's speech-model default or start its provider implementation.

## Recommendation for the reference Mac

A read-only hardware check reports **MacBook Pro, Apple M5 Pro, 48 GB unified memory**. No serial number or hardware UUID is retained.

Start with **Qwen3-4B-Instruct-2507 at 4-bit** for formatting and short summaries. It is explicitly a non-thinking instruction model, so it avoids configuring a reasoning toggle. This is a deliberate compact baseline rather than a claim that it is the newest or best model. [Publisher model card](https://huggingface.co/Qwen/Qwen3-4B-Instruct-2507).

For broader writing, translation, questions and small coding tasks, try **Qwen3.5-9B at 4-bit** next. If that leaves a quality gap for your general work, your 48 GB Mac has room to explore **Qwen3.5-35B-A3B at 4-bit** with a modest context and other large models unloaded. The dense **Qwen3.5-27B** is another quality-oriented comparison, not an additional required download. These are candidates to evaluate on your own tasks; published general benchmarks do not establish Aparté formatting or French-summary quality. [9B card](https://huggingface.co/Qwen/Qwen3.5-9B), [35B-A3B card](https://huggingface.co/Qwen/Qwen3.5-35B-A3B).

For the initial Aparté design, select one LLM for both commands. A separate larger chat model can be used in the runtime outside Aparté; two command-specific providers are not part of the initial scope. Keep only the model you need loaded while comparing.

## Memory planning

The file sizes below are publisher metadata for the named **GGUF Q4_K_M** files. The LLM working-memory ranges are **our conservative planning estimates**, not measured peaks or guaranteed limits. They assume one request, roughly 4K–8K context, short text output and no image/video processing. Runtime settings, caches and load-time peaks can push usage beyond them.

| Model | Named GGUF file size | Estimated LLM working-memory budget | Comfortable total Mac RAM for this workload | Why try it |
| --- | ---: | ---: | --- | --- |
| [Qwen3-4B-Instruct-2507](https://huggingface.co/unsloth/Qwen3-4B-Instruct-2507-GGUF/tree/main) | 2.5 GB | 4–6 GB | 16 GB+ | First formatting/short-summary candidate; non-thinking |
| [Qwen3.5-9B](https://huggingface.co/unsloth/Qwen3.5-9B-GGUF/tree/main) | 5.68 GB | 8–12 GB | 24 GB+; 16 GB needs a lean workload | General-use comparison with moderate memory cost |
| [Qwen3.5-27B](https://huggingface.co/unsloth/Qwen3.5-27B-GGUF/tree/main) | 16.7 GB | 20–28 GB | 32 GB with limited other apps; 48 GB preferable | Larger dense-model comparison |
| [Qwen3.5-35B-A3B](https://huggingface.co/unsloth/Qwen3.5-35B-A3B-GGUF/tree/main) | 22 GB | 26–34 GB | 48 GB+ | Larger general-use MoE candidate |

These are comfortable starting tiers, not minimum hardware requirements. On **8 GB**, start with the setup guide's small Qwen2.5-1.5B-Instruct 4-bit example and verify quality before considering 4B. On **64 GB+**, the shortlist has more headroom for other apps or a longer context; additional RAM alone does not establish higher generation speed.

For the reference Mac, initially reserve around **12 GB for macOS, ordinary other apps and Aparté**, adjusting this allowance to the actual workload. This is a planning allowance, not an OS measurement. Aparté's previous speech benchmarks measured whole-process peaks of about 0.84 GB for Small, 2.51 GB for Medium and 3.24 GB for Turbo; actual simultaneous live use can differ. [Speech benchmark evidence](MODEL-COMPARISON.md).

Watch **Activity Monitor → Memory** with the LLM, Aparté and your usual apps running. Sustained rising memory pressure or swap during requests means reduce the context, unload another model or choose a smaller model. Avoid sizing to the last free gigabyte.

Qwen3.5 also has vision components: an app may download/load a separate projector even for a text session. The linked repositories list these separately; the table counts the main language-model file only. Confirm the actual loaded total in your runtime.

## What “35B-A3B” means

It has **35 billion total parameters, around 3 billion activated per token**. The mixture-of-experts architecture reduces active computation, but the full quantized weights still need storage and memory. It does not have a 3B model's RAM requirement. [Publisher architecture](https://huggingface.co/Qwen/Qwen3.5-35B-A3B).

This can make it an attractive speed/quality comparison against a dense 27B model. Unsloth's guide recommends the 35B model for faster inference relative to 27B; that is publisher guidance, not an M5 Pro timing result. [Local runtime guide](https://unsloth.ai/docs/models/qwen3.5).

## Do formatting and summaries need thinking?

For punctuation, paragraphs, lists and a short summary of supplied text, **start without generated thinking output**. Extra reasoning tokens consume time and output budget. Non-thinking does not mean a model cannot interpret text; it describes how it generates its answer. Complex or contradictory documents may benefit from a stronger model or reasoning, and still need quality checks.

The exact **Qwen3-4B-Instruct-2507** variant supports only non-thinking mode. Do not confuse it with Qwen3-4B, Qwen3-4B-Thinking-2507 or a Base checkpoint.

For **Qwen3.5**, the publisher documents a non-thinking mode controlled through the serving configuration. Its example uses `chat_template_kwargs: {"enable_thinking": false}`; `/nothink` is not an officially supported soft switch for this family. That example is not a universal request field for every local server. Verify that your runtime applies its thinking control to API calls as well as Chat, and that the final response contains only the requested text. [Publisher non-thinking instructions](https://huggingface.co/Qwen/Qwen3.5-9B#instruct-or-non-thinking-mode).

## Which download in LM Studio or Unsloth Desktop?

- **LM Studio / MLX baseline:** search [`mlx-community/Qwen3-4B-Instruct-2507-4bit`](https://huggingface.co/mlx-community/Qwen3-4B-Instruct-2507-4bit). Its model card identifies the conversion and about 2.26 GB of model files. MLX file sizes and memory behavior differ from the GGUF table.
- **Unsloth Desktop / GGUF:** search the linked `unsloth/…-GGUF` repository and select the single **Q4_K_M** variant for a reproducible starting point. **UD-Q4_K_XL** is another option with different sizes; for example the linked 35B repository lists about 22.2 GB. Match the selected filename to your notes rather than assuming all “4-bit” downloads are identical.
- Start with 4-bit rather than downloading full-precision weights. A 5/6-bit comparison is optional if you observe a quality problem and have memory headroom; more bits are not a remedy for every model mistake.
- Refresh the runtime's model API and use its exact model ID. Confirm that the chosen model family and its API path are supported by the installed runtime version; a downloadable card alone is not proof. Setup instructions remain in [LOCAL-LLM-SETUP.md](LOCAL-LLM-SETUP.md).

## Performance: what to expect and what to measure

**No tokens/second or end-to-end latency is established on this Mac for these LLMs.** The small model is the first candidate for responsive short transformations. Dense larger models generally do more computation per output token; MoE active parameters, quantization, backend and context can change that ordering. A RAM tier establishes space, not a throughput score.

There are three separate delays:

1. **Cold model load:** reading weights and preparing the runtime. Keep the selected model loaded for dictation use.
2. **Prompt processing / time to first token:** affected by input length. A 60-second transcript and a long document are different workloads.
3. **Output generation:** affected by generated token count, including reasoning. A brief summary often completes sooner than a full formatted transcript, even with the same model.

For illustration only: at a measured 50 output tokens/second, 150 output tokens take about 3 seconds of generation **plus** prompt processing. This is arithmetic, not a speed prediction for any model here. Count user-visible completion time rather than relying only on a server's throughput label.

For a useful comparison after you set up the runtime:

- Use the same fixed synthetic English/French examples, 4K context and 512-token output cap, with thinking disabled and no tools/web search. Include paragraphs/lists, issue IDs, names, numbers, negation and decisions/deadlines. Check that formatting preserves facts and summaries invent none.
- Record cold load separately, then run at least ten warm requests per task/model. Use the same sampling settings where supported and record any differences. Inspect full output for truncation; do not score partial output as a fast pass.
- Keep aggregate quality results, median/slow-tail completion time, first-token time where available, output token count, process memory and system memory pressure. Record runtime/version/model filename. Do not retain private text or recordings.
- Repeat with the actual Aparté speech model and normal apps resident. Chat/API timing does not include speech decoding or guarded insertion, and cannot pass the deferred integration or existing acceptance gates.

**First trial on the 48 GB Mac:** compare the non-thinking 4B model against 9B on these short tasks. Explore 35B-A3B for broader work only if there is a useful quality gain to seek. There is no need to load all four or keep a large reasoning model running for simple dictation cleanup.
