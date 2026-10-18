from pathlib import Path
import json,subprocess,time,hashlib,argparse,shutil
import numpy as np
import onnxruntime as ort
import soundfile as sf
from kokoro_onnx import Kokoro
ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--model-dir',type=Path,default=ROOT.parent/'voice-model');parser.add_argument('--ffmpeg',default=shutil.which('ffmpeg'));parser.add_argument('--audit',type=Path,default=ROOT.parent/'qa/neural-audio-audit.json');args=parser.parse_args()
if not args.ffmpeg:parser.error('Specify --ffmpeg PATH or add FFmpeg to PATH')
MODEL=args.model_dir
opts=ort.SessionOptions();opts.intra_op_num_threads=2;opts.inter_op_num_threads=1
model=MODEL/'kokoro-v1.0.onnx'
session=ort.InferenceSession(str(model),sess_options=opts,providers=['CPUExecutionProvider'])
tts=Kokoro.from_session(session,str(MODEL/'voices-v1.0.bin'))
manifest=json.loads((ROOT/'tools/audio-v2-manifest.json').read_text(encoding='utf-8'))
audit=args.audit;audit.parent.mkdir(parents=True,exist_ok=True);done=json.loads(audit.read_text()) if audit.exists() else {}
temp=MODEL/'current.wav'
for index,item in enumerate(manifest):
    dest=ROOT/'app/src/main/assets'/item['path']
    key=hashlib.sha256((item['text']+'|af_heart|0.97').encode()).hexdigest()
    if item['id'] in done and done[item['id']]['key']==key and dest.exists():continue
    began=time.time()
    wave,rate=tts.create(item['text'],voice='af_heart',speed=.97,lang='en-us')
    assert len(wave)>rate*.2 and np.isfinite(wave).all(),item['id']
    sf.write(str(temp),wave,rate)
    subprocess.run([args.ffmpeg,'-v','error','-y','-i',str(temp),'-af','loudnorm=I=-18:TP=-2:LRA=9','-ar','24000','-ac','1','-b:a','64k',str(dest)],check=True)
    done[item['id']]={'key':key,'seconds':len(wave)/rate,'synthesisSeconds':time.time()-began,'bytes':dest.stat().st_size}
    if index%10==0:
        audit.write_text(json.dumps(done,indent=2));print(index+1,'/',len(manifest),item['id'],round(time.time()-began,1),flush=True)
audit.write_text(json.dumps(done,indent=2));print('Completed',len(done),flush=True)
