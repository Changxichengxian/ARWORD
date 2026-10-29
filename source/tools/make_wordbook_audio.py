"""Generate reusable local word recordings with Kokoro; never call an online voice API."""
from pathlib import Path
import argparse,concurrent.futures,hashlib,json,os,shutil,subprocess,time,sys
import numpy as np
import soundfile as sf
import onnxruntime as ort
from kokoro_onnx import Kokoro

ROOT=Path(__file__).resolve().parents[1]
VOICE='af_heart'
SPEED=.94
TTS=None
FFMPEG=None
PRONUNCIATION=json.loads((ROOT/'assets/wordbooks/sources/pronunciation-overrides.json').read_text('utf-8'))

def key(word):
    return hashlib.sha256(word.encode('utf-8')).hexdigest()[:20]

def save_audit(path,audit):
    temporary=path.with_suffix('.json.tmp')
    temporary.write_text(json.dumps(audit,ensure_ascii=False,indent=2),'utf-8')
    temporary.replace(path)

def initialize(models,ffmpeg,threads):
    global TTS,FFMPEG
    options=ort.SessionOptions();options.intra_op_num_threads=threads;options.inter_op_num_threads=1
    TTS=Kokoro.from_session(ort.InferenceSession(str(Path(models)/'kokoro-v1.0.onnx'),sess_options=options,providers=['CPUExecutionProvider']),str(Path(models)/'voices-v1.0.bin'))
    FFMPEG=ffmpeg

def generate(job):
    word,directory=job;destination=Path(directory)/(key(word)+'.mp3');tmp=destination.with_suffix('.wav')
    began=time.monotonic()
    phonemes=PRONUNCIATION.get(word,{}).get('phonemes','')
    samples,rate=TTS.create(phonemes or word,voice=VOICE,speed=SPEED,lang='en-us',is_phonemes=bool(phonemes))
    if len(samples)<rate*.16 or not np.isfinite(samples).all():
        raise RuntimeError('Invalid generated audio: '+word)
    sf.write(str(tmp),samples,rate,subtype='PCM_16')
    subprocess.run([FFMPEG,'-v','error','-y','-i',str(tmp),'-af','loudnorm=I=-18:TP=-2:LRA=9','-ar','24000','-ac','1','-b:a','48k',str(destination)],check=True)
    tmp.unlink()
    return word,{'text':word,'phonemes':phonemes,'voice':VOICE,'speed':SPEED,'generated':True,'seconds':round(len(samples)/rate,4),'synthesis_seconds':round(time.monotonic()-began,4),'sha256':hashlib.sha256(destination.read_bytes()).hexdigest(),'bytes':destination.stat().st_size,'path':'wordbooks/audio/'+destination.name}

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--models',type=Path,required=True);parser.add_argument('--words',type=Path,required=True)
    parser.add_argument('--cache',type=Path);parser.add_argument('--ffmpeg',required=True);parser.add_argument('--workers',type=int,default=6);parser.add_argument('--threads',type=int,default=1);parser.add_argument('--limit',type=int,default=0);parser.add_argument('--recover',action='store_true')
    args=parser.parse_args()
    directory=ROOT/'assets/wordbooks/audio';directory.mkdir(parents=True,exist_ok=True)
    audit_path=ROOT/'assets/wordbooks/audio-audit.json'
    audit=json.loads(audit_path.read_text('utf-8')) if audit_path.exists() else {}
    words=json.loads(args.words.read_text('utf-8'))
    if words and isinstance(words[0],dict):words=[row['word'] for row in words]
    cache=json.loads(args.cache.read_text('utf-8')) if args.cache else {}
    pending=[];copied=0;recovered=0
    for word in words:
        destination=directory/(key(word)+'.mp3')
        expected_phonemes=PRONUNCIATION.get(word,{}).get('phonemes','')
        if word in audit and audit[word].get('phonemes','')==expected_phonemes and destination.exists() and hashlib.sha256(destination.read_bytes()).hexdigest()==audit[word]['sha256']:continue
        if args.recover and not expected_phonemes and word not in audit and destination.exists() and not destination.with_suffix('.wav').exists():
            # Only files with the temporary WAV removed reached a completed encode.
            samples,rate=sf.read(str(destination))
            if len(samples)>rate*.16 and np.isfinite(samples).all() and max(abs(samples))>.001:
                audit[word]={'text':word,'voice':VOICE,'speed':SPEED,'generated':True,'recovered_checkpoint':True,'seconds':round(len(samples)/rate,4),'sha256':hashlib.sha256(destination.read_bytes()).hexdigest(),'bytes':destination.stat().st_size,'path':'wordbooks/audio/'+destination.name};recovered+=1
                continue
        cached=ROOT.parent/cache[word] if word in cache else None
        if cached and cached.exists() and not expected_phonemes:
            shutil.copyfile(cached,destination);info=sf.info(str(destination))
            audit[word]={'text':word,'voice':VOICE,'speed':.94 if cache[word].startswith('source/') else .97,'generated':False,'reused_from':cache[word],'seconds':round(info.duration,4),'sha256':hashlib.sha256(destination.read_bytes()).hexdigest(),'bytes':destination.stat().st_size,'path':'wordbooks/audio/'+destination.name};copied+=1
        else:pending.append(word)
    save_audit(audit_path,audit)
    if args.limit:pending=pending[:args.limit]
    print('AUDIO_START',len(words),'words',copied,'cache copies',recovered,'recovered',len(pending),'pending',args.workers,'workers',args.threads,'threads_each',flush=True)
    began=time.monotonic();completed=0
    with concurrent.futures.ProcessPoolExecutor(max_workers=args.workers,initializer=initialize,initargs=(str(args.models),args.ffmpeg,args.threads)) as pool:
        for word,result in pool.map(generate,[(word,str(directory)) for word in pending],chunksize=1):
            audit[word]=result;completed+=1
            if completed%25==0 or completed==len(pending):
                save_audit(audit_path,audit)
                elapsed=time.monotonic()-began
                print('AUDIO_PROGRESS',completed,'/',len(pending),'elapsed',round(elapsed,1),'remaining_estimate',round((len(pending)-completed)*elapsed/max(1,completed),1),'last',word,flush=True)
    print('AUDIO_COMPLETE',len(audit),'elapsed',round(time.monotonic()-began,1),flush=True)

if __name__=='__main__':main()
