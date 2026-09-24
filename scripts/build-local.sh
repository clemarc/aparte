#!/bin/bash
source "$(dirname "$0")/common.sh"
configuration=Debug
if [[ $# == 2 && $1 == --configuration && ($2 == Debug || $2 == Release) ]]; then configuration=$2
elif [[ $# != 0 ]]; then echo 'Usage: build-local.sh --configuration Debug|Release' >&2; exit 64; fi
./scripts/local-signing.py requirement >/dev/null
xcodebuild -project Aparte.xcodeproj -scheme Aparte -configuration "$configuration" -destination 'platform=macOS,arch=arm64' -derivedDataPath artifacts/DerivedData -clonedSourcePackagesDirPath artifacts/Packages -onlyUsePackageVersionsFromResolvedFile build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO 2>&1 | tee "artifacts/build-$configuration.log"
./scripts/local-signing.py sign "artifacts/DerivedData/Build/Products/$configuration/Aparte.app"
echo "Built: artifacts/DerivedData/Build/Products/$configuration/Aparte.app (stable local development signature; not notarised)"
