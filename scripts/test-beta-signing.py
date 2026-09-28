#!/usr/bin/env python3
"""Exercise real beta signatures on two different compiled apps; no OS grants."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
SIGNER = ROOT / 'scripts/local-signing.py'
ARTIFACTS = ROOT / 'artifacts'


def command(args, succeeds=True):
    result = subprocess.run([str(a) for a in args], cwd=ROOT, capture_output=True, text=True)
    if (result.returncode == 0) != succeeds:
        raise RuntimeError(f'Unexpected result from {args[0]}: {result.returncode}\n{result.stdout}{result.stderr}')
    return result.stdout + result.stderr


with tempfile.TemporaryDirectory(prefix='beta-signing-check-', dir=ARTIFACTS) as temporary:
    apps, records = {}, {}
    for configuration in ['Debug', 'Release']:
        app = Path(temporary) / configuration / 'Aparte.app'
        shutil.copytree(ARTIFACTS / f'StandardDerivedData/Build/Products/{configuration}/Aparte.app', app)
        command([SIGNER, '--profile', 'beta', 'sign', app])
        output = command(['/usr/bin/codesign', '-d', '-r-', app])
        requirement = next(line.removeprefix('designated => ') for line in output.splitlines() if line.startswith('designated => '))
        apps[configuration] = app
        records[configuration] = {'requirement': requirement, 'binarySHA256': hashlib.sha256((app / 'Contents/MacOS/Aparte').read_bytes()).hexdigest()}
    assert records['Debug']['binarySHA256'] != records['Release']['binarySHA256'], 'Need different built executables'
    assert records['Debug']['requirement'] == records['Release']['requirement'], 'Beta identity changed'
    assert 'cdhash' not in records['Debug']['requirement'], 'Identity must not pin a changing executable hash'
    command([SIGNER, '--profile', 'beta', 'compare', apps['Debug'], apps['Release']])
    # Development and beta identities must be distinct, in both directions.
    command([SIGNER, 'verify', apps['Release']], succeeds=False)
    development = ARTIFACTS / 'DerivedData/Build/Products/Release/Aparte Dew.app'
    command([SIGNER, 'verify', development])
    command([SIGNER, '--profile', 'beta', 'verify', development], succeeds=False)
    negative = Path(temporary) / 'negative/Aparte.app'
    shutil.copytree(apps['Release'], negative)
    resource = negative / 'Contents/Resources/Compatibility.json'
    resource.write_bytes(resource.read_bytes() + b'\n')
    command([SIGNER, '--profile', 'beta', 'verify', negative], succeeds=False)
    shutil.rmtree(negative)
    shutil.copytree(apps['Release'], negative)
    command(['/usr/bin/codesign', '--force', '--sign', '-', negative])
    command([SIGNER, '--profile', 'beta', 'verify', negative], succeeds=False)
report = {'status': 'PASS', 'builds': records, 'mutualRequirementVerification': 'PASS',
          'tamperedResourceRejected': 'PASS', 'adHocReplacementRejected': 'PASS', 'separateDevelopmentIdentity': 'PASS',
          'permissionPersistence': 'BLOCKED: no fresh-Mac grant/update capability test',
          'gatekeeperDownloadedLaunch': 'BLOCKED: no fresh-Mac downloaded launch test'}
(ARTIFACTS / 'beta-signing-checks.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
