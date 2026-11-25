#!/usr/bin/env python3
"""Gera, sem salvar, as 21 cores do Kitty a partir da capa escolhida."""
import argparse
import colorsys
import datetime
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

HOME=Path.home()
CONFIG=Path(os.getenv('XDG_CONFIG_HOME',str(HOME/'.config')))
CFG=CONFIG/'illogical-impulse'/'config.json'
SCHEMES=CONFIG/'illogical-impulse'/'schemes'
PROFILES=CONFIG/'illogical-impulse'/'terminal-theme-profiles.json'
HEX=re.compile(r'^#[0-9a-fA-F]{6}$')
ID=re.compile(r'^[a-z0-9_-]+$')

def rgb(hexcolor):
    s=hexcolor.lstrip('#')
    return tuple(int(s[i:i+2],16) for i in (0,2,4))

def hx(val):
    return '#'+''.join(f'{round(max(0,min(255,v))):02X}' for v in val)

def mix(a,b,p):
    if isinstance(a,str): a=rgb(a)
    if isinstance(b,str): b=rgb(b)
    return hx([a[i]*(1-p)+b[i]*p for i in range(3)])

def hsl(h,s,l):
    return hx(tuple(int(round(255*v)) for v in colorsys.hls_to_rgb(h%1,l,max(0,min(1,s)))))

def luminance(c):
    values=[]
    for k in rgb(c):
        x=k/255
        values.append(x/12.92 if x<=0.04045 else ((x+0.055)/1.055)**2.4)
    return 0.2126*values[0]+0.7152*values[1]+0.0722*values[2]

def contrast(a,b):
    u,v=sorted((luminance(a),luminance(b)),reverse=True)
    return (u+0.05)/(v+0.05)

def video_duration(path):
    try:
        cp=subprocess.run(['ffprobe','-v','error','-show_entries','format=duration','-of','default=noprint_wrappers=1:nokey=1',str(path)],
                          check=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=10,text=True)
        return max(0.0,float(cp.stdout.strip()))
    except (OSError,ValueError,subprocess.CalledProcessError,subprocess.TimeoutExpired):
        return 0.0

def pixels_from_frame(path, second=None):
    cmd=['ffmpeg','-nostdin','-hide_banner','-loglevel','error']
    if second is not None:cmd.extend(['-ss',str(round(second,3))])
    cmd.extend(['-i',str(path),'-frames:v','1','-vf','scale=256:144:force_original_aspect_ratio=decrease,pad=256:144:(ow-iw)/2:(oh-ih)/2',
                '-f','rawvideo','-pix_fmt','rgb24','-'])
    try:
        cp=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=25,check=True)
    except (OSError,subprocess.CalledProcessError,subprocess.TimeoutExpired) as e:
        raise RuntimeError('Falha na leitura da imagem/video pelo ffmpeg: '+str(e)) from e
    if len(cp.stdout)!=256*144*3:
        raise RuntimeError(f'Frame inválido (esperado {256*144*3} bytes; recebido {len(cp.stdout)})')
    data=cp.stdout
    # Amostragem 1 a cada 2 pixels para acelerar.
    return [(data[i],data[i+1],data[i+2]) for i in range(0,len(data),6)]

