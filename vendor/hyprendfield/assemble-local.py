#!/usr/bin/env python3
"""Reassemble the published HUD code with a trusted, matching local resource archive."""
import argparse
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import tarfile

ROOT = Path(__file__).resolve().parent

def read_regular(root, name):
    p = root / name
    if any(q.is_symlink() for q in [p, *p.parents] if q != root.parent) or not p.is_file():
        raise ValueError(f'Expected regular source file: {name}')
    return p.read_bytes()

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    inputs = ap.add_mutually_exclusive_group(required=True)
    inputs.add_argument('--assets-archive', type=Path, help='Your own authorized matching local HyprEndfield tar.gz')
    inputs.add_argument('--assets-dir', action='append', type=Path, help='Authorized local project root containing assets/; repeat to combine roots')
    ap.add_argument('--output', required=True, type=Path, help='New tar.gz outside the repository')
    ap.add_argument('--apply', action='store_true', help='Write output; default verifies only')
    a = ap.parse_args()
    out = a.output.expanduser().resolve()
    if ROOT.parent.parent in out.parents:
        raise ValueError('Keep assembled archives outside the Irideshell repository')
    if out.exists() or out.is_symlink():
        raise ValueError('Output already exists; choose a new filename')
    manifest = json.loads((ROOT/'local-assets.json').read_text())
    source = {name: read_regular(ROOT, name) for name in manifest['source_files']}
    expected = manifest['assets']
    checked = {}
    if a.assets_dir:
        roots = [p.expanduser().absolute() for p in a.assets_dir]
        for root in roots:
            if not root.is_dir() or any(p.is_symlink() for p in [root, *root.parents]):
                raise ValueError(f'Expected regular local project directory: {root}')
        for name, entry in expected.items():
            rel = PurePosixPath(name)
            if rel.is_absolute() or '..' in rel.parts or not rel.parts or rel.parts[0] != 'assets':
                raise ValueError(f'Invalid resource path in manifest: {name}')
            for root in roots:
                path = root.joinpath(*rel.parts)
                if any(p.is_symlink() for p in [path, *path.parents]):
                    raise ValueError(f'Symbolic link in local resource path: {name}')
                if not path.exists():
                    continue
                if not path.is_file() or path.stat().st_size != entry['bytes']:
                    raise ValueError(f'Invalid local resource type or size: {name}')
                data = path.read_bytes()
                if hashlib.sha256(data).hexdigest() != entry['sha256']:
                    raise ValueError(f'Resource hash mismatch: {name}')
                checked[name] = data
                break
    else:
        with tarfile.open(a.assets_archive, 'r:gz') as archive:
            for member in archive:
                p = PurePosixPath(member.name)
                if p.is_absolute() or '..' in p.parts:
                    raise ValueError('Unsafe path in local archive')
                name = str(p)
                if name not in expected:
                    continue
                entry = expected[name]
                if name in checked or not member.isfile() or member.size != entry['bytes']:
                    raise ValueError(f'Duplicate, invalid type or size mismatch: {name}')
                data = archive.extractfile(member).read()
                if hashlib.sha256(data).hexdigest() != entry['sha256']:
                    raise ValueError(f'Resource hash mismatch: {name}')
                checked[name] = data
    missing = sorted(set(expected)-set(checked))
    if missing:
        raise ValueError('Required resources missing: ' + ', '.join(missing[:12]))
    print(f'Verified {len(source)} source files and {len(checked)} local assets.')
    if not a.apply:
        print('DRY RUN: no archive written; no installation.')
        return
    created = False
    try:
        with out.open('xb') as stream:
            created = True
            with tarfile.open(fileobj=stream, mode='w:gz') as result:
                for name, data in sorted({**source, **checked}.items()):
                    info = tarfile.TarInfo(name)
                    info.size = len(data); info.mode = 0o644
                    result.addfile(info, io.BytesIO(data))
    except BaseException:
        if created: out.unlink(missing_ok=True)
        raise
    print(f'Created {out}; do not publish it. No HUD installed or launched.')

if __name__ == '__main__':
    try: main()
    except (OSError, ValueError, tarfile.TarError) as exc: raise SystemExit(f'ERROR: {exc}')
