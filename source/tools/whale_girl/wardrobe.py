"""Fit the painted panels, puff sleeves and soft palms to their moving bones."""
import math
from geometry import MATERIALS, material, texture_paint, tint
from dress_form import cloth_form, cloth_palette, skirt_paint
from tailor import tailor, textile_uv


def replaced(name):
    return any(key in name.lower() for key in ("hypothenar","digit ","opposed thumb",
        "cream pintucked stomacher","fluted bib side flounce","bib rouleau","falling throat ribbon",
        "cravat wing","gilt scallop bezel","repousse scallop rib"))


def accessory_uv(name,x,y,z):
    part=name.lower()
    sign=1 if x>0 else -1
    q=abs(x)
    if "wrapped cummerbund" in part:
        a=math.atan2(x*.79,.005-y)
        t=max(0,min(1,(.693-z)/.037))
        return 247+36*math.sin(a),351.5+15.5*t+1.2*math.cos(a)
    if "gathered bishop sleeve" in part:
        t=min(1,max(0,(q-.135)/.270))
        radius=.051+.044*math.sin(math.pi*t)**.70
        across=max(-.97,min(.97,(z-(.903-.016*t-.008*math.sin(math.pi*t)))/radius))
        # The line of the arm in the illustration slopes toward its cuff.
        width=6+13*math.sin(math.pi*t)**.58
        u=188-23*t+across*width*.69
        v=321+49*t+across*4
        return (u if sign<0 else 493-u),v
    if "gauntlet cuff" in part:
        t=min(1,max(0,(q-.396)/.057))
        across=max(-1,min(1,(z-.887)/.033))
        u=162-9*t+13*across
        return (u if sign<0 else 493-u),377+20*t+4.8*across
    return None


def fit(item):
    name = item.name
    original = [v.co.copy() for v in item.data.vertices]
    def form(x,y,z):
        if any(k in name.lower() for k in ("pinafore","apron shells","apron pearl","fine shell edging")):
            h=min(1,max(0,(.676-z)/.29))
            # Mount the bottom edge higher on the bell. Its radius must follow
            # the new ring too, otherwise the apron hangs away from the skirt.
            x*=1-.117*h
            y=.006+(y-.006)*(1-.107*h)
            z+=.050*h
        x,y,z = cloth_form(name,*tailor(name,x,y,z))
        return x,y,z
    if item.data.shape_keys:
        for key in item.data.shape_keys.key_blocks:
            for vertex in key.data:
                vertex.co=form(*vertex.co)
    else:
        for vertex,p in zip(item.data.vertices,original):
            vertex.co=form(*p)
    if "shell petal underskirt" in name.lower():
        def scallop(x,y,z):
            a=math.atan2(x*.72,.006-y)
            petal=math.sqrt(max(0.,.5-.5*math.cos(24*a)))
            bottom=.248+.048*math.sin(a)**2-.018*max(0.,math.cos(a))**2+.023*(1-petal)
            rim=max(0,min(1,(z-bottom)/.024))
            fold=(1-petal)**2
            return .999-.07*fold,.894-.13*fold+.045*rim,.835-.12*fold+.051*rim
        tint(item,scallop)
        return
    coords=[]
    for p in original:
        uv=accessory_uv(name,*p) or textile_uv(name,*p)
        if uv is None:
            uv=skirt_paint(name,*form(*p))
        coords.append(uv)
    if all(uv is not None for uv in coords):
        texture_paint(item, coords,"costume-and-face")
        return
    color=cloth_palette(name)
    if not color:return
    n=name.casefold()
    rgb=tuple(int(color[i:i+2],16)/255 for i in (1,3,5))
    if "rounded patent vamp" in n or "button strap" in n:
        def leather(x,y,z):
            dx=(abs(x)-.092)
            gleam=math.exp(-((dx+.014)/.020)**2-((y+.114)/.021)**2-((z-.042)/.012)**2)
            gleam+=.32*math.exp(-((dx-.039)/.009)**2-((y+.098)/.020)**2-((z-.050)/.015)**2)
            streak=math.exp(-((dx-.040)/.008)**2-((y+.050)/.046)**2)
            crown=min(1,max(0,z/.065))
            return (.13+.075*crown+.65*gleam+.09*streak,.14+.076*crown+.62*gleam+.09*streak,.26+.11*crown+.48*gleam+.12*streak)
        tint(item,leather)
    elif any(k in n for k in ("leg","arm","instep")):
        def skin(x,y,z):
            side=min(1,abs(abs(x)-.091)/.066)
            shade=.13*side**2+.045*max(0,math.tanh(y*25))
            under=.12*math.exp(-((z-.27)/.052)**2) if "leg" in n else .015
            return rgb[0]-.05*shade,.929-shade-under,.872-shade-under
        tint(item,skin)
    else:
        key=material("Woven "+color,color,rough=.68)
        item.data.materials[0]=MATERIALS[key]
