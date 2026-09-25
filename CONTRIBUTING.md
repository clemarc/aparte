# Contributing

Aparté is a macOS 14+ arm64 project. Use Xcode 27 and the commands in [README.md](README.md) for local builds and tests. The committed Swift package lockfiles are authoritative; keep them in sync when updating dependencies.

For a clean source checkout without the owner's local development identity:

```sh
swift package resolve
./scripts/build-local.sh --configuration Release --signing adhoc
./scripts/test-local.sh --suite unit
```

The ad-hoc app is a development artifact. It may need separate macOS privacy grants and is not a notarised download. The owner's stable local signing path remains `./scripts/local-signing.py setup` followed by the default build command. Do not commit signing material, model weights, build output, personal recordings or transcripts.

Pull requests should explain the user-visible change, update [CHANGELOG.md](CHANGELOG.md) under Unreleased, and include relevant automated results. CI runs the build and unit tests without secrets. Model inference and macOS permission, microphone, accessibility and cross-app insertion checks require the real-Mac process in [docs/ACCEPTANCE.md](docs/ACCEPTANCE.md) and [docs/HANDOFF.md](docs/HANDOFF.md). A passing PR build does not imply those checks passed.

Keep third-party and model provenance current in [docs/THIRD_PARTY.md](docs/THIRD_PARTY.md) when pins change. Avoid logging speech, clipboard contents or unrelated keystrokes.
