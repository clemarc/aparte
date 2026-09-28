#!/usr/bin/env python3
"""Persistent development or beta signing. Private material stays outside Git.

No trust settings, TCC grants, system keychains or Apple accounts are modified.
The default profile reuses the existing development certificate for the Dew app identifier. The beta profile
uses a separate owner-authorized self-signed identity. The key is non-exportable
after import; only codesign receives
access. The dedicated keychain and its unlock secret have owner-only permissions.
"""
import argparse
import fcntl
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import tempfile

ROOT = Path.home() / 'Library/Application Support/Aparte/DevelopmentSigning'
KEYCHAIN = ROOT / 'development.keychain-db'
CONFIG = ROOT / 'identity.json'
PASSWORD = ROOT / 'keychain-password'
IDENTIFIER = 'dev.aparte.Aparte.dew'
PROFILE = 'development'
PURPOSE = 'Aparté local development only'
COMMON_NAME = 'Aparte Local Development'
PIN = Path(__file__).resolve().parent.parent / 'docs/BETA-SIGNING.json'


def run(args, *, data=None):
    result = subprocess.run([str(a) for a in args], input=data, text=True, capture_output=True)
    if result.returncode:
        # Never include argv: security's password options contain private values.
        raise RuntimeError(f'{Path(args[0]).name} failed ({result.returncode}): {result.stderr.strip()}')
    return result.stdout


def load(*, allow_unpinned=False):
    if not CONFIG.exists():
        raise RuntimeError(f'{PROFILE} identity is not configured. Run local-signing.py --profile {PROFILE} setup; no ad-hoc fallback is allowed.')
    for private_path in [ROOT, CONFIG, PASSWORD, KEYCHAIN]:
        if private_path.exists() and (private_path.is_symlink() or private_path.stat().st_uid != os.getuid() or private_path.stat().st_mode & 0o077):
            raise RuntimeError('Local signing material must be owned by this user, not symlinked, and inaccessible to other users.')
    config = json.loads(CONFIG.read_text())
    if config.get('schema') != 1 or not re.fullmatch(r'[A-F0-9]{40}', config.get('certificateSHA1', '')):
        raise RuntimeError('Invalid local signing configuration. Preserve the existing keychain; do not regenerate the identity.')
    if not KEYCHAIN.is_file() or not PASSWORD.is_file():
        raise RuntimeError('Local signing material is missing. Restore it; regenerating would invalidate existing grants.')
    if config.get('purpose') != PURPOSE:
        raise RuntimeError('Signing identity has the wrong purpose.')
    if PROFILE == 'beta':
        if PIN.exists():
            pin = json.loads(PIN.read_text())
            if pin.get('certificateSHA1') != config['certificateSHA1'] or pin.get('bundleIdentifier') != IDENTIFIER:
                raise RuntimeError('Beta identity does not match the public pin. Restore the original identity; do not rotate silently.')
        elif not allow_unpinned:
            raise RuntimeError('Commit docs/BETA-SIGNING.json from the beta public-info command before signing.')
    return config


def requirement(config):
    return f'identifier "{IDENTIFIER}" and anchor H"{config["certificateSHA1"]}"'


def verify(app, config):
    run(['/usr/bin/codesign', '--verify', '--deep', '--strict', '-R', '=' + requirement(config), app])


def setup():
    if CONFIG.exists():
        config = load(allow_unpinned=True)
        print(f'Reusing existing {PROFILE} identity: ' + config['certificateSHA1'])
        return
    if PROFILE == 'beta' and PIN.exists():
        raise RuntimeError('A public beta identity is already pinned. Restore its private keychain; do not create a replacement.')
    if any(path.name != '.lock' for path in ROOT.iterdir()):
        raise RuntimeError('Incomplete local identity setup exists. Preserve it and investigate; refusing to replace a potentially used key.')
    password = os.urandom(32).hex()
    # Creation can alter the keychain search list. Restore its exact previous value.
    search_list = shlex.split(run(['/usr/bin/security', 'list-keychains', '-d', 'user']))
    with tempfile.TemporaryDirectory(prefix='creation-', dir=ROOT) as directory:
        temporary = Path(directory)
        (temporary / 'certificate.cnf').write_text('''[req]
prompt = no
distinguished_name = name
x509_extensions = extensions
[name]
CN = SIGNING_COMMON_NAME
[extensions]
basicConstraints = critical,CA:TRUE
keyUsage = critical,digitalSignature,keyCertSign
extendedKeyUsage = critical,codeSigning
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always
'''.replace('SIGNING_COMMON_NAME', COMMON_NAME))
        (temporary / 'password').write_text(password)
        run(['/usr/bin/openssl', 'req', '-new', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '3650', '-sha256',
             '-config', temporary / 'certificate.cnf', '-keyout', temporary / 'private.pem', '-out', temporary / 'certificate.pem'])
        run(['/usr/bin/openssl', 'pkcs12', '-export', '-inkey', temporary / 'private.pem', '-in', temporary / 'certificate.pem',
             '-out', temporary / 'identity.p12', '-passout', f'file:{temporary / "password"}'])
        fingerprint = run(['/usr/bin/openssl', 'x509', '-in', temporary / 'certificate.pem', '-noout', '-fingerprint', '-sha1']).strip().split('=')[-1].replace(':', '').upper()
        try:
            run(['/usr/bin/security', 'create-keychain', '-p', password, KEYCHAIN])
        finally:
            run(['/usr/bin/security', 'list-keychains', '-d', 'user', '-s', *search_list])
        PASSWORD.write_text(password)
        run(['/usr/bin/security', 'set-keychain-settings', '-l', '-u', '-t', '600', KEYCHAIN])
        run(['/usr/bin/security', 'unlock-keychain', '-p', password, KEYCHAIN])
        try:
            run(['/usr/bin/security', 'import', temporary / 'identity.p12', '-k', KEYCHAIN, '-f', 'pkcs12', '-P', password, '-x', '-T', '/usr/bin/codesign'])
            run(['/usr/bin/security', 'set-key-partition-list', '-S', 'apple-tool:,codesign:', '-s', '-k', password, KEYCHAIN])
            CONFIG.write_text(json.dumps({'schema': 1, 'certificateSHA1': fingerprint, 'purpose': PURPOSE}, indent=2) + '\n')
            (ROOT / 'certificate.pem').write_bytes((temporary / 'certificate.pem').read_bytes())
        finally:
            run(['/usr/bin/security', 'lock-keychain', KEYCHAIN])
    print(f'Created dedicated {PROFILE} identity: ' + fingerprint)
    print('Private material is outside the repository. No trust settings were changed.')


