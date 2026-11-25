import pathlib, tempfile, subprocess, json, os
root=pathlib.Path(__file__).resolve().parents[1]
s=(root/'staging/shell-source/quickshell/scripts/colors/switchwall.sh').read_text()
block=s[s.index('    # Preferir associação explícita'):s.index('    switch "$imgpath"',s.index('    # Preferir associação explícita'))]
with tempfile.TemporaryDirectory() as td:
    p=pathlib.Path(td); (p/'schemes').mkdir();(p/'scripts').mkdir();(p/'config.json').write_text('{}')
    for n in ['haimiya','bibian','custom']:(p/'schemes'/f'{n}.json').write_text('{}')
    img=p/'Haimiya.jpg';img.touch(); other=p/'random.png';other.touch()
    def check(image,expected,links={},**flags):
        (p/'wallpaper-scheme-links.json').write_text(json.dumps({'wallpapers':links}))
        env=dict(os.environ,SCRIPT_DIR=str(p/'scripts'),SHELL_CONFIG_FILE=str(p/'config.json'),imgpath=str(image),explicit_image='1',explicit_scheme='',noswitch_flag='',colors_only_flag='',colors_lock_flag='',named_scheme='bibian',auto_named_scheme_changed='')
        env.update(flags)
        r=subprocess.run(['bash','-c','select_theme() {\n'+block+'\n}\nselect_theme\nprintf "%s|%s" "$named_scheme" "$auto_named_scheme_changed"'],env=env,text=True,capture_output=True,check=True)
        assert r.stdout==expected,(r.stdout,expected,r.stderr)
    check(img,'haimiya|1')
    check(img,'custom|1',{str(img):'custom'})
    check(other,'custom|1',{str(other):'custom'})
    check(img,'haimiya|1',{str(img):'missing'})
    check(img,'bibian|',{str(img):'custom'},explicit_scheme='1')
    check(img,'bibian|',{str(img):'custom'},noswitch_flag='1')
    check(other,'bibian|')
    print('PASS: name matching, explicit binding precedence, missing scheme fallback, --scheme-name and --noswitch isolation')
