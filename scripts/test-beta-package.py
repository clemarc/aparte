#!/usr/bin/env python3
"""Real archive/provenance rejection checks for an already prepared beta."""
import argparse
from importlib.util import module_from_spec, spec_from_file_location
import json
from pathlib import Path
import shutil
import tempfile

spec = spec_from_file_location('prepare_beta', Path(__file__).with_name('prepare-beta.py'))
beta = module_from_spec(spec)
spec.loader.exec_module(beta)
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('directory', type=Path)
args = parser.parse_args()
metadata = beta.validate_package(args.directory.resolve())
report = {'archiveRoundTrip': 'PASS', 'sourceCommit': metadata['sourceCommit'], 'archiveSHA256': metadata['archiveSHA256']}


def must_reject(directory, reason):
    try:
        beta.validate_package(directory)
    except RuntimeError as error:
        if reason not in str(error):
            raise RuntimeError(f'Unexpected refusal: {error}')
    else:
        raise RuntimeError('Invalid package was accepted')


with tempfile.TemporaryDirectory(prefix='beta-package-negative-', dir=beta.ROOT / 'artifacts') as temporary:
    directory = Path(temporary) / 'candidate'
    shutil.copytree(args.directory, directory)
    forged = dict(metadata, sourceCommit='0' * 40)
    (directory / 'release.json').write_text(json.dumps(forged, indent=2) + '\n')
    # Recompute external checksums: the signed bundle must still refuse forged provenance.
    archive = directory / metadata['archive']
    (directory / 'SHA256SUMS').write_text(f'{beta.digest(archive)}  {archive.name}\n{beta.digest(directory / "release.json")}  release.json\n')
    must_reject(directory, 'Signed app provenance')
    report['forgedSourceWithRecomputedChecksumsRejected'] = 'PASS'
    shutil.rmtree(directory)
    shutil.copytree(args.directory, directory)
    archive = directory / metadata['archive']
    with archive.open('ab') as stream:
        stream.write(b'corruption-probe')
    must_reject(directory, 'Archive checksum')
    report['corruptedArchiveRejected'] = 'PASS'
(beta.ROOT / 'artifacts/beta-package-checks.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
