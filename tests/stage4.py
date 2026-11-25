"""File lifecycle tests in disposable HOME; no real Arch/desktop actions."""
import json, os, pathlib, shutil, subprocess, sys, tempfile
ROOT=pathlib.Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='ht-stage4-') as td:
    t=pathlib.Path(td); project=t/'project'; shutil.copytree(ROOT,project,ignore=shutil.ignore_patterns('prepared','__pycache__','.git'))
    home=t/'home'; home.mkdir(); bin=home/'bin'; bin.mkdir()
    for name in ('rofi','kitty','fish','fastfetch'):
        p=bin/name; p.write_text('#!/bin/sh\nexit 0\n');p.chmod(0o755)
    config=home/'.config'; data=home/'.local/share/Hyprland-Themes'
    env=dict(os.environ,HOME=str(home),XDG_CONFIG_HOME=str(config),XDG_DATA_HOME=str(data.parent),PATH=str(bin)+':'+os.environ['PATH'])
    def run(*args,ok=True):
        p=subprocess.run([str(project/'setup'),*args],env=env,capture_output=True,text=True)
        assert (p.returncode==0)==ok,(args,p.stdout[-2000:],p.stderr)
        return p.stdout+p.stderr
    def state(): return json.loads((data/'ownership.json').read_text())
    assert 'nenhum' in run('doctor') and not data.exists()
    assert 'Nenhum' in run('update') and not data.exists()
    cfg=config/'rofi/config.rasi'; cfg.parent.mkdir(parents=True); cfg.write_text('ORIGINAL')
    dash=config/'rofi/dashboard.rasi'
    src=project/'modules/launcher/config/rofi/config.rasi'; srcdash=src.parent/'dashboard.rasi'
    dash.write_bytes(srcdash.read_bytes())  # identical before installation: must not be owned
    run('install','--modules','launcher','--apply','--replace')
    first=state()['last']; installed=cfg.read_bytes()
    assert list(state()['files'])==['rofi/config.rasi']
    src.write_text('VERSION 2')
    assert 'SIMULAÇÃO' in run('update') and cfg.read_bytes()==installed
    run('update','--apply'); assert cfg.read_text()=='VERSION 2'
    assert state()['files']['rofi/config.rasi']['origin']==first
    run('restore','--apply'); assert cfg.read_bytes()==installed
    cfg.write_text('LOCAL EDIT')
    assert 'Alterado/ausente' in run('doctor')
    run('update','--apply',ok=False); assert cfg.read_text()=='LOCAL EDIT'
    run('backup','--apply'); capture=state()['last']; cfg.write_text('AFTER BACKUP')
    run('restore','--apply',ok=False); assert cfg.read_text()=='AFTER BACKUP'
    run('restore','--id',capture,'--apply','--replace'); assert cfg.read_text()=='LOCAL EDIT'
    last=state()['last']; assert (data/'backups'/last/'originals/rofi/config.rasi').read_text()=='AFTER BACKUP'
    run('restore','--id',first,'--apply',ok=False)
    assert 'Preservado' in run('uninstall','--apply') and cfg.read_text()=='LOCAL EDIT'
    run('update','--apply','--replace'); assert cfg.read_text()=='VERSION 2'
    assert 'SIMULAÇÃO' in run('uninstall') and cfg.read_text()=='VERSION 2'
    run('uninstall','--apply'); assert cfg.read_text()=='ORIGINAL' and dash.read_bytes()==srcdash.read_bytes()
    assert state()['files']=={}
    run('restore','--apply'); assert cfg.read_text()=='VERSION 2'
    cfg.unlink(); cfg.symlink_to('/etc/passwd')
    run('uninstall','--apply',ok=False); assert cfg.is_symlink()
    cfg.unlink(); cfg.write_text('VERSION 2')
    # Refuse tampered original before changing anything.
    original=data/'backups'/first/'originals/rofi/config.rasi'; original.write_text('TAMPERED')
    run('uninstall','--apply',ok=False); assert cfg.read_text()=='VERSION 2'
    original.write_text('ORIGINAL')
    (data/'pending.json').write_text('{}')
    run('update','--apply',ok=False); assert cfg.read_text()=='VERSION 2'
    (data/'pending.json').unlink()
    run('uninstall','--apply'); assert cfg.read_text()=='ORIGINAL'
    # Fresh files are removed, not pre-existing identical ones.
    cfg.unlink(); run('install','--modules','launcher','--apply'); assert cfg.exists()
    run('uninstall','--apply'); assert not cfg.exists() and dash.exists()
    print('PASS: ownership, read-only simulation, update, rollback latest, local edits, backup, restore with confirmation, original recovery, identical files, symlinks, tamper and interrupted transaction guards, uninstall created files')

# Inject an ordinary failure during the second copy; verify rollback of the first.
sys.path.insert(0,str(ROOT/'scripts'))
from lifecycle import Lifecycle
from setup import digest,safe_path,atomic_copy
with tempfile.TemporaryDirectory(prefix='ht-stage4-failure-') as td:
    t=pathlib.Path(td); config=t/'config'; config.mkdir(); data=t/'data'
    src=t/'source'; src.write_text('new'); (config/'a').write_text('old')
    def fail(source,target):
        if target==config/'b': raise OSError('simulated write failure')
        atomic_copy(source,target)
    life=Lifecycle(config,data,digest,safe_path,fail)
    with life.lock(True):
        state=life.state()
        try: life.transact('install',state,{}, {'a':(digest(config/'a'),src),'b':(None,src)})
        except OSError: pass
        else: raise AssertionError('failure not injected')
        assert (config/'a').read_text()=='old' and not (config/'b').exists()
        assert life.state()==state and not (life.root/'pending.json').exists()
    print('PASS: ordinary write failure rolls back file and ownership state')
