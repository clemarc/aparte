#!/bin/bash
source "$(dirname "$0")/common.sh"
allow_migration=false
if [[ $# == 1 && $1 == --allow-signing-migration ]]; then allow_migration=true
elif [[ $# != 0 ]]; then echo 'Usage: install-local.sh [--allow-signing-migration]' >&2; exit 64; fi
source_app=artifacts/DerivedData/Build/Products/Release/Aparte.app
[[ -d "$source_app" ]] || { echo 'Build Release first.' >&2; exit 2; }
./scripts/local-signing.py verify "$source_app"
destination="$HOME/Applications/Aparte.app"
if [[ -e "$destination" ]]; then
  identifier=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$destination/Contents/Info.plist" 2>/dev/null || true)
  [[ "$identifier" == dev.aparte.Aparte ]] || { echo 'Refusing to replace an unrelated existing app.' >&2; exit 2; }
  if ! ./scripts/local-signing.py compare "$destination" "$source_app" >/dev/null 2>&1; then
    if ! $allow_migration; then
      echo 'BLOCKED: signing identity would change. Use --allow-signing-migration only for an intentional one-time transition; fresh owner grants may be needed.' >&2
      exit 2
    fi
    echo 'Intentional signing transition: fresh owner permission grants may be needed.'
  fi
fi
# Never overwrite the bundle behind a running process.
xcrun swift scripts/app-lifecycle.swift
mkdir -p "$HOME/Applications"
staging=$(mktemp -d "$HOME/Applications/.aparte-install.XXXXXX")
backup="$HOME/Applications/.Aparte.previous.app"
[[ ! -e "$backup" ]] || { rmdir "$staging"; echo 'A previous install backup exists; investigate before replacing it.' >&2; exit 2; }
trap 'rm -rf "$staging"' EXIT
ditto "$source_app" "$staging/Aparte.app"
./scripts/local-signing.py verify "$staging/Aparte.app"
if [[ -e "$destination" ]]; then mv "$destination" "$backup"; fi
if ! mv "$staging/Aparte.app" "$destination"; then
  if [[ -e "$backup" ]]; then mv "$backup" "$destination"; fi
  exit 1
fi
if ! ./scripts/local-signing.py verify "$destination"; then
  mv "$destination" "$staging/failed.app"
  if [[ -e "$backup" ]]; then mv "$backup" "$destination"; fi
  exit 1
fi
if [[ -e "$backup" ]]; then rm -rf "$backup"; fi
echo 'Installed locally at ~/Applications/Aparte.app (stable local development signature; not notarised).'
