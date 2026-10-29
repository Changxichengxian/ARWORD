"""Extract actual ECDICT corpus POS ratios for existing wordbook entries."""
from pathlib import Path
import argparse,csv,json,hashlib,sys
ROOT=Path(__file__).resolve().parents[1];BASE=ROOT/'assets/wordbooks'
parser=argparse.ArgumentParser();parser.add_argument('--csv',type=Path,required=True);parser.add_argument('--archive',type=Path,required=True);args=parser.parse_args()
wanted=set(json.loads((BASE/'sources/ecdict-selected.json').read_text('utf-8')))
found={};csv.field_size_limit(10**7)
with args.csv.open(encoding='utf-8-sig') as stream:
    for row in csv.DictReader(stream):
        word=row['word'].lower().strip()
        if word in wanted and row.get('pos') and (word not in found or row['word']==word):found[word]={'pos':row['pos']}
(BASE/'sources/ecdict-pos-frequency.json').write_text(json.dumps(found,ensure_ascii=False,indent=2),'utf-8')
metadata={'source':'ECDICT full stardict.csv','url':'https://raw.githubusercontent.com/skywind3000/ECDICT/master/stardict.7z','license':'MIT','archive_sha256':hashlib.sha256(args.archive.read_bytes()).hexdigest(),'csv_sha256':hashlib.sha256(args.csv.read_bytes()).hexdigest(),'selected_count':len(found),'requested_count':len(wanted),'use':'Order available dictionary POS groups by measured corpus proportions; do not change any source wordbook membership.'}
(BASE/'sources/ecdict-pos-source.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2),'utf-8')
print('POS_FREQUENCY_EXTRACTED',len(found),'/',len(wanted))
