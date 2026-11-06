"""Reproducible offline wordbooks: exact headword subtraction, shared entries and audio."""
from pathlib import Path
import argparse,csv,hashlib,json,re,shutil,sys,random
ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'assets/wordbooks'
TAGS={'zk':'junior','gk':'senior','cet4':'cet4','cet6':'cet6'}
EXCLUDES={'senior':'primary','cet4':'junior','cet6':'senior','tem8':'cet4'}
TITLES={'primary':'小学','junior':'初中','senior':'高中','cet4':'四级','cet6':'六级','tem8':'专八'}
BANDS={'primary':0,'junior':0,'senior':1,'cet4':2,'cet6':2,'tem8':3}
POS_NAMES={'n':'名词','a':'形容词','adj':'形容词','adv':'副词','v':'动词','vt':'动词','vi':'动词','prep':'介词','pron':'代词','conj':'连词','num':'数词','interj':'感叹词','int':'感叹词','aux':'助动词','art':'冠词','det':'限定词','pl':'名词','abbr':'缩写'}
REJECTED={'gonorrh':'原表词头疑似截断，未作为完整英语词条收录。','premi':'原表词头疑似截断，未作为完整英语词条收录。'}

def canonical(word):return word.strip().lower()
def dump(path,data):path.write_text(json.dumps(data,ensure_ascii=False,indent=2),'utf-8')
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def clean_definition(text):
    lines=[]
    for line in text.replace('\\n','\n').splitlines():
        if any(0xE000<=ord(c)<=0xF8FF for c in line):
            parts=re.split('[,，;；]',line)
            line='，'.join(p for p in parts if not any(0xE000<=ord(c)<=0xF8FF for c in p))
        if line.strip():lines.append(line)
    return '\n'.join(lines)

def sense_key(text):
    text=re.sub(r'\([^)]*\)|（[^）]*）','',text)
    text=re.sub(r'[^\u4e00-\u9fff]','',text)
    for a,b in [('上方','上'),('上面','上'),('下方','下'),('下面','下'),('之后','后'),('以后','后'),('之前','前'),('以前','前'),('之上','上'),('之下','下')]:text=text.replace(a,b)
    return text.strip('在于自从的地')

def ordered_dictionary_row(row,frequency):
    weights={tag.split(':')[0]:float(tag.split(':')[1]) for tag in frequency.get('pos','').split('/') if ':' in tag}
    codes={'n':['n'],'pl':['n'],'v':['v'],'vt':['v'],'vi':['v'],'a':['j','d'],'adj':['j','d'],'adv':['r'],'prep':['i'],'pron':['p','d'],'num':['m'],'conj':['c'],'det':['d'],'art':['a'],'int':['u'],'interj':['u'],'aux':['v']}
    lines=clean_definition(row['translation']).splitlines()
    def score(item):
        index,line=item;m=re.match(r'^([a-z]+)\.',line)
        keys=codes.get(m[1],[]) if m else []
        return (-max((weights.get(k,0) for k in keys),default=-1),index)
    ordered=[line for _,line in sorted(enumerate(lines),key=score)] if weights else lines
    return dict(row,translation='\n'.join(ordered))

