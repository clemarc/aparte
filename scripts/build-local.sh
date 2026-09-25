#!/bin/bash
source "$(dirname "$0")/common.sh"
configuration=Debug
signing=local
while [[ $# -gt 0 ]]; do
  case "$1" in
    --configuration)
      [[ $# -ge 2 && ($2 == Debug || $2 == Release) ]] || { echo 'Expected Debug or Release configuration.' >&2; exit 64; }
      configuration=$2; shift 2 ;;
    --signing)
      [[ $# -ge 2 && ($2 == local || $2 == adhoc) ]] || { echo 'Expected local or adhoc signing.' >&2; exit 64; }
      signing=$2; shift 2 ;;
    *) echo 'Usage: build-local.sh [--configuration Debug|Release] [--signing local|adhoc]' >&2; exit 64 ;;
  esac
done
if [[ $signing == local ]]; then ./scripts/local-signing.py requirement >/dev/null; fi
xcodebuild -project Aparte.xcodeproj -scheme Aparte -configuration "$configuration" -destination 'platform=macOS,arch=arm64' -derivedDataPath artifacts/DerivedData -clonedSourcePackagesDirPath artifacts/Packages -onlyUsePackageVersionsFromResolvedFile build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO 2>&1 | tee "artifacts/build-$configuration.log"
app="artifacts/DerivedData/Build/Products/$configuration/Aparte.app"
if [[ $signing == local ]]; then
  ./scripts/local-signing.py sign "$app"
  echo "Built: $app (stable local development signature; not notarised)"
else
  /usr/bin/codesign --force --sign - --timestamp=none "$app"
  /usr/bin/codesign --verify --deep --strict "$app"
  echo "Built: $app (ad-hoc CI signature; not notarised or suitable for distribution)"
fi
