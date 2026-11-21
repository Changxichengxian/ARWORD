# SPDX-License-Identifier: CC-BY-NC-SA-4.0
import math
from parting import fringe_form, fringe_hem
from geometry import face_y, head_profile, painted

def build():
    V, F, UV = [], [], []
    pi = math.pi
    sin, cos = math.sin, math.cos

    # Shape-preserving cubic interpolation. In particular, do not round
    # a brow opening downwards or overshoot the end of a cheek point.
    def spline(xs, ys):
        h = [b-a for a, b in zip(xs, xs[1:])]
        d = [(b-a)/s for a, b, s in zip(ys, ys[1:], h)]
        m = [d[0]]
        for i in range(1, len(d)):
            a, b = d[i-1], d[i]
            if a*b <= 0:
                m.append(0.0)
            else:
                p = 2*h[i]+h[i-1]
                r = h[i]+2*h[i-1]
                m.append((p+r)/(p/a+r/b))
        m.append(d[-1])

        def sample(x):
            if x <= xs[0]:
                return ys[0]
            for i, s in enumerate(h):
                if x <= xs[i+1]:
                    t = (x-xs[i])/s
                    k = 1-t
                    return (k*k*((1+2*t)*ys[i]+s*t*m[i]) +
                            t*t*((3-2*t)*ys[i+1]-s*k*m[i+1]))
            return ys[-1]
        return sample

    def ease(t):
        t = max(0.0, min(1.0, t))
        return t*t*(3-2*t)

    cz, rz = 1.238, .405
    top = .952 + (279-65)*.00323
    vp = 279-(cz+rz-.952)/.00323

    def height(v):
        return .952+(279-v)*.00323

    def latitude(v):
        return math.acos(max(-1.0, min(1.0, (height(v)-cz)/rz)))

    # Radius of a latitude, in projection pixels. Factor out sin(phi)
    # before interpolation so the pole is a round dome, not a cone.
    levels = [100, 145, 177, 211, 235, 250, 262]
    widths = [92, 119, 130, 122, 116, 108, 102]
    scale = spline(levels, [w/sin(latitude(v))
                            for v, w in zip(levels, widths)])

    # Longitude guides, NOT mesh strips. Each row is a strictly ordered
    # set of frontal positions at one latitude. The inward sweep below
    # the eyes lets the cheek tips turn back in X without crossing faces.
    # Interpolate whole longitude fields between latitudes (a convex
    # blend of increasing functions remains increasing).
    rows = [
        [161,166,171,176,181,187,199,211,227,245,256,267,280,292,304,311,317,323,330],
        [137,143,149,155,161,169,184,202,224,245,261,278,302,325,339,345,350,355,360],
        [127,133,140,147,154,164,183,202,222,245,262,284,313,342,351,357,363,368,372],
        [133,138,144,150,158,169,181,210,233,245,258,266,319,346,352,356,360,363,365],
        [137,143,151,161,172,179,194,215,236,245,258,269,313,327,340,346,351,355,358],
        [144,152,166,176,186,195,207,222,238,245,258,270,294,304,315,330,339,345,351],
        [146,158,188,197,206,214,221,230,239,245,256,266,285,293,303,318,331,340,345],
    ]
    keys = list(range(-1, 20))
    fields = []
    for v, w, row in zip(levels, widths, rows):
        angles = [math.asin(max(-.9999, min(.9999, (u-245)/w)))
                  for u in row]
        fields.append(spline(keys, [-1.80]+angles+[1.80]))

    def longitude(q, v):
        if v <= levels[0]:
            return fields[0](q)
        for i in range(len(levels)-1):
            if v <= levels[i+1]:
                t = ease((v-levels[i])/(levels[i+1]-levels[i]))
                return (1-t)*fields[i](q)+t*fields[i+1](q)
        return fields[-1](q)

    # One ordered boundary. q is a material longitude, not screen X.
    # The shared q=9 meridian is the crown part; it has no duplicated edge.
    outline = [
        (-1,211),(-.55,228),(0,248),(.7,257),(1.45,261),(2,262),
        (2.77,253),(3,249),(4,250),(4.65,238),(5,218),
        (5.3,213),(6,198),(6.65,179),(7,159),
        (7.18,177),(7.47,194),(8,212),(8.22,216),
        (8.12+0.46,206),(9,214),(10,220),(9.99+0.33,212),
        (10.60,201),(10.77,208),(11,190),(11.19,160),
        (11.42,178),(11.8,197),(12,211),(12.35,215),
        (12.65,217),(12.75,226),(12.87,238),(13,249),
        (14,249),(14.35,255),(14.58,261),(15.2,260),
        (16.35,256),(17.25,247),(18,232),(19,211)
    ]
    hem = spline([p[0] for p in outline], [p[1] for p in outline])
    breaks = sorted(set([q for q, v in outline]+keys))
    qs = [breaks[0]]
    for a, b in zip(breaks, breaks[1:]):
        n = max(2, int(math.ceil((b-a)*5)))
        qs.extend(a+(b-a)*k/n for k in range(1, n+1))

    def add(x, y, z, u, v):
        i = len(V)
        V.append((x, y, z))
        UV.append((u, v))
        return i

    pole = add(0, .022, cz+rz, 245, vp)
    ends = [latitude(fringe_hem(q,hem(q))) for q in qs]
    previous = None
    N = 52
    for j in range(1, N+1):
        line = []
        for q, end in zip(qs, ends):
            phi = end*j/N
            s = sin(phi)
            z = cz+rz*cos(phi)
            v = 279-(z-.952)/.00323
            a = longitude(q, v)
            ca = cos(a)
            x = .0032*scale(v)*s*sin(a)
            y = .022-.350*s*ca

            # Smoothly clear the native forehead on the visible face;
            # retain the elliptic return past the lateral tangent.
            front = ease(ca/.42)*ease((top-z)/.078)
            if front:
                native = face_y(x, min(z, 1.621))-.009
                delta = y-native
                y -= front*.5*(delta+math.sqrt(delta*delta+.000009))

            u = 245+x/.0032
            # Exact projection until the surface turns away. On the
            # hidden return stay on temple ink, not on the pale exterior.
            turn = ease((-ca+.015)/.19)*ease((v-92)/45)
            ink = 151 if a < 0 else 343
            line.append(add(x, y, z, u+(ink-u)*turn,
                            v+(184-v)*turn))

        if previous is None:
            F.extend((pole, a, b) for a, b in zip(line, line[1:]))
        else:
            F.extend((previous[k], line[k], line[k+1], previous[k+1])
                     for k in range(len(qs)-1))
        previous = line

    # Only the free hem rolls under. The two rear meridians are open
    # mating boundaries; there is no second cap buried in the head.
    lip = previous
    for k in range(1, 5):
        t = .5*pi*k/4
        inner = []
        for i, q in zip(previous, qs):
            x, y, z = V[i]
            u, v = UV[i]
            a = longitude(q, hem(q))
            inset = .0034*(1-cos(t))
            inner.append(add(x-inset*sin(a), y+inset*cos(a),
                             z-.0022*sin(t), u, v-.65*(1-cos(t))))
        F.extend((lip[k+1], lip[k], inner[k], inner[k+1])
                 for k in range(len(qs)-1))
        lip = inner
    for i,(p,uv) in enumerate(zip(V,UV)):
        x,y,z,u,v = fringe_form(*p,*uv)
        V[i], UV[i] = (x,y,z), (u,v)
    painted("Fringe • continuous parted forelock", "head", V, F, UV)
