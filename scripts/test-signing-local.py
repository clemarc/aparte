#!/usr/bin/env python3
"""Real signature continuity and negative checks; never requests OS permissions."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
ARTIFACTS = ROOT / 'artifacts'
APPS = {name: ARTIFACTS / f'DerivedData/Build/Products/{name}/Aparte.app' for name in ['Debug', 'Release']}


def command(args, succeeds=True):
    result = subprocess.run([str(a) for a in args], cwd=ROOT, capture_output=True, text=True)
    if (result.returncode == 0) != succeeds:
        raise RuntimeError(f'Unexpected result {result.returncode}: {args[0]}\n{result.stdout}{result.stderr}')
    return result.stdout + result.stderr


records = {}
for name, app in APPS.items():
    command(['./scripts/local-signing.py', 'verify', app])
    output = command(['/usr/bin/codesign', '-d', '-r-', app])
    requirement = next(line.removeprefix('designated => ') for line in output.splitlines() if line.startswith('designated => '))
    records[name] = {'requirement': requirement, 'binarySHA256': hashlib.sha256((app / 'Contents/MacOS/Aparte').read_bytes()).hexdigest()}
assert records['Debug']['binarySHA256'] != records['Release']['binarySHA256'], 'Need two different built binaries'
assert records['Debug']['requirement'] == records['Release']['requirement'], 'Identity changed across builds'
assert 'cdhash' not in records['Release']['requirement'], 'Identity must not pin a changing binary hash'
command(['./scripts/local-signing.py', 'compare', APPS['Debug'], APPS['Release']])
for name, app in APPS.items():
    other = 'Release' if name == 'Debug' else 'Debug'
    command(['/usr/bin/codesign', '--verify', '--strict', '-R', '=' + records[other]['requirement'], app])
with tempfile.TemporaryDirectory(prefix='signature-negative-', dir=ARTIFACTS) as temporary:
    copy = Path(temporary) / 'Aparte.app'
    shutil.copytree(APPS['Release'], copy)
    resource = copy / 'Contents/Resources/Compatibility.json'
    resource.write_bytes(resource.read_bytes() + b'\n')
    command(['./scripts/local-signing.py', 'verify', copy], succeeds=False)
    shutil.rmtree(copy)
    shutil.copytree(APPS['Release'], copy)
    command(['/usr/bin/codesign', '--force', '--sign', '-', copy])
    command(['./scripts/local-signing.py', 'verify', copy], succeeds=False)
report = {'status': 'PASS', 'builds': records, 'mutualRequirementVerification': 'PASS',
          'tamperedResourceRejected': 'PASS', 'adHocFallbackRejected': 'PASS',
          'privacyPermissionPersistence': 'BLOCKED: requires owner grant and real post-update capability check; signatures alone do not establish TCC behavior'}
(ARTIFACTS / 'stable-signing-checks.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
