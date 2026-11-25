#!/usr/bin/env python3
"""Opt-in local HUD build and installation. No network fetch."""
import argparse
import os
import hashlib
import json
import shlex
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import tarfile
import tempfile

ALLOWED = {'CMakeLists.txt', 'LICENSE', 'README.md', 'src', 'qml', 'shaders', 'tools', 'assets'}


def members(archive):
    selected = []
    seen = set()
    for member in archive.getmembers():
        p = PurePosixPath(member.name)
        if p.is_absolute() or '..' in p.parts:
            raise ValueError('Unsafe archive path')
        if not p.parts:
            continue
        if p.parts[0] not in ALLOWED:
            continue
        if not (member.isfile() or member.isdir()):
            raise ValueError(f'Unsupported archive entry: {p}')
        if p in seen:
            raise ValueError(f'Duplicate archive entry: {p}')
        seen.add(p)
        selected.append(member)
    if not {PurePosixPath('CMakeLists.txt'), PurePosixPath('LICENSE')} <= seen:
        raise ValueError('Missing CMakeLists.txt or LICENSE at archive root')
    return selected


def installation_paths(home):
    prefix = home / '.local/share/irideshell/hyprendfield'
    launcher = home / '.local/bin/hyprendfield'
    return prefix, launcher


def check_destination(home):
    prefix, launcher = installation_paths(home)
    for path in (prefix, launcher):
        for parent in path.parents:
            if parent.is_symlink() or (parent.exists() and not parent.is_dir()):
                raise ValueError(f'Unsafe installation parent: {parent}')
        if path.exists() or path.is_symlink():
            raise ValueError(f'Existing installation or launcher preserved: {path}')
    return prefix, launcher


def install_local(binary, source, home):
    prefix, launcher = check_destination(home)
    prefix.parent.mkdir(parents=True, exist_ok=True)
    launcher.parent.mkdir(parents=True, exist_ok=True)
    prefix.mkdir(mode=0o700)  # exclusive; never overwrite an installed version
    tmp = None
    linked = False
    try:
        target = prefix / 'HyprEndfield'
        shutil.copy2(binary, target)
        target.chmod(0o755)
        for rel, name in [('LICENSE', 'LICENSE'),
                          ('assets/settings/EndfieldHUD-LICENSE', 'EndfieldHUD-LICENSE'),
                          ('assets/orbipom/Matter-LICENSE.txt', 'Matter-LICENSE.txt'),
                          ('assets/fonts/HarmonyOS-Sans-LICENSE.txt', 'HarmonyOS-Sans-LICENSE.txt')]:
            notice = source / rel
            if not notice.is_file():
                raise ValueError(f'Required notice missing: {rel}')
            shutil.copy2(notice, prefix / name)
        wrapper = '#!/usr/bin/env bash\nexec ' + shlex.quote(str(target)) + ' "$@"\n'
        fd, tmp = tempfile.mkstemp(prefix='.irideshell-hud-', dir=launcher.parent)
        with os.fdopen(fd, 'w') as stream:
            stream.write(wrapper)
        os.chmod(tmp, 0o755)
        (prefix/'installation.json').write_text(json.dumps({
            'binary_sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
            'launcher': str(launcher), 'source': 'user-supplied local archive'
        }, indent=2) + '\n')
        os.link(tmp, launcher)  # atomic and fails if another launcher appeared
        linked = True
    except BaseException:
        if linked:
            launcher.unlink()
        shutil.rmtree(prefix)
        raise
    finally:
        if tmp is not None:
            Path(tmp).unlink(missing_ok=True)
    print(f'INSTALLED: {target}\nLauncher: {launcher}\nNo HUD process started or live settings changed.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive', type=Path, required=True, help='Locally supplied HyprEndfield source tar.gz')
    parser.add_argument('--jobs', type=int, default=4)
    parser.add_argument('--apply', action='store_true', help='Extract and build in a new temporary directory')
    parser.add_argument('--install', action='store_true', help='Install locally after build; never overwrite an existing HUD launcher')
    args = parser.parse_args()
    if args.apply and os.geteuid() == 0:
        raise ValueError('Run as a normal user, not root')
    if args.install:
        prefix, launcher = installation_paths(Path.home())
        print(f'Local install destinations: {prefix}, {launcher}', flush=True)
        if args.apply:
            check_destination(Path.home())
    if not 1 <= args.jobs <= 32:
        parser.error('--jobs must be between 1 and 32')
    with tarfile.open(args.archive, 'r:gz') as archive:
        selected = members(archive)
        print(f'Local archive: {len(selected)} selected entries', flush=True)
        missing = [p for p in ('cmake', 'ninja', 'pkg-config', 'wayland-scanner') if not shutil.which(p)]
        print('Missing build tools: ' + (', '.join(missing) or 'none detected (CMake checks libraries)'), flush=True)
        if not args.apply:
            print('DRY RUN: no extraction, build, install or live configuration changes.')
            return
        if missing:
            raise ValueError('Install build dependencies before retrying')
        work = Path(tempfile.mkdtemp(prefix='irideshell-hud-'))
        source, build = work/'source', work/'build'
        source.mkdir()
        print(f'Isolated build directory: {work}', flush=True)
        archive.extractall(source, members=selected, filter='data')
    subprocess.run(['cmake', '-S', str(source), '-B', str(build), '-G', 'Ninja',
                    '-DCMAKE_BUILD_TYPE=Release', '-DBUILD_TESTING=OFF'], check=True)
    subprocess.run(['cmake', '--build', str(build), '--target', 'hyprendfield', '-j', str(args.jobs)], check=True)
    binary = build/'bin/HyprEndfield'
    if not binary.is_file():
        raise ValueError('Expected binary is missing after build')
    print(f'BUILD OK: {binary}')
    if args.install:
        install_local(binary, source, Path.home())
    else:
        print('Not installed; existing HUD and desktop unchanged.')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, tarfile.TarError, subprocess.CalledProcessError) as e:
        raise SystemExit(f'ERROR: {e}')
