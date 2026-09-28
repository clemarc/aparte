#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p artifacts/brand
xcrun swiftc -module-cache-path artifacts/brand/ModuleCache Sources/Aparte/Branding.swift scripts/render-brand.swift -o artifacts/brand/render-brand
artifacts/brand/render-brand artifacts/brand/Aparte.iconset
/usr/bin/iconutil -c icns artifacts/brand/Aparte.iconset -o Resources/Aparte.icns
