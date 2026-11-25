#!/usr/bin/env python3
"""Assemble pinned upstream checkouts and reviewed overlays in a separate workspace."""
import colorsys, hashlib, json, math, os, pathlib, shutil, struct, subprocess, tempfile, zlib
ROOT = pathlib.Path(__file__).resolve().parents[1]
LOCK = json.loads((ROOT/'upstream-lock.json').read_text())

def git(*args, cwd=None):
    return subprocess.check_output(['git', *map(str,args)], cwd=cwd, text=True).strip()

def checkout(spec, path):
    git('clone','--no-checkout','--',spec['url'],path)
    git('checkout','--detach',spec['commit'],cwd=path)
    verify(path,spec)

def verify(path,spec):
    if git('rev-parse','HEAD',cwd=path)!=spec['commit'] or git('status','--porcelain','--untracked-files=all',cwd=path):
        raise ValueError(f'Checkout não corresponde à revisão limpa esperada: {path}')

def overlay(src,dst,skip=()):
    """Copy regular files; resolve only symlinks to files inside the source tree."""
    for p in sorted(src.rglob('*')):
        rel=p.relative_to(src)
        if '.git' in rel.parts or str(rel) in skip: continue
        t=dst/rel
        if p.is_symlink():
            actual=p.resolve(strict=True)
            if not actual.is_relative_to(src.resolve()) or not actual.is_file():
                raise ValueError(f'Link externo ou inválido: {p}')
        elif p.is_dir(): continue
        elif not p.is_file(): raise ValueError(f'Arquivo especial: {p}')
        else: actual=p
        t.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(actual,t)

def wheel(path,n=512):
    # Original procedural HSV wheel: right=red, positive screen y=clockwise,
    # matching ColorWheelSchemeDialog.chooseAt. Transparent outside the disk.
    def chunk(kind,data):
        return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
    raw=bytearray(); r=n/2-8
    for y in range(n):
        raw.append(0)
        for x in range(n):
            dx=x+.5-n/2; dy=y+.5-n/2; d=math.hypot(dx,dy)
            h=(math.atan2(dy,dx)/(2*math.pi))%1
            rgb=colorsys.hsv_to_rgb(h,min(1,d/r),1)
            raw.extend([*(round(c*255) for c in rgb),round(max(0,min(1,r+.5-d))*255)])
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',n,n,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(raw))+chunk(b'IEND',b''))

def assemble(end4,pc,out,root=ROOT):
    shell=out/'modules/shell/config/quickshell/end4-pC'
    # Upstream showcase images are not runtime dependencies. Keep README credits,
    # but link to the exact upstream revision instead of bundling the screenshots.
    omitted=tuple(f'screenshots/{i}.png' for i in range(1,7))
    overlay(pc,shell,omitted)
    for readme in shell.glob('README*.md'):
        text=readme.read_text()
        for rel in omitted:
            text=text.replace(f']({rel})', f'](https://github.com/pctrade/end4-pC/blob/{LOCK["pctrade"]["commit"]}/{rel})')
        readme.write_text(text)
    # Legacy separate collage writer is deliberately excluded; QML owns the profiles.
    overlay(root/'staging/shell-source/quickshell',shell,('scripts/colors/collage_por_tema.py',))
    wheel(shell/'modules/ii/settings/ColorWheelSpectrum.png')
    # Preserve upstream notices and README in the assembled tree; separate licenses for end-4.
    overlay(end4/'licenses',out/'licenses/end4')
    shutil.copy2(end4/'LICENSE',out/'licenses/end4/GPL-3.0.txt')
    for folder in ('hypr','matugen'):
        dst=out/'modules/desktop-base/config'/folder
        overlay(end4/'dots/.config'/folder,dst)
        overlay(root/'staging'/folder,dst)
    # Don't copy source-machine monitor overrides, login helpers, timer or private HUD.
    # Keep the existing empty upstream restore stub (switchwall creates it on demand).
    for rel in ('scripts/colors/named_scheme.py','scripts/lib/config.sh','shell.qml','LICENSE'):
        if not (shell/rel).is_file(): raise ValueError(f'Base incompleta: {rel}')
    for rel in ('hypr/hyprland/lib/init.lua','hypr/hyprland/services/init.lua','matugen/templates/hyprland/colors.lua'):
        if not (out/'modules/desktop-base/config'/rel).is_file(): raise ValueError(f'Base incompleta: {rel}')
    # Helper scripts are required by the shell; terminal configuration itself remains optional.
    for name in ('terminal_theme_manager.py','kitty_paleta_auto.py'):
        dst=out/'modules/shell/config/illogical-impulse'/name
        dst.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(root/'modules/terminal/config/illogical-impulse'/name,dst)
    manifest={str(p.relative_to(out)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((out/'modules').rglob('*')) if p.is_file()}
    (out/'manifest.json').write_text(json.dumps({'upstream':LOCK,'files':manifest},indent=2)+'\n')

def prepare():
    dest=ROOT/'prepared'
    if dest.exists() or dest.is_symlink(): raise ValueError('prepared/ já existe; preserve ou renomeie antes de remontar')
    with tempfile.TemporaryDirectory(prefix='.prepare-',dir=ROOT) as tmp:
        work=pathlib.Path(tmp); repos=work/'repos'; repos.mkdir()
        for key,spec in LOCK.items(): checkout(spec,repos/key)
        out=work/'prepared'; out.mkdir()
        assemble(repos/'end4',repos/'pctrade',out)
        shutil.move(repos,out/'repos')
        out.rename(dest)
    print('Base montada em prepared/. Nenhum arquivo do desktop foi alterado.')

def bootstrap():
    path=ROOT/'prepared/repos/end4'
    verify(path,LOCK['end4'])
    # Upstream setup may install packages, change services and existing dotfiles.
    subprocess.run(['git','submodule','update','--init','--recursive'],cwd=path,check=True)
    subprocess.run(['bash','./setup','install'],cwd=path,check=True)
    print('Setup original concluído. Revise o plano de instalação do módulo desktop antes de aplicar.')
