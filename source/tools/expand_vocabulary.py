"""Frequency-stratified recognition bank. Frequency is NOT a calibrated difficulty scale."""
from pathlib import Path
import csv,json,random,re,argparse
ROOT=Path(__file__).resolve().parents[1]
rng=random.Random(20261014)
parser=argparse.ArgumentParser();parser.add_argument('--ecdict',type=Path);args=parser.parse_args()
source=args.ecdict or ROOT.parents[0]/'research/ecdict.csv'
if not source.exists(): source=ROOT.parents[1]/'research/ecdict.csv'
rows=list(csv.DictReader(source.open(encoding='utf-8-sig')))
bands=[[] for _ in range(8)]
for r in rows:
    word=r['word'];rank=int(r['bnc'] or 0)
    if not re.fullmatch('[a-z]{4,16}',word) or not 1000<=rank<17000:continue
    if any(x in r['translation'] for x in ['人名','地名','姓氏','过去式','过去分词','现在分词','复数','缩写','[网络]']):continue
    lines=r['translation'].replace('\\n','\n').splitlines()
    definitions=[];pos=''
    for line in lines:
        m=re.match(r'^(n\.|a\.|adj\.|adv\.|v\.|vt\.|vi\.)\s*(.+)',line)
        if not m: continue
        meaning=re.split('[,，;；]',m[2])[0].strip()
        if re.search(r'[\[\]()（）=<>]',meaning) or not re.fullmatch('[\u4e00-\u9fff…·]{2,10}',meaning):continue
        if not pos:pos='v' if m[1].startswith('v') else 'a' if m[1] in ('a.','adj.') else m[1]
        definitions.append(meaning)
    if not definitions:continue
    band=min(7,(rank-1000)//2000)
    bands[band].append((word,definitions[0],pos,rank,r['phonetic']))
selected=[]
for i,bank in enumerate(bands):
    rng.shuffle(bank)
    chosen=bank[:150]
    for w,meaning,pos,rank,phonetic in chosen:
        distractors=[x[1] for x in bank if x[2]==pos and x[1]!=meaning and x[0]!=w and x[1] not in meaning and meaning not in x[1]]
        rng.shuffle(distractors);opts=[meaning]
        for x in distractors:
            if x not in opts:opts.append(x)
            if len(opts)==4:break
        if len(opts)<4:continue
        selected.append(dict(id='x_'+w,skill=0,level=min(3,i//2+1),band=i,frequency=rank,word=w,text='',zh=meaning,phonetic=phonetic,prompt='选择最接近的词义',options=opts,correct=0,explain=w+'：'+meaning,signal=-1,audio='audio/x_'+w+'.mp3'))
    print(i,len(bank),len(chosen),[x[0] for x in chosen[:5]])
for q in selected:
    if q['word']=='honda':
        row=next(r for r in rows if r['word']=='subtlety')
        q.update(id='x_subtlety',word='subtlety',zh='微妙之处',phonetic=row['phonetic'],frequency=int(row['bnc']),options=['微妙之处','排水系统','临时住所','公开声明'],explain='subtlety：微妙之处',audio='audio/x_subtlety.mp3')
    if q['word']=='nonconformist':
        q.update(zh='不墨守成规的人',explain='nonconformist：不墨守成规的人')
        q['options'][0]='不墨守成规的人'
(ROOT/'app/src/main/assets/vocabulary-extra.json').write_text(json.dumps(selected,ensure_ascii=False,separators=(',',':')),encoding='utf-8')
manifest=json.loads((ROOT/'tools/audio-manifest.json').read_text(encoding='utf-8'))
manifest=[m for m in manifest if not m['id'].startswith('x_')]
manifest.extend(dict(id=q['id'],path=q['audio'],text=q['word']) for q in selected)
(ROOT/'tools/audio-v2-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
print('Extra words',len(selected),'audio',len(manifest))
