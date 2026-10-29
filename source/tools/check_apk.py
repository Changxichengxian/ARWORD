"""Verify a signed Android package against its recorded source input hashes."""
from pathlib import Path
import argparse,json,hashlib,zipfile,subprocess,re
parser=argparse.ArgumentParser();parser.add_argument('--apk',type=Path,required=True);parser.add_argument('--inputs',type=Path,required=True);parser.add_argument('--sdk',type=Path,required=True);parser.add_argument('--out',type=Path,required=True);args=parser.parse_args()
r=Path(__file__).resolve().parents[1];args.out.mkdir(parents=True,exist_ok=True)
inputs=json.loads(args.inputs.read_text('utf-8-sig'))
for item in inputs:assert hashlib.sha256((r/item['path']).read_bytes()).hexdigest()==item['sha256'],item['path']
with zipfile.ZipFile(args.apk) as z:
 assert z.testzip() is None
 names=z.namelist();name_set=set(names)
 assert all('tests/' not in n and 'signing.properties' not in n and not n.endswith(('.keystore','.jks','.html','.blend')) for n in names)
 abis=[n.split('/')[1] for n in names if n.endswith('/libgodot_android.so')]
 assert set(abis)=={'arm64-v8a','armeabi-v7a','x86_64'}
 catalog=json.loads(z.read('assets/assets/wordbooks/catalog.json'))
 lexicon=json.loads(z.read('assets/assets/wordbooks/lexicon.json'))
 assert len(catalog['books'])==6 and len(lexicon)==10696
 assert z.read('assets/assets/wordbooks/lexicon.json')==(r/'assets/wordbooks/lexicon.json').read_bytes()
 for row in lexicon:
  metadata=z.read('assets/assets/'+row['audio']+'.import').decode('utf-8')
  imported=re.search(r'^path="res://([^\"]+)"',metadata,re.M)
  assert imported and 'assets/'+imported.group(1) in name_set,row['id']
 for attribution in ['SOURCE_NOTES.txt','provenance.json','licenses/ECDICT-LICENSE.txt','licenses/CC-BY-SA-4.0.txt','licenses/OpenEtymology-DATA_LICENSE.md']:
  assert 'assets/assets/wordbooks/'+attribution in name_set,attribution
 assert not any('assets/wordbooks/sources/' in n for n in names)
build_tools=sorted((args.sdk/'build-tools').iterdir(),key=lambda p:tuple(map(int,p.name.split('.'))) if re.fullmatch(r'\d+\.\d+\.\d+',p.name) else (0,))[-1]
rp=subprocess.run([str(build_tools/'aapt2.exe'),'dump','badging',str(args.apk)],capture_output=True,text=True,encoding='utf-8');assert rp.returncode==0
assert "package: name='com.wordfrontier.planet' versionCode='10' versionName='0.10.0'" in rp.stdout
assert 'android.permission.INTERNET' not in rp.stdout
(args.out/'package-check.txt').write_text(rp.stdout,'utf-8')
subprocess.run([str(build_tools/'zipalign.exe'),'-c','-P','16','4',str(args.apk)],check=True)
report={'sha256':hashlib.sha256(args.apk.read_bytes()).hexdigest(),'bytes':args.apk.stat().st_size,'source_inputs_verified':len(inputs),'zip_crc':True,'alignment_16KB':True,'ABIs':abis,'package':'com.wordfrontier.planet','version':'0.10.0','wordbooks':6,'offline_word_recordings':len(lexicon),'wordbook_attribution_included':True,'no_internet_permission':True,'test_and_private_files_excluded':True}
(args.out/'artifact-check.json').write_text(json.dumps(report,indent=2),'utf-8');print(json.dumps(report))
