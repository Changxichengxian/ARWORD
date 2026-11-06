"""Check editorial gates, examples and reproducible data without changing assets."""
from pathlib import Path
import hashlib,json,subprocess,sys
ROOT=Path(__file__).resolve().parents[1]
def read(path):return json.loads((ROOT/path).read_text('utf-8'))
entries={q['id']:q for q in read('assets/wordbooks/lexicon.json')}
data=read('assets/wordbooks/common-senses.json')
examples=read('assets/word_examples.json')
for word,item in data['entries'].items():
    assert word in entries and item['status']=='reviewed' and item['source'].startswith('https://') and item['reason']
    senses=item['senses'];labels=[s['zh'] for s in senses]
    assert len(senses) in (2,3) and len({s['id'] for s in senses})==len(senses)
    assert len(senses)+len(item['distractors'])==len(set(labels+item['distractors']))==6
    assert all(s['pos'] and s['level'] and s['example'] and s['translation'] for s in senses)
    assert all(len(x)<=18 for x in labels+item['distractors'])
    for s in senses:
        assert any(e['en']==s['example'] and e['zh']==s['translation'] for e in examples[word]),word
assert 'tradition' not in data['entries']
assert '银行' in [s['zh'] for s in data['entries']['bank']['senses']]
assert all(1<=len(v)<=3 and len({p['en'] for p in v})==len(v) for v in examples.values())
assert all(p['en'] and p['zh'] and p['credit'] for pairs in examples.values() for p in pairs)
assert len(examples['tradition'])==3
paths=[ROOT/'assets/wordbooks/lexicon.json',ROOT/'assets/word_examples.json']
before=[hashlib.sha256(p.read_bytes()).hexdigest() for p in paths]
for tool in ['make_wordbooks.py','make_word_examples.py']:
    subprocess.run([sys.executable,str(ROOT/'tools'/tool)],check=True,stdout=subprocess.DEVNULL)
assert before==[hashlib.sha256(p.read_bytes()).hexdigest() for p in paths], 'generation must be deterministic'
print(json.dumps({'multiselect_words':len(data['entries']),'six_choose_two':sum(len(e['senses'])==2 for e in data['entries'].values()),'six_choose_three':sum(len(e['senses'])==3 for e in data['entries'].values()),'words_with_examples':len(examples),'words_with_three_examples':sum(len(v)==3 for v in examples.values()),'rebuild':'identical'}))
