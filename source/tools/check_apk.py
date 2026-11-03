"""Verify a signed Android package against its recorded source input hashes."""
from pathlib import Path
import argparse,json,hashlib,zipfile,subprocess,re
parser=argparse.ArgumentParser();parser.add_argument('--apk',type=Path,required=True);parser.add_argument('--inputs',type=Path,required=True);parser.add_argument('--sdk',type=Path,required=True);parser.add_argument('--out',type=Path,required=True);parser.add_argument('--personal',action='store_true');args=parser.parse_args()
r=Path(__file__).resolve().parents[1];args.out.mkdir(parents=True,exist_ok=True)
inputs=json.loads(args.inputs.read_text('utf-8-sig'))
for item in inputs:assert hashlib.sha256((r/item['path']).read_bytes()).hexdigest()==item['sha256'],item['path']
with zipfile.ZipFile(args.apk) as z:
 assert z.testzip() is None
 names=z.namelist();name_set=set(names)
 assert all('tests/' not in n and 'signing.properties' not in n and not n.endswith(('.keystore','.jks','.html','.blend')) for n in names)
 avatars=[n for n in names if n.lower().endswith('.vrm')]
 assert avatars==(['assets/assets/characters/deepseek.vrm'] if args.personal else []),'Unexpected model in this build flavor'
 if avatars:assert hashlib.sha256(z.read(avatars[0])).hexdigest()=='c14879ff5c42501043896aae03ce971b2c11eee2e76106d47ee98741aa842ff5'
 assert not any(n.startswith('assets/') and ('android-plugin/' in n or n.lower().endswith(('.java','.gradle','.gradle.kts','.class','.aar')) or n.rsplit('/',1)[-1] in ('gradlew','gradlew.bat','gradle.properties','local.properties')) for n in names),'Android build source leaked into assets'
 dex_files=[n for n in names if re.fullmatch(r'classes\d*\.dex',n)]
 assert any(b'Lio/github/changxichengxian/arword/PlanetUpdates;' in z.read(n) for n in dex_files),'Native update plugin missing from DEX'
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
preset=(r/'export_presets.cfg').read_text('utf-8')
code=int(re.search(r'^version/code=(\d+)',preset,re.M)[1])-int(args.personal)
version=re.search(r'^version/name="([^"]+)"',preset,re.M)[1]+('-setup' if args.personal else '')
assert f"package: name='io.github.changxichengxian.arword' versionCode='{code}' versionName='{version}'" in rp.stdout
minimum=re.search(r"^(?:minSdkVersion|sdkVersion):'(\d+)'",rp.stdout,re.M);target=re.search(r"^targetSdkVersion:'(\d+)'",rp.stdout,re.M)
assert minimum and int(minimum.group(1))==24,'APK minimum SDK must be 24'
assert target and int(target.group(1))==35,'APK target SDK must be 35'
permissions=re.findall(r"^uses-permission(?:-sdk-\d+)?: name='([^']+)'",rp.stdout,re.M)
assert set(permissions)=={'android.permission.INTERNET','android.permission.REQUEST_INSTALL_PACKAGES'},permissions
(args.out/'package-check.txt').write_text(rp.stdout,'utf-8')
manifest=subprocess.run([str(build_tools/'aapt2.exe'),'dump','xmltree',str(args.apk),'--file','AndroidManifest.xml'],capture_output=True,text=True,encoding='utf-8');assert manifest.returncode==0
metadata_blocks=re.findall(r'^\s+E: meta-data[^\n]*\n((?:\s+A:.*\n?)+)',manifest.stdout,re.M)
assert any('="org.godotengine.plugin.v2.PlanetUpdates"' in block and '="io.github.changxichengxian.arword.PlanetUpdates"' in block for block in metadata_blocks),'Update plugin registration missing'
assert 'io.github.changxichengxian.arword.updates' in manifest.stdout,'Update file provider is missing'
(args.out/'manifest-check.txt').write_text(manifest.stdout,'utf-8')
subprocess.run([str(build_tools/'zipalign.exe'),'-c','-P','16','4',str(args.apk)],check=True)
report={'sha256':hashlib.sha256(args.apk.read_bytes()).hexdigest(),'bytes':args.apk.stat().st_size,'source_inputs_verified':len(inputs),'zip_crc':True,'alignment_16KB':True,'ABIs':abis,'package':'io.github.changxichengxian.arword','version':version,'version_code':code,'wordbooks':6,'offline_word_recordings':len(lexicon),'wordbook_attribution_included':True,'test_and_signing_files_excluded':True}
report.update({'min_sdk':int(minimum.group(1)),'target_sdk':int(target.group(1)),'permissions':permissions,'native_update_plugin_registered':True,'no_broad_storage_permission':True,'bundled_personal_vrm':args.personal,'android_build_source_excluded':True})
(args.out/'artifact-check.json').write_text(json.dumps(report,indent=2),'utf-8');print(json.dumps(report))
