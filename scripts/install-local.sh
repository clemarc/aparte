#!/bin/bash
source "$(dirname "$0")/common.sh"
source_app=artifacts/DerivedData/Build/Products/Release/Aparte.app
[[ -d "$source_app" ]] || { echo 'Build Release first.' >&2; exit 2; }
destination="$HOME/Applications/Aparte.app"
if [[ -e "$destination" ]]; then
  identifier=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$destination/Contents/Info.plist" 2>/dev/null || true)
  [[ "$identifier" == dev.aparte.Aparte ]] || { echo 'Refusing to replace an unrelated existing app.' >&2; exit 2; }
fi
mkdir -p "$HOME/Applications"
ditto "$source_app" "$destination"
codesign --verify --deep --strict "$destination"
echo 'Installed locally at ~/Applications/Aparte.app (ad-hoc signed, not notarised).'
