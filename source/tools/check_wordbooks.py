"""Check source subtraction, compact questions and every offline audio asset."""
from pathlib import Path
import argparse,hashlib,json,sys,collections
import numpy as np
import soundfile as sf
from make_wordbooks import definitions,sense_key,EXCLUDES,REJECTED

ROOT=Path(__file__).resolve().parents[1];BASE=ROOT/'assets/wordbooks'
def read(path):return json.loads(path.read_text('utf-8'))
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--allow-pending-audio',action='store_true');parser.add_argument('--report',type=Path);args=parser.parse_args()
    books=read(BASE/'catalog.json')['books'];rows=read(BASE/'lexicon.json');entries={r['id']:r for r in rows}
    sources=read(BASE/'sources/exam-headwords.json')
    sources['primary']=' '.join(l for l in (BASE/'sources/primary.txt').read_text('utf-8').splitlines() if not l.startswith('#')).split()
    sources['tem8']=(BASE/'sources/tem8.txt').read_text('utf-8').splitlines()
    sources={key:set(w.strip().lower() for w in values if w.strip()) for key,values in sources.items()}
    checks=[];errors=[]
    def check(condition,label):
        checks.append({'check':label,'passed':bool(condition)})
        if not condition:errors.append(label)
    check([b['id'] for b in books]==['primary','junior','senior','cet4','cet6','tem8'],'six explicit source-backed book categories')
    check(len(entries)==len(rows) and all(r['id']==r['word']==r['word'].lower().strip() for r in rows),'shared stable exact normalized headwords')
    union=set()
    for b in books:
        raw=sources[b['id']];excluded=raw&sources[EXCLUDES[b['id']]] if b['id'] in EXCLUDES else set()
        rejected=(raw-excluded)&REJECTED.keys();expected=raw-excluded-rejected
        check(set(b['words'])==expected and len(set(b['words']))==len(b['words']),'exact source subtraction '+b['id'])
        check(b['source_count']==len(raw) and b['excluded_count']==len(excluded) and b['rejected_count']==len(rejected),'auditable counts '+b['id'])
        union|=set(b['words'])
    check(union==set(entries),'catalog and complete shared lexicon agree')
    check(all(0<len(r['zh'])<=24 and r['definition'] for r in rows),'compact meaning and separate complete definition')
    check(all(len(r['options'])==len(set(r['options']))==4 and r['options'][r['correct']]==r['zh'] and all(0<len(s)<=24 for s in r['options']) for r in rows),'four unique compact options and correct-answer alignment')
    check(all(len(r['option_ids'])==4 and r['option_ids'][r['correct']]==r['id'] and all(entries[w]['zh']==r['options'][i] for i,w in enumerate(r['option_ids'])) for r in rows),'every choice has a traceable source word')
    check(all(not any(0xE000<=ord(c)<=0xF8FF for c in r['definition']+r['zh']+''.join(r['options'])) for r in rows),'displayed meanings contain no private-use corrupt characters')
    check(all(r['example']==r['translation']=='' for r in rows),'no fabricated examples or example translations')
    check(all(r['audio']=='wordbooks/audio/'+hashlib.sha256(r['word'].encode()).hexdigest()[:20]+'.mp3' for r in rows),'safe deterministic audio paths')
    check(all((BASE/'licenses'/f).exists() for f in ['ECDICT-LICENSE.txt','OpenEtymology-DATA_LICENSE.md','CC-BY-SA-4.0.txt']),'data source licenses retained')
    raw=read(BASE/'sources/ecdict-selected.json');overrides=read(BASE/'sources/definition-overrides.json')
    review=read(BASE/'sources/reviewed-meanings.json')
    overrides={**review['entries'],**overrides}
    check(all(entries[w]['zh']==d['zh'] and entries[w]['meaning_source']=='reviewed' for w,d in overrides.items() if w in entries),'reviewed main meanings cannot regress to dictionary first sense')
    check(all(entries[w]['meaning_source']=='reviewed' for w in entries if 0<int(raw.get(w,{}).get('frq') or 0)<=review['frequency_rank_limit']),'common words require explicit reviewed main meanings')
    check(entries['tradition']['zh'].startswith('传统') and entries['industry']['zh'].startswith('工业') and entries['kid']['zh'].startswith('小孩') and entries['stock']['zh'].startswith('股票'),'known misleading old first senses stay corrected')
    frequencies=read(BASE/'sources/ecdict-pos-frequency.json')
    check(len(frequencies)>10000 and frequencies['give']['pos']=='v:100' and frequencies['keep']['pos']=='n:1/v:99','real corpus POS evidence covers most entries and exposes noun-first bias')
    check(all(entries[w]['pos']=='动词' for w in ['settle','allow','affect','imagine']),'unreviewed common verbs use the corpus-supported verb group')
    related={}
    for group in read(BASE/'sources/related-distractor-groups.json'):
        for word in group:related.setdefault(word,set()).update(group)
    sets={}
    for word in entries:
        senses=set(definitions(raw[word])[1]) if word in raw else set()
        if word in overrides:senses.add(overrides[word]['zh'])
        sets[word]=senses
    ambiguous=[]
    for row in rows:
        for i,option in enumerate(row['options']):
            if option==row['zh']:continue
            if any(option in sense or sense in option for sense in sets[row['id']]) or sense_key(option) in {sense_key(s) for s in sets[row['id']]} or row['option_ids'][i] in related.get(row['id'],set()):ambiguous.append((row['id'],option))
    check(not ambiguous,'no distractor repeats or contains a recorded target sense')
    audit=read(BASE/'audio-audit.json') if (BASE/'audio-audit.json').exists() else {}
    pronunciation=read(BASE/'sources/pronunciation-overrides.json')
    pending=[];bad=[];durations=[];peaks=[];bytes_total=0;reused=0
    for row in rows:
        word=row['id'];path=ROOT/'assets'/row['audio'];item=audit.get(word)
        if not path.exists() or not item or item.get('phonemes','')!=pronunciation.get(word,{}).get('phonemes',''):pending.append(word);continue
        try:
            samples,rate=sf.read(str(path));seconds=len(samples)/rate;peak=float(np.max(np.abs(samples)))
            valid=item['text']==word and item['voice']=='af_heart' and item['path']==row['audio'] and hashlib.sha256(path.read_bytes()).hexdigest()==item['sha256']
            valid=valid and samples.ndim==1 and rate==24000 and .16<seconds<12 and np.isfinite(samples).all() and .001<peak<1
            if not valid:bad.append(word)
            else:durations.append(seconds);peaks.append(peak);bytes_total+=path.stat().st_size;reused+=not item.get('generated',True)
        except Exception as error:bad.append(word+': '+str(error))
    check(not bad,'all available recordings decode, match text hashes and have valid mono waveforms')
    if not args.allow_pending_audio:
        check(not pending,'every word has a verified offline recording')
        expected={Path(r['audio']).name for r in rows}
        check({p.name for p in (BASE/'audio').glob('*.mp3')}==expected and not list((BASE/'audio').glob('*.wav')),'audio folder contains exactly the wordbook recordings and no temporary WAVs')
    report={'passed':sum(c['passed'] for c in checks),'failed':len(errors),'unique_words':len(rows),'books':{b['id']:len(b['words']) for b in books},'max_meaning_characters':max(len(r['zh']) for r in rows),'max_option_characters':max(len(v) for r in rows for v in r['options']),'recordings_checked':len(durations),'recordings_pending':len(pending),'recordings_reused':reused,'recording_bytes':bytes_total,'total_audio_seconds':round(sum(durations),3),'max_peak':max(peaks,default=0),'bad_audio':bad,'ambiguous_by_dictionary':ambiguous,'checks':checks}
    if args.report:args.report.parent.mkdir(parents=True,exist_ok=True);args.report.write_text(json.dumps(report,ensure_ascii=False,indent=2),'utf-8')
    print(json.dumps({k:v for k,v in report.items() if k!='checks'},ensure_ascii=False,indent=2))
    for error in errors:print('FAIL',error)
    return 1 if errors else 0
if __name__=='__main__':
    sys.stdout.reconfigure(encoding='utf-8');sys.stderr.reconfigure(encoding='utf-8');raise SystemExit(main())
