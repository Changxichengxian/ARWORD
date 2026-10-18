"""Use dictionary primary senses, then select non-overlapping same-POS distractors."""
from pathlib import Path
import json,csv,re,random,sys
root=Path(__file__).resolve().parents[1];assets=root/'assets'
vocab=json.loads((assets/'vocabulary.json').read_text(encoding='utf-8'))
dictionary=json.loads((assets/'dictionary.json').read_text(encoding='utf-8'))
needed=set(dictionary)|{q['word'] for q in vocab}
if len(sys.argv)>1:
    with open(sys.argv[1],encoding='utf-8-sig',newline='') as f:
        for row in csv.DictReader(f):
            w=row.get('word','')
            if w in needed and row.get('translation'):
                dictionary[w]={'meaning':row['translation'].replace('\\n','\n'),'phonetic':row.get('phonetic','')}
overrides={'bird':('n.','鸟'),'ought':('aux.','应该'),'surf':('vi.','冲浪'),'double':('a.','两倍的；双重的'),'coast':('n.','海岸')}
pos_names={'n.':'名词','v.':'动词','vi.':'动词','vt.':'动词','a.':'形容词','adj.':'形容词','adv.':'副词','aux.':'助动词','prep.':'介词','pron.':'代词','conj.':'连词','num.':'数词'}
for q in vocab:
    raw=dictionary[q['word']]['meaning'];first=raw.splitlines()[0]
    match=re.match(r'^([a-z]+\.)\s*(.*)',first)
    pos,gloss=(match.group(1),match.group(2)) if match else ('',first)
    gloss=re.sub(r'\[[^\]]*\]','',gloss).strip()
    pieces=[p.strip() for p in re.split('[,，;；]',gloss) if p.strip()]
    gloss='；'.join(pieces[:2])[:30]
    if q['word'] in overrides:pos,gloss=overrides[q['word']]
    q.update(zh=gloss,pos=pos_names.get(pos,'常用词义'),explain=q['word']+'：'+gloss)
def grams(text):
    # Exclude answers that repeat any sense of the target, including another POS.
    return set(re.findall(r'[\u4e00-\u9fff]{2,}',text))
rng=random.Random(3377)
synonyms=[['捐赠','捐献','捐助','赠送'],['提高','提升','增进'],['减少','削减','降低'],['不久','很快','马上','立即'],['相同','一样','同样'],['说服','劝说'],['呼喊','喊叫','大喊','叫喊'],['暂时','临时','短暂'],['开始','开端','起点'],['结束','终止','停止'],['聪明','明智','聪慧'],['痛苦','苦难','折磨'],['幸福','快乐','愉快'],['拒绝','谢绝','否决'],['允许','许可','准许'],['承认','认可','认同'],['损害','破坏','损伤'],['增长','增加','增大'],['帮助','援助','协助'],['指责','谴责','责备'],['赞扬','称赞','赞美'],['恐惧','害怕','惊恐'],['必须','必要','必需'],['热切','渴望','迫切'],['故意','蓄意','有意']]
def synonymous(a,b):return any(any(s in a for s in group) and any(s in b for s in group) for group in synonyms)
for q in vocab:
    target=dictionary[q['word']]['meaning']
    pool=[p for p in vocab if p['word']!=q['word'] and p['pos']==q['pos'] and abs(p['band']-q['band'])<=2]
    rng.shuffle(pool);choices=[q['zh']]
    for p in pool:
        if p['zh'] in choices:continue
        if synonymous(q['zh'],p['zh']):continue
        if any(g in target for g in grams(p['zh'])):continue
        if any(g in dictionary[p['word']]['meaning'] for g in grams(q['zh'])):continue
        choices.append(p['zh'])
        if len(choices)==4:break
    if len(choices)<4:
        for p in vocab:
            if p['zh'] not in choices and not any(g in target for g in grams(p['zh'])):choices.append(p['zh'])
            if len(choices)==4:break
    q.update(options=choices,correct=0)
    assert q['zh'] and len(choices)==4 and len(set(choices))==4
(assets/'vocabulary.json').write_text(json.dumps(vocab,ensure_ascii=False,indent=2),encoding='utf-8')
(assets/'dictionary.json').write_text(json.dumps(dictionary,ensure_ascii=False,indent=2),encoding='utf-8')
print('Refined',len(vocab),'questions; enriched',len(dictionary),'dictionary entries')
print(json.dumps([{k:q[k] for k in ['word','pos','options']} for q in vocab[:12]],ensure_ascii=False))
