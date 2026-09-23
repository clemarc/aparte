#!/bin/bash
source "$(dirname "$0")/common.sh"
[[ $# -ge 1 && ($1 == base || $1 == small) ]] || { echo 'Usage: install-model.sh base|small [destination-root] [offline-source-directory]' >&2; exit 64; }
model=$1
root=${2:-artifacts/models}
args=(install Resources/Models.json "$root" "$model")
[[ $# -lt 3 ]] || args+=("$3")
swift run --disable-automatic-resolution aparte-check "${args[@]}"
