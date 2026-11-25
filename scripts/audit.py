#!/usr/bin/env python3
"""Read-only release preflight. Reports file paths, never matching secret text."""
import hashlib
import json
from pathlib import Path
import re
import shutil
import sys
from collections import Counter

ROOT = Path(__file__).resolve().parents[1]
MEDIA = {'.png', '.jpg', '.jpeg', '.webp', '.avif', '.bmp', '.gif', '.ico', '.svg', '.ttf', '.otf', '.woff', '.woff2', '.mp4', '.webm', '.mov', '.mkv', '.mp3', '.ogg', '.wav', '.flac', '.qoi', '.pdf'}
RULES = {
    'possible-credential': re.compile(r'-----BEGIN (?:[A-Z ]+ )?PRIVATE KEY-----|\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|AKIA[A-Z0-9]{16}|AIza[A-Za-z0-9_-]{35}|sk-(?:proj-)?[A-Za-z0-9_-]{24,})\b'),
    'local-machine-path': re.compile(r'/home/(?!user(?:/|\b)|example(?:/|\b))[A-Za-z0-9_.-]+/|/run/media/[A-Za-z0-9_.-]+/|/dev/(?:nvme\d|sd[a-z]\d)'),
}
GROUPS = {
    'setup': ('bash', 'python3', 'git'),
    'shell (minimum installer check)': ('qs', 'jq', 'matugen'),
    'desktop-base (minimum installer check)': ('hyprctl', 'hypridle', 'hyprlock'),
    'terminal': ('kitty', 'fish', 'fastfetch'),
    'launcher': ('rofi',),
    'wallpaper and color tools': ('kdialog', 'notify-send', 'xdg-user-dir', 'gsettings', 'bc'),
    'animated wallpapers and image generation': ('mpvpaper', 'ffmpeg', 'ffprobe'),
    'desktop integration (feature dependent)': ('cliphist', 'wl-paste', 'gnome-keyring-daemon', 'dbus-update-activation-environment', 'easyeffects', 'hyprshot'),
    'optional integrations': ('gh', 'yay', 'plasma-apply-colorscheme', 'hyprendfield'),
}


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def regular_files(root, folder):
    """Reject symlinks and special files; do not traverse .git or Python caches."""
    if not folder.exists() and not folder.is_symlink():
        return
    if folder.is_symlink() or not folder.is_dir():
        raise ValueError(f'Unsafe directory: {folder.relative_to(root)}')
    for p in sorted(folder.iterdir()):
        if p.name in ('.git', '__pycache__'):
            continue
        if p.is_symlink():
            raise ValueError(f'Unexpected symlink: {p.relative_to(root)}')
        if p.is_dir():
            yield from regular_files(root, p)
        elif p.is_file():
            yield p
        else:
            raise ValueError(f'Unexpected file type: {p.relative_to(root)}')


def inventory(root, folder):
    paths = list(regular_files(root, folder))
    findings, assets, notices = [], [], []
    for p in paths:
        rel = str(p.relative_to(root))
        name = p.name.lower()
        if name.startswith(('license', 'licence', 'copying', 'notice', 'copyright')):
            notices.append(rel)
        if re.search(r'(^|[.\-_])(bak|backup|passwd|credentials|id_rsa|id_ed25519)([.\-_]|$)', name) or name in ('.env', 'config.json.bak'):
            findings.append(('review-file-name', rel, 0))
        if p.suffix.lower() in MEDIA:
            assets.append((rel, p.stat().st_size, digest(p)))
        # Search bounded text only. SVG and other textual media are included.
        if p.stat().st_size > 4 * 1024 * 1024:
            if p.suffix.lower() not in MEDIA:
                findings.append(('large-unscanned-file', rel, 0))
            continue
        raw = p.read_bytes()
        if b'\0' in raw:
            if p.suffix.lower() not in MEDIA:
                findings.append(('binary-unclassified', rel, 0))
            continue
        try:
            s = raw.decode('utf-8')
        except UnicodeDecodeError:
            if p.suffix.lower() not in MEDIA:
                findings.append(('non-utf8-unscanned', rel, 0))
            continue
        for i, line in enumerate(s.splitlines(), 1):
            for tag, pattern in RULES.items():
                if pattern.search(line):
                    findings.append((tag, rel, i))
    return paths, findings, assets, notices


def check_prepared(root):
    base = root / 'prepared'
    if not base.exists() and not base.is_symlink():
        return None
    if base.is_symlink() or not base.is_dir():
        raise ValueError('prepared/ is not a real directory')
    manifest = base / 'manifest.json'
    lock = root / 'upstream-lock.json'
    if manifest.is_symlink() or not manifest.is_file():
        raise ValueError('Missing or unsafe prepared manifest')
    record = json.loads(manifest.read_text())
    if record['upstream'] != json.loads(lock.read_text()):
        raise ValueError('Upstream lock mismatch')
    paths = list(regular_files(root, base / 'modules'))
    actual = {str(p.relative_to(base)): digest(p) for p in paths}
    if record['files'] != actual:
        raise ValueError('Prepared files differ from manifest')
    return len(actual)


def report(root=ROOT):
    print('=== RELEASE PREFLIGHT / READ ONLY ===')
    print('Scope: modules/, staging/, scripts/, tests/, prepared/modules/, prepared/licenses/.')
    print('Excludes: HOME, live configuration, Git history, upstream repos/ and untracked root files.')
    print('Heuristic only: does not certify secrets, copyright, packages, QML or runtime.')
    print('=== INTEGRITY ===')
    count = check_prepared(root)
    print('Prepared manifest: ' + (f'{count} files matched' if count is not None else 'NOT AVAILABLE'))
    roots = ['modules', 'staging', 'scripts', 'tests']
    if count is not None:
        roots += ['prepared/modules', 'prepared/licenses']
    findings, assets, notices = [], [], []
    print('=== SCOPE ===')
    for folder in roots:
        paths, f, a, n = inventory(root, root / folder)
        print(f'{folder}: {len(paths)} files')
        findings += f; assets += a; notices += n
    print('=== HEURISTIC FINDINGS (no matching content) ===')
    for tag, rel, line in findings:
        print(f'{tag}: {rel}' + (f':{line}' if line else ''))
    print(f'Total findings: {len(findings)}')
    print('=== LICENSE NOTICE INVENTORY (not proof of coverage) ===')
    for rel in notices:
        print(rel)
    print('Root LICENSE:', 'present' if (root/'LICENSE').is_file() else 'MISSING')
    print('=== MEDIA INVENTORY (requires manual provenance review) ===')
    for ext, number in sorted(Counter(Path(x[0]).suffix.lower() for x in assets).items()):
        print(f'{ext}: {number}')
    for rel, size, sha in assets:
        print(f'{sha} {size} {rel}')
    print('=== DEPENDENCY AVAILABILITY (PATH, not package compatibility) ===')
    for group, commands in GROUPS.items():
        print(group + ': ' + ', '.join(f'{x}={"yes" if shutil.which(x) else "no"}' for x in commands))
    print('=== RELEASE STATUS ===')
    print('REVIEW REQUIRED: audit source notices and media rights; inspect all findings; runtime not tested.')
    return 1 if any(f[0]=='possible-credential' for f in findings) else 0


if __name__ == '__main__':
    try:
        sys.exit(report())
    except (OSError, ValueError, KeyError, TypeError) as e:
        print(f'ERROR: {e}', file=sys.stderr)
        sys.exit(2)
