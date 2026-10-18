"""Short original synthesized feedback sounds, without sampled media."""
from pathlib import Path
import wave,numpy as np
root=Path(__file__).resolve().parents[1]/'app/src/main/res/raw';root.mkdir(parents=True,exist_ok=True)
sr=22050
def pluck(freq,seconds=.38):
    t=np.arange(int(seconds*sr))/sr
    return (np.sin(2*np.pi*freq*t)+.25*np.sin(2*np.pi*freq*2*t))*np.exp(-t*13)*np.minimum(t*250,1)
def write(name,y):
    y=np.asarray(y);y=np.clip(y*.32,-.8,.8)
    with wave.open(str(root/(name+'.wav')),'wb') as f:f.setnchannels(1);f.setsampwidth(2);f.setframerate(sr);f.writeframes((y*32767).astype('<i2').tobytes())
def chord(freqs,spacing):
    y=np.zeros(int((.4+spacing*(len(freqs)-1))*sr))
    for i,f in enumerate(freqs):
        v=pluck(f);start=int(i*spacing*sr);y[start:start+len(v)]+=v
    return y
write('duel_good',chord([523.25,783.99],.07))
write('duel_even',chord([349.23,440.0],.02))
t=np.arange(int(.26*sr))/sr
rng=np.random.default_rng(14)
write('duel_bad',(np.sin(2*np.pi*(150*t-120*t*t))+.14*rng.normal(size=len(t)))*np.exp(-t*15)*np.minimum(t*300,1))
write('build_complete',chord([392,493.88,587.33,783.99],.09))
print('Rendered 4 original feedback WAV files')
