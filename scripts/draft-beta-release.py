#!/usr/bin/env python3
"""Upload a verified local beta as a GitHub draft prerelease. Never publishes."""
import argparse
import json
from pathlib import Path
import sys
from importlib.util import module_from_spec, spec_from_file_location

spec = spec_from_file_location('prepare_beta', Path(__file__).with_name('prepare-beta.py'))
beta = module_from_spec(spec)
spec.loader.exec_module(beta)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    args = parser.parse_args()
    directory = args.directory.resolve()
    metadata = beta.validate_package(directory)
    tag, commit = metadata['tag'], metadata['sourceCommit']
    if beta.run(['git', 'status', '--porcelain', '--untracked-files=normal']):
        raise RuntimeError('Working tree must be clean.')
    if beta.run(['git', 'rev-parse', 'HEAD']) != commit:
        raise RuntimeError('Check out the exact packaged source commit.')
    remote = beta.run(['git', 'remote', 'get-url', 'origin'])
    if remote not in ('git@github.com:clemarc/aparte.git', 'https://github.com/clemarc/aparte.git', 'https://github.com/clemarc/aparte'):
        raise RuntimeError('origin must be the personal clemarc/aparte repository.')
    if beta.run(['git', 'ls-remote', 'origin', 'refs/heads/main']).split()[0] != commit:
        raise RuntimeError('Candidate must be the current protected main commit.')
    if beta.run(['git', 'cat-file', '-t', f'refs/tags/{tag}']) != 'tag':
        raise RuntimeError('Create and review an annotated local beta tag first.')
    if beta.run(['git', 'rev-parse', f'{tag}^{{commit}}']) != commit:
        raise RuntimeError('Beta tag points at a different commit.')
    remote_tag = beta.run(['git', 'ls-remote', 'origin', f'refs/tags/{tag}^{{}}'])
    if not remote_tag or remote_tag.split()[0] != commit:
        raise RuntimeError('Push the reviewed annotated tag before creating the draft.')
    beta.run(['gh', 'auth', 'status'])
    runs = json.loads(beta.run(['gh', 'api', f'repos/{beta.REPOSITORY}/actions/workflows/build.yml/runs?head_sha={commit}&event=push&status=success']))
    if not any(r.get('head_sha') == commit and r.get('head_branch') == 'main' and r.get('conclusion') == 'success'
               for r in runs.get('workflow_runs', [])):
        raise RuntimeError('No successful main build/test run exists for this source commit.')
    pages = json.loads(beta.run(['gh', 'api', '--paginate', '--slurp', f'repos/{beta.REPOSITORY}/releases?per_page=100']))
    published = [release for page in pages for release in page if not release.get('draft') and release.get('published_at')]
    notes_flags = ['--generate-notes']
    if published:
        previous = max(published, key=lambda release: release['published_at'])
        notes_flags += ['--notes-start-tag', previous['tag_name']]
    # gh refuses an existing release; do not replace its notes/assets or publish it.
    print(beta.run(['gh', 'release', 'create', tag, '--repo', beta.REPOSITORY, '--verify-tag', '--draft', '--prerelease',
                    '--latest=false', '--fail-on-no-commits', *notes_flags,
                    '--title', f'Aparté {tag} — self-signed beta', '--notes-file', directory / 'RELEASE-NOTES.md',
                    directory / metadata['archive'], directory / 'SHA256SUMS', directory / 'release.json']))


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, OSError, ValueError, KeyError) as error:
        print('BLOCKED: ' + str(error), file=sys.stderr)
        sys.exit(2)
