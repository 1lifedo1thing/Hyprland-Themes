#!/usr/bin/env python3
"""Exercise local HUD installation safeguards without Qt or a live desktop."""
import contextlib
import io
from pathlib import Path
import sys
import tempfile
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from build_hyprendfield import install_local, installation_paths

with tempfile.TemporaryDirectory() as td:
    root = Path(td)
    source = root/'source'; source.mkdir()
    binary = root/'binary'; binary.write_bytes(b'fixture')
    for rel in ('LICENSE', 'assets/settings/EndfieldHUD-LICENSE',
                'assets/orbipom/Matter-LICENSE.txt', 'assets/fonts/HarmonyOS-Sans-LICENSE.txt'):
        p = source/rel; p.parent.mkdir(parents=True, exist_ok=True); p.write_text('fixture notice')
    home = root/'home with spaces'; home.mkdir()
    with contextlib.redirect_stdout(io.StringIO()):
        install_local(binary, source, home)
    prefix, launcher = installation_paths(home)
    assert (prefix/'HyprEndfield').read_bytes() == b'fixture'
    assert (prefix/'installation.json').is_file()
    original = launcher.read_bytes()
    try: install_local(binary, source, home)
    except ValueError: pass
    else: raise AssertionError('Existing launcher overwritten')
    assert launcher.read_bytes() == original
    home2 = root/'home2'; home2.mkdir()
    p2, l2 = installation_paths(home2); l2.parent.mkdir(parents=True)
    l2.write_text('existing manual launcher')
    try: install_local(binary, source, home2)
    except ValueError: pass
    else: raise AssertionError('Existing manual launcher overwritten')
    assert l2.read_text() == 'existing manual launcher' and not p2.exists()
    home3 = root/'home3'; home3.mkdir(); (source/'LICENSE').unlink()
    try: install_local(binary, source, home3)
    except ValueError: pass
    else: raise AssertionError('Missing notice accepted')
    assert not any(p.exists() for p in installation_paths(home3))
print('PASS: local HUD install, manual launcher protection, repeated install refusal, rollback on missing license')
