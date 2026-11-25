#!/usr/bin/env python3
"""Offline fixture: multiple authorized local asset roots, dry run and strict hashes."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='irideshell-hud-assets-') as tmp:
    root = Path(tmp)
    vendor = root/'project/vendor/hyprendfield'
    vendor.mkdir(parents=True)
    script = vendor/'assemble-local.py'
    shutil.copyfile(ROOT/'vendor/hyprendfield/assemble-local.py', script)
    (vendor/'LICENSE').write_text('fixture')
    expected = {'assets/icons/test.bin': b'icon', 'assets/world-map/test.bin': b'map'}
    manifest = {'source_files': ['LICENSE'], 'assets': {
        p: {'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}
        for p, data in expected.items()}}
    (vendor/'local-assets.json').write_text(json.dumps(manifest))
    a, b = root/'upstream', root/'local'
    a.mkdir(); b.mkdir()
    for (name, data), folder in zip(expected.items(), (a, b)):
        p = folder/name
        p.parent.mkdir(parents=True)
        p.write_bytes(data)
    out = root/'assembled.tar.gz'
    cmd = [sys.executable, str(script), '--assets-dir', str(a), '--assets-dir', str(b), '--output', str(out)]
    def run(args, success=True):
        result = subprocess.run(args, capture_output=True, text=True)
        assert (result.returncode == 0) == success, result.stdout + result.stderr
        return result
    run(cmd)
    assert not out.exists()
    run(cmd + ['--apply'])
    with tarfile.open(out) as archive:
        assert set(archive.getnames()) == {'LICENSE', *expected}
        for name, data in expected.items():
            assert archive.extractfile(name).read() == data
    out.unlink()
    map_file = b/'assets/world-map/test.bin'
    map_file.write_bytes(b'bad')
    assert 'hash mismatch' in run(cmd, False).stderr
    map_file.unlink()
    assert 'missing' in run(cmd, False).stderr
    map_file.symlink_to(a/'assets/icons/test.bin')
    assert 'Symbolic link' in run(cmd, False).stderr
    assert not out.exists()
print('PASS: local asset roots, dry-run, archive integrity, hash mismatch, missing and symlink refusal')
