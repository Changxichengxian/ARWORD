"""Bake inverse orbital radius for Schwarzschild rays, independent of camera or disk color."""
from pathlib import Path
import numpy as np
from PIL import Image

# A null orbit in its plane obeys u'' = 3u² - u, u = GM / r.
# Each column is one impact parameter. Rows advance the polar angle along
# the ray. After a capture keep u=1/2; after an escape keep u=0.
width, height = 1024, 512
impact = np.linspace(.05, 26., width)
step = 2*np.pi/(height-1)
u = np.zeros(width)
velocity = 1/impact
active = np.ones(width, dtype=bool)
table = np.zeros((height, width), dtype=np.uint16)
for row in range(1,height):
    accel = 3*u*u-u
    next_u = np.clip(u+velocity*step+.5*accel*step**2, 0, .5)
    active &= (next_u>0)&(next_u<.5)
    velocity = np.where(active,velocity+.5*(accel+3*next_u**2-next_u)*step,0)
    u = np.where(active,next_u,np.where(next_u>.25,.5,0))
    table[row] = np.rint(u*131070)
pixels = np.zeros((height,width,3),dtype=np.uint8)
pixels[:,:,0] = table >> 8
pixels[:,:,1] = table & 255
Image.fromarray(pixels).save(Path(__file__).resolve().parents[1]/'assets/cosmos/null_orbits.png',optimize=True)
