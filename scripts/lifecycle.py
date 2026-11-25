"""File-level lifecycle journal. Only files actually written by Stage 4 are owned."""
import contextlib
import fcntl
import json
import os
from pathlib import Path
from datetime import datetime, timezone
import tempfile
import shutil
import re


def relative(value):
    p = Path(value)
    if not p.parts or p.is_absolute() or '..' in p.parts or str(p) != value:
        raise ValueError(f'Caminho inválido: {value}')
    return p


def identifier(value):
    if not re.fullmatch(r'\d{8}-\d{6}-\d{6}', value):
        raise ValueError('ID de backup inválido')
    return value


class Lifecycle:
    def __init__(self, config, data, digest, safe_path, atomic_copy):
        self.config = config
        self.root = data/'Hyprland-Themes'
        self.digest, self.safe, self.copy = digest, safe_path, atomic_copy
        self.state_path = self.root/'ownership.json'
        self.safe(self.state_path)

    @contextlib.contextmanager
    def lock(self, apply):
        if not apply:
            yield
            return
        path = self.root/'lifecycle.lock'
        self.safe(path)
        self.root.mkdir(parents=True, mode=0o700, exist_ok=True)
        fd = os.open(path, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
        with os.fdopen(fd, 'r+') as f:
            fcntl.flock(f, fcntl.LOCK_EX)
            yield

    def read(self, path):
        self.safe(path)
        return json.loads(path.read_text())

    def write(self, path, obj):
        self.safe(path)
        fd, tmp = tempfile.mkstemp(prefix='.ht-json-', dir=path.parent)
        try:
            with os.fdopen(fd, 'w') as f:
                json.dump(obj, f, indent=2, sort_keys=True); f.write('\n'); f.flush(); os.fsync(f.fileno())
            os.replace(tmp, path)
        finally:
            if os.path.exists(tmp): os.unlink(tmp)

    def state(self):
        pending = self.root/'pending.json'
        self.safe(pending)
        if pending.exists():
            raise ValueError(f'Transação interrompida: {pending}. Preserve os backups e revise manualmente antes de continuar.')
        state = self.read(self.state_path) if self.state_path.exists() else {'files': {}, 'last': None}
        for rel, entry in state['files'].items():
            relative(rel); identifier(entry['origin'])
            if not entry['owners']: raise ValueError('Registro sem proprietário')
        if state['last']: identifier(state['last'])
        return state

    def current(self, rel):
        target = self.config/relative(rel)
        self.safe(target)
        return self.digest(target) if target.exists() else None

    def transaction_dir(self, id):
        return self.root/'backups'/identifier(id)

    def snapshot(self, id, rel, sha):
        if sha is None: return None
        path = self.transaction_dir(id)/'originals'/relative(rel)
        self.safe(path)
        if not path.is_file() or self.digest(path) != sha:
            raise ValueError(f'Backup ausente ou alterado: {rel}')
        return path

    def manifest(self, id):
        result = self.read(self.transaction_dir(id)/'manifest.json')
        if not isinstance(result, dict) or result.get('version') != 4 or result.get('status') != 'complete':
            raise ValueError('Backup não é uma transação Stage 4 concluída')
        return result

    def transact(self, kind, before, files, changes, *, capture=False):
        # changes: rel -> (expected current hash, source to install or None)
        id = datetime.now(timezone.utc).strftime('%Y%m%d-%H%M%S-%f')
        backup = self.transaction_dir(id)
        self.safe(backup/'manifest.json')
        records = {}
        for rel, (expected, source) in changes.items():
            if self.current(rel) != expected: raise ValueError(f'Arquivo mudou durante o planejamento: {rel}')
            if source is not None: self.safe(source)
            records[rel] = {'before': expected, 'after': self.digest(source) if source is not None else None}
        # Resolve first ownership references only after the transaction ID exists.
        for entry in files.values():
            if entry['origin'] is None: entry['origin'] = id
        after = {'files': files, 'last': id}
        backup.mkdir(parents=True, mode=0o700, exist_ok=False)
        for rel, record in records.items():
            if record['before'] is not None:
                dest = backup/'originals'/relative(rel)
                self.safe(dest); self.copy(self.config/rel, dest)
                if self.digest(dest) != record['before']: raise ValueError(f'Arquivo mudou durante backup: {rel}')
            if capture: record['after'] = record['before']
        manifest = {'version':4, 'kind':kind, 'status':'pending', 'before':before, 'after':after, 'records':records}
        self.write(backup/'manifest.json', manifest)
        pending = self.root/'pending.json'
        self.write(pending, {'id':id})
        completed = []
        try:
            if not capture:
                for rel, (expected, source) in changes.items():
                    if self.current(rel) != expected: raise ValueError(f'Arquivo mudou durante a operação: {rel}')
                    if source is not None:
                        if self.digest(source) != records[rel]['after']: raise ValueError(f'Fonte alterada: {rel}')
                        self.copy(source, self.config/rel)
                    else: (self.config/rel).unlink()
                    completed.append(rel)
            self.write(self.state_path, after)
            manifest['status'] = 'complete'; self.write(backup/'manifest.json', manifest)
            pending.unlink()
        except (Exception, KeyboardInterrupt):
            failed = False
            for rel in reversed(completed):
                try:
                    if self.current(rel) != records[rel]['after']: raise ValueError('Arquivo mudou após a escrita')
                    src = self.snapshot(id, rel, records[rel]['before'])
                    if src is None: (self.config/rel).unlink()
                    else: self.copy(src, self.config/rel)
                except Exception as exc:
                    failed = True; print(f'Falha ao reverter {rel}: {exc}')
            try:
                self.write(self.state_path, before)
                manifest['status'] = 'rollback-incomplete' if failed else 'rolled-back'
                self.write(backup/'manifest.json', manifest)
                if not failed: pending.unlink()
            except Exception: failed = True
            print(f'Rollback tentado. Backup: {backup}. Revisão manual: {failed}')
            raise
        print(f'{kind}: {len(records)} arquivos. Backup: {backup}')
        return id

    def backup(self, state, apply):
        changes = {rel:(self.current(rel), None) for rel in state['files']}
        if not changes: print('Nenhum arquivo gerenciado para salvar.'); return
        print(f'Backup de {len(changes)} arquivos gerenciados (inclui edições locais).')
        if apply: self.transact('backup', state, state['files'], changes, capture=True)
        else: print('SIMULAÇÃO: nenhum arquivo escrito.')

    def restore(self, state, apply, replace, id=None):
        id = id or state['last']
        if not id: raise ValueError('Nenhuma transação Stage 4 para restaurar')
        if id != state['last']: raise ValueError('Somente a última transação pode ser restaurada com segurança')
        m = self.manifest(id)
        if m['after'] != state: raise ValueError('Registro atual não corresponde ao backup')
        changes = {}
        for rel, r in m['records'].items():
            current = self.current(rel)
            src = self.snapshot(id, rel, r['before'])
            if current == r['before']: continue
            if current != r['after'] and not replace:
                raise ValueError(f'Edição posterior preservada: {rel}. Para restaurar com backup da edição, use --apply --replace.')
            changes[rel] = (current, src)
        print(f'Restaurar {id}: {len(changes)} alterações propostas.')
        if apply: self.transact('restore', state, m['before']['files'], changes)
        else: print('SIMULAÇÃO: nenhum arquivo escrito.')

    def uninstall(self, state, names, apply):
        import copy
        files = copy.deepcopy(state['files']); changes = {}
        remaining = {o for e in files.values() for o in e['owners']} - set(names)
        if 'shell' in names and remaining.intersection({'desktop-base','themes'}):
            raise ValueError('Remova desktop-base e themes junto com shell, ou preserve shell.')
        for rel, entry in list(files.items()):
            if not set(names).intersection(entry['owners']): continue
            owners = sorted(set(entry['owners'])-set(names))
            if owners: entry['owners'] = owners; continue
            current = self.current(rel)
            if current != entry['installed']:
                print(f'Preservado (alterado ou ausente): {rel}'); continue
            source = self.snapshot(entry['origin'], rel, entry['original'])
            changes[rel] = (current, source); del files[rel]
            print(('Restaurar original: ' if source else 'Remover criado: ')+rel)
        if files == state['files']: print('Nada a alterar.'); return
        print(f'Desinstalação: {len(changes)} alterações propostas.')
        if apply: self.transact('uninstall', state, files, changes)
        else: print('SIMULAÇÃO: nenhum arquivo escrito.')
