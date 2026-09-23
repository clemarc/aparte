#!/bin/bash
source "$(dirname "$0")/common.sh"
[[ $# == 2 && $1 == --manifest ]] || { echo 'Usage: benchmark-local.sh --manifest Tests/Fixtures/manifest.json' >&2; exit 64; }
manifest=$2
model=${APARTE_MODEL:-small}
model_dir=${APARTE_MODEL_DIR:-artifacts/models/$model}
[[ -f "$manifest" && -d "$model_dir" && -f artifacts/fixtures/en-01.wav ]] || { echo 'BLOCKED: verified local model and generated fixed corpus required; see README.' >&2; exit 2; }
pmset -g custom > artifacts/power-mode.txt
swift build -c release --product aparte-check --disable-automatic-resolution 2>&1 | tee artifacts/benchmark-build.log
binary=$(swift build -c release --show-bin-path)/aparte-check
sandbox-exec -p '(version 1)(allow default)(deny network*)' "$binary" benchmark Resources/Models.json "$model_dir" "$manifest" "$model" > "artifacts/benchmark-$model.jsonl" 2> "artifacts/benchmark-$model.stderr"
python3 scripts/report-benchmark.py "artifacts/benchmark-$model.jsonl"
