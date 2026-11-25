#!/usr/bin/env python3
"""Create complete end4-pC named color schemes from three chosen colors.
Never overwrite user schemes; validate produced roles and both light/dark modes.
"""
import argparse
import colorsys
import json
import re
import sys
import unicodedata
from pathlib import Path

NAMES = ['red', 'orange', 'yellow', 'green', 'teal', 'cyan', 'blue', 'purple']
SURFACES = [
    'surface_dim','surface','surface_bright','surface_container_lowest',
    'surface_container_low','surface_container','surface_container_high',
    'surface_container_highest','on_surface','on_surface_variant',
    'outline','outline_variant','error','on_accent'
]

def rgb(h):
    return tuple(int(h[i:i+2], 16) / 255 for i in (1,3,5))

def hx(rgb3):
    return '#' + ''.join(f'{round(max(0, min(1, n)) * 255):02x}' for n in rgb3)

def blend(a,b,t):
    return hx(tuple(x*(1-t)+y*t for x,y in zip(rgb(a),rgb(b))))

def shift(col,sat=None,light=None):
    h,l,s=colorsys.rgb_to_hls(*rgb(col))
    if sat is not None: s=sat
    if light is not None: l=light
    return hx(colorsys.hls_to_rgb(h,max(0,min(1,l)),max(0,min(1,s))))

def make_mode(primary,secondary,tertiary,dark):
    base='#15151a' if dark else '#f9f7f5'
    raised='#25252c' if dark else '#ebe7e3'
    text='#f7f5f3' if dark else '#18191d'
    subtext='#cbc8c8' if dark else '#4a4a50'
    accent_light=0.68 if dark else 0.43
    accent_sat=0.72 if dark else 0.68
    anchors=[shift(primary,accent_sat,accent_light), shift(secondary,accent_sat,accent_light), shift(tertiary,accent_sat,accent_light)]
    accents={
      'red': shift('#e05562',light=accent_light),
      'orange': shift('#eb9254',light=accent_light),
      'yellow':shift('#e8c65e',light=accent_light),
      'green':shift('#74c67a',light=accent_light),
      'teal':shift('#6abfb8',light=accent_light),
      'cyan':shift('#70bbdb',light=accent_light),
      'blue':shift('#6c8de8',light=accent_light),
      'purple':shift('#b68be3',light=accent_light),
      'custom_primary':anchors[0],
      'custom_secondary':anchors[1],
      'custom_tertiary':anchors[2],
    }
    mixes=[0.0,0.10,0.23,0.33,0.45,0.60] if dark else [0.0,0.09,0.22,0.35,0.48,0.65]
    panel=[blend(base,raised,t) for t in mixes]
    if dark:
        surfaces={
          'surface_dim':'#101015','surface':panel[1],'surface_bright':blend(raised,text,0.14),
          'surface_container_lowest':'#111116','surface_container_low':panel[1],
          'surface_container':panel[2],'surface_container_high':panel[4],
          'surface_container_highest':blend(raised,text,0.13),
          'on_surface':text,'on_surface_variant':subtext,
          'outline':blend(subtext,base,0.37),'outline_variant':blend(raised,text,0.20),
          'error':'#f49ba0','on_accent':'#15151a'
        }
    else:
        surfaces={
          'surface_dim':blend(base,'#5c5553',0.14),'surface':base,
          'surface_bright':'#ffffff',
          'surface_container_lowest':'#ffffff','surface_container_low':blend(base,raised,0.16),
          'surface_container':blend(base,raised,0.40),
          'surface_container_high':blend(base,raised,0.68),
          'surface_container_highest':raised,
          'on_surface':text,'on_surface_variant':subtext,
          'outline':blend(subtext,base,0.36),'outline_variant':blend(raised,subtext,0.17),
          'error':'#b32635','on_accent':'#ffffff'
        }
    bg=surfaces['surface']
    ansi=[bg,accents['red'],accents['green'],accents['yellow'],accents['blue'],accents['purple'],accents['cyan'],text]
    bright=[surfaces['surface_container_highest'],accents['red'],accents['green'],accents['yellow'],accents['blue'],accents['purple'],accents['teal'],text]
    surfaces['accents']=accents
    surfaces['term']=ansi+bright
    return surfaces

def write_scheme(name,primary,secondary,tertiary,output_dir, builtins_dir=None):
    if not name.strip() or len(name)>70:
        raise ValueError('Nome do tema obrigatório (até 70 caracteres)')
    for c in (primary,secondary,tertiary):
        if not re.fullmatch(r'#[a-fA-F0-9]{6}',c):
            raise ValueError(f'Cor inválida: {c}')
    decomposed=unicodedata.normalize('NFKD', name)
    ascii_name=''.join(c for c in decomposed if not unicodedata.combining(c))
    slug=re.sub(r'[^a-z0-9_-]+','-',ascii_name.lower()).strip('-_')[:48]
    if not slug:
        raise ValueError('Nome sem caracteres utilizáveis para o arquivo')
    if slug.startswith('_'):
        raise ValueError('Nome reservado')
    output_dir.mkdir(parents=True,exist_ok=True)
    # Never overwrite an existing user scheme. Also avoid the built-in same name
    # by checking folder supplied separately by caller if available.
    target=output_dir/f'{slug}.json'
    if builtins_dir and (builtins_dir / (slug + '.json')).exists():
        raise FileExistsError(f'{slug} já é um tema interno do end4-pC. Escolha outro nome.')
    if target.exists() or target.is_symlink():
        raise FileExistsError(f'O tema {slug} já existe. Escolha outro nome.')
    data={
       'name':name.strip(),
       'defaults':{'primary':'custom_primary','secondary':'custom_secondary','tertiary':'custom_tertiary'},
       'dark':make_mode(primary,secondary,tertiary,True),
       'light':make_mode(primary,secondary,tertiary,False)
    }
    for mode in ['dark','light']:
        for key in SURFACES:
            assert re.fullmatch(r'#[0-9a-f]{6}', data[mode][key],re.I),key
        assert len(data[mode]['term'])==16
    # Exclusive creation is atomic with respect to collisions.
    with target.open('x',encoding='utf-8') as fp:
        json.dump(data,fp,indent=2,ensure_ascii=False)
        fp.write('\n')
    return slug


def main():
    a=argparse.ArgumentParser()
    a.add_argument('--name',required=True)
    a.add_argument('--primary',required=True)
    a.add_argument('--secondary',required=True)
    a.add_argument('--tertiary',required=True)
    a.add_argument('--dir',default=str(Path.home()/'.config/illogical-impulse/schemes'))
    a.add_argument('--builtin-dir',default=str(Path(__file__).resolve().parent/'schemes'))
    args=a.parse_args()
    try:
        slug=write_scheme(args.name,args.primary,args.secondary,args.tertiary,Path(args.dir),Path(args.builtin_dir))
        print(slug)
    except (ValueError,OSError) as e:
        print(f'ERRO: {e}',file=sys.stderr)
        return 1
    return 0

if __name__=='__main__':
    sys.exit(main())
