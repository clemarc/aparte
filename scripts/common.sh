#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p artifacts
if [[ $(uname -s) != Darwin || $(uname -m) != arm64 ]] || ! xcrun --find swift >/dev/null 2>&1 || ! xcodebuild -version >/dev/null 2>&1; then
  echo 'BLOCKED: Apple Silicon Mac with Xcode is required.' >&2; exit 2
fi
{ sysctl -n machdep.cpu.brand_string hw.memsize; sw_vers; xcodebuild -version; xcrun swift --version; xcrun --sdk macosx --show-sdk-version; } > artifacts/toolchain.txt 2>&1
