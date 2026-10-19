from pathlib import Path
import json,subprocess,hashlib,wave,argparse,tempfile
import soundfile as sf,numpy as np,onnxruntime as ort
from kokoro_onnx import Kokoro
parser=argparse.ArgumentParser();parser.add_argument('--models',type=Path,required=True);parser.add_argument('--ffmpeg',default='ffmpeg');args=parser.parse_args()
R=Path(__file__).resolve().parents[1];M=args.models;W=Path(tempfile.mkdtemp(prefix='little-tide-voice-'))
opts=ort.SessionOptions();opts.intra_op_num_threads=2;opts.inter_op_num_threads=1
tts=Kokoro.from_session(ort.InferenceSession(str(M/'kokoro-v1.0.onnx'),sess_options=opts,providers=['CPUExecutionProvider']),str(M/'voices-v1.0.bin'))
audit=json.loads((R/'tools/voice-audit.json').read_text('utf-8')) if (R/'tools/voice-audit.json').exists() else {}
manifest=json.loads((R/'tools/audio-manifest.json').read_text(encoding='utf-8'))
for i,item in enumerate(manifest):
    p=R/'assets'/item['path'];text_hash=hashlib.sha256(item['text'].encode()).hexdigest()
    if p.exists() and audit.get(item['id'],{}).get('textHash')==text_hash:continue
    samples,rate=tts.create(item['text'],voice='af_heart',speed=.94,lang='en-us');sf.write(str(W/'planet-tmp.wav'),samples,rate)
    subprocess.run([args.ffmpeg,'-v','error','-y','-i',str(W/'planet-tmp.wav'),'-af','loudnorm=I=-18:TP=-2:LRA=9','-ar','24000','-ac','1','-b:a','64k',str(p)],check=True)
    audit[item['id']]={'textHash':hashlib.sha256(item['text'].encode()).hexdigest(),'seconds':len(samples)/rate}
    if i%12==0:
        print('Voice',i+1,'/',len(manifest),flush=True)
        (R/'tools/voice-audit.json').write_text(json.dumps(audit,indent=2),encoding='utf-8')
rng=np.random.default_rng(17);sr=24000
for name,duration,frequencies in [('chop',.16,[170,310]),('stone',.20,[640,930,1280]),('land',.16,[440,660]),('build',.55,[523,659,784,1046]),('tap',.05,[700]),('soft',.22,[392,494])]:
    t=np.arange(int(sr*duration))/sr;audio=np.zeros_like(t)
    for j,f in enumerate(frequencies):
        delay=j*(.06 if name=='build' else .007);u=np.maximum(0,t-delay);audio+=np.sin(2*np.pi*f*u)*np.exp(-u*(14 if name!='build' else 10))*(t>=delay)/len(frequencies)
    if name=='chop':audio+=rng.uniform(-1,1,len(t))*np.exp(-t*38)*.3
    audio=np.clip(audio*.30,-.9,.9);sf.write(str(R/'assets/audio'/f'{name}.wav'),audio,sr,subtype='PCM_16')
(R/'tools/voice-audit.json').write_text(json.dumps(audit,indent=2),encoding='utf-8')
print('VOICE_AND_SFX_COMPLETE',len(audit),flush=True)

(W/'planet-tmp.wav').unlink(missing_ok=True);W.rmdir()
