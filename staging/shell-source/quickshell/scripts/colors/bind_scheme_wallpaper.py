#!/usr/bin/env python3
"""Vincula wallpaper atual à paleta nomeada já salva no end4-pC.

Não edita config.json, tema JSON, nem toca em wallpapers. O serviço existente
end4-wallpaper-theme aplica o vínculo quando o wallpaper mudar.
"""
from __future__ import annotations
import argparse
from datetime import datetime
import json
import os
from pathlib import Path
import re
import shutil
import sys
import tempfile

ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_-]{0,80}$")
CFG = Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home()/'.config'))).expanduser()
CONFIG = CFG/'illogical-impulse/config.json'
LINKS = CFG/'illogical-impulse/wallpaper-scheme-links.json'
USER_SCHEMES = CFG/'illogical-impulse/schemes'
BUILTIN_SCHEMES = CFG/'quickshell/end4-pC/scripts/colors/schemes'


def read_object(path: Path, default=None):
    if path.is_symlink():
        raise ValueError(f'Link simbólico recusado: {path}')
    if not path.exists():
        if default is not None:
            return default
        raise FileNotFoundError(str(path))
    data = json.loads(path.read_text(encoding='utf-8'))
    if not isinstance(data, dict):
        raise ValueError(f'JSON inválido em {path}')
    return data


def current_wallpaper():
    data = read_object(CONFIG)
    wall = data.get('background', {}).get('wallpaperPath', '')
    if not isinstance(wall, str) or not wall.strip():
        raise ValueError('Nenhum wallpaper ativo no config.json. Escolha um wallpaper antes de salvar.')
    if not Path(wall).is_absolute() or any(c in wall for c in '\r\n\0'):
        raise ValueError('Caminho do wallpaper atual é inválido.')
    return wall


def ensure_scheme(scheme_id):
    if not ID.fullmatch(scheme_id) or scheme_id.startswith('_'):
        raise ValueError('Identificador de tema inválido.')
    for folder in (USER_SCHEMES, BUILTIN_SCHEMES):
        path = folder / (scheme_id + '.json')
        if path.is_symlink():
            raise ValueError('Arquivo de tema é link simbólico; operação cancelada.')
        if path.is_file():
            data = read_object(path)
            if isinstance(data.get('name'), str) and isinstance(data.get('dark'), dict) and isinstance(data.get('light'), dict):
                return
            raise ValueError(f'Tema incompleto: {path}')
    raise FileNotFoundError(f'Tema não encontrado: {scheme_id}')


def write_links(data):
    if LINKS.parent.is_symlink():
        raise ValueError('Pasta de configurações é link simbólico; operação cancelada.')
    LINKS.parent.mkdir(parents=True, exist_ok=True)
    if LINKS.is_symlink():
        raise ValueError('Arquivo de associações é link simbólico; operação cancelada.')
    # Mantém cópia de cada versão alterada das associações.
    if LINKS.exists():
        old = LINKS.read_bytes()
        new = (json.dumps(data, indent=2, ensure_ascii=False) + '\n').encode('utf-8')
        if old == new:
            return False
        back = LINKS.parent/'.wallpaper-scheme-links-backups'
        if back.is_symlink():
            raise ValueError('Pasta de backups é link simbólico; operação cancelada.')
        back.mkdir(exist_ok=True)
        shutil.copy2(LINKS,back/('wallpaper-scheme-links-'+datetime.now().strftime('%Y%m%d-%H%M%S-%f')+'.json'))
    else:
        new = (json.dumps(data, indent=2, ensure_ascii=False) + '\n').encode('utf-8')
    fd, tmp = tempfile.mkstemp(prefix='.wallpaper-scheme-links-', dir=LINKS.parent)
    try:
        with os.fdopen(fd, 'wb') as f:
            f.write(new)
            f.flush()
            os.fsync(f.fileno())
        if LINKS.exists():
            os.chmod(tmp, LINKS.stat().st_mode & 0o777)
        else:
            os.chmod(tmp, 0o600)
        os.replace(tmp, LINKS)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)
    return True


def main():
    parser=argparse.ArgumentParser(description='Associa o wallpaper atual à paleta do tema selecionado.')
    action=parser.add_mutually_exclusive_group(required=True)
    action.add_argument('--bind',metavar='SCHEME_ID')
    action.add_argument('--status',action='store_true')
    args=parser.parse_args()
    try:
        wall=current_wallpaper()
        data=read_object(LINKS,{'version':1,'wallpapers':{}})
        mapping=data.get('wallpapers')
        if not isinstance(mapping,dict):
            raise ValueError('wallpaper-scheme-links.json tem formato inesperado; preservado sem alterar.')
        if args.status:
            print(f'Wallpaper: {wall}')
            print(f'Tema vinculado: {mapping.get(wall) or "(nenhum)"}')
            return 0
        ensure_scheme(args.bind)
        data['wallpapers'][wall]=args.bind
        changed=write_links(data)
        print(f'{"Vinculado" if changed else "Já vinculado"}: {wall} -> {args.bind}')
        return 0
    except (ValueError, OSError, json.JSONDecodeError) as e:
        print(f'ERRO: {e}',file=sys.stderr)
        return 1

if __name__=='__main__':
    sys.exit(main())
