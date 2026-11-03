"""Bake disk intersection coordinates for an almost edge-on Schwarzschild camera.

In units G=M=c=1 a null orbit in its own plane obeys u''=3*u*u-u,
u=1/r. At infinity u=0 and u'=1/b. Spherical symmetry lets all screen
azimuths share one table indexed by impact parameter b and orbital angle.
The game animates a single emitting annulus through these intersections.
"""
from pathlib import Path
import sys
import numpy as np
sys.path.append(str(Path(sys.base_prefix)/'Lib/site-packages'))
from PIL import Image

OUT=Path(__file__).resolve().parents[1]/'assets/cosmos'
W,H=1152,640
HALF_WIDTH=23.5
INNER,OUTER=5.8,21.6

def orbits():
    b=np.linspace(.02,28,4096)
    phi=np.linspace(0,2*np.pi+.02,1250)
    step=phi[1]-phi[0]
    u=np.zeros_like(b); velocity=1/b
    values=np.zeros((len(phi),len(b)),np.float32)
    active=np.ones(len(b),bool)
    for i in range(1,len(phi)):
        accel=3*u*u-u
        un=u+velocity*step+.5*accel*step**2
        active&=(un>0)&(un<.5)
        un=np.where(active,un,0.)
        velocity=np.where(active,velocity+(accel+3*un*un-un)*step*.5,0.)
        u=un;values[i]=u
    return b,phi,values

def smoothstep(a,b,x):
    t=np.clip((x-a)/(b-a),0,1)
    return t*t*(3-2*t)

def main():
    impacts,angles,table=orbits()
    y,x=np.mgrid[0:H,0:W]
    dx=(x+.5-W/2)*2*HALF_WIDTH/W
    dy=(H/2-y-.5)*2*HALF_WIDTH/W
    # A slight camera roll, independent of orbital motion.
    roll=np.deg2rad(6)
    xx=dx*np.cos(roll)+dy*np.sin(roll);yy=-dx*np.sin(roll)+dy*np.cos(roll)
    b=np.hypot(xx,yy)
    cb=xx/np.maximum(.001,b);sb=yy/np.maximum(.001,b)
    inc=np.deg2rad(4.5)
    phase=np.arctan2(np.sin(inc),-np.cos(inc)*sb)
    bi=np.clip((b-impacts[0])/(impacts[1]-impacts[0]),0,len(impacts)-2)
    j=bi.astype(int);fb=bi-j
    radial=np.zeros_like(b);azimuth=np.zeros_like(b);energy=np.zeros_like(b)
    for image_order in range(2):
        a=phase+np.pi*image_order
        fi=a/angles[1];i=fi.astype(int);f=fi-i
        u=(1-f)*((1-fb)*table[i,j]+fb*table[i,j+1])+f*((1-fb)*table[i+1,j]+fb*table[i+1,j+1])
        radius=1/np.maximum(1e-9,u)
        hit=(radius>=INNER)&(radius<OUTER)&(energy==0)
        azi=np.arctan2(np.cos(a)*np.cos(inc)-np.sin(a)*sb*np.sin(inc),np.sin(a)*cb)
        # Warm optically emitting gas falls off with radius. Soften the
        # extreme Doppler asymmetry for both sides to remain readable.
        ring=smoothstep(INNER,INNER+.38,radius)*(1-smoothstep(13.4,OUTER,radius))
        light=ring*(INNER/np.maximum(INNER,radius))**1.28*(1-.14*np.cos(azi))
        energy[hit]=light[hit]*(1. if image_order==0 else .46)
        radial[hit]=(radius[hit]-INNER)/(OUTER-INNER)
        azimuth[hit]=azi[hit]
    def save(name,channels):
        a=np.stack(channels,axis=-1)
        Image.fromarray(np.uint8(np.clip(a,0,1)*255+.5)).save(OUT/name,optimize=True)
    save('disk_orbits.png',[radial,.5+.5*np.cos(azimuth),.5+.5*np.sin(azimuth)])
    pad=160
    raster=np.pad(energy,pad)
    spectrum=np.fft.rfft2(raster)
    freqs=np.fft.fftfreq(raster.shape[0])[:,None]**2+np.fft.rfftfreq(raster.shape[1])[None,:]**2
    def blur(sigma):
        return np.fft.irfft2(spectrum*np.exp(-2*np.pi**2*sigma**2*freqs),s=raster.shape,axes=(0,1))[pad:-pad,pad:-pad]
    glow=np.maximum(0,.32*blur(3)+.45*blur(14)+.49*blur(39)+.18*blur(73))
    shadow=1-smoothstep(np.sqrt(27)-.035,np.sqrt(27)+.035,b)
    save('disk_light.png',[energy,np.sqrt(glow),shadow])

if __name__=='__main__':main()
