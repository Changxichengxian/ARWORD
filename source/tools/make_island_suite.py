"""Three original instrumental miniatures for the offline island playlist."""
from pathlib import Path
import numpy as np
import soundfile as sf

RATE = 32000
OUT = Path(__file__).resolve().parents[1] / "assets/audio"

def render(name, beat, bars, score):
    duration = bars * beat + 3.5
    mix = np.zeros((round(duration * RATE), 2))
    for start, beats, pitch, gain, pan, voice in score:
        at = round(start * beat * RATE)
        t = np.arange(min(round((beats * beat + 1.2) * RATE), len(mix) - at)) / RATE
        phase = 2 * np.pi * 440 * 2**((pitch-69)/12) * t
        if voice == "bow":
            tone = np.sin(phase + .12*np.sin(2*np.pi*4.5*t)) + .17*np.sin(phase*2)
            env = (1-np.exp(-t/.34)) * np.exp(-.23*t)
        elif voice == "glass":
            tone = np.sin(phase) + .22*np.sin(phase*2.71)*np.exp(-t*2)
            env = (1-np.exp(-t/.015))*np.exp(-t/2)
        else:
            tone = np.sin(phase)+.30*np.sin(phase*2.002)*np.exp(-t*3)+.12*np.sin(phase*3)*np.exp(-t*7)
            env = (1-np.exp(-t/.012))*np.exp(-t/(1.3 if voice=="felt" else .68))
        release=np.exp(-np.maximum(0,t-beats*beat)*5)
        mix[at:at+len(t)] += (tone*env*release*gain)[:,None]*np.sqrt([(1-pan)/2,(1+pan)/2])
    dry=mix.copy()
    for lag,gain in [(.22,.12),(.41,.09),(.70,.045)]:
        k=round(RATE*lag);mix[k:] += dry[:-k,::-1]*gain
    mix[:RATE//4] *= np.linspace(0,1,RATE//4)[:,None]
    mix[-RATE:] *= np.linspace(1,0,RATE)[:,None]
    mix *= min(.38/np.max(np.abs(mix)),.047/np.sqrt(np.mean(mix**2)))
    with sf.SoundFile(OUT/(name+".ogg"),"w",samplerate=RATE,channels=2,format="OGG",subtype="VORBIS") as stream:
        for k in range(0,len(mix),4096):stream.write(mix[k:k+4096])
    print(name,round(duration,1),flush=True)

def score():
    harbor=[];orchard=[];night=[]
    for b in range(16):
        chord=[[50,57,62,66],[47,54,62,66],[43,55,59,62],[45,52,59,64]][b%4]
        for i,k in enumerate([0,1,2,1,3,2]):
            harbor.append((6*b+i,.85,chord[k],.09 if i%3==0 else .054,(i%3-1)*.36,"wood"))
        if b%2==0:harbor.append((6*b+2,2.5,chord[3]+7,.065,.24,"bow"))
        root=[48,53,45,55][b%4]
        orchard.append((4*b,3,root,.09,-.24,"felt"))
        for i,p in enumerate([[67,69,72],[69,65,64],[64,67,69],[71,69,67]][b%4]):
            orchard.append((4*b+[.5,1.75,3][i],.8,p+(0 if b<8 else -5),.072,.30,"felt"))
        bass=[43,46,41,48][(b//2)%4]
        for n in [bass,bass+7]:night.append((4*b,3.8,n,.048,-.18,"bow"))
        for i in range(2 if b%3 else 1):
            night.append((4*b+.7+i*1.8,2,bass+[24,19,26,22][(b+i)%4],.082,.44-i*.76,"glass"))
    render("harbor_six",.57,96,harbor)
    render("orchard_keys",.91,64,orchard)
    render("glass_orbit",1.13,64,night)

if __name__=="__main__":score()
