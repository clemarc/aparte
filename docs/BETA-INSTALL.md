# Install an Aparté beta

These experimental builds are for **Apple Silicon (arm64), macOS 14 or later**. They are signed with a persistent Aparté beta certificate, **not signed with Apple Developer ID and not notarised by Apple**. Minimum-OS execution and the full live-device acceptance matrix remain unverified; see the release notes and acceptance ledger. Model weights are not included.

1. Download the beta ZIP and `SHA256SUMS` from the same release in [clemarc/aparte](https://github.com/clemarc/aparte/releases). To check download integrity, run `shasum -a 256 -c SHA256SUMS` in their download directory with `release.json` present. Checksums detect changes against the published record; they do not independently establish publisher trust.
2. Quit every running Aparté copy through its menu. Extract the ZIP and move `Aparte.app` into Applications. When updating, replace the previous app at the same path after quitting it; keep a backup until the new version works. Do not run it from the ZIP/extracted staging directory.
3. Open the installed app. If macOS blocks this unidentified developer, follow Apple's [Open Anyway instructions](https://support.apple.com/en-gb/102445): after the blocked attempt, go to System Settings → Privacy & Security and approve that app. Availability depends on the OS and device policy; managed Macs may prohibit it. Do not disable Gatekeeper, remove quarantine recursively, or install/trust a root certificate.
4. In Settings & Setup, explicitly download Small (the default) or import its verified model files, then Prepare / Use. Grant Microphone and Accessibility when requested. Recheck; restart Aparté if the grant has not taken effect. Input Monitoring is needed only when the app reports the event tap cannot start.
5. Test dictation first in the app's test box, then in a disposable target field. Aparté normally lives in the menu bar and has no Dock icon. Recovery text may be placed on the system clipboard; inspect the target before manually pasting an unconfirmed result.

## Updating and permissions

Beta builds retain the same bundle ID and pinned beta certificate. This supports identity continuity across updates, but actual Microphone/Accessibility permission persistence is still awaiting a two-version test on a fresh Mac. Switching from a development/ad-hoc build to this beta identity, or later to Developer ID, may require new grants. Only grant the exact installed copy. You never need the signing private key or a certificate trust installation.

There is no automatic updater. Download future betas from the same GitHub repository. Models and preferences are stored outside the app and should survive replacement. Keep only one running Aparté copy so an old Settings window is not mistaken for the new version.
