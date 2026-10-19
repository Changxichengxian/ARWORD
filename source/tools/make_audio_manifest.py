from pathlib import Path
import json
R=Path(__file__).resolve().parents[1]
v=json.loads((R/'assets/vocabulary.json').read_text('utf-8'))
notes=json.loads((R/'assets/missions.json').read_text('utf-8'))
d=json.loads((R/'assets/dictionary.json').read_text('utf-8'))
manifest=[dict(id=q['id'],text=q['word'],path=q['audio']) for q in v]
words={q['word'] for q in v}
for n in notes:
 for mode,key in [('short','short'),('full','text'),('cue','cue')]:
  manifest.append(dict(id=n['id']+'_'+mode,text=n[key],path='audio/'+n['id']+'_'+mode+'.mp3'))
for w in sorted(d):
 if w not in words:manifest.append(dict(id='lookup_'+w,text=w,path='audio/lookup_'+w+'.mp3'))
(R/'tools/audio-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),'utf-8')
print('MANIFEST',len(manifest))
