from pathlib import Path
import csv,json,re,argparse
R=Path(__file__).resolve().parents[1];parser=argparse.ArgumentParser();parser.add_argument('ecdict',type=Path);csvpath=parser.parse_args().ecdict
v=json.loads((R/'assets/vocabulary.json').read_text(encoding='utf-8'));lessons=json.loads((R/'assets/lessons.json').read_text(encoding='utf-8'))
needed=set(re.findall(r"[a-z]+(?:'[a-z]+)?",' '.join([q['example'] for q in v]+[l['text']+' '+l['sentence'] for l in lessons]).lower()))|{q['word'] for q in v}
found={}
with csvpath.open(encoding='utf-8') as f:
    for row in csv.DictReader(f):
        w=row['word'].lower()
        if w in needed and w not in found:found[w]={'phonetic':row.get('phonetic',''),'translation':row.get('translation','').replace('\\n','\n')}
for q in v:
    q['phonetic']=found.get(q['word'],{}).get('phonetic','') or q.get('phonetic','')
    found[q['word']]={'phonetic':q['phonetic'],'translation':q['pos']+' '+q['zh']}
for w,meaning in {'the':'定冠词，指特定或双方已知的人、事物','a':'不定冠词，一个；一种','to':'表示方向、对象，或用于动词不定式','its':'它的','wood':'木材；木头','water':'水','before':'在……之前','rather':'相当；宁可；rather than：而不是','us':'我们（宾格）'}.items():
    found.setdefault(w,{'phonetic':''});found[w]['translation']=meaning
(R/'assets/dictionary.json').write_text(json.dumps(found,ensure_ascii=False,indent=2),encoding='utf-8')
(R/'assets/vocabulary.json').write_text(json.dumps(v,ensure_ascii=False,indent=2),encoding='utf-8')
print('DICTIONARY',len(found),'IPA',sum(bool(q['phonetic']) for q in v),'/',len(v),'missing word forms',sorted(needed-found.keys()))
