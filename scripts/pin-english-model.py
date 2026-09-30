#!/usr/bin/env python3
"""Maintainer-only pin for the optional English-only Core ML base model."""
import concurrent.futures
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent.parent
MODEL_REV = "0f63a7800b00dd0226abd051b906c246e1907482"
TOKEN_REV = "911407f4214e0e1d82085af863093ec0b66f9cd6"
MODEL = "base.en"
PARTS = ("analytics/coremldata.bin", "coremldata.bin", "metadata.json", "model.mil", "weights/weight.bin")
SOURCES = [f"{module}.mlmodelc/{part}" for module in ("AudioEncoder", "MelSpectrogram", "TextDecoder") for part in PARTS]
SOURCES += ["AudioEncoder.mlmodelc/model.mlmodel", "TextDecoder.mlmodelc/model.mlmodel", "config.json", "generation_config.json"]


def pinned_file(job):
    source, repository, revision = job
    destination = ROOT / "artifacts/models" / MODEL / source
    destination.parent.mkdir(parents=True, exist_ok=True)
    url = f"https://huggingface.co/{repository}/resolve/{revision}/{source if repository.startswith('openai/') else 'openai_whisper-base.en/' + source}"
    if not destination.exists():
        partial = destination.with_name(destination.name + ".partial")
        subprocess.run(["curl", "--fail", "--location", "--silent", "--show-error", "--retry", "4", "--retry-all-errors", "--max-time", "600", url, "-o", str(partial)], check=True)
        partial.replace(destination)
    digest = hashlib.sha256(destination.read_bytes()).hexdigest()
    return {"path": source, "url": url, "bytes": destination.stat().st_size, "sha256": digest}


jobs = [(source, "argmaxinc/whisperkit-coreml", MODEL_REV) for source in SOURCES]
jobs += [(source, "openai/whisper-base.en", TOKEN_REV) for source in ("tokenizer.json", "tokenizer_config.json", "special_tokens_map.json")]
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    files = list(pool.map(pinned_file, jobs))
catalog_path = ROOT / "Resources/Models.json"
catalog = json.loads(catalog_path.read_text())
catalog["models"] = [entry for entry in catalog["models"] if entry["id"] != MODEL]
catalog["models"].append({"id": MODEL, "displayName": "Whisper base · English only", "revision": MODEL_REV, "tokenizerRevision": TOKEN_REV, "license": "MIT (OpenAI Whisper / Argmax Core ML conversion); tokenizer Apache-2.0 repository metadata", "files": files})
catalog_path.write_text(json.dumps(catalog, indent=2) + "\n")
print(MODEL, sum(item["bytes"] for item in files))