def definitions(row):
    result=[];pos=''
    for line in row['translation'].replace('\\n','\n').splitlines():
        match=re.match(r'^((?:[a-z]+\.)+)\s*(.*)',line.strip())
        if match:
            first_pos=match[1].split('.')[0]
            if not pos:pos=POS_NAMES.get(first_pos,first_pos+'.')
            text=match[2]
        else:text=line.strip()
        text=re.sub(r'\[[^\]]*\]|<[^>]*>|\(=[^)]*\)','',text).strip().replace('...','…')
        text=re.sub(r'^(?:[a-z]+\.)+','',text).strip()
        for part in re.split('[,，;；]',text):
            part=part.strip(' .；;,')
            if not part or part in {'的','地','得','和','与'} or not re.search('[\u4e00-\u9fff]',part):continue
            if part not in result:result.append(part)
    return pos,result

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--ecdict',type=Path);parser.add_argument('--tem8',type=Path);parser.add_argument('--research',type=Path)
    args=parser.parse_args();(BASE/'sources').mkdir(parents=True,exist_ok=True);(BASE/'licenses').mkdir(exist_ok=True)
    primary=set(' '.join(l for l in (BASE/'sources/primary.txt').read_text('utf-8').splitlines() if not l.startswith('#')).split())
    if args.tem8:shutil.copyfile(args.tem8,BASE/'sources/tem8.txt')
    tem8={canonical(w) for w in (BASE/'sources/tem8.txt').read_text('utf-8-sig').splitlines() if w.strip()}
    raw={'primary':primary,'junior':set(),'senior':set(),'cet4':set(),'cet6':set(),'tem8':tem8}
    rows={}
    if args.ecdict:
        with args.ecdict.open(encoding='utf-8-sig') as f:
            for row in csv.DictReader(f):
                word=canonical(row['word']);tags=row.get('tag','').split()
                if word in primary or word in tem8 or any(tag in TAGS for tag in tags):
                    if word not in rows or row['word']==word:
                        rows[word]={k:row.get(k,'') for k in ['word','translation','pos','phonetic','tag','bnc','frq','definition']}
                for tag in tags:
                    if tag in TAGS:raw[TAGS[tag]].add(word)
        dump(BASE/'sources/ecdict-selected.json',rows)
        dump(BASE/'sources/exam-headwords.json',{k:sorted(raw[k]) for k in TAGS.values()})
    else:
        rows=json.loads((BASE/'sources/ecdict-selected.json').read_text('utf-8'))
        for book,words in json.loads((BASE/'sources/exam-headwords.json').read_text('utf-8')).items():raw[book]=set(words)
    overrides=json.loads((BASE/'sources/definition-overrides.json').read_text('utf-8'))
    review=json.loads((BASE/'sources/reviewed-meanings.json').read_text('utf-8'))
    reviewed=review['entries']
    primary={**reviewed,**overrides}
    pronunciation=json.loads((BASE/'sources/pronunciation-overrides.json').read_text('utf-8'))
    frequencies=json.loads((BASE/'sources/ecdict-pos-frequency.json').read_text('utf-8'))
    related={}
    for group in json.loads((BASE/'sources/related-distractor-groups.json').read_text('utf-8')):
        for word in group:related.setdefault(word,set()).update(group)
    books=[];unique=set();word_bands={}
    for book,words in raw.items():
        excluded=words&raw[EXCLUDES[book]] if book in EXCLUDES else set()
        rejected=(words-excluded)&REJECTED.keys()
        selected=words-excluded-rejected;unique|=selected
        # Order is frequent-to-less-frequent inside each source; this does not add words.
        def order(w):
            row=rows.get(w,{});ranks=[int(row[k]) for k in ['bnc','frq'] if str(row.get(k,'')).isdigit() and int(row[k])>0]
            return (min(ranks) if ranks else 999999,w)
        ordered=sorted(selected,key=order)
        books.append({'id':book,'title':TITLES[book],'source_count':len(words),'excluded_count':len(excluded),'excluded_book':EXCLUDES.get(book,''),'rejected_count':len(rejected),'words':ordered})
        for word in selected:word_bands[word]=min(word_bands.get(word,3),BANDS[book])
    entries=[];meaning_sets={};issues=[]
    for word in sorted(unique):
        row=rows.get(word,{})
        ordered=ordered_dictionary_row(row,frequencies.get(word,{})) if row else {}
        pos,meanings=definitions(ordered) if row else ('',[])
        if word in primary:
            override=primary[word];pos=override['pos'];zh=override['zh']
            meanings=list(dict.fromkeys([zh]+meanings))
        else:
            rank=int(row.get('frq') or 0)
            if 0<rank<=review['frequency_rank_limit']:
                raise ValueError('Common word needs an explicit reviewed main meaning: '+word)
            # Prefer a concise general sense over specialist dictionary annotations.
            candidates=[m for m in meanings if len(m)<=30 and not re.search(r'[=<>\[\]]|人名|姓氏|地名|音译',m)]
            zh=candidates[0] if candidates else (meanings[0] if meanings else '')
        if not zh:raise ValueError('No validated definition for '+word)
        if len(zh)>24 or re.search(r'[=<>\[\]]',zh):issues.append({'word':word,'zh':zh,'translation':row.get('translation','')})
        meaning_sets[word]=set(meanings)
        # A reviewed short answer must not erase the remaining dictionary senses.
        full_definition=clean_definition(row.get('translation','')) or zh
        if word in primary:
            full_definition=primary[word].get('definition',full_definition)
        entries.append({'id':word,'word':word,'zh':zh,'definition':full_definition,'pos':pos or '词语','band':word_bands[word],'audio':'wordbooks/audio/'+hashlib.sha256(word.encode()).hexdigest()[:20]+'.mp3','options':[],'correct':0,'example':'','translation':'','phonetic':row.get('phonetic','')})
        if word in pronunciation:entries[-1]['phonetic']=pronunciation[word]['phonetic']
        entries[-1]['meaning_source']='reviewed' if word in primary else 'dictionary'
    by_pos={}
    for entry in entries:by_pos.setdefault(entry['pos'],[]).append(entry)
    for entry in entries:
        rng=random.Random(int(hashlib.sha256(entry['id'].encode()).hexdigest()[:16],16))
        pool=[e for e in by_pos[entry['pos']] if e['band']==entry['band']]
        if len(pool)<12:pool=[e for e in entries if e['band']==entry['band']]
        rng.shuffle(pool);options=[entry['zh']];option_words={entry['zh']:entry['id']}
        for candidate in pool:
            if candidate['id']==entry['id'] or candidate['zh'] in options:continue
            if candidate['id'] in related.get(entry['id'],set()):continue
            # Reject identical/contained Chinese senses in either entry's full dictionary.
            senses=meaning_sets[entry['id']];other=meaning_sets[candidate['id']]
            if senses&other:continue
            normalized={sense_key(m) for m in senses if sense_key(m)}
            if sense_key(candidate['zh']) in normalized:continue
            if sense_key(entry['zh']) in {sense_key(m) for m in other if sense_key(m)}:continue
            if any(candidate['zh'] in m or m in candidate['zh'] for m in senses):continue
            if any(entry['zh'] in m or m in entry['zh'] for m in other):continue
            if len(candidate['zh'])>24:continue
            if candidate['id'] in entry['id'] or entry['id'] in candidate['id']:continue
            options.append(candidate['zh'])
            option_words[candidate['zh']]=candidate['id']
            if len(options)==4:break
        if len(options)!=4:raise ValueError('Insufficient distinct distractors for '+entry['id']+' '+repr(meaning_sets[entry['id']])+' '+str(len(pool)))
        rng.shuffle(options);entry['options']=options;entry['option_ids']=[option_words[option] for option in options];entry['correct']=options.index(entry['zh'])
    dump(BASE/'catalog.json',{'version':1,'books':books});dump(BASE/'lexicon.json',entries)
    dump(BASE/'sources/rejected.json',REJECTED);dump(BASE/'content-review.json',issues)
    if args.research:
        for name in ['ECDICT-LICENSE.txt','OpenEtymology-DATA_LICENSE.md','CC-BY-SA-4.0.txt']:
            shutil.copyfile(args.research/name,BASE/'licenses'/name)
    provenance={'version':1,'normalization':'lowercase and trim only; no stemming or lemmatization','subtraction':'compare against original lower-stage source lists, not already-filtered lists','dictionary':{'name':'ECDICT','url':'https://github.com/skywind3000/ECDICT','license':'MIT','sha256':sha(args.ecdict) if args.ecdict else ''},'primary':{'name':'Little Tide elementary foundation','scope':'Independently selected basic reference vocabulary; not an official syllabus or textbook transcription','license':'CC0-1.0','sha256':sha(BASE/'sources/primary.txt')},'tem8':{'name':'OpenEtymology TEM8','scope':'3984-headword reference wordbook, not a claim of complete official TEM8 coverage','url':'https://github.com/openetymology/OpenEtymology/blob/main/TEM8/TEM8.txt','license':'CC-BY-SA-4.0','sha256':sha(BASE/'sources/tem8.txt')},'changes':['Extracted headwords only from OpenEtymology; no examples or etymology copied.','Applied requested two-stage subtraction and documented malformed-headword exclusions.','ECDICT Chinese meanings shortened; common basic meanings reviewed in definition-overrides.json.','Created deterministic four-choice exercises; generated local af_heart English speech.'],'dataset_license':'CC-BY-SA-4.0; preserve ECDICT MIT notice and original source notices'}
    old_path=BASE/'provenance.json'
    provenance['pos_frequency']=json.loads((BASE/'sources/ecdict-pos-source.json').read_text('utf-8'))
    provenance['meaning_selection']='Reviewed compact meaning first; otherwise prefer dictionary POS groups with the highest observed ECDICT corpus proportion. Fall back to dictionary order only where corpus POS evidence is absent.'
    provenance['removed_unreadable_aliases']={'rabid':'Removed only the medical alias containing private-use U+E7B3.','rabies':'Removed only the medical alias containing private-use U+E7B3.'}
    provenance['pronunciation_corrections']=json.loads((BASE/'sources/pronunciation-overrides.json').read_text('utf-8'))
    if not args.ecdict and old_path.exists():provenance['dictionary']['sha256']=json.loads(old_path.read_text('utf-8'))['dictionary']['sha256']
    dump(old_path,provenance)
    print(json.dumps({'unique_words':len(entries),'books':[{k:v for k,v in b.items() if k!='words'} for b in books],'review_count':len(issues)},ensure_ascii=False,indent=2))

if __name__=='__main__':
    sys.stdout.reconfigure(encoding='utf-8');sys.stderr.reconfigure(encoding='utf-8');main()
