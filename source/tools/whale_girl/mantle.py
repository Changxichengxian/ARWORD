# SPDX-License-Identifier: CC-BY-NC-SA-4.0
# See assets/characters/whale-girl-CREDITS.txt.
from geometry import backpainted
from locks import build as make_side_locks, trim_mantle
from parting import back_cap_form
from math import sin as sn, cos as cs

def build():
    pi = 3.141592653589793

    def sat(x):
        return max(0., min(1., x))

    def ease(x):
        x = sat(x)
        return x*x*(3-2*x)

    def mix(a, b, k):
        return a + (b-a)*k

    # Shape-preserving cubic for cross sections and brush trajectories.
    def slope(d, e, h, k):
        if d*e <= 0:
            return 0.
        return 3*(h+k)/((2*k+h)/d + (k+2*h)/e)

    def sample(rows, t):
        if t <= rows[0][0]:
            return rows[0][1:]
        for i in range(len(rows)-1):
            a, b = rows[i:i+2]
            if t <= b[0]:
                l = rows[max(0, i-1)]
                r = rows[min(len(rows)-1, i+2)]
                h = b[0]-a[0]
                u = (t-a[0])/h
                out = []
                for j in range(1, len(a)):
                    d = (b[j]-a[j])/h
                    p = slope((a[j]-l[j])/(a[0]-l[0]), d,
                              a[0]-l[0], h) if i else d
                    q = slope(d, (r[j]-b[j])/(r[0]-b[0]), h,
                              r[0]-b[0]) if r != b else d
                    out.append(mix(a[j], b[j], ease(u)) +
                               h*u*(1-u)*((1-u)*p-u*q))
                return out
        return rows[-1][1:]

    def zpx(v):
        return .952 + (279-v)*.00323

    def back_weights(x, y, z):
        k = ease((1.22-z)/.28)
        return {"head": 1-k, "HairBack": k}

    # Width in frontal pixels, occipital ridge Y, side seam Y, frontal depth.
    sections = [
        (65, 0, .026, .026, .026), (69, 32, .118, .026, -.064),
        (82, 61, .206, .025, -.135), (105, 88, .275, .023, -.206),
        (142, 113, .328, .022, -.262), (183, 128, .351, .016, -.284),
        (217, 128, .349, .010, -.274), (247, 124, .330, .012, -.246),
        (281, 122, .300, .025, -.209), (306, 129, .283, .038, -.177),
        (337, 149, .279, .048, -.155), (365, 157, .292, .055, -.134),
        (392, 150, .306, .060, -.121), (417, 157, .298, .067, -.109),
        (441, 152, .268, .080, -.095), (465, 141, .235, .095, -.082),
        (476, 144, .223, .099, -.078)]
    # Hem height measured around the head, rather than horizontal ring ends.
    perimeter = [
        (0,348), (.16,353), (.33,346), (.48,358), (.59,383),
        (.73,403), (.83,389), (.96,430), (1.10,455), (1.22,436),
        (1.32,444), (1.45,468), (1.54,451), (1.63,433),
        (1.74,438), (1.83,402), (1.91,335), (2.02,265),
        (2.16,224), (2.34,179), (2.57,146), (2.84,125), (pi,119)]

    # Inset continuous region of the back painting. Ends before either bow
    # wing, the white fin, or the holes between the outer curls.
    back_width = [(68,4),(73,22),(84,49),(108,78),(144,101),
                  (184,108),(218,104),(243,110),(271,112),
                  (297,119),(320,133),(342,144),(365,150),
                  (381,147),(401,132),(425,121),(443,119)]
    safe_end = [(0,355),(12,355),(24,349),(38,345),(54,345),
                (67,347),(77,352),(83,373),(90,397),(99,411),
                (107,422),(116,432),(124,430),(136,411),
                (146,389),(160,380),(180,379)]

    def back_uv(v, a):
        # Back-view right is character -X. Do not continue the orthographic
        # projection into negative cos angles (would repeat the central part).
        s = sn(min(abs(a), pi*.5))
        if abs(a) > pi*.5:
            s *= 1-.34*ease((abs(a)-pi*.5)/(pi*.5))
        s *= -1 if a > 0 else 1
        vp = max(68., v)
        w = sample(back_width, vp)[0]
        end = sample(safe_end, abs(w*s))[0]
        if vp > 331:
            vp = 331 + (end-331)*sat((vp-331)/max(22., end-323))
        w = sample(back_width, vp)[0]
        return (210 + 2*ease((vp-190)/130) + w*s, vp)

    verts, faces, uv = [], [], []
    N, M = 112, 48

    def add(p, tex):
        idx = len(verts)
        verts.append(p)
        uv.append(tex)
        return idx

    bases = []
    poles = []
    for lining in (0, 1):
        poles.append(add((0,.026,zpx(65)-lining*.012), (210,68)))
        bases.append(len(verts))
        for j in range(1,M+1):
            t = j/M
            for i in range(N):
                a = -pi + 2*pi*i/N
                sa, ca = sn(a), cs(a)
                end = sample(perimeter, abs(a))[0]
                end += 4*sa*ease((end-245)/140)
                v = 65+(end-65)*t**1.67
                width, rear, seam, fore = sample(sections, v)
                k = ease((v-213)/130)
                phase = 8*a + .90*sn((v-268)*.037) + .39*sn(3*a)
                fold = .64*cs(phase)+.36*cs(2*phase-.45)
                bow = (1-ease(abs(a)/.73))*ease((v-281)/72)
                theta = a + sa*k*(.078*sn((v-281)*.047 + .8*ca)
                                     + .044*sn(4*a))
                s,c = sn(theta),cs(theta)
                lip = ease((t-.87)/.13)*k
                w = width*.00320 + k*(.017*fold+.013*lip)
                deep = rear-seam if c>=0 else seam-fore
                rad = deep + k*(.023*fold-.083*bow) + lip*.015*cs(phase)
                gauge = mix(.020,.043,k)*(1-.64*lip)
                x = s*(w-lining*gauge)
                y = seam+c*(rad-lining*gauge)
                z = zpx(v) + lip*.015*(1+cs(phase+.65))
                if lining:
                    z += .008*lip-.012*(1-ease((v-65)/38))
                add((x,y,z),back_uv(v,theta))
        b = bases[-1]
        for i in range(N):
            n = (i+1)%N
            f = (poles[-1], b+n, b+i)
            faces.append(f[::-1] if lining else f)
        for j in range(M-1):
            q = b+j*N
            for i in range(N):
                n = (i+1)%N
                f = (q+i,q+n,q+N+n,q+N+i)
                faces.append(f[::-1] if lining else f)
    q,r = [b+(M-1)*N for b in bases]
    for i in range(N):
        n = (i+1)%N
        faces.append((q+i,q+n,r+n,r+i)[::-1])
    backpainted("Occipital silk - continuous folded mantle",back_weights,
                [trim_mantle(*back_cap_form(*pt)) for pt in verts],faces,uv)
    make_side_locks()
