#!/usr/bin/env python3
"""Persistent local-only signing. Private material stays outside the checkout.

No trust settings, TCC grants, system keychains, accounts or release identities are
modified. The private key is non-exportable after import; only codesign receives
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
IDENTIFIER = 'dev.aparte.Aparte'


def run(args, *, data=None):
    result = subprocess.run([str(a) for a in args], input=data, text=True, capture_output=True)
    if result.returncode:
        # Never include argv: security's password options contain private values.
        raise RuntimeError(f'{Path(args[0]).name} failed ({result.returncode}): {result.stderr.strip()}')
    return result.stdout


def load():
    if not CONFIG.exists():
        raise RuntimeError('Local identity is not configured. Run ./scripts/local-signing.py setup once; no ad-hoc fallback is allowed.')
    for private_path in [ROOT, CONFIG, PASSWORD, KEYCHAIN]:
        if private_path.exists() and (private_path.is_symlink() or private_path.stat().st_uid != os.getuid() or private_path.stat().st_mode & 0o077):
            raise RuntimeError('Local signing material must be owned by this user, not symlinked, and inaccessible to other users.')
    config = json.loads(CONFIG.read_text())
    if config.get('schema') != 1 or not re.fullmatch(r'[A-F0-9]{40}', config.get('certificateSHA1', '')):
        raise RuntimeError('Invalid local signing configuration. Preserve the existing keychain; do not regenerate the identity.')
    if not KEYCHAIN.is_file() or not PASSWORD.is_file():
        raise RuntimeError('Local signing material is missing. Restore it; regenerating would invalidate existing grants.')
    return config


def requirement(config):
    return f'identifier "{IDENTIFIER}" and anchor H"{config["certificateSHA1"]}"'


def verify(app, config):
    run(['/usr/bin/codesign', '--verify', '--deep', '--strict', '-R', '=' + requirement(config), app])


def setup():
    if CONFIG.exists():
        config = load()
        print('Reusing existing local identity: ' + config['certificateSHA1'])
        return
    if KEYCHAIN.exists() or PASSWORD.exists():
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
CN = Aparte Local Development
[extensions]
basicConstraints = critical,CA:TRUE
keyUsage = critical,digitalSignature,keyCertSign
extendedKeyUsage = critical,codeSigning
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always
''')
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
            CONFIG.write_text(json.dumps({'schema': 1, 'certificateSHA1': fingerprint, 'purpose': 'Aparté local development only'}, indent=2) + '\n')
            (ROOT / 'certificate.pem').write_bytes((temporary / 'certificate.pem').read_bytes())
        finally:
            run(['/usr/bin/security', 'lock-keychain', KEYCHAIN])
    print('Created dedicated local development identity: ' + fingerprint)
    print('Private material is outside the repository. No trust settings were changed.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['setup', 'sign', 'verify', 'requirement', 'compare'])
    parser.add_argument('app', nargs='?')
    parser.add_argument('other_app', nargs='?')
    args = parser.parse_args()
    os.umask(0o077)
    if args.action == 'setup':
        ROOT.mkdir(parents=True, exist_ok=True, mode=0o700)
    if not ROOT.is_dir():
        raise RuntimeError('Run ./scripts/local-signing.py setup before building.')
    with (ROOT / '.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if args.action == 'setup':
            setup()
            return
        config = load()
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
        print('Verified certificate-backed local identity: ' + config['certificateSHA1'])


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, OSError, ValueError) as error:
        print('BLOCKED: ' + str(error), file=sys.stderr)
        sys.exit(2)
