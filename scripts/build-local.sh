#!/bin/bash
source "$(dirname "$0")/common.sh"
configuration=Debug
if [[ $# == 2 && $1 == --configuration && ($2 == Debug || $2 == Release) ]]; then configuration=$2
elif [[ $# != 0 ]]; then echo 'Usage: build-local.sh --configuration Debug|Release' >&2; exit 64; fi
xcodebuild -project Aparte.xcodeproj -scheme Aparte -configuration "$configuration" -destination 'platform=macOS,arch=arm64' -derivedDataPath artifacts/DerivedData -clonedSourcePackagesDirPath artifacts/Packages -onlyUsePackageVersionsFromResolvedFile build CODE_SIGN_IDENTITY=- 2>&1 | tee "artifacts/build-$configuration.log"
echo "Built: artifacts/DerivedData/Build/Products/$configuration/Aparte.app (local ad-hoc signature; not notarised)"