def extract_colors(path):
    path=Path(path).expanduser().resolve()
    if not path.is_file():raise ValueError('Arquivo não encontrado: '+str(path))
    duration=video_duration(path) if path.suffix.lower() in ('.mp4','.mkv','.webm','.mov','.avi') else 0
    positions=[max(.2,duration*p) for p in (0.25,0.5,0.75)] if duration>1 else [None]
    pixels=[]
    for pos in positions:pixels+=pixels_from_frame(path,pos)
    grouped={}
    candidates=[]
    for r,g,b in pixels:
        hh,ll,ss=colorsys.rgb_to_hls(r/255,g/255,b/255)
        if .14<ll<.92 and ss>.15:
            # 24 setores, 3 faixas de luz para preservar azuis, lilases e vermelhos.
            k=(int(hh*24)%24,int(min(2,ll*3)))
            w=min(1.0,(ss*.65+0.35))* (.35+ll) 
            entry=grouped.setdefault(k,[0.,0.,0.,0.])
            entry[0]+=r*w;entry[1]+=g*w;entry[2]+=b*w;entry[3]+=w
        # fundo ignora pixels escuros/claros demais
        if .04<ll<.45:
            candidates.append((r,g,b))
    if not grouped:
        raise ValueError('Não consegui extrair cores suficientes; tente outro frame ou imagem.')
    ranked=sorted(grouped.values(),key=lambda x:x[3],reverse=True)
    unique=[]
    for vals in ranked:
        col=tuple(x/vals[3] for x in vals[:3]);h,l,s=colorsys.rgb_to_hls(*(v/255 for v in col))
        # Evita que três variações quase idênticas de laranja virem a paleta toda.
        if all(min(abs(h-pr[0]),1-abs(h-pr[0]))>.16 for pr in unique):
            unique.append((h,l,s))
        if len(unique)==3:break
    # Tons de apoio derivados da imagem, sem afirmar que eram tons dominantes.
    if len(unique)==1:
        hh,ll,ss=unique[0]
        unique.append(((hh+.22)%1,.48,.30))    # Olive/teal conforme cor dominante.
    if len(unique)==2:
        hh,ll,ss=unique[0]
        unique.append(((hh+.095)%1,.53,.40))   # Destaque adjacente mais quente.
    def tone(a):
        h,l,s=a
        return hsl(h,max(.30,min(.72,s)),max(.48,min(.70,l)))
    p,s,t=[tone(x) for x in unique[:3]]
    # Fundo escuro derivado da temperatura das sombras da imagem.
    if candidates:
        # media dos quartis mais escuros para evitar fundo de tom igual ao personagem.
        candidates=sorted(candidates,key=lambda c: .2126*c[0]+.7152*c[1]+.0722*c[2])
        samples=candidates[:max(1,len(candidates)//3)]
        avg=tuple(sum(x[n] for x in samples)//len(samples) for n in range(3))
    else: avg=rgb(p)
    bg=mix('#101218',avg,.25)
    bg=mix('#0C0E13',bg,.50)
    return p,s,t,bg

def make_scheme(name, primary, secondary, tertiary, bg):
    # Papéis ANSI conservam cores semânticas (vermelho/verde/amarelo etc.),
    # com pequenas misturas da paleta extraída para manter a identidade visual.
    p_h=colorsys.rgb_to_hls(*(v/255 for v in rgb(primary)))[0]
    hues=[0.01,.35,.115,.61,.83,.51]
    base=[hsl(h,.56,.59) for h in hues]
    sem=[mix(col,secondary if i%2 else primary,.14) for i,col in enumerate(base)]
    bright=[mix(c,'#FFFFFF',.23) for c in sem]
    fg=mix('#F4F2F0',primary,.045)
    bg=mix(bg,'#080A0D',.12)
    if contrast(fg,bg)<7:fg='#F8F8F7'
    # ANSI0,1,2,3,4,5,6,7, ANSI8-15
    term=[mix(bg,'#82929A',.13),*sem,mix(fg,bg,.10),mix(bg,fg,.35),*bright,'#FFFFFF']
    dark={
        'surface_dim':mix(bg,'#000000',.17), 'surface':bg,
        'surface_bright':mix(bg,'#FFFFFF',.23),
        'surface_container_lowest':mix(bg,'#000000',.25),
        'surface_container_low':mix(bg,'#FFFFFF',.055),
        'surface_container':mix(bg,'#FFFFFF',.11),
        'surface_container_high':mix(bg,'#FFFFFF',.18),
        'surface_container_highest':mix(bg,'#FFFFFF',.27),
        'on_surface':fg, 'on_surface_variant':mix(fg,bg,.23),
        'outline':mix(bg,fg,.52),'outline_variant':mix(bg,fg,.33),
        'error':sem[0],'on_accent':'#121216',
        'accents':{'principal':primary,'secundaria':secondary,'terciaria':tertiary,
                   'vermelho':sem[0],'verde':sem[1],'amarelo':sem[2],
                   'azul':sem[3],'magenta':sem[4],'ciano':sem[5]},
        'term':term}
    # Produz também modo claro completo para funcionar ao alternar dark/light.
    paper=mix('#FFF9F1',primary,.08)
    darkfg=mix('#12141A',primary,.12)
    light={
        'surface_dim':mix(paper,bg,.17),'surface':paper,
        'surface_bright':mix(paper,'#FFFFFF',.35),
        'surface_container_lowest':'#FFFFFF',
        'surface_container_low':mix(paper,'#FFFFFF',.28),
        'surface_container':mix(paper,bg,.11),
        'surface_container_high':mix(paper,bg,.18),
        'surface_container_highest':mix(paper,bg,.26),
        'on_surface':darkfg,'on_surface_variant':mix(darkfg,paper,.28),
        'outline':mix(darkfg,paper,.45),'outline_variant':mix(darkfg,paper,.70),
        'error':hsl(.02,.63,.42),'on_accent':'#FFFFFF',
        'accents':{'principal':mix(primary,'#000000',.25),
                   'secundaria':mix(secondary,'#000000',.25),
                   'terciaria':mix(tertiary,'#000000',.25),
                   'vermelho':hsl(.02,.57,.43),'verde':hsl(.35,.43,.37),
                   'amarelo':hsl(.12,.60,.39),'azul':hsl(.60,.54,.43),
                   'magenta':hsl(.81,.45,.43),'ciano':hsl(.52,.40,.37)},
        'term':[mix(paper,darkfg,.10),* [mix(c,'#000000',.26) for c in sem],mix(darkfg,paper,.15),
                mix(paper,darkfg,.29),*sem,darkfg]}
    return {'name':name,'defaults':{'primary':'principal','secondary':'secundaria','tertiary':'terciaria'},'dark':dark,'light':light}

def kitty_from_scheme(scheme):
    c=scheme['dark'];term=c['term'];p=c['accents']['principal']
    data={'background':c['surface'],'foreground':c['on_surface'],'cursor':p,
          'selection_background':mix(c['surface'],p,.55),
          'selection_foreground':'#FFFFFF'}
    for i,v in enumerate(term):data[f'color{i}']=v
    return data



def main():
    # Uma saída JSON para o processo QML; nunca escreve arquivos.
    if len(sys.argv) != 2:
        raise ValueError('Informe o caminho da imagem da capa do Fastfetch.')
    path = Path(sys.argv[1]).expanduser()
    if not path.is_file():
        raise ValueError('Capa não encontrada: ' + str(path))
    if path.suffix.lower() not in ('.png', '.jpg', '.jpeg', '.webp'):
        raise ValueError('A capa deve ser PNG, JPG ou WEBP.')
    primary, secondary, tertiary, background = extract_colors(path)
    colors = kitty_from_scheme(make_scheme('Prévia', primary, secondary, tertiary, background))
    print(json.dumps({'ok': True, 'colors': colors,
                      'samples': {'primary': primary, 'secondary': secondary, 'tertiary': tertiary}},
                     ensure_ascii=False))


if __name__ == '__main__':
    try:
        main()
    except (ValueError, RuntimeError, OSError, KeyError, TypeError, json.JSONDecodeError) as error:
        print(json.dumps({'ok': False, 'error': str(error)}, ensure_ascii=False))
        sys.exit(1)
