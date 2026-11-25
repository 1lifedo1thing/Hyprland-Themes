#!/usr/bin/env python3
"""Stage 4: modular installation and file lifecycle preview."""
import argparse
import copy
from lifecycle import Lifecycle, relative
import hashlib
import json
import os
from pathlib import Path
import shutil
import tempfile
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[1]
MODULES = {'themes': (), 'launcher': ('rofi',), 'terminal': ('kitty', 'fish', 'fastfetch'),
           'shell': ('qs','jq','matugen'), 'desktop-base': ('hyprctl','hypridle','hyprlock')}
DESKTOP = ('desktop-base','shell','themes','terminal','launcher')
GENERATED = {'shell','desktop-base'}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def safe_path(path):
    for part in [path, *path.parents]:
        if part.is_symlink():
            raise ValueError(f'Link simbólico não suportado: {part}')
    if path.exists() and not path.is_file():
        raise ValueError(f'Destino não é arquivo regular: {path}')
    for part in path.parents:
        if part.exists() and not part.is_dir():
            raise ValueError(f'Pai não é diretório: {part}')

def unchanged_icon_alias(source, target, rel):
    """Keep known upstream SVG aliases only when both prepared files agree.

    Never follow an external link, directory link, or link chain. Never write
    through an alias. All other destinations retain the original strict policy.
    """
    aliases = {'ai-openai-symbolic.svg', 'google-gemini-symbolic.svg'}
    if rel.parent != Path('quickshell/end4-pC/assets/icons') or rel.name not in aliases:
        return False
    if not target.is_symlink():
        return False
    # Check the directory itself and every ancestor before reading its contents.
    for parent in target.parents:
        if parent.is_symlink() or (parent.exists() and not parent.is_dir()):
            return False
    raw = Path(os.readlink(target))
    if raw.is_absolute() or len(raw.parts) != 1 or raw.suffix != '.svg' or raw.name == target.name:
        return False
    linked = target.parent/raw
    prepared_linked = source.parent/raw
    if (linked.is_symlink() or not linked.is_file() or
            prepared_linked.is_symlink() or not prepared_linked.is_file()):
        return False
    return digest(source) == digest(prepared_linked) == digest(linked)

def atomic_copy(source, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix='.ht-', dir=target.parent)
    os.close(fd)
    try:
        shutil.copy2(source, tmp)
        os.replace(tmp, target)
    finally:
        if os.path.exists(tmp): os.unlink(tmp)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['list','prepare','bootstrap','install','update','backup','restore','uninstall','doctor','audit'])
    parser.add_argument('--modules', help='desktop, shell, themes, launcher, terminal (separados por vírgula)')
    parser.add_argument('--apply', action='store_true', help='Grava arquivos; padrão é simulação')
    parser.add_argument('--replace', action='store_true', help='Autoriza substituir arquivos diferentes, com backup')
    parser.add_argument('--test-environment', action='store_true', help='Confirma VM/usuário de teste para bootstrap')
    parser.add_argument('--id', help='ID da última transação para restore')
    args = parser.parse_args()
    if args.id and args.command != 'restore': parser.error('--id é exclusivo de restore')
    if args.replace and (not args.apply or args.command not in ('install','update','restore')): parser.error('--replace requer --apply e install/update/restore')
    if args.command in ('backup','restore','doctor') and args.modules: parser.error('Este comando não aceita --modules')
    if args.command in ('doctor','audit') and args.apply: parser.error('Comando somente leitura')
    if args.command == 'audit':
        if args.modules or args.test_environment: parser.error('audit não aceita opções de instalação')
        from audit import report
        raise SystemExit(report(ROOT))
    if args.command == 'list':
        for name in ('desktop', *MODULES): print(name)
        return
    if os.geteuid() == 0: raise ValueError('Não execute com sudo/root')
    if args.command in ('prepare','bootstrap'):
        if args.modules or args.replace: parser.error('Opções de instalação não se aplicam')
        if not args.apply:
            print('SIMULAÇÃO: ' + ('clonar bases pinadas em prepared/' if args.command=='prepare' else 'executar instalador original (pacotes, serviços e dotfiles)'))
            return
        from prepare import prepare, bootstrap
        if args.command == 'bootstrap':
            if not args.test_environment: parser.error('bootstrap exige --test-environment; use VM descartável')
            bootstrap()
        else: prepare()
        return
    home = Path.home()
    config = Path(os.environ.get('XDG_CONFIG_HOME') or home/'.config')
    data = Path(os.environ.get('XDG_DATA_HOME') or home/'.local/share')
    if config != home/'.config': raise ValueError('Prévia suporta somente ~/.config (scripts locais usam esse caminho)')
    if not data.is_absolute(): raise ValueError('XDG_DATA_HOME deve ser absoluto')
    life = Lifecycle(config,data,digest,safe_path,atomic_copy)
    with life.lock(args.apply):
        state = life.state()
        managed = sorted({o for e in state['files'].values() for o in e['owners']})
        if args.command == 'backup': return life.backup(state,args.apply)
        if args.command == 'restore': return life.restore(state,args.apply,args.replace,args.id)
        if args.command == 'doctor':
            print('Base preparada:', 'manifesto presente' if (ROOT/'prepared/manifest.json').is_file() else 'não montada')
            print('Módulos gerenciados:', ', '.join(managed) or 'nenhum')
            print('Última transação:',state['last'] or 'nenhuma')
            for name, programs in MODULES.items():
                missing = [p for p in programs if not shutil.which(p)]
                print(f'{name}: ' + (', '.join(missing) + ' ausentes' if missing else 'comandos disponíveis'))
            for rel, entry in state['files'].items():
                try:
                    if life.current(rel) != entry['installed']: print('Alterado/ausente:',rel)
                    life.snapshot(entry['origin'],rel,entry['original'])
                except (OSError,ValueError) as e: print('AVISO:',e)
            print('Diagnóstico estático: não valida QML, serviços ou funcionamento visual.')
            return
        defaults = managed if args.command in ('update','uninstall') else ['desktop']
        names = list(dict.fromkeys(args.modules.split(',') if args.modules else defaults))
        if 'desktop' in names: names = list(dict.fromkeys([*DESKTOP, *(n for n in names if n!='desktop')]))
        if args.command != 'uninstall' and 'desktop-base' in names and 'shell' not in names: names.append('shell')
        if any(name not in MODULES for name in names): parser.error('Módulo inexistente ou ainda indisponível')
        if args.command == 'uninstall': return life.uninstall(state,names,args.apply)
        if args.command == 'update' and set(names)-set(managed): raise ValueError('Use install para módulos ainda não gerenciados')
        if not names: print('Nenhum módulo gerenciado; use install primeiro.'); return
        return install(args, names, state, life, config)


