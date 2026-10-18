from pathlib import Path
from PIL import Image
import argparse

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--source',type=Path,default=ROOT/'art-source');args=parser.parse_args()
SRC=args.source
OUT=ROOT/'app/src/main/assets/art'
OUT.mkdir(exist_ok=True)
Image.open(SRC/'exec-eaa56f8c-2cbd-47f6-8cdf-9f02b18c4146.png').convert('RGB').save(OUT/'valley.webp',quality=92)
for source,names in [('exec-619977f8-a276-4b98-a386-0635065005e8.png',['garden','workshop','bridge','hall']),('exec-05136812-d0a4-4294-ad2b-6ab2a333924c.png',['ranger','fox','guardian','raven'])]:
    im=Image.open(SRC/source).convert('RGBA')
    assert im.getextrema()[3][0]==0, 'Real transparency is required'
    w,h=im.size
    for i,name in enumerate(names):
        tile=im.crop(((i%2)*w//2,(i//2)*h//2,(i%2+1)*w//2,(i//2+1)*h//2))
        box=tile.getbbox()
        tile=tile.crop(box)
        tile.thumbnail((640,640),Image.Resampling.LANCZOS)
        tile.save(OUT/(name+'.webp'),lossless=True)
im=Image.open(SRC/'exec-fb2e6426-9707-440d-a252-b335979d3e18.png').convert('RGBA');w,h=im.size
for i in range(3):
    tile=im.crop((i*w//3,0,(i+1)*w//3,h));tile=tile.crop(tile.getbbox());tile.thumbnail((640,640),Image.Resampling.LANCZOS);tile.save(OUT/f'garden-{i}.webp',lossless=True)
icon=Image.open(OUT/'ranger.webp').convert('RGBA');iw,ih=icon.size
icon=icon.crop((0,0,iw,int(ih*.61)));icon.thumbnail((432,432),Image.Resampling.LANCZOS)
canvas=Image.new('RGBA',(512,512),(37,150,190,255));canvas.alpha_composite(icon,((512-icon.width)//2,(512-icon.height)//2))
dest=ROOT/'app/src/main/res/drawable-nodpi';dest.mkdir(exist_ok=True);canvas.convert('RGB').save(dest/'launcher_ranger.png')
print('Art prepared:',len(list(OUT.glob('*.webp'))))
