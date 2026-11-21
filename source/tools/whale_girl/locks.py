import math
from geometry import painted


def _sat(t):
    return min(1.0, max(0.0, t))


def _ease(t):
    t = _sat(t)
    return t * t * (3.0 - 2.0 * t)


def _row(z):
    return 279.0 + (.952 - z) / .00323


def _profile(v, keys):
    for (a, p), (b, q) in zip(keys, keys[1:]):
        if v <= b:
            return p + (q - p) * _ease((v - a) / (b - a))
    return keys[-1][1]


def trim_mantle(x, y, z):
    # Apply to original BACK mantle vertices only, before skinning.
    v = _row(z)
    if v <= 236:
        return x, y, z

    a = abs(x)
    blend = _ease((v - 236) / 21)
    # Maximum projected half-width, not a depth mask: a rear surface
    # moved straight backwards would still show through both windows.
    cap = _profile(v, ((236, .401), (259, .361), (284, .371),
                       (313, .410), (334, .440), (360, .475),
                       (380, .461), (404, .398), (432, .358),
                       (474, .302)))
    shoulder = cap - .082
    excess = max(0.0, a - shoulder)
    narrow = shoulder + .082 * math.tanh(excess / .082)
    ax = a + blend * (min(a, narrow) - a)
    flank = _ease((a - .14) / .23)
    hem = _ease((v - 389) / 70)
    lobe = .5 + .5 * math.cos(39.0 * ax + (.43 if x > 0 else 0))
    return (math.copysign(ax, x),
            y + blend * flank * (.047 + .011 * lobe),
            z + hem * (.009 + .027 * flank) * (1.0 - lobe))


def ear_color(x, y, z):
    # Optional RGB for EXISTING fin material only. The approved ear has
    # pearl lower vanes under a blue lip; the render reads mostly slate.
    u = abs(x) / .0032
    lip = 214.0 + .14 * (u - 148.0)
    pearl = _ease((_row(z) - lip + 1.0) / 7.0)
    light = _ease((_row(z) - lip - 3.0) / 9.0)
    return (.16 + .65 * pearl + .13 * light,
            .25 + .57 * pearl + .12 * light,
            .60 + .36 * pearl + .04 * light)


# Guides in approved-front.png, top-left origin. Each station is
# (centre u, centre v, half breadth measured NORMAL to the brush path).
# The little waist near row 320 is intentional. The two strokes lap
# there, part again at the belly, then lap at the base of the turn.
_MAIN_R = (
    (134,244,6), (137,260,9), (135,280,11), (127,297,14),
    (111,312,17), (98,326,16), (99,337,10), (102,354,17),
    (106,372,24), (113,390,22), (116,405,17), (113,423,15),
    (104,436,13), (89,445,10), (81,455,8), (82,465,6),
    (87,471,3), (96,474,0))
_SILK_R = (
    (124,244,4), (119,261,3.5), (108,277,3.2), (93,292,4.8),
    (85,306,5.6), (85,318,4.8), (77,326,5.7), (63,339,7),
    (56,353,6.5), (56,367,7), (63,381,8), (78,391,7.8),
    (89,401,7), (91,415,7.5), (85,426,8.4), (73,428,8.2),
    (61,424,5.6), (54,416,3.8), (54,406,2.7), (58,401,1.5),
    (64,401,0))
_MAIN_L = (
    (357,244,6), (354,262,8), (357,282,11), (365,300,14),
    (382,315,17), (395,328,15), (392,341,10.5), (389,357,16.5),
    (387,373,21), (379,388,18), (376,405,15), (381,422,14),
    (392,435,12), (405,442,10), (413,450,8), (413,460,6.6),
    (407,468,4), (396,473,0))
_SILK_L = (
    (369,242,3.7), (374,259,3.1), (383,274,3.6), (398,289,5),
    (408,304,6), (409,317,4.8), (414,325,4.6), (427,338,6.2),
    (435,353,5.4), (436,367,4.5), (431,381,4.7), (420,391,5.8),
    (408,396,7.8), (399,407,8), (401,420,8.6), (411,425,9),
    (423,425,7.6), (432,419,4.8), (437,411,2.3), (437,403,0))


def _sample(g, i, t):
    a, b = g[i:i+2]
    p, q = g[max(i-1, 0)], g[min(len(g)-1, i+2)]
    out, vel = [], []
    for k in range(3):
        m, n = .5 * (b[k]-p[k]), .5 * (q[k]-a[k])
        c = 3*(b[k]-a[k])-2*m-n
        d = 2*(a[k]-b[k])+m+n
        out.append(a[k]+t*(m+t*(c+t*d)))
        vel.append(m+t*(2*c+3*t*d))
    return out, vel


def _weights(x, y=None, z=None):
    if z is None:
        x, y, z = x
    h = _ease((_row(z) - 245.0) / 48.0)
    return {"head": 1.0-h, ("HairL" if x > 0 else "HairR"): h}


def _sheet(name, guide, fine):
    verts, faces, pixels = [], [], []
    # Cross section runs across the painted front and returns along the
    # back. Paired edge vertices give actual narrow, closed side walls.
    section = ([-1, -.78, -.44, 0, .41, .76, 1] +
               [1, .64, 0, -.64, -1])
    count = len(section)
    steps = 4 * (len(guide)-1)

    def vertex(u, v, y):
        pixels.append((u, v))
        verts.append(((u-245)*.0032, y, .952+(279-v)*.00323))
        return len(verts)-1

    def floor_y(v):
        # Side hair travels aft of the sleeve/hand rather than following
        # the apron surface forwards. Finer overstroke is nearer camera.
        return (.006 + .079*_ease((v-251)/117)
                - .012*_ease((v-419)/40)
                - (.030 if fine else 0.0)*_ease((v-244)/59))

    for k in range(steps):
        (u, v, w), (du, dv, _) = _sample(guide, k//4, (k%4)/4)
        length = math.hypot(du, dv)
        nx, nv = dv/length, -du/length
        phase = (v-250)*.024 + (.85 if fine else 0)
        # Reverse the roll, not the winding, on the opposing temple.
        roll = (.22*math.sin(phase) + .09) * (1 if u > 245 else -1)
        for j, s in enumerate(section):
            arch = 1.0-s*s
            # Both faces converge towards an ink-thin hem. Thickness
            # scales down with breadth so the apex is not a chisel end.
            depth = (roll*s - .34*arch if j < 7
                     else roll*s + .13*arch + .036)
            vertex(u+nx*w*s, v+nv*w*s, floor_y(v)+w*.0032*depth)

        b = k*count
        if k:
            for j in range(count):
                i = (j+1) % count
                faces.append((b-count+j, b+j, b+i, b-count+i))

    # Root cap and a single sewn apex (no coincident zero-width ring).
    u, v, w = guide[0]
    root = vertex(u, v, floor_y(v)-.08*w*.0032)
    u, v, _ = guide[-1]
    tip = vertex(u, v, floor_y(v))
    last = (steps-1)*count
    for j in range(count):
        i = (j+1) % count
        faces.append((root, j, i))
        faces.append((last+j, tip, last+i))
    return painted("Temple silk " + name, _weights, verts, faces, pixels)


def build():
    # Replacement pass, not additive to the old long-lock generator.
    # Four closed sheets, 3416 vertices; no alteration to cheek tufts,
    # ear topology, crown, arm weights or forehead.
    return (_sheet("R tide", _MAIN_R, False),
            _sheet("R returning filament", _SILK_R, True),
            _sheet("L tide", _MAIN_L, False),
            _sheet("L returning filament", _SILK_L, True))
