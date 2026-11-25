#!/usr/bin/env python3
"""Rebuild the local prepared workspace, retaining the previous tree. No HOME writes."""
import os
from pathlib import Path
import shutil
import tempfile
from datetime import datetime, timezone
from audit import check_prepared
from prepare import LOCK, ROOT, assemble, verify


def refresh(root=ROOT):
    if check_prepared(root) is None:
        raise ValueError('prepared/ não existe; use ./setup prepare --apply')
    dest=root/'prepared'
    repos=dest/'repos'
    if repos.is_symlink() or not repos.is_dir():
        raise ValueError('Repositórios locais ausentes ou inválidos')
    for key, spec in LOCK.items():
        path=repos/key
        if path.is_symlink() or not path.is_dir():
            raise ValueError(f'Repositório inválido: {key}')
        verify(path,spec)
    with tempfile.TemporaryDirectory(prefix='.prepare-',dir=root) as tmp:
        out=Path(tmp)/'prepared'; out.mkdir()
        assemble(repos/'end4',repos/'pctrade',out,root)
        shutil.copytree(repos,out/'repos',symlinks=True)
        for key,spec in LOCK.items(): verify(out/'repos'/key,spec)
        # Check new prepared hashes before swapping, using the same audit function.
        shutil.copy2(root/'upstream-lock.json',Path(tmp)/'upstream-lock.json')
        count=check_prepared(Path(tmp))
        backup=root/('.prepare-backup-'+datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ'))
        if backup.exists() or backup.is_symlink(): raise ValueError('Backup já existe')
        dest.rename(backup)
        try: out.rename(dest)
        except BaseException:
            backup.rename(dest)
            raise
    print(f'Base remontada: {count} arquivos. Backup: {backup.name}. HOME não alterado.')

if __name__=='__main__':
    if os.geteuid()==0: raise SystemExit('Não execute como root')
    try: refresh()
    except (OSError,ValueError,KeyError) as exc: raise SystemExit(f'ERRO: {exc}')
