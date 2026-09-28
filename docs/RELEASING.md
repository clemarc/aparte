# Release tracking

The current 0.4.13 app is a **local M4 candidate**, with formal real-device acceptance pending. M5A publishes source and CI development artifacts. Owner-approved D030 adds separate self-signed beta packaging and manual draft prereleases. No app binary has been published; Developer ID/notarisation remains deferred.

Use `CHANGELOG.md` as the single human-written change record. Each user-visible PR adds a short entry under **Unreleased**, grouped as Added, Changed, Fixed, Removed or Security. Link an issue when useful. Keep internal implementation-only churn out of the changelog. Use GitHub issues and the [M5A milestone](https://github.com/clemarc/aparte/milestone/1) for CI/public-source work, and a separate `M5B` milestone only if signed distribution is later authorised. Close issues against the milestone; the changelog records what users receive.

For a future source release, choose a SemVer version, update `Resources/Info.plist` and move the relevant Unreleased entries into a dated version section. Confirm the protected `main` CI result and review the real-Mac acceptance ledger, including the checks still blocked on macOS 14 and external apps. Merge the version/changelog PR after its required CI check passes. Make an annotated `vX.Y.Z` tag from that exact reviewed `main` commit and push the tag. In GitHub, open **Releases → Draft a new release**, choose that tag, set the version title and paste the matching changelog section into the notes. Save a draft for review, then publish it when the release criteria are met. GitHub supplies source archives for the tag; leave the binary attachment area empty for a source-only release. GitHub's [release instructions](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository) describe the current UI. No tag or GitHub Release is published yet.

## Release when ready, not on every version

Keep normal development on protected `main`. Version bumps and merges only run CI. Choose a `vX.Y.Z-beta.N` tag when deliberately preparing a beta; X.Y.Z must match the app's current version. Many internal versions can ship together in one release. A separate release branch is unnecessary until maintaining an older supported series alongside new development.

Keep user-facing changes under `CHANGELOG.md` → Unreleased until choosing a release. The package's notes include that accumulated section. The draft command adds GitHub-generated PR/contributor/compare notes from the most recently **published** release tag (including betas, excluding drafts); the first release has no previous tag. `.github/release.yml` groups labelled PRs, with a catch-all for unlabelled work. Review generated notes and move the shipped Unreleased entries into a dated version section in the version/release PR, before building its final committed source. Historical local candidate entries are not public releases. Only actual release tags identify distributed versions. See [GitHub generated notes](https://docs.github.com/en/repositories/releasing-projects-on-github/automatically-generated-release-notes).

## Stable self-signed beta packages

The beta certificate is separate from D016's development identity. Its public fingerprints and designated requirement are committed in `BETA-SIGNING.json`; private material stays under the owner-only `~/Library/Application Support/Aparte/BetaSigning/` directory. The key is non-exportable after import, with the same signing-tool access controls and temporary keychain membership as development signing. Preserve a private backup of the whole directory; losing it requires a deliberate signing migration. Setup reuses the identity and refuses to create a new one when a public pin already exists. No certificate trust rules are installed. Users receive the signed app, never the private material. Actual grant persistence remains a real-device test, not a claim from signature verification.

From a clean committed checkout on the signing Mac:

```sh
# Identity was created once for this project. This reuses it, never rotates it:
./scripts/local-signing.py --profile beta setup
./scripts/prepare-beta.py --tag v0.4.13-beta.1
./scripts/prepare-beta.py --verify artifacts/beta/v0.4.13-beta.1
```

Preparation builds Release through the CI command, runs unit tests, copies the app into isolated staging, signs with the pinned beta certificate, includes install/licence notices, creates a ZIP/checksums/source metadata, then extracts and verifies the signature again. It refuses dirty source, a wrong version/identity or an existing candidate directory. Outputs are ignored under `artifacts/beta/<tag>/`. It never installs over the development app or uploads private material. The ZIP is self-signed and **NOT NOTARISED**, not the ad-hoc CI artifact.

For a reviewed final candidate at the current protected `main` commit with passing hosted CI:

```sh
git tag -a v0.4.13-beta.1 -m 'Aparté 0.4.13 beta 1'
git push origin v0.4.13-beta.1
./scripts/draft-beta-release.py artifacts/beta/v0.4.13-beta.1
```

The draft command requires `gh` authenticated to GitHub, verifies the personal `clemarc/aparte` remote, annotated remote tag, exact current main/source commit, package signature/checksums and successful main build. It uploads only the ZIP, checksums and public metadata to a **draft prerelease** with notes, never publishes or marks it latest. It refuses existing releases rather than replacing their assets. Review the draft in GitHub; publish manually only after the concrete artifact and validation ledger have been reviewed. A failed upload may leave a partial draft; inspect its assets before retrying, do not silently overwrite it.

Before publication, use a fresh Mac to download/open the packaged app with normal quarantine intact, follow Apple's per-app Open Anyway UI, grant Microphone/Accessibility, then install a second beta with a different executable and confirm both capabilities still work without re-grant. Do not substitute ZIP/signature tests for these checks. Keep the M4 microphone/target/UI/login/macOS14 blockers in the release notes. [BETA-INSTALL.md](BETA-INSTALL.md) is bundled for users. A future Developer ID identity will be a deliberate migration and may require new grants.

Hosted signing and automatic publishing are not configured. A future protected release environment must keep signing secrets out of PR jobs; it needs a separately approved credential migration because this local key is non-exportable. Developer ID, hardened-runtime/notarisation/stapling and clean-Mac Gatekeeper checks remain a separate distribution option.

The CI artifact remains ad-hoc signed, explicitly marked **NOT NOTARISED**, and retained for seven days for build inspection. It is not a deployment channel. There is no automatic publishing job or release credential in PR workflows.
