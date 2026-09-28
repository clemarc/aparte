#!/usr/bin/env python3
"""Build, sign and verify a local beta archive. Never installs or publishes it."""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent
SIGNER = ROOT / 'scripts/local-signing.py'
REPOSITORY = 'clemarc/aparte'


def run(args):
    result = subprocess.run([str(a) for a in args], cwd=ROOT, text=True, capture_output=True)
    if result.returncode:
        raise RuntimeError(f'{Path(args[0]).name} failed: {result.stderr.strip() or result.stdout[-2000:]}')
    return result.stdout.strip()


def digest(path):
    checksum = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            checksum.update(chunk)
    return checksum.hexdigest()


def beta_version(tag):
    match = re.fullmatch(r'v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)-beta\.([1-9][0-9]*)', tag)
    if not match:
        raise RuntimeError('Expected vX.Y.Z-beta.N, for example v0.4.13-beta.1.')
    return '.'.join(match.groups()[:3])


def release_changes(changelog, tag):
    sections = re.split(r'^## ', changelog, flags=re.MULTILINE)[1:]
    for title in (tag.removeprefix('v'), 'Unreleased'):
        for section in sections:
            heading, _, body = section.partition('\n')
            if heading == title or heading.startswith(title + ' — '):
                return body.strip() or 'No user-facing changes recorded.'
    raise RuntimeError('CHANGELOG.md needs the selected beta section or an Unreleased section.')


def signing_info():
    actual = json.loads(run([SIGNER, '--profile', 'beta', 'public-info']))
    expected = json.loads((ROOT / 'docs/BETA-SIGNING.json').read_text())
    if actual != expected or expected.get('profile') != 'beta' or expected.get('notarised') is not False:
        raise RuntimeError('Local beta certificate differs from the committed public identity.')
    return actual


def verify_app(app, version):
    run([SIGNER, '--profile', 'beta', 'verify', app])
    with (app / 'Contents/Info.plist').open('rb') as stream:
        info = plistlib.load(stream)
    if info.get('CFBundleIdentifier') != 'dev.aparte.Aparte' or info.get('CFBundleShortVersionString') != version:
        raise RuntimeError('Bundle identifier/version does not match the beta tag.')
    executable = app / 'Contents/MacOS' / info['CFBundleExecutable']
    if run(['/usr/bin/lipo', '-archs', executable]) != 'arm64':
        raise RuntimeError('Beta must contain the intended arm64 executable.')
    return info


def validate_package(directory):
    metadata = json.loads((directory / 'release.json').read_text())
    version = beta_version(metadata['tag'])
    expected = signing_info()
    if metadata.get('signing') != expected or metadata.get('repository') != REPOSITORY:
        raise RuntimeError('Archive metadata has the wrong repository/signing identity.')
    if not re.fullmatch(r'[0-9a-f]{40}', metadata.get('sourceCommit', '')):
        raise RuntimeError('Missing exact source commit.')
    name = f'Aparte-{metadata["tag"]}-arm64-self-signed-NOT-NOTARISED.zip'
    archive = directory / name
    if metadata.get('archive') != name or metadata.get('archiveSHA256') != digest(archive):
        raise RuntimeError('Archive checksum does not match release metadata.')
    checksums = f'{digest(archive)}  {name}\n{digest(directory / "release.json")}  release.json\n'
    if (directory / 'SHA256SUMS').read_text() != checksums:
        raise RuntimeError('SHA256SUMS differs from the archive/metadata.')
    # Only extract our locally generated bundle; no arbitrary third-party ZIPs.
    import zipfile
    import stat
    with zipfile.ZipFile(archive) as stream:
        for member in stream.infolist():
            path = Path(member.filename)
            if path.is_absolute() or '..' in path.parts or (path.parts and path.parts[0] not in ('Aparte Beta', '__MACOSX')):
                raise RuntimeError('Unexpected archive member.')
            if stat.S_ISLNK(member.external_attr >> 16):
                raise RuntimeError('Beta archive must not contain symlinks.')
    with tempfile.TemporaryDirectory(prefix='beta-roundtrip-', dir=ROOT / 'artifacts') as temporary:
        run(['/usr/bin/ditto', '-x', '-k', archive, temporary])
        app = Path(temporary) / 'Aparte Beta/Aparte.app'
        info = verify_app(app, version)
        provenance = json.loads((app / 'Contents/Resources/BetaRelease.json').read_text())
        if provenance != {key: metadata[key] for key in ('tag', 'sourceCommit', 'appVersion', 'signing')}:
            raise RuntimeError('Signed app provenance does not match release metadata.')
        if metadata.get('appBuild') != info['CFBundleVersion'] or metadata.get('minimumMacOS') != info['LSMinimumSystemVersion']:
            raise RuntimeError('Release metadata does not match the app.')
    return metadata


