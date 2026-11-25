#!/usr/bin/env python3
"""Non-destructive local profiles for Kitty colors + Fastfetch cover images.

Run without arguments for help. No external Python packages required.
"""
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import tempfile
from datetime import datetime
from pathlib import Path

HOME = Path.home()
XDG_CONFIG = Path(os.environ.get('XDG_CONFIG_HOME', HOME / '.config'))
XDG_DATA = Path(os.environ.get('XDG_DATA_HOME', HOME / '.local/share'))
BASE = XDG_CONFIG / 'illogical-impulse'
STATE = BASE / 'terminal-theme-profiles.json'
KITTY = XDG_CONFIG / 'kitty' / 'kitty.conf'
KITTY_MANAGED = XDG_CONFIG / 'kitty' / 'terminal-theme-manager.conf'
DESKTOP_CFG = BASE / 'config.json'
FISH_SCRIPT = XDG_CONFIG / 'fish' / 'conf.d' / 'terminal-theme-manager.fish'
COVER_FILE = BASE / 'terminal-theme-cover.txt'
COVER_DIR = XDG_DATA / 'terminal-theme-manager' / 'covers'
BACKUP_DIR = BASE / 'terminal-theme-backups'
MANAGED_INCLUDE = 'include terminal-theme-manager.conf'
MANAGED_COMMENT = '# Gerenciado pelo editor de temas do terminal'
MANAGED_COMMENT = '# Gerenciado pelo editor de temas do terminal'
MANAGED_COMMENT = '# Gerenciado pelo editor de temas do terminal'
PALETTE = {
    'background':'#160E12', 'foreground':'#F5E9DD', 'cursor':'#E4B977',
    'selection_background':'#803A53', 'selection_foreground':'#FFFFFF',
    'color0':'#23171B', 'color1':'#D84C61', 'color2':'#B38C67', 'color3':'#E4B977',
    'color4':'#8C789C', 'color5':'#CC83A5', 'color6':'#B59A8B', 'color7':'#F5E9DD',
    'color8':'#66525B', 'color9':'#F07988', 'color10':'#D7AF89', 'color11':'#F6CF91',
    'color12':'#A991BB', 'color13':'#ECA5C2', 'color14':'#D5B5AB', 'color15':'#FFFFFF',
}
COLOR_KEYS = list(PALETTE)
HEX = re.compile(r'^#[a-fA-F0-9]{6}$')
NAME = re.compile(r'^[A-Za-z0-9_\-]+$')
ACCEPT_EXT = {'.png','.jpg','.jpeg','.webp'}


def reply(obj):
    print(json.dumps(obj, ensure_ascii=False))


def fail(msg):
    reply({'ok':False,'error':str(msg)})
    raise SystemExit(1)


def backup(path):
    if not path.exists():
        return None
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    date = datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    target = BACKUP_DIR / (str(path.relative_to(XDG_CONFIG)).replace('/','__') + '.' + date + '.bak')
    shutil.copy2(path,target)
    return str(target)


