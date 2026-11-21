# SPDX-License-Identifier: CC-BY-NC-SA-4.0
# See assets/characters/whale-girl-CREDITS.txt.
from geometry import face_y, head_profile, mesh, material, painted, shape, tint
from math import sin as sin_a
import portrait

def build():
    bone = "head"
    pi = 3.141592653589793

    def clip(a):
        return min(1.0, max(0.0, a))

    def ease(a):
        a = clip(a)
        return a*a*(3.0-2.0*a)

    def X(u):
        return (u-245.0)*.00320

    def Z(v):
        return .952+(279.0-v)*.00323

    def U(x):
        return 245.0+x/.00320

    def V(z):
        return 279.0-(z-.952)/.00323

    def point(u,v,lift):
        x,z = X(u),Z(v)
        return (x,face_y(x,z)-lift,z)

    def bell(q):
        return 2.718281828459045**(-min(60.0,q))

    verts,faces = [],[]
    # Equal-angle parallels, with finer vertical sampling at both poles.
    for j in range(1,97):
        h = .5-.5*sin_a(pi/2+pi*j/97)
        z = .95+.68*h
        w,c,r = head_profile(z)
        taper = min(1.0, ((z-.95)/.007)**.5, ((1.63-z)/.013)**.5)
        for i in range(80):
            a = 2*pi*i/80
            s,k = sin_a(a),sin_a(a+pi/2)
            xx = w*s
            if k > .000001:
                y = face_y(xx,z)
                # Blend the last few degrees into the temporal tangent.
                g = ease(k/.18)
                y = (1-g)*(c-r*k)+g*y
            else:
                y = c-r*k
            verts.append((xx*taper,c+(y-c)*taper,z))
        if j > 1:
            for i in range(80):
                n = (j-2)*80+i
                m = (j-2)*80+(i+1)%80
                faces.append((n,m,m+80,n+80))
    for top in (False,True):
        z = 1.63 if top else .95
        n = len(verts)
        verts.append((0,head_profile(z)[1],z))
        row = 95*80 if top else 0
        for i in range(80):
            a,b = row+i,row+(i+1)%80
            faces.append((a,b,n) if top else (b,a,n))
    skull = mesh("Face - chin cheeks and vault",bone,"skin",verts,faces)

    tint(skull,portrait.complexion)

    # Each section is (source column, first covered row, last covered row).
    left = [(163.4,217.8,218.1),(168,216,220),(171,214.4,222.5),
            (172.3,209.6,224),(174,210,226),(177,209.2,230.8),
            (179,207.4,232.9),(182.4,205,235.8),(183.3,202.2,236.5),
            (186.6,203.4,238),(191,202.3,240),(196,202,241.7),
            (201,202.1,242.6),(207,203,242.4),(213,205.4,241.2),
            (217,208.2,237.7),(219.6,212,232.5),(221,214.4,219.3),
            (224.2,218.8,219.4)]
    right = [(265,216.9,217.5),(268.5,210,218.3),(270.4,207.4,229),
             (272.3,205.5,235.5),(275.2,203.7,239),(280,202,240.7),
             (286,201.1,241.4),(291,201.3,241.5),(297,201.9,240),
             (302,201.3,238),(306.7,200,234.8),(305.9+2,203.1,234),
             (311.4,205.2,230.7),(315.2,207.3,226.5),(318.7,207,223),
             (319.4,211.3,222),(322,213.2,219.5),(327.5,215.3,215.8)]

    def sample(rows,u,k):
        for i in range(1,len(rows)):
            a,b = rows[i-1],rows[i]
            if u <= b[0]:
                t = clip((u-a[0])/(b[0]-a[0]))
                return a[k]+(b[k]-a[k])*t
        return rows[-1][k]

    def grid(cols,n,fn):
        vv,ff,uv = [],[],[]
        for i,u in enumerate(cols):
            for j in range(n+1):
                v,d = fn(u,j/n)
                vv.append(point(u,v,d))
                uv.append((u,v))
                a = len(vv)-1
                if i and j:
                    ff.append((a-n-2,a-n-1,a,a-1))
        return vv,ff,uv

    liner = material("Roasted plum lash","#382032",rough=.83)
    browmat = material("Indigo brow","#33315B",rough=.82)
    lipmat = material("Persimmon lip seam","#974E51",rough=.85)
    for side,rows in (("L",left),("R",right)):
        lo,hi = rows[0][0],rows[-1][0]
        cols = [lo]
        for a,b in zip(rows,rows[1:]):
            n = 1+int((b[0]-a[0])/.95)
            cols.extend(a[0]+(b[0]-a[0])*j/n for j in range(1,n+1))

        def axis(u):
            t = clip((u-lo)/(hi-lo))
            return t if side=="L" else 1-t

        def shut(u):
            t = axis(u)
            return 217.6+3*t+4.4*sin_a(pi*t)

        def patch(u,t):
            a,b = sample(rows,u,1),sample(rows,u,2)
            return (a+(b-a)*t,.0014+.0033*sin_a(pi*t)*sin_a(pi*axis(u)))

        vv,ff,uv = grid(cols,16,patch)
        eye = painted("Illustrated eye "+side,bone,vv,ff,uv)

        def blink_eye(x,y,z):
            u = U(x)
            return point(u,shut(u)+.014*(V(z)-shut(u)),-.0028)
        shape(eye,"blink",blink_eye)

        def ridge(u):
            a,b = sample(rows,u,1),sample(rows,u,2)
            return a+min(2.6,(b-a)*.25)

        def width(u):
            return .04+.52*sin_a(pi*axis(u))**.6

        def lid(u,t):
            return ridge(u)+(2*t-1)*width(u),.0041
        vv,ff,uv = grid(cols,3,lid)
        lash = mesh("Mobile upper lash "+side,bone,liner,vv,ff)

        def blink_lash(x,y,z):
            u = U(x)
            return point(u,shut(u)+1.8*(V(z)-ridge(u)),.0032)
        shape(lash,"blink",blink_lash)

        # Secondary arcs sit above the socket, under the fringe.
        outer,inner = (177.5,215.3) if side=="L" else (312.2,269.2)
        def brow(u,t):
            a = clip((u-outer)/(inner-outer))
            line = (181 if side=="L" else 179)-6*a-5*sin_a(pi*a)
            return line+(2*t-1)*(.06+1.35*sin_a(pi*a)**.7),.0022
        bc = [min(outer,inner)+abs(inner-outer)*j/32 for j in range(33)]
        vv,ff,uv = grid(bc,3,brow)
        ob = mesh("Brush brow "+side,bone,browmat,vv,ff)
        for key,innerdrop,raise_mid in (("angry",5.2,-1.4),("happy",-1.8,-2.0),
                                       ("relaxed",1.5,1.2)):
            def shift(x,y,z):
                u = U(x)
                t = clip((u-outer)/(inner-outer))
                return point(u,V(z)+innerdrop*t+raise_mid*sin_a(pi*t),.0022)
            shape(ob,key,shift)

    # One continuously deformable oral inset, rather than an open-mouth
    # overlay on top of the neutral ink stroke.
    cols = [241.8+8.6*j/32 for j in range(33)]
    def oral(u,t):
        a = (u-246.1)/4.3
        h = max(0,1-a*a)
        return 259.65-2.55*h+(2*t-1)*(.08+.47*h),.00165
    vv,ff,uv = grid(cols,12,oral)
    mouth = mesh("Little pout",bone,lipmat,vv,ff)
    def mouth_t(x,z):
        u = U(x)
        a,b = oral(u,0)[0],oral(u,1)[0]
        return clip((V(z)-a)/(b-a))
    def mouth_color(x,y,z):
        t = mouth_t(x,z)
        glow = ease((t-.55)/.43)
        return (.54+.32*glow,.254+.21*glow,.276+.22*glow)
    tint(mouth,mouth_color)
    for key,w,mid,bend,height in (("ih",7.0,258.8,-.55,5.45),
                                  ("happy",6.6,258.2,2.35,.84),
                                  ("relaxed",4.2,258.9,.45,.31),
                                  ("angry",4.9,259.9,-1.85,.52)):
        def expression(x,y,z):
            a = (U(x)-246.1)/4.3
            h = max(0,1-a*a)
            t = mouth_t(x,z)
            return point(246.1+w*a,mid+bend*h+(2*t-1)*(.07+height*h**.72),
                         .00165)
        shape(mouth,key,expression)
