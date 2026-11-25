"""Release preflight fixtures: no desktop changes, no network."""
import contextlib
import hashlib
import io
import json
from pathlib import Path
import sys
import tempfile
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'scripts'))
from audit import inventory, check_prepared, report
with tempfile.TemporaryDirectory() as tmp:
    root = Path(tmp)
    mod = root/'modules'; mod.mkdir()
    # Construct a synthetic token at runtime; no actual credential.
    token = 'gh'+'p_'+'a'*36
    (mod/'sample.txt').write_text(token+'\n/home/example/Pictures/foo.png\n/home/localname/private/foo\n')
    (mod/'picture.png').write_bytes(b'\0fake')
    (mod/'LICENSE').write_text('fixture')
    _, findings, media, notices = inventory(root,mod)
    assert ('possible-credential','modules/sample.txt',1) in findings
    assert ('local-machine-path','modules/sample.txt',3) in findings
    assert len(findings)==2 and len(media)==1 and notices==['modules/LICENSE']
    assert check_prepared(root) is None
    out=io.StringIO()
    with contextlib.redirect_stdout(out):
        assert report(root)==1
    assert token not in out.getvalue()
    base=root/'prepared'; dest=base/'modules/shell'; dest.mkdir(parents=True)
    p=dest/'fixture'; p.write_bytes(b'ok')
    lock={'fixture': 'pin'}
    (root/'upstream-lock.json').write_text(json.dumps(lock))
    (base/'manifest.json').write_text(json.dumps({'upstream':lock,'files':{'modules/shell/fixture':hashlib.sha256(b'ok').hexdigest()}}))
    assert check_prepared(root)==1
    p.write_bytes(b'changed')
    try: check_prepared(root)
    except ValueError: pass
    else: raise AssertionError('tamper missed')
    p.write_bytes(b'ok')
    (dest/'extra').symlink_to('/etc/passwd')
    try: check_prepared(root)
    except ValueError: pass
    else: raise AssertionError('symlink accepted')
print('PASS: credential redaction, path heuristics, media and notice inventory, manifest verification, tamper and symlink rejection')
