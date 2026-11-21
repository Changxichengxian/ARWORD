# SPDX-License-Identifier: CC-BY-NC-SA-4.0
# See assets/characters/whale-girl-CREDITS.txt.
#
# cloth_form takes tailor() OUTPUT, in character rest space (not posed
# space). Apply the same point map to Basis and to each absolute key.
# skirt_paint takes the resulting rest point and returns source pixels,
# origin TOP LEFT. Bake/store these coordinates before posing the character.

from math import atan2, cos, exp, pi, sin, sqrt


def _part(name):
    n = name.strip().casefold()
    while True:
        stem, dot, suffix = n.rpartition(".")
        if not dot or not suffix.isdecimal():
            break
        n = stem
    if n.startswith("left "):
        return n[5:], 1
    if n.startswith("right "):
        return n[6:], -1
    return n, 0


def _sat(t):
    return max(0.0, min(t, 1.0))


def _s(a, b, x):
    t = _sat((x - a) / (b - a))
    return t * t * (3.0 - 2.0 * t)


def _bell(t):
    return exp(-t * t)


_SKIRT = frozenset((
    "sixteen pressed fan pleats", "indigo woven hem",
    "shell petal underskirt", "petticoat picot braid",
    "separate u-front pinafore", "eight gathered apron shells",
    "apron pearl seam", "fine shell edging", "wrapped cummerbund",
    "satin stitched sounding whale", "embroidered whale fin",
    "whale seed pearl", "delft wave flourish", "butterfly bow cinch",
    "indigo butterfly loop", "gilt bow selvedge", "fishtail ribbon",
    "ribbon end gilt", "ribbon outer gilt",
))
_BODICE = frozenset((
    "princess seamed dress", "cream pintucked stomacher",
    "fluted bib side flounce", "bib rouleau", "falling throat ribbon",
    "cravat wing", "gilt scallop bezel", "repousse scallop rib",
))
_FOOT = frozenset((
    "leather sole", "rounded patent vamp", "exposed instep", "button strap",
    "square brass buckle", "buckle tongue",
))
_DIGITS = ("digit 1", "digit 2", "digit 3", "digit 4")


def _arm_axis(q):
    # Interpolate the actual joint line; don't scale from the world origin.
    a = _sat((q - .155) / .160)
    b = _sat((q - .315) / .145)
    return -.003 * b, .903 - .011 * a - .007 * b


def _skirt_angle(x, y):
    # Parametric angle of an elliptical ring, zero at center front.
    return atan2(x * .72, .006 - y)


def cloth_form(name, x, y, z):
    n, side = _part(name)

    if n in _SKIRT:
        # One continuous cage for all layers, including the stitchwork.
        # Add volume through the hip rather than just stretching the last
        # ring (which makes a cone). The slip continues the same hem field.
        h = _sat((.682 - z) / .402)
        belly = sin(pi * h)
        a = _skirt_angle(x, y)
        fold = .010 * _s(.10, .85, h) * cos(16.0 * a)
        sx = 1.22 - .065 * h + .115 * belly + fold
        sy = 1.16 - .045 * h + .095 * belly + fold
        # A shallow upsweep at the sides; no blanket lowering of the hem.
        return (x * sx, .006 + (y - .006) * sy,
                z + (.048 * sin(a) ** 2 - .018 * max(0.,cos(a))**2)
                * _s(.24, .97, h))

    if n in _BODICE:
        # Match the waist cage. Keep the neck opening small but carry the
        # princess shoulder ring well inside the sleeve cap.
        neck = _s(.910, .954, z)
        return (x * (1.22 - .13 * neck),
                y * (1.16 - .08 * neck), z)

    if n == "neck":
        return x * 1.09, y * 1.08, z

    if not side:
        return x, y, z

    q = side * x
    if n in ("arm", "gathered bishop sleeve", "gauntlet cuff", "cuff button"):
        cy, cz = _arm_axis(q)
        if n == "gathered bishop sleeve":
            # Fuller crown and a second gather just above the cuff.
            # Extend the INNER lip into the bodice, not the distal seam
            # along the forearm. The elbow station stays at its own x.
            crown = _bell((q - .165) / .059)
            blouse = _bell((q - .356) / .054)
            sy = 1.34 + .25 * crown + .18 * blouse
            sz = 1.30 + .30 * crown + .16 * blouse
            x -= side * .029 * (1.0 - _s(.135, .183, q))
        elif n == "arm":
            sy, sz = 1.19, 1.22
        else:
            sy, sz = 1.42, 1.38
        return x, cy + (y - cy) * sy, cz + (z - cz) * sz

    if n == "thenar and hypothenar pad":
        return x, -.003 + 1.23 * (y + .003), .885 + 1.42 * (z - .885)

    if n in _DIGITS:
        i = _DIGITS.index(n)
        tip = (.537, .540, .535, .527)[i]
        yc = -.022 + .012 * i
        rise = (.011 if side > 0 else .019) - .0015 * i
        # Subtract the constructed centerline before padding the section:
        # scaling absolute z would magnify the hooked distal joint.
        t = _s(.499, tip - .002, q)
        old_z = (.885 + .001 * _s(.495, .509, q)
                 + rise * (.48 * _s(.509, tip - .008, q)
                           + .52 * _s(tip - .008, tip - .002, q))
                 + .002 * _s(tip - .002, tip, q))
        old_y = yc * (.83 + .17 * _s(.495, .509, q) + .06 * t)
        new_y = -.003 + .87 * (old_y + .003)
        new_z = .885 + .0025 * sin(pi * t) - .003 * t
        # Ease the final taper into a short blunt pad. Retain individual
        # tips and all skin weights, rather than welding fingers together.
        end = _s(tip - .009, tip, q)
        return (side * (q - .0035 * end),
                new_y + (y - old_y) * (1.04 + .23 * end),
                new_z + (z - old_z) * (1.16 + .23 * end))

    if n == "opposed thumb":
        t = _s(.478, .499, q)
        return (side * (q - .002 * t),
                -.011 + .90 * (y + .011),
                .886 + 1.10 * (z - .886) - .015 * t)

    if n == "leg":
        # Follow the slightly wandering center of each loft, including the
        # ankle pivot shared with the shoe. Leave both leg lengths intact.
        cx = (.092 - .002 * _s(.17, .256, z)
              - .002 * _s(.319, .404, z) - .013 * _s(.50, .55, z))
        calf = _bell((z - .198) / .090)
        return (side * (cx + (q - cx) * (1.27 + .15 * calf)),
                .005 + (y - .005) * (1.18 + .11 * calf), z)

    if n in _FOOT:
        # Shared horizontal last for vamp, sole, strap and hardware.
        # Dome the instep into the ankle opening while leaving the
        # planting plane and strap height alone.
        lift = 0.0
        if n == "exposed instep":
            lift = .014 * _s(.045, .087, z)
        elif n == "rounded patent vamp":
            lift = .008 * _s(.019, .061, z)
        return (side * (.092 + 1.38 * (q - .092)),
                .005 + 1.14 * (y - .005), z + lift)

    return x, y, z


