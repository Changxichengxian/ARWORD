from pathlib import Path
import json,subprocess,hashlib,time
import soundfile as sf
import onnxruntime as ort
from kokoro_onnx import Kokoro
R=Path(__file__).resolve().parents[1];M=R.parent/'voice-model'
opts=ort.SessionOptions();opts.intra_op_num_threads=2;opts.inter_op_num_threads=1
tts=Kokoro.from_session(ort.InferenceSession(str(M/'kokoro-v1.0.onnx'),sess_options=opts,providers=['CPUExecutionProvider']),str(M/'voices-v1.0.bin'))
manifest=json.loads((R/'tools/audio-manifest.json').read_text())
audit={}
for item in manifest:
    p=R/'assets'/item['path']
    wave,rate=tts.create(item['text'],voice='af_heart',speed=.96,lang='en-us');sf.write(str(M/'frontier3d.wav'),wave,rate)
    subprocess.run([r'C:\App\Work\BBDown\ffmpeg.exe','-v','error','-y','-i',str(M/'frontier3d.wav'),'-af','loudnorm=I=-18:TP=-2:LRA=9','-ar','24000','-ac','1','-b:a','64k',str(p)],check=True)
    audit[item['id']]={'textHash':hashlib.sha256(item['text'].encode()).hexdigest(),'seconds':len(wave)/rate};print(item['id'],round(len(wave)/rate,1),flush=True)
(R.parent/'qa3d/voice-audit.json').write_text(json.dumps(audit,indent=2))
