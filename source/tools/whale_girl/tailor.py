# SPDX-License-Identifier: CC-BY-NC-SA-4.0
# See assets/characters/whale-girl-CREDITS.txt.


def tailor(name, x, y, z):
    n = name.casefold()
    base, dot, suffix = n.rpartition(".")
    if dot and suffix.isdecimal():
        n = base

    def smooth(t):
        t = min(1.0, max(0.0, t))
        return t * t * (3.0 - 2.0 * t)

    if n in (
        "sixteen pressed fan pleats", "indigo woven hem",
        "shell petal underskirt", "petticoat picot braid",
        "separate u-front pinafore", "eight gathered apron shells",
        "apron pearl seam", "fine shell edging", "wrapped cummerbund",
        "satin stitched sounding whale", "embroidered whale fin",
        "whale seed pearl", "delft wave flourish", "butterfly bow cinch",
        "left indigo butterfly loop", "right indigo butterfly loop",
        "left gilt bow selvedge", "right gilt bow selvedge",
        "left fishtail ribbon", "right fishtail ribbon",
        "left ribbon end gilt", "right ribbon end gilt",
        "left ribbon outer gilt", "right ribbon outer gilt",
    ):
        f = smooth((0.685 - z) / (0.685 - 0.386))
        return (x * (1.0 + 0.41 * f),
                0.006 + (y - 0.006) * (1.0 + 0.41 * f),
                z - 0.106 * f)

    if n == "princess seamed dress":
        # Raise only the narrowing neckline above the shoulder ring.
        return x, y, z + 0.020 * smooth((z - 0.910) / 0.021)

    if n in ("cream pintucked stomacher", "fluted bib side flounce",
             "bib rouleau", "falling throat ribbon", "cravat wing",
             "gilt scallop bezel", "repousse scallop rib"):
        # A common lift, nearly rigid around the clasp and its carved ribs.
        lift = 0.033 * smooth((z - 0.710) / 0.150)
        tuck = smooth((z - 0.898) / 0.022)
        return x * (1.0 - 0.12 * tuck), y, z + lift

    return x, y, z


def textile_uv(name, x, y, z):
    from math import cos, pi, sin

    n = name.casefold()
    base, dot, suffix = n.rpartition(".")
    if dot and suffix.isdecimal():
        n = base

    def clamp(t):
        return min(1.0, max(0.0, t))

    if n == "separate u-front pinafore" and y < 0.0:
        # Recover the panel coordinates, not a rectangular skirt bounding box.
        h = clamp((z - 0.386) / 0.29)
        u = 1.0 - h
        lo, hi = 0.0, 1.0
        for _ in range(24):
            q = (lo + hi) * 0.5
            bottom = 0.222 + 0.207 * q ** 3
            t = clamp((h - bottom) / (1.0 - bottom))
            r = 0.123 + 0.157 * u ** 0.85 + 0.003 * cos(5.0 * pi * q) * u
            if r * sin(q * (0.99 - 0.13 * t)) < abs(x):
                lo = q
            else:
                hi = q
        q = (lo + hi) * 0.5
        bottom = 0.222 + 0.207 * q ** 3
        t = clamp((h - bottom) / (1.0 - bottom))
        # Pixel rows counted down from the top. Stay inboard of the
        # pearl seam, following its curved lower edge at every column.
        half = 74.0 * (1.0 - t) + 41.0 * t
        v = (454.0 - 19.0 * q ** 3) * (1.0 - t) + 377.0 * t
        return 247.0 + (-q if x < 0.0 else q) * half, v

    if n == "cream pintucked stomacher" and y < 0.0:
        t = clamp((z - 0.680) / 0.238)
        half = 0.052 + 0.035 * sin(0.59 * pi * t) + 0.008 * t
        q = max(-1.0, min(1.0, x / half))
        # The uninterrupted fold below the ribbon tips supplies the linen;
        # the cravat and scallop clasp above it remain dimensional.
        return 249.0 + q * (20.0 + 5.0 * t), 347.0 - 13.0 * t

    return None


def textile_skip(name):
    n = name.casefold()
    base, dot, suffix = n.rpartition(".")
    if dot and suffix.isdecimal():
        n = base
    return n in ("satin stitched sounding whale", "embroidered whale fin",
                 "whale seed pearl", "delft wave flourish")
