"""Generate a periodic gas-density field in orbital coordinates (no camera or lighting)."""
from pathlib import Path
import numpy as np
from PIL import Image
width,height=1024,512
y,x=np.mgrid[:height,:width]
az=x/width
rad=y/height
rng=np.random.default_rng(9753)
def noise(u,v,cols,rows):
    grid=rng.random((rows,cols))
    ux=u*cols;vy=v*rows
    ix=np.floor(ux).astype(int);iy=np.floor(vy).astype(int)
    fx=ux-ix;fy=vy-iy
    fx=fx*fx*(3-2*fx);fy=fy*fy*(3-2*fy)
    a=grid[iy%rows,ix%cols]*(1-fx)+grid[iy%rows,(ix+1)%cols]*fx
    b=grid[(iy+1)%rows,ix%cols]*(1-fx)+grid[(iy+1)%rows,(ix+1)%cols]*fx
    return a*(1-fy)+b*fy
# Long streams shear around each other. Warped, finer wakes break up their edges.
warp=rad+.120*(noise(az,rad,4,4)-.5)+.035*(noise(az,rad,12,14)-.5)
twist=az+.03*np.sin(2*np.pi*(rad*2+noise(az,rad,4,5)))+.12*rad
large=noise(twist,warp,9,17)
wake=noise(twist+.023*large,warp+.046*large,21,47)
v=warp+.016*wake+.009*noise(twist,warp,64,59)
thin=noise(twist,v,36,130)
micro=noise(twist+.005*wake,v+.002*thin,110,276)
density=.52*large+.29*wake+.14*thin+.05*micro
filament=1-abs(2*noise(twist,v+.011*thin,18,84)-1)
edge=noise(twist,v,12,10)*.47+wake*.36+micro*.17
pixels=np.uint8(np.clip(np.stack([density,filament**4,edge],axis=-1),0,1)*255+.5)
Image.fromarray(pixels).save(Path(__file__).resolve().parents[1]/'assets/cosmos/orbital_gas.png',optimize=True)
