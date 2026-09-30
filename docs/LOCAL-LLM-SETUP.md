# Local text formatting and summaries on Apple Silicon

**Updated:** 29 September 2026

**Audience:** Someone starting with no local LLM software installed.

**Availability:** Aparté currently transcribes speech locally. Its optional text handling is still a placeholder. You can set up and test the separate local server now; connecting it to Aparté belongs to the deferred [Post-M5 scope](POST-M5-DICTATION.md). The Aparté configuration section below describes planned controls.

## What you will set up

Use **LM Studio with the MLX runtime**. It provides a graphical model downloader and a local API server, and supports Apple's MLX on Apple Silicon. This guide uses that path without Ollama, Homebrew, Python, Docker or Xcode setup. [LM Studio overview](https://lmstudio.ai/docs/app).

There are two separate models:

| Model | Job | Where it runs |
| --- | --- | --- |
| Aparté's Whisper speech model | Audio → transcript | Inside Aparté; already available |
| Your chosen instruction LLM | Transcript → formatted text or summary | In LM Studio; future optional Aparté integration |

Changing the LLM does not improve recognition of a French accent. Compare speech models separately in Aparté's Processing and Try it sections.

## 1. Check your Mac

Open **Apple menu → About This Mac** and check the chip, memory and macOS version. LM Studio requires Apple Silicon and macOS 14 or later; its documentation recommends at least 16 GB memory and smaller models/modest context on 8 GB Macs. [System requirements](https://lmstudio.ai/docs/app/system-requirements).

These are starting points for testing, not Aparté performance or quality guarantees:

| Memory | First model to try | Approximate model files |
| --- | --- | --- |
| 8 GB, or a lightweight first test | [`mlx-community/Qwen2.5-1.5B-Instruct-4bit`](https://huggingface.co/mlx-community/Qwen2.5-1.5B-Instruct-4bit) | 0.9 GB |
| 16 GB or more, formatting/short summaries | [`mlx-community/Qwen3-4B-Instruct-2507-4bit`](https://huggingface.co/mlx-community/Qwen3-4B-Instruct-2507-4bit) | 2.3 GB |

Both linked conversions identify MLX format and Apache-2.0 licensing. They are examples, not bundled models or a permanent approved catalog. The exact Qwen3-4B-Instruct-2507 variant uses non-thinking mode, which simplifies a first formatting test. [Publisher model card](https://huggingface.co/Qwen/Qwen3-4B-Instruct-2507). The earlier [Qwen2.5-7B MLX example](https://huggingface.co/mlx-community/Qwen2.5-7B-Instruct-4bit) remains an optional comparison.

[Model and memory recommendations](LOCAL-LLM-MODELS.md) cover the reference M5 Pro / 48 GB Mac, other RAM tiers, Unsloth GGUF choices, thinking controls and a timing/quality comparison procedure. Working-memory ranges there are estimates, not local LLM benchmarks.

Leave disk space beyond the displayed download size for the app/runtime and downloads. File size is not total working memory: macOS, other apps, Aparté's active speech model, the LLM and its context all share memory. Start with the smaller option if uncertain. In **Activity Monitor → Memory**, watch memory pressure while both apps are running.

## 2. Install LM Studio and MLX

1. Download the macOS Apple Silicon installer from [LM Studio](https://lmstudio.ai/download). Install it in Applications and open it.
2. Enable **Developer mode** in **Settings → Developer** to expose server and load controls. [Mode instructions](https://lmstudio.ai/docs/app/user-interface/modes).
3. Press **⌘⇧R** to open runtime management. Install the available **MLX** runtime if it is missing. Finish this while online. [Runtime management](https://lmstudio.ai/docs/app).
4. Open **Discover** (**⌘2**). Paste one complete model name from the table above, or its linked Hugging Face URL. Select the matching **MLX, 4-bit, Instruct** model and finish the download. [Model download instructions](https://lmstudio.ai/docs/app/basics/download-model).

“Instruct” means a model intended to follow instructions. The MLX download is different from a GGUF download for the llama.cpp runtime; choose the format named here.

## 3. Load and try the model

In **Chat**, open the model loader, select your downloaded model and load it. If load settings offer a context length, start with **4096 tokens** for these short tests; this is a suggested test budget, not a model's maximum. Wait until loading completes. [Loading instructions](https://lmstudio.ai/docs/app/basics).

Use this synthetic message:

```text
Format the following as a short list. Preserve every fact and add no introduction:
tomorrow call Alex then review issue AP-42 then send the agenda
```

Check that all three tasks and `AP-42` survive. A fluent answer can still lose facts. The Chat test checks generation; the next step checks the API that Aparté will use.

## 4. Start the local server

Open **Developer**, then server settings. Use:

| Setting | Value for this walkthrough |
| --- | --- |
| Server port | `1234`, or another free port used consistently below |
| Serve on Local Network | Off |
| Enable CORS | Off |
| Allow per-request MCPs / calling servers from mcp.json | Off |
| Just in Time Model Loading | Off for the initial test; load the model yourself |

These settings keep this walkthrough on your Mac with a manually loaded text model. [Server settings](https://lmstudio.ai/docs/developer/core/server/settings).

Toggle **Start server** and check that it is running. Keep the chosen model loaded and LM Studio running during testing. [Starting the server](https://lmstudio.ai/docs/developer/core/server).

LM Studio defaults to requests without authentication. The commands below use that default on loopback (`127.0.0.1`, this Mac). Other software on your Mac can still reach a loopback server. If you want token authentication, LM Studio 0.4.0+ supports **Require Authentication → Manage Tokens → Create Token**; keep the token in a password manager and later enter it in Aparté's API key field. Authenticated requests need a Bearer token; the unauthenticated examples below will then return 401. [Authentication instructions](https://lmstudio.ai/docs/developer/core/authentication).

## 5. Verify the API with synthetic text

Open **Terminal** from Applications → Utilities. No extra command-line package is required. Paste:

```sh
curl --fail --show-error --silent --max-time 10 --noproxy '*' \
  http://127.0.0.1:1234/v1/models
```

Find your text model's exact `id` inside the returned `data` list. Copy it, including any alias or suffix. The download's name and the API ID may differ. A listed model is not proof that it is loaded: LM Studio can also list downloaded models when just-in-time loading is enabled. [List Models API](https://lmstudio.ai/docs/developer/openai-compat/models).

In the next command, replace **only** `PASTE_MODEL_ID_HERE` with that ID before running it. Keep the surrounding double quotes and the final `JSON` line:

```sh
curl --fail --show-error --silent --max-time 120 --noproxy '*' \
  http://127.0.0.1:1234/v1/chat/completions \
  -H 'Content-Type: application/json' \
  --data-binary @- <<'JSON'
{
  "model": "PASTE_MODEL_ID_HERE",
  "messages": [
    {
      "role": "system",
      "content": "Format the supplied text as a short list. Preserve all facts and identifiers. Return only the formatted text."
    },
    {
      "role": "user",
      "content": "tomorrow call Alex then review issue AP-42 then send the agenda"
    }
  ],
  "temperature": 0.2,
  "max_tokens": 512,
  "stream": false
}
JSON
```

The response should contain non-empty text in `choices[0].message.content`. It should include the three tasks and `AP-42`, with no extra facts. A `finish_reason` of `length` indicates an output limit; treat it as an incomplete result. These parameters are for this LM Studio smoke test, not a universal payload for every hosted model. [Chat Completions API](https://lmstudio.ai/docs/developer/openai-compat/chat-completions).

To test summarization, reuse the command with system content `Summarize the supplied text in one short paragraph. Add no facts. Return only the summary.` and user content `The team reviewed AP-42 today. Alex will prepare a fix by Friday. Testing starts on Monday. No release date was agreed.` Verify that the summary preserves the timeline and does not invent a release date. Try French synthetic text as well if that is how you will use it.

The 120-second timeout allows a setup test to complete; it does not define Aparté's future interaction deadline. Preloading avoids putting the initial model load into each first request.

## 6. Connect Aparté when text handling is implemented

**These controls do not exist in the current build.** The deferred Processing → Text handling design will use:

| Planned field | Value for this server |
| --- | --- |
| API format | OpenAI-compatible Chat Completions |
| API base URL | `http://127.0.0.1:1234/v1` |
| LLM model | Exact API ID verified above; select from refreshed models or enter manually |
| API key | Empty for the default local server, or your LM Studio token if authentication is enabled |
| Commands | Enable Format and/or Summarize after the synthetic connection test passes |
| Additional instructions | Optional, separately for each command |

Enter the **base URL**, including `/v1`, rather than the full `/chat/completions` route. Aparté's adapter will add the route. Use the actual port if you changed it.

The initial design uses one provider/model for both commands. Prompt enrichment happens in Aparté so the instructions accompany API requests; do not rely on an LM Studio Chat preset being applied to API calls. Example Format enrichment: `Use British spelling. Preserve technical names and issue IDs.` Example Summarize enrichment: `Keep decisions and next actions. Write in French.` These are optional preferences, independent of accent recognition.

## Daily use and offline check

Open LM Studio, load the selected model and start the server before using text handling. If you change models, select the matching API ID and retest. Stop the server and unload the model when finished to release resources. Ordinary Aparté dictation will remain independent of this server.

After downloading both model and runtime, disconnect from the internet, reopen LM Studio, reload the model, start the server and repeat the synthetic API test. Reconnect when finished. Local inference/server operation can work offline; discovery, downloads and update checks use the network. [Offline operation](https://lmstudio.ai/docs/app/offline).

LM Studio is a separate application with its own chats, server logs and settings. Aparté's transient-text policy does not erase data retained by that application. Keep setup tests synthetic and review its retention settings before using sensitive text. Do not configure remote model routing or integrations for this local walkthrough.

## Troubleshooting

| Symptom | Next step |
| --- | --- |
| Connection refused | Confirm Start server is on and the port matches both URLs. |
| Port already in use | Select a free port in LM Studio and update both test URLs and the planned Aparté base URL. |
| No models, wrong model or unknown ID | Finish the download, manually load the intended model, refresh `/v1/models` and copy its exact ID. |
| MLX model cannot load | Check Apple Silicon, the MLX runtime and that you downloaded MLX rather than GGUF. |
| High memory pressure, very slow generation or load failure | Unload other LLMs, close heavy apps, reduce context or use the smaller model. Include Aparté's speech model in the memory budget. |
| First request slow | Load the model before testing; confirm it has not been unloaded. |
| 401 response | Authentication is enabled: use a token through an authenticated client. Avoid putting secrets into saved commands, screenshots or diagnostics. |
| API responds but text is inaccurate or truncated | Try the synthetic checks again with a suitable model/output budget. API success alone does not establish useful quality. |

## Documentation and validation status

Official runtime/API documentation and the linked model cards were checked on 29 September 2026. GUI labels can change between LM Studio versions. No LM Studio installation, model download, live API request or performance benchmark was performed for this documentation checkpoint. Before shipping Aparté's integration, run the guide from a clean Mac setup and verify combined ASR/LLM memory, warm/cold timing, offline operation and actual command delivery. Existing M4 and beta acceptance gates remain in [ACCEPTANCE](ACCEPTANCE.md).