def install(args, names, state, life, config):
    files = copy.deepcopy(state['files'])
    changes = {}
    conflicts = []
    missing=[]
    seen={}
    if GENERATED.intersection(names):
        prepared=ROOT/'prepared'
        manifest=prepared/'manifest.json'
        if not manifest.is_file():
            raise ValueError('Base ainda não montada. Execute ./setup prepare --apply primeiro')
        record=json.loads(manifest.read_text())
        if record['upstream']!=json.loads((ROOT/'upstream-lock.json').read_text()):
            raise ValueError('Revisões da base preparada não conferem')
        for rel,sha in record['files'].items():
            path=prepared/relative(rel)
            safe_path(path)
            if not path.is_file() or path.is_symlink() or digest(path)!=sha:
                raise ValueError(f'Base preparada modificada: {rel}')
        actual={str(p.relative_to(prepared)) for p in (prepared/'modules').rglob('*') if p.is_file() or p.is_symlink()}
        if actual!=set(record['files']): raise ValueError('Arquivos extras na base preparada')
    for name in names:
        missing.extend(cmd for cmd in MODULES[name] if not shutil.which(cmd))
        folder=(ROOT/'prepared' if name in GENERATED else ROOT)/'modules'/name/'config'
        if not folder.is_dir(): raise ValueError(f'Módulo não montado: {name}')
        for source in sorted(folder.rglob('*')):
            if source.is_symlink(): raise ValueError(f'Fonte é link: {source}')
            if not source.is_file(): continue
            rel=source.relative_to(folder)
            target=config/rel
            key = str(rel)
            sha = digest(source)
            if rel in seen and seen[rel] != sha: raise ValueError(f'Conflito entre módulos: {rel}')
            seen[rel] = sha
            if unchanged_icon_alias(source, target, rel):
                print(f'{name}: igual (link preservado) {rel}')
                continue
            current = life.current(key)
            entry = files.get(key)
            if key in changes:
                if entry and name not in entry['owners']: entry['owners'].append(name); entry['owners'].sort()
                continue
            action = 'igual' if current == sha else ('substituir' if current is not None else 'criar')
            print(f'{name}: {action:10} {rel}')
            if current == sha:
                # Do not claim identical pre-existing files; they may belong to upstream/user.
                if entry:
                    if current != entry['installed'] and not args.replace: conflicts.append(key)
                    if entry['installed'] != sha and set(entry['owners'])-set(names):
                        raise ValueError(f'Arquivo compartilhado requer atualizar todos os módulos: {key}')
                    entry['installed'] = sha
                    entry['owners'] = sorted(set(entry['owners'])|{name})
                continue
            if entry and entry['installed'] != sha and set(entry['owners'])-set(names):
                raise ValueError(f'Arquivo compartilhado requer atualizar todos os módulos: {key}')
            if entry is not None and current != entry['installed']:
                conflicts.append(key)
            if current is not None and (args.command != 'update' or entry is None): conflicts.append(key)
            if entry is None:
                files[key] = {'owners':[name], 'origin':None, 'original':current, 'installed':sha}
            else:
                entry['owners'] = sorted(set(entry['owners'])|{name})
                entry['installed'] = sha
            changes[key] = (current,source)
    if 'themes' in names and 'shell' not in names and not (config/'quickshell/end4-pC/scripts/colors/named_scheme.py').is_file():
        missing.append('end4-pC compatível com esquemas nomeados')
    if missing: print('Pré-requisitos ausentes: '+', '.join(sorted(set(missing))))
    if not args.apply:
        print(f'SIMULAÇÃO: {len(changes)} alterações propostas; nenhum arquivo escrito.')
        return
    if missing: raise ValueError('Instale os pré-requisitos primeiro')
    if conflicts and not args.replace:
        raise ValueError('Há arquivos diferentes ou edições locais. Revise a simulação antes de usar --apply --replace: ' + ', '.join(sorted(set(conflicts))))
    if not changes and files == state['files']:
        print('Nada a alterar.'); return
    life.transact(args.command,state,files,changes)

if __name__=='__main__':
    try: main()
    except (OSError,ValueError,KeyboardInterrupt, __import__('subprocess').CalledProcessError) as exc:
        raise SystemExit(f'ERRO: {exc}')
