#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p artifacts
if [[ $(uname -s) != Darwin || $(uname -m) != arm64 ]] || ! xcrun --find swift >/dev/null 2>&1 || ! xcodebuild -version >/dev/null 2>&1; then
  echo 'BLOCKED: Apple Silicon Mac with Xcode is required.' >&2; exit 2
fi
record_toolchain() {
  sysctl -n machdep.cpu.brand_string hw.memsize || return
  sw_vers || return
  xcodebuild -version || return
  xcrun swift --version || return
  xcrun --sdk macosx --show-sdk-version || return
}
if ! record_toolchain > artifacts/toolchain.txt 2>&1; then
  echo 'BLOCKED: could not inspect the required hardware/toolchain. See artifacts/toolchain.txt for the system error (a restricted execution sandbox may deny access).' >&2
  exit 2
fi
