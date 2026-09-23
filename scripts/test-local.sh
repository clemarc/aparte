#!/bin/bash
source "$(dirname "$0")/common.sh"
[[ $# == 2 && $1 == --suite ]] || { echo 'Usage: test-local.sh --suite unit|integration' >&2; exit 64; }
case "$2" in
unit) swift test --disable-automatic-resolution 2>&1 | tee artifacts/unit-tests.log ;;
integration)
  model=${APARTE_MODEL_DIR:-artifacts/models/base}
  fixture=${APARTE_FIXTURE:-artifacts/upstream/Tests/WhisperKitTests/Resources/jfk.wav}
  [[ -d "$model" && -f "$fixture" ]] || { echo 'BLOCKED: integration needs verified model and public fixture. See README.' >&2; exit 2; }
  swift run --disable-automatic-resolution aparte-check transcribe Resources/Models.json "$model" "$fixture" 2>&1 | tee artifacts/integration.log ;;
*) echo 'Unknown suite' >&2; exit 64 ;;
esac
