#!/usr/bin/env python3
"""Seleciona um wallpaper, MOVE imediatamente e notifica depois de confirmar.

Sem confirmação extra, sem aplicar wallpaper, sem substituir arquivos existentes.
Somente stdout JSON no sucesso para a galeria atualizar sua pasta.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import time
import sys
import traceback
from datetime import datetime
from pathlib import Path
from urllib.parse import unquote, urlsplit

STATIC = {'.png', '.jpg', '.jpeg', '.webp', '.bmp', '.gif', '.avif'}
ANIMATED = {'.mp4'}
LOG = Path.home() / '.cache/end4-wallpaper-import.log'


def log(message: str) -> None:
    try:
        LOG.parent.mkdir(parents=True, exist_ok=True)
        with LOG.open('a', encoding='utf-8') as f:
            f.write(f'[{datetime.now().isoformat(timespec="seconds")}] {message}\n')
    except OSError:
        pass


def notify(summary: str, message: str, urgency: str = 'normal') -> None:
    # O kdialog ja e o seletor usado por este importador e funciona na sessao
    # do usuario. Seu passivepopup nao depende do processo da galeria estar vivo.
    # Diferente do notify-send anterior, qualquer falha na abertura fica no log.
    label = str(summary).replace('\n', ' ')
    detail = str(message)
    command = ['kdialog', '--title', label, '--passivepopup', detail, '6']
    log(f'AVISO: tentando abrir popup: {label} | {detail}')
    try:
        with LOG.open('a', encoding='utf-8') as trace:
            proc = subprocess.Popen(
                command, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                stderr=trace, start_new_session=True
            )
        # Retorno instantaneo com codigo de erro significa que o popup falhou.
        # Se permanecer executando, o popup pode continuar por seus 6 segundos.
        time.sleep(0.25)
        status = proc.poll()
        if status is None or status == 0:
            log(f'AVISO: kdialog iniciado; pid={proc.pid}; status={status}')
            return
        log(f'AVISO: kdialog terminou com codigo {status}; tentando notify-send')
    except OSError as exc:
        log(f'AVISO: falha ao iniciar kdialog: {exc}; tentando notify-send')

    try:
        result = subprocess.run(
            ['notify-send', '-a', 'end4-pC', '-u', urgency,
             '--expire-time=6000', label, detail],
            stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE, text=True, timeout=7, check=False
        )
        if result.returncode == 0:
            log('AVISO: notify-send enviado')
        else:
            log(f'AVISO: notify-send falhou ({result.returncode}): {result.stderr.strip()}')
    except (OSError, subprocess.TimeoutExpired) as exc:
        log(f'AVISO: notify-send indisponivel: {exc}')


def parse_path(raw: str) -> Path:
    text = raw.strip('\r\n')
    if not text:
        raise ValueError('O seletor não retornou nenhum caminho.')
    if text.startswith('file://'):
        parsed = urlsplit(text)
        if parsed.netloc not in ('', 'localhost'):
            raise ValueError('Selecione um arquivo local.')
        text = unquote(parsed.path)
    return Path(os.path.expanduser(text))


def select_path() -> Path | None:
    # O Quickshell fecha sua janela ANTES do diálogo aparecer, liberando o foco.
    # O helper é iniciado em modo detached: a destruição da galeria não o interrompe.
    time.sleep(0.55)
    command = [
        'kdialog', '--getopenfilename', str(Path.home()),
        'Imagens e MP4 (*.png *.jpg *.jpeg *.webp *.bmp *.gif *.avif *.mp4)',
        '--title', 'Adicionar wallpaper',
    ]
    log('ABRINDO SELETOR: kdialog')
    try:
        process = subprocess.Popen(command, stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE, text=True)
    except FileNotFoundError as exc:
        raise RuntimeError('kdialog não encontrado. Instale com: sudo pacman -S kdialog') from exc
    log(f'SELETOR INICIADO: pid={process.pid}; aguardando arquivo')
    output, error = process.communicate()
    log(f'SELETOR FINALIZADO: exit={process.returncode}; saída={output.strip()!r}; erro={error.strip()!r}')
    if process.returncode == 1 and not output.strip():
        return None
    if process.returncode != 0:
        raise RuntimeError('Falha no seletor: ' + (error.strip() or str(process.returncode)))
    if not output.strip():
        return None
    entries = output.strip().splitlines()
    if len(entries) != 1:
        raise ValueError('Selecione um arquivo por vez.')
    return parse_path(entries[0])


def move_wallpaper(source: Path, home: Path) -> dict:
    source = source.expanduser()
    if source.is_symlink():
        raise ValueError('Não é permitido importar um link simbólico.')
    if not source.is_file():
        raise FileNotFoundError(f'Arquivo não encontrado: {source}')
    ext = source.suffix.lower()
    if ext not in STATIC | ANIMATED:
        raise ValueError(f'Formato não suportado: {source.suffix}')
    target_dir = home / 'Pictures' / 'Wallpapers'
    if ext in ANIMATED:
        target_dir = target_dir / 'Animated'
    target_dir.mkdir(parents=True, exist_ok=True)

    # Quando já está no lugar certo, nunca move para si mesmo.
    if source.parent.resolve() == target_dir.resolve():
        return {
            'path': str(source), 'directory': str(target_dir),
            'type': 'video' if ext in ANIMATED else 'image', 'already_here': True
        }

    destination = target_dir / source.name
    suffix = 2
    while destination.exists() or destination.is_symlink():
        destination = target_dir / f'{source.stem} ({suffix}){source.suffix}'
        suffix += 1
    log(f'MOVENDO: {source} -> {destination}')
    shutil.move(str(source), str(destination))
    if not destination.is_file() or source.exists():
        raise RuntimeError(f'Falha ao verificar movimentação para {destination}')
    return {
        'path': str(destination), 'directory': str(target_dir),
        'type': 'video' if ext in ANIMATED else 'image', 'already_here': False
    }


def main() -> int:
    log('INÍCIO V4: processo independente acionado')
    try:
        selected = parse_path(sys.argv[1]) if len(sys.argv) > 1 else select_path()
        if selected is None:
            log('CANCELADO: nenhum arquivo escolhido')
            return 2
        log(f'SELECIONADO: {selected}')
        result = move_wallpaper(selected, Path.home())
        log(f'OK: {result["path"]}; já existia na pasta={result["already_here"]}')
        if result['already_here']:
            notify('Wallpaper já está na biblioteca', str(result['path']))
        else:
            notify('Wallpaper movido', f'Movido para: {result["path"]}')
        print(json.dumps(result, ensure_ascii=False), flush=True)
        return 0
    except Exception as exc:
        log(f'ERRO: {exc}\n{traceback.format_exc()}')
        notify('Falha ao mover wallpaper', f'{exc}\nDetalhes: {LOG}', 'critical')
        print(f'ERRO: {exc}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
