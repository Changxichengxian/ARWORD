"""Create an original, quiet 80-second seamless ambient miniature. No external recording."""
from pathlib import Path
import json, math
import numpy as np
import soundfile as sf
print('Synthesizing original ambient loop',flush=True)

ROOT=Path(__file__).resolve().parents[1];RATE=32000;DURATION=80;N=RATE*DURATION
rng=np.random.default_rng(918)
audio=np.zeros((N,2),dtype=np.float64)
def frequency(midi):return 440*2**((midi-69)/12)
def add(midi,start,length,level,pan=0,kind='felt'):
    count=round(length*RATE);t=np.arange(count)/RATE;f=frequency(midi)
    if kind=='pad':
        env=np.sin(np.pi*np.clip(t/length,0,1))**1.6
        signal=(np.sin(2*np.pi*f*t)+.22*np.sin(2*np.pi*f*2*t+.2)+.09*np.sin(2*np.pi*f*3*t+.1))*.7
    else:
        env=(1-np.exp(-t/.025))*np.exp(-t/2.7)*np.minimum(1,(length-t)/.9)
        signal=np.sin(2*np.pi*f*t)+.23*np.sin(2*np.pi*f*2*t)*np.exp(-t/1.2)+.07*np.sin(2*np.pi*f*3*t)*np.exp(-t/.5)
    wave=signal*env*level
    # Circular indexing preserves tails across the loop boundary.
    indices=(np.arange(count)+round(start*RATE))%N
    audio[indices,0]+=wave*math.sqrt((1-pan)*.5);audio[indices,1]+=wave*math.sqrt((1+pan)*.5)

# A restrained original sequence; long rests, no drums or dramatic peaks.
chords=[[48,55,59,64],[45,52,59,60],[41,48,55,60],[43,50,57,62]]
for cycle in range(2):
    for index,chord in enumerate(chords):
        at=cycle*40+index*10
        for i,note in enumerate(chord):add(note,at-.8,12,.025,-.45+i*.3,'pad')
        pattern=[(0.8,chord[2]+12),(3.4,chord[3]+12),(6.6,chord[1]+12),(8.1,chord[2]+12)]
        if cycle:pattern=[(1.2,chord[3]+12),(4.5,chord[2]+12),(7.0,chord[1]+12)]
        for offset,note in pattern:add(note,at+offset,7,.09,float(rng.uniform(-.45,.45)))
# Very soft, alternating cross echoes create space without a constant wash.
dry=audio.copy()
for delay,gain in [(.31,.18),(.59,.13),(.91,.09),(1.31,.06)]:
    audio+=np.roll(dry[:,::-1],round(delay*RATE),axis=0)*gain
audio=np.tanh(audio*1.2)
peak=float(np.max(np.abs(audio)));audio*=.42/max(.42,peak)
target=ROOT/'assets/audio/island_drift.ogg'
print('Encoding loop',flush=True)
with sf.SoundFile(target,'w',samplerate=RATE,channels=2,format='OGG',subtype='VORBIS') as output:
    for offset in range(0,N,4096):output.write(audio[offset:offset+4096])
report={'title':'Island Drift','duration_seconds':DURATION,'sample_rate':RATE,'channels':2,'peak_before_export':float(np.max(np.abs(audio))),'rms':float(np.sqrt(np.mean(audio**2))),'original_synthesis':True,'seed':918,'loop':'circular synthesis including notes and echo tails'}
(ROOT/'assets/audio/island_drift.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report))
