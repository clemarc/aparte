# Stable local development signing

Owner-approved D016 replaces ad-hoc development app signatures so rebuilds can have a compatible identity for macOS privacy grants. This is local development only: no Apple account, paid service, Developer ID, release key, notarisation, publication or trust-root installation is involved.

## Setup and normal updates

```sh
./scripts/local-signing.py setup
./scripts/build-local.sh --configuration Debug
./scripts/build-local.sh --configuration Release
./scripts/test-signing-local.py
# Quit Aparté through its menu, then:
./scripts/install-local.sh
open "$HOME/Applications/Aparte.app"
```

Setup reuses the existing identity. It never silently replaces missing/partial signing material. Builds fail if it is unavailable; they do not fall back to ad-hoc signing. Use the build script for a signed app. Direct Xcode builds have automatic signing disabled and must be signed with `scripts/local-signing.py sign <app>` before installation. The installer rejects unsigned/ad-hoc or wrong-certificate bundles.

The one-time transition from an existing ad-hoc build requires:

```sh
./scripts/install-local.sh --allow-signing-migration
```

This is an intentional identity change. After opening the updated installed app, grant its requested Microphone access and re-add this exact installed app in Accessibility if the old row no longer applies. If Microphone still shows an old enabled entry, quit Aparté, toggle that app's Microphone access off/on in System Settings and reopen; verify the actual app status. Input Monitoring is only relevant if the app reports its event tap cannot start. Do not automatically reset TCC, weaken Gatekeeper, or assume a checkbox proves the running app's access. Actual permissions surviving an update require an owner-granted test; matching signatures alone do not prove it.

The app may also be quit explicitly with `xcrun swift scripts/app-lifecycle.swift --quit`. Installation refuses a running installed instance, verifies a staged copy before replacement, and keeps the old bundle until the new one verifies. An interrupted install leaving `~/Applications/.Aparte.previous.app` fails closed on the next attempt; inspect/restore that backup rather than deleting it blindly. This avoids copying changing executable files underneath a live process.

## Local identity and private material

`~/Library/Application Support/Aparte/DevelopmentSigning/` is owner-only (0700); its configuration, dedicated keychain and unlock-secret file are 0600. The persistent self-signed RSA certificate is restricted to code signing and valid for ten years. Its private key is imported as non-extractable, with access scoped to codesign/Apple signing tools in this dedicated keychain. Temporary PEM/P12 material is removed after import. The encrypted keychain's unlock secret is kept locally for unattended development builds; both files rely on the owner's filesystem/account security. This is not hardware-backed key storage and does not protect against software already controlling the owner's account.

Signing briefly adds the dedicated keychain to the user's search list as required by codesign, then removes that entry and locks it again, including on failure. It does not set it as the default keychain, alter the login/system keychain, install certificate trust rules, or grant app permissions. A lock serializes operations on this identity. The code requirement pins the bundle identifier and the actual certificate fingerprint; it is not a bundle-name-only identity check.

Do not delete/recreate this directory between builds or copy it into the repository, chat, logs, or an evidence bundle. Losing/changing the identity can require fresh grants. Backups containing it are private credentials. Setup refuses partial state so a failed command cannot quietly replace a previously authorized identity. Certificate expiry/rotation or migration to a different signing authority needs a separate deliberate identity transition and repeat permission checks.

## Evidence and limits

`test-signing-local.py` compares Debug and Release binaries with different hashes, verifies both against each other's actual designated requirement, and rejects tampered resources and ad-hoc replacements. It never opens the microphone or changes grants. Evidence is in `docs/evidence/stable-signing.json`; live permission persistence remains separate.

Apple describes permission checks across updates in [TN3127](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements) and local self-signed identities in its [Code Signing Guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/Procedures/Procedures.html). This locally signed app is not a notarised distributable release.
