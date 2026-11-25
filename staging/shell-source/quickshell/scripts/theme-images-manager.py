#!/usr/bin/env python3
"""Importador de imagens de tema para end4-pC.

* inspect: confere origem/destino SEM modificar arquivos.
* install: copia/converte para o destino; deixa a origem.
* move: converte/copia com backup e SÓ depois remove o original externo.
* prepare: cria/mostra a pasta de destino.

Não sobrescreve imagens de outros temas e não apaga a origem em caso de falha.
"""
from __future__ import annotations

import argparse
from datetime import datetime
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
from urllib.parse import unquote, urlparse

DIR = Path.home() / "Pictures" / "SidebarThemes"
ALIASES = {"hotlinemiami": "hotline-miami"}


def report(**data):
    print(json.dumps(data, ensure_ascii=False))


def target_theme(value: str) -> str:
    key = re.sub(r"[^a-z0-9]", "", value.lower())
    if not key:
        raise ValueError("Selecione um tema nomeado antes de importar imagens.")
    return ALIASES.get(key, key)


def path_from_url(value: str) -> Path:
    if value.startswith("file:"):
        url = urlparse(value)
        if url.scheme != "file" or url.netloc not in ("", "localhost"):
            raise ValueError("Somente arquivos locais são aceitos.")
        path = Path(unquote(url.path)).expanduser()
    else:
        path = Path(value).expanduser()
    if not path.is_absolute():
        raise ValueError("Use um caminho absoluto, como /home/user/Pictures/foto.png")
    return path


def validate_source(source: Path) -> None:
    if not source.is_file():
        raise ValueError(f"Arquivo não encontrado: {source}")
    if not os.access(source, os.R_OK):
        raise ValueError(f"Arquivo sem permissão de leitura: {source}")
    with source.open("rb") as fp:
        header = fp.read(12)
    if not (header[:4] == b"RIFF" and header[8:12] == b"WEBP"
            or header[:8] == b"\x89PNG\r\n\x1a\n"
            or header[:3] == b"\xff\xd8\xff"):
        raise ValueError("Formato inválido. Selecione WebP, PNG ou JPG.")


def get_info(theme: str, kind: str, source_text: str) -> dict:
    key = target_theme(theme)
    if kind not in ("icon", "card"):
        raise ValueError("Tipo deve ser icon ou card")
    source = path_from_url(source_text)
    validate_source(source)
    final = DIR / (key + ("-card" if kind == "card" else "") + ".webp")
    if final.is_symlink():
        raise ValueError(f"O destino é um link simbólico: {final}. Não vou sobrescrevê-lo.")
    if final.exists() and not final.is_file():
        raise ValueError(f"O destino não é um arquivo: {final}")
    outside = not source.resolve().is_relative_to(DIR.resolve())
    if outside and source.is_symlink():
        raise ValueError("O arquivo escolhido é um link simbólico externo. Escolha o arquivo original.")
    same = source.resolve() == final.resolve()
    return {"source": source, "destination": final, "outside": outside,
            "replace": final.exists() and not same, "already": same}


def convert_webp(source: Path, dest: Path) -> None:
    with source.open("rb") as fp:
        header = fp.read(12)
    if header[:4] == b"RIFF" and header[8:12] == b"WEBP":
        shutil.copyfile(source, dest)
        return
    ffmpeg = shutil.which("ffmpeg")
    magick = shutil.which("magick") or shutil.which("convert")
    if ffmpeg:
        cmd = [ffmpeg, "-nostdin", "-hide_banner", "-loglevel", "error", "-y",
               "-i", str(source), "-frames:v", "1", "-c:v", "libwebp", str(dest)]
    elif magick:
        cmd = [magick, str(source), str(dest)]
    else:
        raise RuntimeError("Para PNG/JPG, instale ffmpeg: sudo pacman -S ffmpeg")
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=90)
    if result.returncode != 0 or not dest.is_file() or dest.stat().st_size == 0:
        raise RuntimeError("Erro na conversão: " + (result.stderr.strip() or "conversão falhou")[-300:])


def install(theme: str, kind: str, source_text: str, *, move: bool = False) -> dict:
    info = get_info(theme, kind, source_text)
    source, final = info["source"], info["destination"]
    if info["already"]:
        return {"path": str(final), "moved": False, "already": True, "backup": ""}

    DIR.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=DIR, prefix=".theme-img-", suffix=".webp", delete=False) as f:
        temp = Path(f.name)
    saved = None
    try:
        convert_webp(source, temp)
        if temp.stat().st_size == 0:
            raise RuntimeError("Imagem vazia")
        os.chmod(temp, 0o644)
        if final.exists():
            folder = DIR / ".backups"
            folder.mkdir(exist_ok=True)
            saved = folder / (final.name + "." + datetime.now().strftime("%Y%m%d-%H%M%S-%f") + ".bak")
            shutil.copy2(final, saved)
        os.replace(temp, final)
    finally:
        temp.unlink(missing_ok=True)

    moved = False
    warning = ""
    if move and info["outside"]:
        try:
            source.unlink()
            moved = True
        except OSError as e:
            warning = ("Imagem salva, mas não consegui remover a origem: " + str(e))
    return {"path": str(final), "moved": moved, "already": False,
            "backup": str(saved) if saved else "", "warning": warning}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("operation", choices=["inspect", "install", "move", "prepare"])
    parser.add_argument("theme", nargs="?", default="")
    parser.add_argument("kind", nargs="?", default="")
    parser.add_argument("source", nargs="?", default="")
    args = parser.parse_args()
    try:
        if args.operation == "prepare":
            DIR.mkdir(parents=True, exist_ok=True)
            report(ok=True, path=str(DIR))
        elif args.operation == "inspect":
            info = get_info(args.theme, args.kind, args.source)
            report(ok=True, outside=info["outside"], replace=info["replace"],
                   already=info["already"], source=str(info["source"]),
                   destination=str(info["destination"]))
        else:
            output = install(args.theme, args.kind, args.source, move=(args.operation == "move"))
            report(ok=True, **output)
        return 0
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as e:
        report(ok=False, error=str(e))
        return 1


if __name__ == "__main__":
    sys.exit(main())