def prepare(tag):
    version = beta_version(tag)
    if run(['git', 'status', '--porcelain', '--untracked-files=normal']):
        raise RuntimeError('Commit the source changes before preparing a beta.')
    commit = run(['git', 'rev-parse', 'HEAD'])
    with (ROOT / 'Resources/Info.plist').open('rb') as stream:
        if plistlib.load(stream)['CFBundleShortVersionString'] != version:
            raise RuntimeError('Tag version must match Resources/Info.plist.')
    signing = signing_info()
    changes = release_changes((ROOT / 'CHANGELOG.md').read_text(), tag)
    output = ROOT / 'artifacts/beta' / tag
    if output.exists():
        raise RuntimeError('This candidate directory already exists. Preserve it; choose a new beta number.')
    # Run the same clean-source commands as CI. No development identity is used.
    for command in [['./scripts/build-local.sh', '--configuration', 'Release', '--signing', 'adhoc'],
                    ['./scripts/test-local.sh', '--suite', 'unit']]:
        if subprocess.run(command, cwd=ROOT).returncode:
            raise RuntimeError('Build/test failed; no beta package prepared.')
    if run(['git', 'rev-parse', 'HEAD']) != commit or run(['git', 'status', '--porcelain', '--untracked-files=normal']):
        raise RuntimeError('Source changed during the build.')
    output.mkdir(parents=True)
    with tempfile.TemporaryDirectory(prefix='beta-stage-', dir=ROOT / 'artifacts') as temporary:
        payload = Path(temporary) / 'Aparte Beta'
        payload.mkdir()
        app = payload / 'Aparte.app'
        run(['/usr/bin/ditto', ROOT / 'artifacts/DerivedData/Build/Products/Release/Aparte.app', app])
        (app / 'Contents/Resources/BetaRelease.json').write_text(json.dumps(
            {'tag': tag, 'sourceCommit': commit, 'appVersion': version, 'signing': signing}, indent=2) + '\n')
        run([SIGNER, '--profile', 'beta', 'sign', app])
        info = verify_app(app, version)
        shutil.copy2(ROOT / 'docs/BETA-INSTALL.md', payload / 'INSTALL.md')
        shutil.copy2(ROOT / 'LICENSE', payload / 'LICENSE')
        shutil.copy2(ROOT / 'docs/THIRD_PARTY.md', payload / 'THIRD_PARTY.md')
        shutil.copytree(ROOT / 'docs/third-party', payload / 'third-party')
        archive = output / f'Aparte-{tag}-arm64-self-signed-NOT-NOTARISED.zip'
        run(['/usr/bin/ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', payload, archive])
    metadata = {'schema': 1, 'tag': tag, 'repository': REPOSITORY, 'sourceCommit': commit,
                'appVersion': version, 'appBuild': info['CFBundleVersion'], 'minimumMacOS': info['LSMinimumSystemVersion'],
                'architecture': 'arm64', 'archive': archive.name, 'archiveSHA256': digest(archive), 'signing': signing,
                'validation': {'build': 'PASS', 'unitTests': 'PASS', 'archiveSignature': 'PASS',
                               'cleanMacGatekeeper': 'BLOCKED', 'permissionPersistence': 'BLOCKED', 'M4Acceptance': 'BLOCKED'}}
    (output / 'release.json').write_text(json.dumps(metadata, indent=2) + '\n')
    (output / 'SHA256SUMS').write_text(f'{digest(archive)}  {archive.name}\n{digest(output / "release.json")}  release.json\n')
    validate_package(output)
    (output / 'RELEASE-NOTES.md').write_text(
        f'# Aparté {tag}\n\nExperimental beta for Apple Silicon Macs. Self-signed; **not notarised by Apple**.\n\n'
        'Download the ZIP and follow INSTALL.md. Models download separately after an explicit action.\n\n'
        f'Source commit: `{commit}`. Verify the archive using SHA256SUMS.\n\n'
        f'## Changes accumulated for this release\n\n{changes}\n\n'
        '## Validation and known limitations\n\n'
        'Release build, unit tests and archive signature verified locally. Clean-Mac downloaded launch and '
        'Microphone/Accessibility permission persistence across updates remain unverified. '
        'Formal M4 live microphone, external-app insertion, UI/login and macOS 14 acceptance is pending.\n\n'
        'Review CHANGELOG.md and docs/ACCEPTANCE.md before publication. This draft is not an accepted stable release.\n')
    print(f'Prepared and verified: {output.relative_to(ROOT)} (not installed or published)')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--tag')
    group.add_argument('--verify', type=Path)
    args = parser.parse_args()
    if args.verify:
        print(json.dumps(validate_package(args.verify.resolve()), indent=2))
    else:
        prepare(args.tag)


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, OSError, ValueError, KeyError) as error:
        print('BLOCKED: ' + str(error), file=sys.stderr)
        sys.exit(2)
