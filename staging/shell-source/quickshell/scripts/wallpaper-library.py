#!/usr/bin/env python3
"""Local wallpaper gallery import for end4-pC.

Read-only: inspect, scan-animated. Mutating: import with explicit copy/move action.
Never overwrites an existing file; never deletes without successfully completing a copy.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

STATIC_EXT = {'.png', '.jpg', '.jpeg', '.webp', '.avif', '.bmp', '.svg'}
ANIMATED_EXT = {'.mp4', '.mkv', '.webm', '.mov', '.gif', '.m4v'}
HOME = Path.home()
STATIC_DIR = HOME / 'Pictures' / 'Wallpapers'
ANIMATED_DIR = STATIC_DIR / 'Animated'
ANIMATED_PICKER = HOME / '.config' / 'quickshell' / 'end4-pC' / 'scripts' / 'animated-picker.py'


def report(**data):
    print(json.dumps(data, ensure_ascii=False), flush=True)


def destination(kind):
    return STATIC_DIR if kind == 'static' else ANIMATED_DIR


def normalize_source(path, kind):
    p = Path(path).expanduser()
    if p.is_symlink():
        raise ValueError('O arquivo selecionado é um link simbólico. Escolha o arquivo original.')
    p = p.resolve(strict=True)
    if not p.is_file():
        raise ValueError('Selecione um arquivo, não uma pasta.')
    allowed = STATIC_EXT if kind == 'static' else ANIMATED_EXT
    if p.suffix.lower() not in allowed:
        raise ValueError('Extensão não suportada para ' + ('estáticos' if kind == 'static' else 'animados'))
    return p


def target_for(p, folder):
    candidate = folder / p.name
    if candidate == p:
        return candidate
    index = 2
    while candidate.exists() or candidate.is_symlink():
        candidate = folder / f'{p.stem} ({index}){p.suffix}'
        index += 1
    return candidate


def inspect(kind, source):
    p = normalize_source(source, kind)
    folder = destination(kind).resolve()
    existing = p.parent == folder
    target = p if existing else target_for(p, folder)
    return dict(ok=True, kind=kind, source=str(p), destination=str(target),
                inside=existing, will_rename=(not existing and target.name != p.name),
                folder=str(folder))


def import_file(kind, source, action):
    if action not in ('copy', 'move'):
        raise ValueError('Ação inválida: use copy ou move.')
    p = normalize_source(source, kind)
    folder = destination(kind)
    folder.mkdir(parents=True, exist_ok=True)
    folder = folder.resolve()
    if p.parent == folder:
        report(ok=True, path=str(p), inside=True, moved=False,
               message='Este wallpaper já está na pasta correta.')
        return
    final = target_for(p, folder)
    tmpname = None
    try:
        with tempfile.NamedTemporaryFile(dir=folder, prefix='.wallpaper-import-',
                                         suffix=p.suffix, delete=False) as output:
            tmpname = Path(output.name)
            with p.open('rb') as src:
                shutil.copyfileobj(src, output, length=1024 * 1024)
            output.flush()
            os.fsync(output.fileno())
        shutil.copystat(p, tmpname)
        if tmpname.stat().st_size != p.stat().st_size:
            raise OSError('Tamanho copiado difere do original; origem preservada.')
        # Hard-link atomically within the destination directory; fail rather than overwrite.
        os.link(tmpname, final)
        tmpname.unlink()
        tmpname = None
    except Exception:
        if tmpname is not None:
            tmpname.unlink(missing_ok=True)
        raise
    moved = False
    warning = ''
    if action == 'move':
        try:
            p.unlink()
            moved = True
        except OSError as exc:
            warning = f'Cópia criada, mas a origem não pôde ser removida: {exc}'
    report(ok=True, path=str(final), source=str(p), moved=moved,
           inside=False, renamed=(p.name != final.name), warning=warning,
           message=('Movido' if moved else 'Copiado') + ' para ' + str(final))


def scan_animated():
    if not ANIMATED_PICKER.is_file():
        raise FileNotFoundError('Sistema animado não encontrado: ' + str(ANIMATED_PICKER))
    result = subprocess.run([sys.executable, str(ANIMATED_PICKER), 'scan'],
                            capture_output=True, text=True, timeout=120, check=False)
    try:
        data = json.loads(result.stdout.strip())
    except (ValueError, TypeError) as exc:
        raise RuntimeError('A galeria animada retornou dados inválidos: ' + result.stderr[-500:]) from exc
    if not data.get('ok'):
        raise RuntimeError(str(data.get('error', 'Falha ao ler wallpapers animados')))
    report(ok=True, items=data.get('items', []), ffmpeg=data.get('ffmpeg', False))


def main():
    parser = argparse.ArgumentParser(description='Galeria local de wallpapers end4-pC')
    command = parser.add_subparsers(dest='command', required=True)
    check = command.add_parser('inspect')
    add = command.add_parser('import')
    command.add_parser('scan-animated')
    for sub in (check, add):
        sub.add_argument('--kind', choices=['static', 'animated'], required=True)
        sub.add_argument('--source', required=True)
    add.add_argument('--action', choices=['move', 'copy'], required=True)
    args = parser.parse_args()
    try:
        if args.command == 'inspect':
            report(**inspect(args.kind, args.source))
        elif args.command == 'import':
            import_file(args.kind, args.source, args.action)
        elif args.command == 'scan-animated':
            scan_animated()
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as exc:
        report(ok=False, error=str(exc))
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
