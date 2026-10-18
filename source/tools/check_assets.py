from pathlib import Path
import json,struct,re,hashlib,subprocess
r=Path(__file__).resolve().parents[1];v=json.loads((r/'assets/vocabulary.json').read_text('utf-8'));letters=json.loads((r/'assets/lessons.json').read_text('utf-8'));dictionary=json.loads((r/'assets/dictionary.json').read_text('utf-8'))
assert len(v)==96 and len({q['id'] for q in v})==96
assert all(len(q['options'])==4 and len(set(q['options']))==4 and q['options'][q['correct']]==q['zh'] and q['phonetic'] for q in v)
needed=set(re.findall(r"[a-z]+(?:'[a-z]+)?",' '.join([q['example'] for q in v]+[l['text']+' '+l['sentence'] for l in letters]).lower()))|{q['word'] for q in v}
assert not needed-dictionary.keys(),needed-dictionary.keys()
manifest=json.loads((r/'tools/audio-manifest.json').read_text('utf-8'));audit=json.loads((r/'tools/voice-audit.json').read_text('utf-8'))
assert len(manifest)==99
for item in manifest:assert hashlib.sha256(item['text'].encode()).hexdigest()==audit[item['id']]['textHash'] and (r/'assets'/item['path']).stat().st_size>1000
assert [m['text'] for m in manifest[-3:]]==[l['text'] for l in letters]
models=[]
for p in (r/'assets/models').glob('*.glb'):
 b=p.read_bytes();magic,version,length=struct.unpack('<4sII',b[:12]);assert magic==b'glTF' and version==2 and length==len(b)
 size=struct.unpack('<I',b[12:16])[0];g=json.loads(b[20:20+size]);models.append({'name':p.stem,'meshes':len(g['meshes']),'bytes':len(b)})
 assert (r/'art-source'/(p.stem+'.blend')).exists()
assert len(models)==11
from fontTools.ttLib import TTFont
codes=set()
for n in ['FrontierSC.ttf','FrontierLatin.ttf']:codes.update(TTFont(r/'assets/fonts'/n).getBestCmap())
chars=''.join(p.read_text('utf-8') for p in [*(r/'scripts').glob('*.gd'),*(r/'assets').glob('*.json')]);missing=set(ord(c) for c in chars if not c.isspace())-codes
assert not missing,[(hex(c),chr(c)) for c in missing]
report={'words':96,'all_words_have_four_unique_choices_and_IPA':True,'lookup_entries':len(dictionary),'all_example_and_letter_word_forms_covered':True,'audio_text_hashes_verified':99,'models':models,'fonts_complete':True}
print(json.dumps(report,ensure_ascii=False,indent=2));print('CONTENT_ASSETS_PASS')