def write_atomic(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(dir=path.parent, prefix='.' + path.name + '.', text=True)
    try:
        with os.fdopen(fd,'w',encoding='utf-8') as f:
            f.write(content)
            f.flush()
            os.fsync(f.fileno())
        if path.exists():
            os.chmod(name, path.stat().st_mode & 0o777)
        else:
            os.chmod(name, 0o600)
        os.replace(name,path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def write_changed(path, content):
    if path.exists() and path.read_text(encoding='utf-8') == content:
        return
    backup(path)
    write_atomic(path,content)


def slug(name):
    out = re.sub(r'[^a-z0-9]+','-',name.lower().strip()).strip('-')
    if not out or not NAME.fullmatch(out):
        fail('Nome do tema inválido.')
    return out


def parse_conf(path):
    colors={}
    if path.is_file():
        for line in path.read_text(encoding='utf-8',errors='replace').splitlines():
            match=re.match(r'^\s*('+'|'.join(COLOR_KEYS)+r')\s+(#[0-9a-fA-F]{6})(?:\s|$)',line)
            if match:
                colors[match.group(1)] = match.group(2).upper()
    return colors


def initial_state():
    profiles={}
    for title in ('changli','hiyuki'):
        path = KITTY.parent/(title+'.conf')
        if path.is_file():
            profiles[title]={'name':title.title(),'colors':{**PALETTE,**parse_conf(path)},'cover':''}
    if not profiles:
        profiles['personalizado']={'name':'Personalizado','colors':{**PALETTE},'cover':''}
    active=next(iter(profiles))
    return {'version':1,'active':active,'profiles':profiles,'desktopMode':False}


def load():
    if not STATE.exists():
        return initial_state()
    value=json.loads(STATE.read_text(encoding='utf-8'))
    if not isinstance(value,dict) or not isinstance(value.get('profiles'),dict):
        fail('Arquivo de perfis inválido. Nenhum arquivo foi sobrescrito.')
    if value.get('active') not in value['profiles']:
        fail('Perfil ativo não encontrado. Corrija o JSON antes de continuar.')
    return value


def save(state):
    write_changed(STATE,json.dumps(state,ensure_ascii=False,indent=2)+'\n')


def set_auto_terminal(enabled):
    if not DESKTOP_CFG.exists():
        return 'Configuração Quickshell não encontrada; verifique se as cores automáticas do terminal estão desativadas.'
    content=DESKTOP_CFG.read_text(encoding='utf-8')
    match=list(re.finditer(r'("enableTerminal"\s*:\s*)(true|false)',content))
    if len(match)!=1:
        return 'Campo enableTerminal não encontrado de maneira única; config.json preservado.'
    m=match[0]
    new=content[:m.start(2)] + ('true' if enabled else 'false') + content[m.end(2):]
    write_changed(DESKTOP_CFG,new)
    return None


def kitty_include(what):
    # Remove ONLY our own dedicated lines, leaving all existing includes/settings intact.
    content = KITTY.read_text(encoding='utf-8') if KITTY.exists() else ''
    filtered=[line for line in content.splitlines() if line.strip() not in (MANAGED_INCLUDE, MANAGED_COMMENT)]
    if what:
        filtered += ['', MANAGED_COMMENT, MANAGED_INCLUDE]
    output='\n'.join(filtered).rstrip()+'\n'
    write_changed(KITTY,output)


def kitty_reload():
    # END4_KITTY_RELOAD_AFTER_SETTLE_V4
    # O Quickshell pode finalizar o recolorimento *depois* deste apply().
    # Recarrega agora e mais uma vez após os processos de tema se assentarem.
    # A segunda recarga lê o arquivo atual: se o usuário trocar de tema
    # novamente, não reaplica uma paleta antiga.
    command = ['pkill', '-USR1', '-u', str(os.getuid()), '-x', 'kitty']
    try:
        subprocess.run(command, check=False, stdout=subprocess.DEVNULL,
                       stderr=subprocess.DEVNULL, timeout=3)
    except (OSError, subprocess.TimeoutExpired):
        pass

    # Recarregamento independente do processo principal, sem bloquear a UI.
    # Não usa acesso remoto nem modifica a configuração de segurança do Kitty.
    late_reload = (
        'import os, subprocess, time\n'
        'time.sleep(1.6)\n'
        'subprocess.run(["pkill", "-USR1", "-u", str(os.getuid()), "-x", "kitty"], '
        'stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=3, check=False)\n'
    )
    try:
        subprocess.Popen([sys.executable, '-c', late_reload],
                         stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL, start_new_session=True,
                         close_fds=True)
    except OSError:
        pass


def install_fish_cover():
    script='''# Arquivo criado pelo gerenciador de capas do terminal.\n# A função mantém os argumentos e o layout original do fastfetch.\nfunction fastfetch --wraps fastfetch --description 'Fastfetch com capa do perfil ativo'\n    set -l capa "$HOME/.config/illogical-impulse/terminal-theme-cover.txt"\n    if test -s "$capa"\n        set -l imagem (string trim -- (cat "$capa"))\n        if test -f "$imagem"\n            command fastfetch $argv --logo-type kitty-icat --logo "$imagem" --logo-width 29\n            return $status\n        end\n    end\n    command fastfetch $argv\nend\n'''
    write_changed(FISH_SCRIPT, script)


def copy_cover(id_, new_path):
    if not new_path:
        return ''
    source=Path(os.path.expanduser(new_path)).resolve()
    if not source.is_file() or source.suffix.lower() not in ACCEPT_EXT:
        fail('A capa deve ser um arquivo .png, .webp, .jpg ou .jpeg existente.')
    if source.stat().st_size > 50*1024*1024:
        fail('A capa tem mais de 50 MB.')
    COVER_DIR.mkdir(parents=True,exist_ok=True)
    dest=COVER_DIR/(id_+source.suffix.lower())
    if dest.resolve()!=source:
        if dest.exists():
            backup_ = COVER_DIR/(id_+'-'+datetime.now().strftime('%Y%m%d%H%M%S%f')+'.previous'+dest.suffix)
            shutil.copy2(dest, backup_)
        shutil.copy2(source,dest)
    return str(dest)


def apply(state):
    profile=state['profiles'][state['active']]
    palette=profile['colors']
    if any(key not in palette or not HEX.fullmatch(palette[key]) for key in COLOR_KEYS):
        fail('Uma ou mais cores do perfil são inválidas.')
    kittyfile = '# Gerado automaticamente. Edite as cores pelo painel, não aqui.\n' + '\n'.join(f'{key} {palette[key]}' for key in COLOR_KEYS)+'\n'
    write_changed(KITTY_MANAGED,kittyfile)
    kitty_include(True)
    note=set_auto_terminal(False)
    cover=profile.get('cover','')
    if cover and not Path(cover).is_file():
        note='Capa não encontrada; mantenho as cores e uso o Fastfetch sem imagem.'
        cover=''
    write_changed(COVER_FILE,cover+'\n')
    install_fish_cover()
    kitty_reload()
    return note


def status():
    state=load()
    result={'ok':True,'active':state['active'],'desktopMode':state.get('desktopMode',False),
            'profiles':[{'id':pid,**data} for pid,data in state['profiles'].items()],
            'paths':{'profiles':str(STATE),'kitty':str(KITTY),'fish':str(FISH_SCRIPT)}}
    reply(result)


def create(name):
    state=load()
    id_=slug(name)
    if id_ in state['profiles']:
        fail('Já existe um perfil com esse nome.')
    template=state['profiles'][state['active']]
    state['profiles'][id_]={'name':name.strip(),'colors':dict(template['colors']),'cover':template.get('cover','')}
    save(state)
    reply({'ok':True,'id':id_})


def update(id_, raw):
    state=load()
    if id_ not in state['profiles']:
        fail('Perfil não encontrado.')
    data=json.loads(raw)
    if not isinstance(data,dict):
        fail('Payload inválido.')
    original=state['profiles'][id_]
    name=data.get('name',original['name'])
    if not isinstance(name,str) or not name.strip() or len(name)>64:
        fail('Nome inválido (máximo de 64 caracteres).')
    original['name']=name.strip()
    newcolors=data.get('colors',{})
    if not isinstance(newcolors,dict) or any(key not in COLOR_KEYS or not isinstance(value,str) or not HEX.fullmatch(value) for key,value in newcolors.items()):
        fail('Cores inválidas. Use #RRGGBB.')
    original['colors'].update({k:v.upper() for k,v in newcolors.items()})
    if 'cover' in data:
        cover=data['cover']
        if not isinstance(cover,str):
            fail('Caminho da capa inválido.')
        original['cover']=copy_cover(id_,cover) if cover else ''
    state['active']=id_
    state['desktopMode']=False
    save(state)
    warning=apply(state)
    reply({'ok':True,'active':id_,'warning':warning})


def activate(id_):
    state=load()
    if id_ not in state['profiles']:
        fail('Perfil não encontrado.')
    state['active']=id_
    state['desktopMode']=False
    save(state)
    warning=apply(state)
    reply({'ok':True,'active':id_,'warning':warning})


def delete(id_):
    state=load()
    if id_ not in state['profiles']:
        fail('Perfil não encontrado.')
    if len(state['profiles'])==1:
        fail('Não é possível excluir o último perfil.')
    del state['profiles'][id_]
    if state['active']==id_:
        state['active']=next(iter(state['profiles']))
    save(state)
    warning=apply(state)
    reply({'ok':True,'active':state['active'],'warning':warning})



# BEGIN END4_TERMINAL_AUTOSYNC_V1
# IDs explícitos de temas do desktop podem ser associados a perfis do terminal.
# Sem associação, tenta ID/nome igual, SEM copiar cores do Quickshell.
def link_desktop_scheme(desktop_id, terminal_id):
    state = load()
    if terminal_id not in state['profiles']:
        fail('Perfil de terminal inexistente: ' + terminal_id)
    links = state.setdefault('desktopLinks', {})
    links[desktop_id] = terminal_id
    save(state)
    reply({'ok': True, 'desktop': desktop_id, 'terminal': terminal_id})


def unlink_desktop_scheme(desktop_id):
    state = load()
    state.setdefault('desktopLinks', {}).pop(desktop_id, None)
    save(state)
    reply({'ok': True, 'desktop': desktop_id, 'unlinked': True})


def sync_desktop_scheme(desktop_id):
    # Automatic integration is opt-in through the terminal module.
    if not (BASE / 'hyprland-themes-terminal-enabled').is_file():
        reply({'ok': True, 'changed': False, 'reason': 'Módulo terminal não instalado; configuração preservada.'})
        return
    state = load()
    profiles = state['profiles']
    links = state.get('desktopLinks', {})
    # Quando nenhum perfil está associado, somente IDs/nome coincidentes são usados.
    # Temas desconhecidos não modificam o terminal atual.
    terminal_id = links.get(desktop_id)
    if terminal_id is None:
        if desktop_id in profiles:
            terminal_id = desktop_id
        else:
            cleaned = re.sub(r'[^a-z0-9]+', '-', desktop_id.casefold()).strip('-')
            if cleaned in profiles:
                terminal_id = cleaned
            else:
                matches = [pid for pid, data in profiles.items()
                           if re.sub(r'[^a-z0-9]+', '-', data.get('name', '').casefold()).strip('-') == cleaned]
                terminal_id = matches[0] if len(matches) == 1 else None
    if terminal_id not in profiles:
        reply({'ok': True, 'changed': False, 'desktop': desktop_id,
               'reason': 'Sem perfil correspondente; Kitty preservado.'})
        return
    # END4_KITTY_SYNC_REAPPLY_V3:
    # 'active' no JSON não garante que o Kitty ainda exibe esta paleta.
    # Outros recarregamentos podem mudar cores em tempo de execução.
    # Aplique de novo inclusive ao selecionar o perfil já marcado como ativo.
    already_active = state['active'] == terminal_id
    if not already_active:
        state['active'] = terminal_id
        state['desktopMode'] = False
        save(state)
    warning = apply(state)
    reply({'ok': True, 'changed': not already_active,
           'reapplied': already_active, 'active': terminal_id, 'warning': warning})
# END END4_TERMINAL_AUTOSYNC_V1

def main(argv):
    if len(argv)<2 or argv[1] in ('-h','--help','help'):
        print('Uso: terminal_theme_manager.py list | new NOME | save ID JSON | apply ID | delete ID')
        return
    op=argv[1]
    if op=='list' and len(argv)==2: status()
    elif op=='new' and len(argv)==3: create(argv[2])
    elif op=='save' and len(argv)==4: update(argv[2],argv[3])
    elif op=='apply' and len(argv)==3: activate(argv[2])
    elif op=='delete' and len(argv)==3: delete(argv[2])
    elif op=='sync' and len(argv)==3: sync_desktop_scheme(argv[2])
    elif op=='link' and len(argv)==4: link_desktop_scheme(argv[2], argv[3])
    elif op=='unlink' and len(argv)==3: unlink_desktop_scheme(argv[2])
    else: fail('Argumentos inválidos. Execute com --help.')


if __name__=='__main__':
    try:
        main(sys.argv)
    except (OSError, ValueError, json.JSONDecodeError) as e:
        fail(str(e))
