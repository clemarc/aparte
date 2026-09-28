#!/bin/bash
source "$(dirname "$0")/common.sh"
configuration=Debug
signing=local
variant=development
while [[ $# -gt 0 ]]; do
  case "$1" in
    --configuration)
      [[ $# -ge 2 && ($2 == Debug || $2 == Release) ]] || { echo 'Expected Debug or Release configuration.' >&2; exit 64; }
      configuration=$2; shift 2 ;;
    --signing)
      [[ $# -ge 2 && ($2 == local || $2 == adhoc) ]] || { echo 'Expected local or adhoc signing.' >&2; exit 64; }
      signing=$2; shift 2 ;;
    --variant)
      [[ $# -ge 2 && ($2 == development || $2 == standard) ]] || { echo 'Expected development or standard variant.' >&2; exit 64; }
      variant=$2; shift 2 ;;
    *) echo 'Usage: build-local.sh [--configuration Debug|Release] [--signing local|adhoc] [--variant development|standard]' >&2; exit 64 ;;
  esac
done
if [[ $signing == local ]]; then ./scripts/local-signing.py requirement >/dev/null; fi
app_name=Aparte
display_name=Aparté
derived_data=artifacts/StandardDerivedData
bundle_identifier=dev.aparte.Aparte
if [[ $variant == development ]]; then app_name='Aparte Dew'; display_name='Aparte Dew'; derived_data=artifacts/DerivedData; bundle_identifier=dev.aparte.Aparte.dew; fi
# Xcode removes stale products after a name change. Isolate variants so a beta
# preparation cannot remove the development app being used for testing.
xcodebuild -project Aparte.xcodeproj -scheme Aparte -configuration "$configuration" -destination 'platform=macOS,arch=arm64' -derivedDataPath "$derived_data" -clonedSourcePackagesDirPath artifacts/Packages -onlyUsePackageVersionsFromResolvedFile build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO "APARTE_PRODUCT_NAME=$app_name" "APARTE_DISPLAY_NAME=$display_name" "APARTE_BUNDLE_IDENTIFIER=$bundle_identifier" 2>&1 | tee "artifacts/build-$configuration.log"
app="$derived_data/Build/Products/$configuration/$app_name.app"
if [[ $signing == local ]]; then
  ./scripts/local-signing.py sign "$app"
  echo "Built: $app (stable local development signature; not notarised)"
else
  /usr/bin/codesign --force --sign - --timestamp=none "$app"
  /usr/bin/codesign --verify --deep --strict "$app"
  echo "Built: $app (ad-hoc CI signature; not notarised or suitable for distribution)"
fi
