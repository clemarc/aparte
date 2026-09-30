#!/usr/bin/env python3
"""Maintainer-only pin for reviewed public Core ML medium/turbo asset sets.

Downloads into ignored artifacts/models, checks upstream LFS SHA-256 values
where available, then atomically adds the complete local hash manifest. Runtime
never queries a mutable catalog or downloads during dictation.
"""
import concurrent.futures
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import urllib.request

ROOT = Path(__file__).resolve().parent.parent
REV = "0f63a7800b00dd0226abd051b906c246e1907482"
MODELS = {
    "medium": ("openai_whisper-medium/", "openai/whisper-medium", "abdf7c39ab9d0397620ccaea8974cc764cd0953e", "Whisper medium · multilingual", "MIT (OpenAI Whisper / Argmax Core ML conversion); tokenizer Apache-2.0 repository metadata"),
    "turbo": ("openai_whisper-large-v3-v20240930_turbo/", "openai/whisper-large-v3-turbo", "41f01f3fe87f28c78e2fbf8b568835947dd65ed9", "Whisper large-v3 turbo · multilingual", "MIT (OpenAI Whisper / Argmax Core ML conversion and OpenAI tokenizer)"),
}
CATALOG = ROOT / "Resources/Models.json"
MODEL_ORDER = {"base": 0, "small": 1, "medium": 2, "turbo": 3, "base.en": 4}


def tree(prefix):
    url = f"https://huggingface.co/api/models/argmaxinc/whisperkit-coreml/tree/{REV}/{prefix[:-1]}?recursive=true&expand=true"
    with urllib.request.urlopen(url, timeout=60) as response:
        return [item for item in json.load(response) if item["type"] == "file"]


def fetch(spec):
    path, url, size, upstream_sha, model_dir = spec
    if not path or path.startswith("/") or ".." in Path(path).parts or "." in Path(path).parts:
        raise ValueError(f"unsafe asset path: {path}")
    local = model_dir / path
    local.parent.mkdir(parents=True, exist_ok=True)
    if not local.exists() or local.stat().st_size != size:
        partial = local.with_name(local.name + ".partial")
        subprocess.run(["curl", "--fail", "--location", "--silent", "--show-error", "--retry", "4", "--retry-all-errors", "--max-time", "3600", url, "-o", str(partial)], check=True)
        if partial.stat().st_size != size:
            raise ValueError(f"size mismatch: {path}")
        partial.replace(local)
    digest = hashlib.sha256()
    with local.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    sha = digest.hexdigest()
    if upstream_sha and sha != upstream_sha:
        raise ValueError(f"upstream LFS digest mismatch: {path}")
    print(f"verified {path}: {size} bytes", flush=True)
    return {"path": path, "url": url, "bytes": size, "sha256": sha}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("model", choices=MODELS)
    args = parser.parse_args()
    prefix, token_repo, token_rev, display_name, license_note = MODELS[args.model]
    model_dir = ROOT / "artifacts/models" / args.model
    specs = []
    for item in tree(prefix):
        source = item["path"]
        if not source.startswith(prefix):
            raise ValueError("unexpected tree path")
        path = source[len(prefix):]
        specs.append((path, f"https://huggingface.co/argmaxinc/whisperkit-coreml/resolve/{REV}/{source}", item["size"], (item.get("lfs") or {}).get("oid"), model_dir))
    token_tree_url = f"https://huggingface.co/api/models/{token_repo}/tree/{token_rev}?recursive=false&expand=true"
    with urllib.request.urlopen(token_tree_url, timeout=60) as response:
        tokens = {item["path"]: item for item in json.load(response)}
    for path in ("tokenizer.json", "tokenizer_config.json", "special_tokens_map.json"):
        item = tokens[path]
        specs.append((path, f"https://huggingface.co/{token_repo}/resolve/{token_rev}/{path}", item["size"], (item.get("lfs") or {}).get("oid"), model_dir))
    paths = [item[0] for item in specs]
    if len(paths) != len(set(paths)) or not {"config.json", "generation_config.json", "tokenizer.json"}.issubset(paths):
        raise ValueError(f"incomplete or duplicate {args.model} asset list")
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        files = list(pool.map(fetch, specs))
    catalog = json.loads(CATALOG.read_text())
    if catalog["schema"] != 1 or [item["id"] for item in catalog["models"][:2]] != ["base", "small"]:
        raise ValueError("unexpected curated catalog")
    catalog["models"] = [item for item in catalog["models"] if item["id"] != args.model]
    catalog["models"].append({
        "id": args.model, "displayName": display_name,
        "revision": REV, "tokenizerRevision": token_rev,
        "license": license_note,
        "files": files,
    })
    catalog["models"].sort(key=lambda item: MODEL_ORDER[item["id"]])
    temporary = CATALOG.with_suffix(".json.partial")
    temporary.write_text(json.dumps(catalog, indent=2, ensure_ascii=False) + "\n")
    temporary.replace(CATALOG)
    print(f"pinned {args.model}: {sum(file['bytes'] for file in files)} installed bytes", flush=True)


if __name__ == "__main__":
    main()
