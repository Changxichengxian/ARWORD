from pathlib import Path
import argparse, json, sqlite3, re, subprocess, statistics, collections, os
parser=argparse.ArgumentParser()
parser.add_argument('--ffmpeg', default=os.environ.get('FFMPEG','ffmpeg'))
parser.add_argument('--skip-audio', action='store_true', help='Only check text and dictionary; does not validate audio')
args=parser.parse_args()
ROOT=Path(__file__).resolve().parents[1]
assets=ROOT/'app/src/main/assets';data=json.loads((assets/'content.json').read_text(encoding='utf-8'))
items=data['questions']+data['stories']+data.get('visits',[]);ids=set();errors=[];durations={}
manifest=json.loads((ROOT/'tools/audio-manifest.json').read_text(encoding='utf-8'))
audio_manifest={entry['id']:entry for entry in manifest}
if len(audio_manifest)!=len(manifest):errors.append('duplicate audio manifest id')
for q in items:
    if q['id'] in ids:errors.append('duplicate id '+q['id'])
    ids.add(q['id'])
    if not 0<=q['level']<=3:errors.append('level '+q['id'])
    if q['skill']==3:
        if collections.Counter(q['tokens'])!=collections.Counter(q['text'].split()):errors.append('token set '+q['id'])
        normal=lambda t:re.sub(r"[^a-z0-9' ]","",t.lower()).split()
        for alternative in q.get('alternatives',[]):
            if collections.Counter(normal(alternative))!=collections.Counter(normal(q['text'])):errors.append('alternate token set '+q['id'])
    else:
        if len(q['options'])!=len(set(q['options'])):errors.append('duplicate choices '+q['id'])
        if 'event' not in q and not 0<=q['correct']<len(q['options']):errors.append('answer index '+q['id'])
    if '\ufffd' in json.dumps(q,ensure_ascii=False):errors.append('broken encoding '+q['id'])
    if q.get('audio'):
        expected=(q['word']+'. ' if q.get('word') else '')+q['text']
        entry=audio_manifest.get(q['id'],{})
        if entry.get('text')!=expected or entry.get('path')!=q['audio']:errors.append('audio manifest mismatch '+q['id'])
    if q.get('audio') and not args.skip_audio:
        path=assets/q['audio']
        if not path.exists():errors.append('missing audio '+q['id']);continue
        run=subprocess.run([args.ffmpeg,'-hide_banner','-i',str(path),'-af','volumedetect','-f','null','-'],capture_output=True,text=True,encoding='utf-8',errors='replace')
        duration=re.search(r'Duration: (\d+):(\d+):(\d+\.\d+)',run.stderr)
        volume=re.search(r'mean_volume: ([\d.\-]+) dB',run.stderr)
        if not duration or not volume or run.returncode:errors.append('unreadable audio '+q['id']);continue
        h,m,s=map(float,duration.groups());seconds=h*3600+m*60+s;durations[q['id']]=round(seconds,2)
        if seconds<1 or float(volume.group(1))<-45:errors.append('short/silent audio '+q['id'])
db=sqlite3.connect(assets/'dictionary.db')
integrity=db.execute('PRAGMA integrity_check').fetchone()[0]
if integrity!='ok':errors.append('dictionary integrity '+integrity)
vocabulary=set(re.findall(r"[a-z]+(?:[-'][a-z]+)?",' '.join(q['text'].lower() for q in items)))
missing=[]
for w in sorted(vocabulary):
    if not db.execute('SELECT 1 FROM words WHERE word=?',(w,)).fetchone():missing.append(w)
summary={'exercise_counts':dict(collections.Counter(q['skill'] for q in data['questions'])),'story_versions':len(data['stories']),'ids_unique':len(ids)==len(items),'dictionary_count':db.execute('SELECT COUNT(*) FROM words').fetchone()[0],'dictionary_integrity':integrity,'reading_words_by_band':{str(level):{'min':min(len(q['text'].split()) for q in data['questions'] if q['skill']==1 and q['level']==level),'max':max(len(q['text'].split()) for q in data['questions'] if q['skill']==1 and q['level']==level)} for level in range(4)},'audio_files':len(durations),'audio_total_seconds':round(sum(durations.values()),1),'audio_durations':durations,'dictionary_missing_in_content':missing,'errors':errors}
qa=ROOT.parent/'qa';qa.mkdir(exist_ok=True);(qa/'content-audit.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in summary.items() if k!='audio_durations'},ensure_ascii=True))
if errors:raise SystemExit(1)
