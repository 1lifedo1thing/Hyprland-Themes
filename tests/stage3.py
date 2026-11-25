"""Offline fixtures only; no upstream package install and no actual desktop launch."""
import json, os, pathlib, shutil, subprocess, sys, tempfile
ROOT=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
from prepare import assemble, checkout, overlay, wheel

def write(base,rel,value='fixture\n'):
    p=base/rel; p.parent.mkdir(parents=True,exist_ok=True); p.write_text(value); return p

def run_git(*args,cwd=None):
    return subprocess.check_output(['git',*map(str,args)],cwd=cwd,text=True).strip()

with tempfile.TemporaryDirectory(prefix='ht-stage3-') as td:
    t=pathlib.Path(td); project=t/'project'; shutil.copytree(ROOT,project,ignore=shutil.ignore_patterns('prepared','__pycache__'))
    end=t/'end4'; pc=t/'pctrade'
    for rel in ['LICENSE','licenses/MIT.txt','dots/.config/hypr/hyprland/lib/init.lua','dots/.config/hypr/hyprland/services/init.lua','dots/.config/matugen/templates/hyprland/colors.lua','dots/.config/hypr/custom/scripts/__restore_video_wallpaper.sh']:
        write(end,rel)
    for rel in ['LICENSE','scripts/colors/named_scheme.py','scripts/lib/config.sh','shell.qml','assets/icons/example.svg']:
        write(pc,rel)
    write(pc,'screenshots/1.png','fixture screenshot')
    write(pc,'README.md','![Demo](screenshots/1.png)\nCredits preserved\n')
    (pc/'assets/icons/alias.svg').symlink_to('example.svg')
    for alias in ('ai-openai-symbolic.svg','google-gemini-symbolic.svg'):
        (pc/'assets/icons'/alias).symlink_to('example.svg')
    for src in (end,pc):
        run_git('init','-q',cwd=src);run_git('add','.',cwd=src)
        run_git('-c','user.name=Fixture','-c','user.email=fixture@example.invalid','commit','-qm','fixture',cwd=src)
    clone=t/'checkout'; checkout({'url':str(pc),'commit':run_git('rev-parse','HEAD',cwd=pc)},clone)
    assert (clone/'scripts/lib/config.sh').exists()
    out=project/'prepared'; out.mkdir(); assemble(end,clone,out,project)
    shell=out/'modules/shell/config/quickshell/end4-pC'
    assert (shell/'scripts/colors/switchwall.sh').read_bytes()==(project/'staging/shell-source/quickshell/scripts/colors/switchwall.sh').read_bytes()
    assert not (shell/'scripts/colors/collage_por_tema.py').exists()
    assert not (shell/'screenshots/1.png').exists()
    assert 'Credits preserved' in (shell/'README.md').read_text()
    assert 'https://github.com/pctrade/end4-pC/blob/' in (shell/'README.md').read_text()
    assert 'git clone' not in (shell/'services/DotsUpdater.qml').read_text()
    assert (shell/'assets/icons/alias.svg').is_file() and not (shell/'assets/icons/alias.svg').is_symlink()
    assert (shell/'modules/ii/settings/ColorWheelSpectrum.png').read_bytes().startswith(b'\x89PNG\r\n\x1a\n')
    assert (out/'licenses/end4/MIT.txt').is_file()
    bad=t/'bad'; bad.mkdir(); (bad/'external').symlink_to('/etc/passwd')
    try: overlay(bad,t/'bad-output')
    except ValueError: pass
    else: raise AssertionError('external symlink allowed')
    home=t/'home'; home.mkdir(); bin=home/'bin';bin.mkdir()
    for name in ('qs','jq','matugen','hyprctl','hypridle','hyprlock','rofi','kitty','fish','fastfetch'):
        p=write(bin,name,'#!/bin/sh\nexit 0\n');p.chmod(0o755)
    env=dict(os.environ,HOME=str(home),XDG_CONFIG_HOME=str(home/'.config'),XDG_DATA_HOME=str(home/'.local/share'),PATH=str(bin)+':'+os.environ['PATH'])
    def run(*args,ok=True):
        p=subprocess.run([str(project/'setup'),*args],env=env,capture_output=True,text=True)
        assert (p.returncode==0)==ok,(args,p.stdout[-1500:],p.stderr)
        return p.stdout+p.stderr
    assert 'SIMULAÇÃO' in run('prepare')
    run('bootstrap','--apply',ok=False)
    assert 'SIMULAÇÃO' in run('install') and not (home/'.config').exists()
    run('install','--modules','shell','--apply')
    assert (home/'.config/quickshell/end4-pC/shell.qml').is_file()
    assert (home/'.config/illogical-impulse/terminal_theme_manager.py').is_file()
    assert not (home/'.config/kitty').exists() and not (home/'.config/hypr').exists()
    result=subprocess.check_output([sys.executable,str(home/'.config/illogical-impulse/terminal_theme_manager.py'),'sync','changli'],env=env,text=True)
    assert json.loads(result)['changed'] is False and not (home/'.config/kitty').exists()
    assert not (home/'.config/illogical-impulse/hyprland-themes-terminal-enabled').exists()
    run('install','--apply')
    assert len(list((home/'.config/illogical-impulse/schemes').glob('*.json')))==15
    assert (home/'.config/hypr/hyprland/lib/init.lua').is_file()
    assert (home/'.config/matugen/templates/hyprland/colors.lua').is_file()
    assert 'Nada a alterar' in run('install','--apply')
    icons=home/'.config/quickshell/end4-pC/assets/icons'
    for name in ('ai-openai-symbolic.svg','google-gemini-symbolic.svg'):
        alias=icons/name
        alias.unlink(); alias.symlink_to('example.svg')
    assert 'igual (link preservado)' in run('install','--modules','shell')
    assert 'Nada a alterar' in run('install','--modules','shell','--apply')
    alias=icons/'ai-openai-symbolic.svg'
    assert alias.is_symlink() and os.readlink(alias)=='example.svg'
    alias.unlink(); alias.symlink_to('/etc/passwd')
    assert 'Link simbólico não suportado' in run('install','--modules','shell',ok=False)
    assert 'Link simbólico não suportado' in run('install','--modules','shell','--apply','--replace',ok=False)
    assert os.readlink(alias)=='/etc/passwd'
    alias.unlink(); alias.symlink_to('example.svg')
    (icons/'example.svg').write_text('different')
    assert 'Link simbólico não suportado' in run('install','--modules','shell',ok=False)
    (icons/'example.svg').write_bytes((shell/'assets/icons/example.svg').read_bytes())
    alias.unlink(); alias.symlink_to('nonexistent.svg')
    assert 'Link simbólico não suportado' in run('install','--modules','shell',ok=False)
    alias.unlink(); alias.symlink_to('google-gemini-symbolic.svg')
    assert 'Link simbólico não suportado' in run('install','--modules','shell',ok=False)
    alias.unlink(); alias.symlink_to('example.svg')
    assert 'Nada a alterar' in run('install','--modules','shell','--apply')
    print('PASS: matching upstream aliases preserved; external, differing, broken and chained aliases refused')
    (shell/'scripts/colors/named_scheme.py').write_text('changed')
    assert 'Base preparada modificada' in run('install','--modules','shell',ok=False)
    print('PASS: pinned local checkout, overlay, internal/external symlink policy, generated wheel, licenses, dry-run, bootstrap guard, shell isolation, full desktop fixture, duplicate helper merge, idempotence, tamper refusal')