def main():
    global ROOT, KEYCHAIN, CONFIG, PASSWORD, PROFILE, PURPOSE, COMMON_NAME, IDENTIFIER
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=['development', 'beta'], default='development')
    parser.add_argument('action', choices=['setup', 'sign', 'verify', 'requirement', 'compare', 'public-info'])
    parser.add_argument('app', nargs='?')
    parser.add_argument('other_app', nargs='?')
    args = parser.parse_args()
    PROFILE = args.profile
    if PROFILE == 'beta':
        IDENTIFIER = 'dev.aparte.Aparte'
        ROOT = Path.home() / 'Library/Application Support/Aparte/BetaSigning'
        KEYCHAIN = ROOT / 'beta.keychain-db'
        CONFIG = ROOT / 'identity.json'
        PASSWORD = ROOT / 'keychain-password'
        PURPOSE = 'Aparté self-signed beta releases'
        COMMON_NAME = 'Aparte Beta Release'
    os.umask(0o077)
    if args.action == 'setup':
        ROOT.mkdir(parents=True, exist_ok=True, mode=0o700)
    if not ROOT.is_dir():
        raise RuntimeError('Run ./scripts/local-signing.py setup before building.')
    if ROOT.is_symlink() or ROOT.stat().st_uid != os.getuid() or ROOT.stat().st_mode & 0o077:
        raise RuntimeError('Signing directory must be owner-only and not symlinked.')
    lock_path = ROOT / '.lock'
    if lock_path.is_symlink():
        raise RuntimeError('Signing lock must not be a symlink.')
    with lock_path.open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if args.action == 'setup':
            setup()
            return
        config = load(allow_unpinned=args.action == 'public-info')
        if args.action == 'public-info':
            certificate = ROOT / 'certificate.pem'
            digest = run(['/usr/bin/openssl', 'x509', '-in', certificate, '-noout', '-fingerprint', '-sha256']).strip().split('=')[-1].replace(':', '').upper()
            print(json.dumps({'schema': 1, 'profile': PROFILE, 'bundleIdentifier': IDENTIFIER,
                              'certificateSHA1': config['certificateSHA1'], 'certificateSHA256': digest,
                              'designatedRequirement': requirement(config), 'notarised': False}, indent=2))
            return
        if args.action == 'requirement':
            print(requirement(config))
            return
        if not args.app or not Path(args.app).is_dir():
            raise RuntimeError('Supply an existing Aparte.app bundle.')
        app = Path(args.app).resolve()
        import plistlib
        with (app / 'Contents/Info.plist').open('rb') as stream:
            if plistlib.load(stream).get('CFBundleIdentifier') != IDENTIFIER:
                raise RuntimeError('Refusing an unrelated app bundle.')
        if args.action == 'compare':
            if not args.other_app or not Path(args.other_app).is_dir():
                raise RuntimeError('Supply both old and new app bundles for identity comparison.')
            other = Path(args.other_app).resolve()
            verify(app, config); verify(other, config)
            for source, target in [(app, other), (other, app)]:
                result = subprocess.run(['/usr/bin/codesign', '-d', '-r-', str(source)], text=True, capture_output=True)
                lines = (result.stdout + result.stderr).splitlines()
                requirements = [line[len('designated => '):] for line in lines if line.startswith('designated => ')]
                if result.returncode or len(requirements) != 1:
                    raise RuntimeError('Could not read the actual designated requirement.')
                run(['/usr/bin/codesign', '--verify', '--deep', '--strict', '-R', '=' + requirements[0], target])
            print('Old and new apps satisfy each other’s actual designated requirements.')
            return
        if args.action == 'sign':
            password = PASSWORD.read_text()
            search_list = shlex.split(run(['/usr/bin/security', 'list-keychains', '-d', 'user']))
            added = str(KEYCHAIN) not in search_list
            if added:
                run(['/usr/bin/security', 'list-keychains', '-d', 'user', '-s', *search_list, KEYCHAIN])
            try:
                run(['/usr/bin/security', 'unlock-keychain', '-p', password, KEYCHAIN])
                run(['/usr/bin/codesign', '--force', '--sign', config['certificateSHA1'], '--keychain', KEYCHAIN,
                     '--timestamp=none', '--requirements', '=designated => ' + requirement(config), app])
            finally:
                try:
                    run(['/usr/bin/security', 'lock-keychain', KEYCHAIN])
                finally:
                    if added:
                        current = shlex.split(run(['/usr/bin/security', 'list-keychains', '-d', 'user']))
                        run(['/usr/bin/security', 'list-keychains', '-d', 'user', '-s', *[x for x in current if x != str(KEYCHAIN)]])
        verify(app, config)
        print(f'Verified certificate-backed {PROFILE} identity: ' + config['certificateSHA1'])


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, OSError, ValueError) as error:
        print('BLOCKED: ' + str(error), file=sys.stderr)
        sys.exit(2)
