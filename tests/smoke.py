import os, pathlib, subprocess, tempfile, json
root=pathlib.Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='hyprland-themes-test-') as temp:
    home=pathlib.Path(temp); bin=home/'bin'; bin.mkdir()
    for name in ('rofi','kitty','fish','fastfetch'):
        f=bin/name; f.write_text('#!/bin/sh\nexit 0\n'); f.chmod(0o755)
    env=dict(os.environ,HOME=temp,XDG_CONFIG_HOME=str(home/'.config'),XDG_DATA_HOME=str(home/'.local/share'),PATH=str(bin)+':'+os.environ['PATH'])
    def run(*args, ok=True):
        p=subprocess.run([str(root/'setup'),*args],env=env,text=True,capture_output=True)
        assert (p.returncode==0)==ok,(args,p.stdout,p.stderr)
        return p.stdout+p.stderr
    assert 'SIMULAÇÃO' in run('install','--modules','launcher')
    assert not (home/'.config').exists()
    run('install','--modules','themes','--apply',ok=False)
    rofi=home/'.config/rofi/config.rasi'; rofi.parent.mkdir(parents=True); rofi.write_text('ORIGINAL')
    run('install','--modules','launcher','--apply',ok=False)
    assert rofi.read_text()=='ORIGINAL'
    run('install','--modules','launcher','--apply','--replace')
    assert rofi.read_text()!='ORIGINAL'
    backups=list((home/'.local/share/Hyprland-Themes/backups').glob('*/originals/rofi/config.rasi'))
    assert len(backups)==1 and backups[0].read_text()=='ORIGINAL'
    assert 'Nada a alterar' in run('install','--modules','launcher','--apply')
    assert not (home/'.config/kitty').exists()
    run('install','--modules','terminal','--apply')
    assert (home/'.config/kitty/kitty.conf').is_file()
    qs=home/'.config/quickshell/end4-pC/scripts/colors'; qs.mkdir(parents=True); (qs/'named_scheme.py').touch()
    run('install','--modules','themes','--apply')
    assert len(list((home/'.config/illogical-impulse/schemes').glob('*.json')))==15
    (home/'.config/rofi/dashboard.rasi').unlink(); (home/'.config/rofi/dashboard.rasi').symlink_to('/etc/passwd')
    run('install','--modules','launcher','--apply','--replace',ok=False)
    assert (home/'.config/rofi/dashboard.rasi').is_symlink()
    run('install','--modules','desktop','--apply',ok=False)
    print('PASS: dry-run, missing prerequisites, collision refusal, backup, module isolation, idempotence, 15 themes, symlink refusal, unavailable module refusal')
