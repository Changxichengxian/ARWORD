"""Build a small offline example index from an attributed Tatoeba TSV snapshot.

Examples illustrate use; corpus matches are NOT evidence of sense frequency.
The selected snapshot is kept so ordinary rebuilds need no network.
"""
import argparse, hashlib, json, re
from collections import defaultdict
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'assets/wordbooks'
SNAPSHOT=BASE/'sources/example-pairs.json'
TOKEN=re.compile(r"[a-z]+(?:[-'][a-z]+)*")

def read(path):return json.loads(path.read_text('utf-8'))
def dump(path,data):path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n','utf-8')
def tokens(text):return set(TOKEN.findall(text.lower().replace('’',"'")))

def choose(candidates):
    result=[];seen=[]
    for item in sorted(candidates,key=lambda p:(abs(len(p['en'].split())-8),len(p['en']),p['en'],p['zh'])):
        words=tokens(item['en'])
        if any(len(words&old)/max(1,len(words|old))>.65 for old in seen):continue
        result.append(item);seen.append(words)
        if len(result)==3:break
    return result

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--tsv',type=Path);args=parser.parse_args()
    entries={q['id']:q for q in read(BASE/'lexicon.json')}
    if args.tsv:
        pairs={}
        for line in args.tsv.read_text('utf-8-sig').splitlines():
            row=line.split('\t')
            if len(row)<2:continue
            en,zh=row[:2];words=tokens(en)
            if not 4<=len(en.split())<=17 or len(zh)>90 or not re.search('[\u4e00-\u9fff]',zh):continue
            if not words&entries.keys():continue
            item={'en':en.strip(),'zh':zh.strip(),'credit':'Tatoeba · CC BY 2.0 FR'}
            if len(row)>2:item['attribution']=row[2]
            pairs.setdefault(en.lower(),item)
        pool=defaultdict(list)
        for pair in pairs.values():
            for w in tokens(pair['en'])&entries.keys():pool[w].append(pair)
        selected={p['en']:p for values in pool.values() for p in choose(values)}
        dump(SNAPSHOT,{'source':'Tatoeba / ManyThings English–Mandarin pairs',
            'mirror':'https://github.com/mc6666/MyNeuralNetwork/blob/ae8c862c3192eaa7bfcd609405a8dc015c14308e/cmn-eng/cmn.txt',
            'input_sha256':hashlib.sha256(args.tsv.read_bytes()).hexdigest(),
            'license':'https://creativecommons.org/licenses/by/2.0/fr/',
            'attribution_guide':'https://en.wiki.tatoeba.org/articles/show/faq',
            'changes':'Selected short distinct pairs; text retained. Legacy mirror does not supply individual author names.',
            'pairs':sorted(selected.values(),key=lambda p:p['en'])})
    pool=defaultdict(list)
    for pair in read(SNAPSHOT)['pairs']:
        for w in tokens(pair['en'])&entries.keys():pool[w].append(pair)
    result={w:choose(values) for w,values in sorted(pool.items())}
    # Authored examples come first, never crowding out sense-specific reviewed examples.
    for q in read(ROOT/'assets/vocabulary.json'):
        if q.get('example') and q.get('translation'):
            result[q['id']]=([{'en':q['example'],'zh':q['translation'],'credit':'ARWORD 原创例句'}]+result.get(q['id'],[]))[:3]
    result.update(read(BASE/'sources/example-overrides.json'))
    dump(ROOT/'assets/word_examples.json',dict(sorted(result.items())))
    print(json.dumps({'words_with_examples':len(result),'words_with_three':sum(len(v)==3 for v in result.values()),'example_slots':sum(map(len,result.values())),'bytes':(ROOT/'assets/word_examples.json').stat().st_size}))

if __name__=='__main__':main()
