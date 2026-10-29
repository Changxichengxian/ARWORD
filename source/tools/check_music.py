"""Check the delivered audio itself, including the decoded loop boundary."""
from pathlib import Path
import json
import numpy as np
import soundfile as sf
root=Path(__file__).resolve().parents[1]
path=root/'assets/audio/island_drift.ogg'
audio,rate=sf.read(path,always_2d=True)
peak=float(np.abs(audio).max());rms=float(np.sqrt(np.mean(audio**2)))
derivative=np.abs(np.diff(audio,axis=0))
seam=float(np.abs(audio[0]-audio[-1]).max())
ordinary=float(np.quantile(derivative,.999))
report={'file_bytes':path.stat().st_size,'duration_seconds':len(audio)/rate,'sample_rate':rate,'channels':audio.shape[1],'peak':peak,'peak_dbfs':20*np.log10(peak),'rms_dbfs':20*np.log10(rms),'loop_seam_step':seam,'normal_step_p99_9':ordinary,'no_clipped_samples':bool(peak<.99),'seam_below_normal_transients':bool(seam<ordinary),'app_default_gain_db':-11,'speech_duck_gain_db':-29}
assert report['no_clipped_samples'] and report['seam_below_normal_transients']
assert 79.99<report['duration_seconds']<80.01 and rate==32000
print(json.dumps(report,indent=2))
