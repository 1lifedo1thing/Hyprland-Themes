#!/usr/bin/env python3
"""Persist per-scheme accent choices, or edit colors of an existing scheme.

User overrides live in ~/.config/illogical-impulse/schemes. Never edit built-in
files. An existing user override is backed up before its contents change.
"""
from __future__ import annotations

import argparse
import colorsys
from datetime import datetime
import json
import os
from pathlib import Path
import re
import shutil
import sys
import tempfile

HEX = re.compile(r'^#[0-9a-fA-F]{6}$')
ID = re.compile(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,80}$')
REQUIRED = ('surface_dim','surface','surface_bright','surface_container_lowest',
    'surface_container_low','surface_container','surface_container_high',
    'surface_container_highest','on_surface','on_surface_variant','outline',
    'outline_variant','error','on_accent')


def rgb(code):
    return tuple(int(code[i:i+2], 16)/255 for i in (1,3,5))


def hx(parts):
    return '#' + ''.join(f'{round(max(0,min(1,n))*255):02x}' for n in parts)


def light_adapt(color):
    h,l,s=colorsys.rgb_to_hls(*rgb(color))
    return hx(colorsys.hls_to_rgb(h,0.43,min(0.82,max(0.40,s))))


def dark_adapt(color):
    h,l,s=colorsys.rgb_to_hls(*rgb(color))
    return hx(colorsys.hls_to_rgb(h,0.68,min(0.85,max(0.40,s))))


def load_json(path):
    if path.is_symlink() or not path.is_file():
        raise ValueError(f'Arquivo de tema ausente ou link simbólico recusado: {path}')
    data=json.loads(path.read_text(encoding='utf-8'))
    validate(data)
    return data


def validate(data):
    if not isinstance(data,dict) or not isinstance(data.get('name'),str) or not data['name'].strip():
        raise ValueError('Tema sem nome válido')
    defaults=data.get('defaults')
    if not isinstance(defaults,dict):
        raise ValueError('Tema sem defaults')
    for mode in ('dark','light'):
        block=data.get(mode)
        if not isinstance(block,dict): raise ValueError(f'Modo {mode} ausente')
        for key in REQUIRED:
            if not isinstance(block.get(key),str) or not HEX.fullmatch(block[key]):
                raise ValueError(f'{mode}.{key} inválido')
        accents=block.get('accents')
        if not isinstance(accents,dict) or not accents:
            raise ValueError(f'{mode}.accents inválido')
        if any(not isinstance(k,str) or not isinstance(v,str) or not HEX.fullmatch(v) for k,v in accents.items()):
            raise ValueError(f'{mode}.accents contém cor inválida')
        if not isinstance(block.get('term'),list) or len(block['term'])!=16 or any(not isinstance(v,str) or not HEX.fullmatch(v) for v in block['term']):
            raise ValueError(f'{mode}.term inválido')
        for slot in ('primary','secondary','tertiary'):
            if defaults.get(slot) not in accents:
                raise ValueError(f'defaults.{slot} não existe em {mode}.accents')


def safe_write(path, data):
    path.parent.mkdir(parents=True,exist_ok=True)
    if path.is_symlink(): raise ValueError(f'Recusado substituir link: {path}')
    new=(json.dumps(data,indent=2,ensure_ascii=False)+'\n').encode()
    if path.is_file():
        if path.read_bytes()==new: return False
        backupdir=path.parent/'.backups'
        backupdir.mkdir(exist_ok=True)
        if backupdir.is_symlink(): raise ValueError('Pasta de backups é link simbólico')
        stamp=datetime.now().strftime('%Y%m%d-%H%M%S-%f')
        shutil.copy2(path, backupdir/f'{path.stem}-{stamp}.json')
    fd,tmp=tempfile.mkstemp(prefix='.theme-save-',dir=path.parent)
    try:
        with os.fdopen(fd,'wb') as f:
            f.write(new); f.flush(); os.fsync(f.fileno())
        os.chmod(tmp,0o644)
        os.replace(tmp,path)
    finally:
        if os.path.exists(tmp): os.unlink(tmp)
    return True


def update(args):
    scheme_id=args.scheme
    if not ID.fullmatch(scheme_id) or scheme_id.startswith('_'):
        raise ValueError('Identificador de tema inválido')
    user=Path(args.user_dir).expanduser()
    builtin=Path(args.builtin_dir).expanduser()
    target=user/(scheme_id+'.json')
    source=target if target.exists() or target.is_symlink() else builtin/(scheme_id+'.json')
    data=load_json(source)
    original=json.loads(json.dumps(data))
    if args.save_defaults:
        for slot,choice in (('primary',args.primary),('secondary',args.secondary)):
            if not choice or any(choice not in data[mode]['accents'] for mode in ('dark','light')):
                raise ValueError(f'{slot}: cor escolhida não existe nos modos claro e escuro: {choice}')
            data['defaults'][slot]=choice
    else:
        codes=(args.primary,args.secondary,args.tertiary)
        for code in codes:
            if not code or not HEX.fullmatch(code):
                raise ValueError(f'Cor HEX inválida: {code}')
        for mode in ('dark','light'):
            for i,slot in enumerate(('primary','secondary','tertiary')):
                name='custom_'+slot
                col=(codes[i].lower() if mode==args.source_mode else
                     light_adapt(codes[i]) if mode=='light' else dark_adapt(codes[i]))
                data[mode]['accents'][name]=col
                data['defaults'][slot]=name
            # Keep existing theme surfaces and all 16 terminal colors intact.
    validate(data)
    if data == original:
        # No file needed if the defaults were already as requested.
        print(scheme_id)
        return
    safe_write(target,data)
    print(scheme_id)


def main():
    p=argparse.ArgumentParser(description='Salvar cores por esquema end4-pC sem alterar temas internos')
    mode=p.add_mutually_exclusive_group(required=True)
    mode.add_argument('--save-defaults',action='store_true')
    mode.add_argument('--edit-colors',action='store_true')
    p.add_argument('--scheme',required=True)
    p.add_argument('--primary',required=True)
    p.add_argument('--secondary',required=True)
    p.add_argument('--tertiary')
    p.add_argument('--source-mode',choices=('dark','light'),default='dark')
    p.add_argument('--user-dir',default=str(Path.home()/'.config/illogical-impulse/schemes'))
    p.add_argument('--builtin-dir',default=str(Path(__file__).resolve().parent/'schemes'))
    args=p.parse_args()
    try:
        update(args)
        return 0
    except (OSError,ValueError,json.JSONDecodeError) as e:
        print(f'ERRO: {e}',file=sys.stderr)
        return 1

if __name__=='__main__': sys.exit(main())
