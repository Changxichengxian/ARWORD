# SPDX-License-Identifier: CC-BY-NC-SA-4.0
# See assets/characters/whale-girl-CREDITS.txt.
from geometry import mesh, tint
from math import cos, exp, pi, sin, sqrt

def build():
    def sat(x):
        return min(1., max(0., x))

    def ease(x):
        x = sat(x)
        return x*x*(3.-2.*x)

    def mix(a,b,t):
        t = sat(t)
        return tuple(x+(y-x)*t for x,y in zip(a,b))

    def shade(c,k):
        return tuple(sat(x*k) for x in c)

    def sample(keys,t):
        f = sat(t)*(len(keys)-1)
        i = min(int(f),len(keys)-2)
        f -= i
        return tuple(.5*(2*b+(c-a)*f+(2*a-5*b+4*c-d)*f*f+
                         (d-a+3*(b-c))*f*f*f)
                     for a,b,c,d in zip(keys[max(i-1,0)],keys[i],
                                        keys[i+1],keys[min(len(keys)-1,i+2)]))

    def shell(name,bone,rows,sides,fn):
        verts, faces, colors = [], [], {}
        for i in range(rows):
            for j in range(sides):
                p,c = fn(i/(rows-1),2*pi*j/sides)
                verts.append(p)
                colors[tuple(round(k,5) for k in p)] = c
        for i in range(rows-1):
            for j in range(sides):
                a = i*sides+j
                b = i*sides+(j+1)%sides
                faces.append((a,b,b+sides,a+sides))
        faces.append(tuple(range(sides-1,-1,-1)))
        faces.append(tuple((rows-1)*sides+j for j in range(sides)))
        volume = 0.
        for f in faces:
            x,y,z = verts[f[0]]
            for j in range(1,len(f)-1):
                a,b,c = verts[f[j]]
                d,e,g = verts[f[j+1]]
                volume += x*(b*g-c*e)+y*(c*d-a*g)+z*(a*e-b*d)
        if volume < 0:
            faces = [f[::-1] for f in faces]
        ob = mesh(name,bone,"white",verts,faces)
        tint(ob,lambda x,y,z: colors.get((round(x,5),round(y,5),round(z,5)),
                                         (.28,.34,.66)))

    ink = (.115,.142,.357)
    silk = (.303,.349,.678)
    blue = (.325,.493,.913)
    ice = (.468,.790,1.)
    glint = (.555,.611,.968)

    def color(z,a,s,out,light):
        c = mix(ink,silk,.70+.20*cos(2*a))
        c = mix(c,blue,ease((1.11+.10*light-z)/.43)*(.70+.30*light))
        c = mix(c,ice,ease((.88+.14*light-z)/.31)*(.68+.31*light))
        ridge = exp(-((s+.28+.09*sin(9*z))/.35)**2)
        c = shade(c,.85+.14*out+.13*ridge-.09*abs(s)**6)
        # A broken, notched satin reflection follows the curvature of the skull.
        stripe = 1.479+.032*cos(a)+.011*s*s+.010*cos(3*pi*s+.8*a)
        width = .010+.010*(1-s*s)+.003*cos(5*a)
        mask = ease((width-abs(z-stripe))/.007)*ease((.98-abs(s))/.19)
        return mix(c,glint,mask*out*(.62+.19*ridge))

    def leaf(name,bone,keys,light,angle=0.,crown=False):
        def section(t,q):
            x,y,z,w,h = sample(keys,t)
            a,b = sample(keys,t-.0008),sample(keys,t+.0008)
            dx,dz = b[0]-a[0],b[2]-a[2]
            mag = max(.000001,sqrt(dx*dx+dz*dz))
            s,v = cos(q),sin(q)
            k = max(.0006,w)*s
            p = (x+k*dz/mag,
                 y-max(.0006,h)*v*(1+.23*exp(-((s-.20)/.33)**2))+angle*k,
                 z-k*dx/mag)
            if crown:
                c = mix(ink,silk,.45+.55*max(0.,v))
                c = mix(c,glint,.43*exp(-((s-.28)/.24)**2)*sin(pi*t)**2)
            else:
                c = color(p[2],1.25,s,max(0.,v),light)
                c = mix(c,(.655,.853,1.),light*.25*max(0.,v)*
                        exp(-((s-.32)/.20)**2)*ease((1.12-z)/.24))
            return p,c
        shell(name,bone,6*len(keys)+1,24,section)

    for sign,side in [(1,"L"),(-1,"R")]:
        for i,(end,height) in enumerate([(.439,1.166),(.491,1.178),(.550,1.202)]):
            def vane(t,q):
                s,v = cos(q),sin(q)
                x = .315+(end-.315)*t
                z = 1.290+(height-1.290)*t-.038*sin(pi*t)
                w = (.049-.005*i)*(1-t)**.75+.018*sin(pi*t)+.0007
                y = -.021-.013*i+.072*t-.010*sin(pi*t)
                p = (sign*x,y-(.015*(1-t)+.001)*v,z+w*s)
                c = mix((.729,.786,.947),(.994,.992,1.),.68+.27*v+.12*s)
                c = mix(c,(.223,.253,.550),ease((abs(s)-.87)/.11))
                return p,c
            shell("Fin | porcelain vane "+side+str(i+1),"head",31,32,vane)
        def sail(t,q):
            x = .311+.245*t
            s,v = cos(q),sin(q)
            top = 1.365-.164*t-.028*sin(pi*t)+.015*t**5
            chord = .095*(1-t)**.83+.014*sin(pi*t)+.0015
            z = top-chord*(1-s)*.5
            p = (sign*x,-.067+.076*t-.017*sin(pi*t)-(.019*(1-t)+.001)*v,z)
            c = mix(ink,silk,.28+.63*max(0.,v))
            return p,mix(c,ink,ease((abs(s)-.79)/.20))
        shell("Fin | indigo leading foil "+side,"head",37,28,sail)

    leaf("CrownLock | single turning tide","head",[
        (.020,.014,1.640,.007,.006),(.032,.015,1.684,.010,.008),
        (.037,.014,1.737,.015,.010),(.018,.010,1.778,.020,.012),
        (-.029,.004,1.792,.023,.012),(-.084,-.002,1.782,.024,.013),
        (-.137,-.010,1.750,.023,.012),(-.176,-.018,1.708,.018,.010),
        (-.188,-.026,1.671,.010,.006),(-.176,-.030,1.656,.001,.001)
    ],0.,.08,True)
