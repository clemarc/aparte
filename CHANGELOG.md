# Changelog

Changes to Aparté are recorded here in [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format. Version numbers follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html); before 1.0, minor versions may contain incompatible changes. The entries below describe local candidates, not public binary releases.

## Unreleased

### Added

- MIT public-source licence, contribution guidance and source-only CI for arm64 macOS with Xcode 27.
- An ad-hoc signed development build artifact from CI. It is not notarised or intended for distribution.
- A separate persistent self-signed beta identity, verified local ZIP packaging and manual GitHub draft prereleases with accumulated release notes. Beta builds are not Apple-notarised; downloaded launch and permission persistence still need real-Mac validation.

## 0.5.1 — 2026-09-29 (local candidate)

### Fixed

- Microphone configuration changes are observed only for the current capture engine. Notifications from other or retired engines cannot cancel a new hold or frozen audio during transcription/insertion.
- Capture observers are removed before engine teardown; genuine changes during startup/recording still cancel safely and use the current default input on the next attempt.

## 0.5.0 — 2026-09-28 (local UX candidate)

### Added

- Workspace with Try it, Processing, Shortcuts and Settings, plus a capability-based first-open setup guide.
- Compact menu bar companion and the selected voice-to-text logo as scalable UI, menu template and app icon assets.
- Separate recognition, text handling and insertion presentation. Text handling remains off; LLM processing is deferred.

### Changed

- Shortcut capture previews modifiers, explains rejection, waits for release and requires explicit Save. The previous binding is preserved until saved.
- Detection-only tests report press and release. Fn/Globe and modifier-only bindings remain unsupported.
- Leaving Try it cancels and clears a local diagnostic session. Model controls retain active-versus-preview distinction and measured comparisons.
- Local/CI builds are named Aparte Dew, with Aparte Dew.app and a separate bundle identifier, preferences, permissions and model storage; beta identity remains unchanged.
- Build 16 identifies this development candidate. No beta package, tag or publication is created by this version bump.

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
