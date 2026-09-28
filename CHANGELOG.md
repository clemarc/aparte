# Changelog

Changes to Aparté are recorded here in [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format. Version numbers follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html); before 1.0, minor versions may contain incompatible changes. The entries below describe local candidates, not public binary releases.

## Unreleased

### Added

- MIT public-source licence, contribution guidance and source-only CI for arm64 macOS with Xcode 27.
- An ad-hoc signed development build artifact from CI. It is not notarised or intended for distribution.
- A separate persistent self-signed beta identity, verified local ZIP packaging and manual GitHub draft prereleases with accumulated release notes. Beta builds are not Apple-notarised; downloaded launch and permission persistence still need real-Mac validation.

## 0.4.13-beta.2 — 2026-09-28 (review candidate)

### Changed

- Build 15 displays its build number in Settings and diagnostics, so the installed update can be identified during the two-beta permission test.
- Uses the same persistent beta signing identity as beta 1. Real permission continuity awaits the owner's update test.

## 0.4.13 — 2026-09-25 (local candidate)

### Added

- A prominent four-model picker and running version labels in Settings and the menu bar.
- A local installer guard against a second Aparté copy running from the checkout.

### Fixed

- Reduced the chance of mistaking an older Debug Settings window for the installed app.

## 0.4.12 — 2026-09-24 (local candidate)

### Added

- Optional pinned multilingual medium and large-v3-turbo models with measured in-app comparisons.

## 0.4.11 — 2026-09-24 (local candidate)

### Added

- A guarded return to the original window after consulting another app during dictation.
- A Recovery clipboard handoff for manual paste when automatic insertion cannot be verified.
