"""Check source assets and regenerated speech against the playable content."""
from pathlib import Path
import json,struct,re,hashlib
r=Path(__file__).resolve().parents[1]
v=json.loads((r/'assets/vocabulary.json').read_text('utf-8'))
notes=[entry for name in ['missions','frontier_missions','reader_missions'] for entry in json.loads((r/'assets'/f'{name}.json').read_text('utf-8'))]
dictionary=json.loads((r/'assets/dictionary.json').read_text('utf-8'))
assert len(v)==96 and len({q['id'] for q in v})==96
assert all(len(q['options'])==4 and len(set(q['options']))==4 and q['options'][q['correct']]==q['zh'] for q in v)
assert len(notes)==34 and len({n['id'] for n in notes})==len(notes)
ids={q['id'] for q in v}
for n in notes:
 assert len(n['options'])==3 and len(set(n['options']))==3 and 0<=n['correct']<3
 assert len(n['cue_options'])==3 and len(set(n['cue_options']))==3 and 0<=n['cue_correct']<3
 if n['id'].startswith('read'):
  assert n['band'] in range(4) and n['topic'] and n['text'].startswith(n['short'])
 else: assert len(n['focus'])==4 and set(n['focus'])<=ids
 assert 24<=len(n['short'].split())<=50 and len(n['text'].split())>len(n['short'].split())
 assert all(n[k] for k in ['zh','question','sentence_zh','cue'])
content=' '.join([q['example'] for q in v]+[n[k] for n in notes for k in ['short','text','cue','sentence']])
needed=set(re.findall(r"[a-z]+(?:'[a-z]+)?",content.lower()))|ids
assert not needed-dictionary.keys(),needed-dictionary.keys()
manifest=json.loads((r/'tools/audio-manifest.json').read_text('utf-8'))
audit=json.loads((r/'tools/voice-audit.json').read_text('utf-8'))
assert len(manifest)>607 and len({m['id'] for m in manifest})==len(manifest)
paths={m['path'] for m in manifest}
for item in manifest:
 assert hashlib.sha256(item['text'].encode()).hexdigest()==audit[item['id']]['textHash'],item['id']
 assert (r/'assets'/item['path']).stat().st_size>1000,item['id']
for word in needed:
 path=next((q['audio'] for q in v if q['id']==word),'audio/lookup_'+word+'.mp3')
 assert path in paths,path
for n in notes:
 for suffix,key in [('short','short'),('full','text'),('cue','cue')]:
  item=next(m for m in manifest if m['path']=='audio/'+n['id']+'_'+suffix+'.mp3')
  assert item['text']==n[key]
models=[]
for p in (r/'assets/models').glob('*.glb'):
 b=p.read_bytes();magic,version,length=struct.unpack('<4sII',b[:12]);assert magic==b'glTF' and version==2 and length==len(b)
 size=struct.unpack('<I',b[12:16])[0];g=json.loads(b[20:20+size]);models.append({'name':p.stem,'meshes':len(g['meshes']),'bytes':len(b)})
 assert (r/'art-source'/(p.stem+'.blend')).exists()
 if p.stem=='builder':assert {'ArmL','ArmR','LegL','LegR','Body'}<={n['name'] for n in g['nodes']}
assert len(models)==89 and {'wild_orca','wild_seal','wild_crab','wild_jelly','tidal_ledge','wild_rabbit','wild_dolphin','wild_seahorse','wild_puffer','wild_squid'}<={m['name'] for m in models}
from fontTools.ttLib import TTFont
codes=set()
for name in ['FrontierSC.ttf','FrontierLatin.ttf']:codes.update(TTFont(r/'assets/fonts'/name).getBestCmap())
runtime_json=[*(r/'assets').glob('*.json'),r/'assets/wordbooks/lexicon.json',r/'assets/wordbooks/catalog.json']
chars=''.join(p.read_text('utf-8-sig') for p in [*(r/'scripts').glob('*.gd'),*(r/'android-plugin').rglob('*.java'),*runtime_json] if p.exists())
missing=set(ord(c) for c in chars if not c.isspace())-codes
assert not missing,[(hex(c),chr(c)) for c in missing]
report={'words':96,'unique_meaning_choices':True,'work_notes':len(notes),'short_and_expanded_readings':len(notes)*2,'listening_instructions':len(notes),'sentence_tasks':len(notes),'lookup_entries':len(dictionary),'every_content_word_has_lookup_and_audio':True,'audio_text_hashes_verified':len(manifest),'models':models,'fonts_complete':True}
print(json.dumps(report,ensure_ascii=False,indent=2));print('CONTENT_ASSETS_PASS')
