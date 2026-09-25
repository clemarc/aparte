# Release tracking

The current 0.4.13 app is a **local M4 candidate**, with formal real-device acceptance pending. M5A publishes source and CI development artifacts only. No public binary release, Developer ID signing or notarisation is configured.

Use `CHANGELOG.md` as the single human-written change record. Each user-visible PR adds a short entry under **Unreleased**, grouped as Added, Changed, Fixed, Removed or Security. Link an issue when useful. Keep internal implementation-only churn out of the changelog. Use GitHub issues and milestone `M5A` for CI/public-source work, and a separate `M5B` milestone only if signed distribution is later authorised. Close issues against the milestone; the changelog records what users receive.

For a future release, choose a SemVer version, update `Resources/Info.plist` and move the relevant Unreleased entries into a dated version section. Confirm the protected `main` CI result and the real-Mac acceptance ledger, including the checks still blocked on macOS 14 and external apps. Make an annotated `vX.Y.Z` tag only from that reviewed commit. GitHub Releases can then provide the source archive and notes copied from the changelog; attaching a public app binary requires a separate M5B decision and its Developer ID/notarisation checks. Do not label a CI development artifact as an installable release.

The CI artifact is ad-hoc signed, explicitly marked **NOT NOTARISED**, and retained for seven days for build inspection. It is not a deployment channel. There is no automatic publishing job or release credential in PR workflows.