def skirt_paint(name, x, y, z):
    n, _ = _part(name)
    if n not in ("sixteen pressed fan pleats", "indigo woven hem",
                 "shell petal underskirt", "petticoat picot braid",
                 "eight gathered apron shells", "fluted bib side flounce"):
        return None

    a = _skirt_angle(x, y)
    # A mirrored half-turn repeat: linear in ring angle, continuous at
    # both sides and at the rear meridian (no UV jump across a back face).
    phase = 1.0 - abs(2.0 * abs(a) / pi - 1.0)
    if a < 0.0:
        phase = -phase
    p = abs(phase)

    if n in ("sixteen pressed fan pleats", "indigo woven hem"):
        # Follow the curved navy band, not its bounding rectangle: the
        # upper center of that rectangle contains cream apron scallops,
        # and the lower corners fall OUTSIDE the navy hem.
        h = _sat((.678 - z) / .398)
        if n == "indigo woven hem":
            h = .88
        u = 249.0 + 116.0 * phase
        crown = sqrt(max(0.0, 1.0 - (.85 * p) ** 2))
        bottom = 466.0 + 55.0 * crown
        return u, bottom - 27.0 + 25.0 * h

    if n in ("shell petal underskirt", "petticoat picot braid"):
        # Interior of the broad center cream petal, below the navy and
        # above its inked bottom contour. Tile it on the 24 petal lobes.
        w = cos(24.0 * a)
        return 251.0 + 8.0 * w, 532.0 + 6.0 * _sat((.283 - z) / .035)

    if n == "eight gathered apron shells":
        # Sample the interior of the lower-center apron shell, not the
        # side silhouette where hair shows between the gathered shells.
        return 251.0 + 7.0 * sin(16.0 * a), 468.0 + 5.0 * cos(16.0 * a)

    # Small side ruffles on the stomacher use vanilla, not navy. Use
    # the same clean shell interior rather than the adjacent throat bow.
    return 251.0 + 6.0 * sin(155.0 * z), 469.0 + 3.0 * cos(155.0 * z)


def cloth_palette(name):
    # sRGB base colors, not linear multipliers for the sampled artwork.
    n, _ = _part(name)
    if n in _DIGITS or n in ("thenar and hypothenar pad", "opposed thumb", "arm"):
        return "#FFD7CD"
    if n in ("leg", "exposed instep"):
        return "#FFDFD0"
    if n in ("rounded patent vamp", "button strap"):
        return "#434779"
    if n == "leather sole":
        return "#34344F"
    if n in ("gathered bishop sleeve", "princess seamed dress"):
        return "#343452"
    if n == "gauntlet cuff":
        return "#FFEBDB"
    return None
