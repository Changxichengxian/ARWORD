# SPDX-License-Identifier: CC-BY-NC-SA-4.0
"""Shape hooks for the continuous fringe. UV coordinates are source pixels.

In build(), wrap the original hem evaluator once, before computing ends:
    painted_hem = hem
    hem = lambda q: fringe_hem(q, painted_hem(q))

Build the pole, shell and rolled lip normally, then before painted():
    for i, (p, uv) in enumerate(zip(V, UV)):
        x, y, z, u, v = fringe_form(*p, *uv)
        V[i], UV[i] = (x, y, z), (u, v)

Apply back_cap_form only to the rear mantle, in the same head-local frame.
"""

import math
from bisect import bisect_right

__all__ = ("fringe_form", "fringe_hem", "back_cap_form")


def _rise(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


def _bell(x, center, width):
    t = (x - center) / width
    return math.exp(-t * t)


# A single-valued material edge. The large changes in projected X at the
# cheeks already come from longitude(q,v); no secondary cheek tooth is needed.
_Q = (-1., -.3, .7, 2., 3., 4., 5., 6., 6.65, 7.,
      7.47, 8., 9., 9.72, 10., 10.60, 11.19, 11.65,
      12.35, 13., 14., 14.75, 16., 17.25, 18., 19.)
_V = (211., 231., 250., 258., 251., 236., 214., 188., 164., 157.,
      176., 193., 209., 215., 207., 185., 158., 171.,
      201., 224., 244., 257., 254., 245., 231., 211.)


def _tangents():
    h = [b - a for a, b in zip(_Q, _Q[1:])]
    d = [(b - a) / s for a, b, s in zip(_V, _V[1:], h)]
    m = [d[0]]
    for i in range(1, len(d)):
        a, b = d[i - 1:i + 1]
        w = 2.0 * h[i] + h[i - 1]
        k = h[i] + 2.0 * h[i - 1]
        m.append((w + k) / (w / a + k / b) if a * b > 0 else 0.0)
    return tuple(m + [d[-1]])


_M = _tangents()


def fringe_hem(station, original_v):
    if not _Q[0] < station < _Q[-1]:
        return original_v
    i = bisect_right(_Q, station) - 1
    h = _Q[i + 1] - _Q[i]
    t = (station - _Q[i]) / h
    s = 1.0 - t
    return (s * s * ((1.0 + 2.0 * t) * _V[i] + t * h * _M[i])
            + t * t * ((1.0 + 2.0 * s) * _V[i + 1] - s * h * _M[i + 1]))


def fringe_form(x, y, z, u, v):
    # Use the *position* to locate the lobe. UV on the hidden return
    # has already been pulled into the temple and is not a position.
    px = 245.0 + x / .00320
    py = 279.0 + (.952 - z) / .00323
    front = 1.0 - _rise(-.115, .018, y)
    center = _bell(px, 245., 34.)
    fall = _rise(83., 208., py)
    lock = center * front

    # Slight counter-bend at the root, then a rightward sweep. Keep the
    # paint attached to the surface rather than reprojecting the moved X.
    sweep = 4.7 * fall - 3.5 * _bell(py, 134., 30.) * _rise(76., 106., py)
    x += .00320 * sweep * lock
    y -= .0055 * lock * _bell(py, 155., 43.)

    # Roll sideways first, then rearwards. Fade before the rear mating
    # meridians; pushing the entire perimeter back would open a seam.
    side = px - 245.
    wing = (_rise(42., 71., abs(side)) * _rise(155., 244., py)
            * (1.0 - _rise(-.090, .034, y)))
    x += math.copysign(.009 * wing, side)
    y += .013 * wing
    z += .003 * wing

    # Sample just inside each painted mass near the free edge. In
    # particular, going straight up the texture from a hooked cheek tip
    # would hit sclera/lash pixels; follow the cheek *out* as well as up.
    cheek = _rise(39., 59., abs(side)) * _rise(202., 255., py) * front
    u += math.copysign(7.0 * cheek, side)
    v -= 8.0 * cheek
    tip = _bell(px, 252., 22.) * _rise(179., 212., py) * front
    v -= 4.5 * tip
    # Leave the single front crown print alone; the second print belongs
    # to the intersecting mantle, not to a second meridian in this mesh.
    return x, y, z, u, v


def back_cap_form(x, y, z):
    # Sink the overlapping sector along its ellipsoidal inward normal.
    # An angular mask alone is singular at the pole: blend to a shallow
    # continuous pole seat there. Leave the posterior profile in place.
    dy = y - .022
    lateral = x / .410
    depth = dy / .350
    r = math.hypot(lateral, depth)
    az = -depth / max(r, 1.e-9)
    sector = _rise(-.29, .24, az)
    polar = _rise(.035, .25, r)
    overlap = (1.0 - polar) + polar * sector
    seat = overlap * _rise(1.195, 1.465, z)
    if seat == 0.0:
        return x, y, z
    nx = lateral / .410
    ny = depth / .350
    nz = (z - 1.238) / (.405 * .405)
    length = math.sqrt(nx * nx + ny * ny + nz * nz)
    inset = .017 * seat / max(length, 1.e-9)
    return x - nx * inset, y - ny * inset, z - nz * inset
