# SPDX-License-Identifier: CC-BY-NC-SA-4.0
from math import atan2, degrees, hypot


def _ramp(lo, hi, x):
    t = min(1.0, max(0.0, (x - lo) / (hi - lo)))
    return t * t * (3.0 - 2.0 * t)


def _profile(z, knots):
    for (a, p), (b, q) in zip(knots, knots[1:]):
        if z < b:
            return p + (q - p) * _ramp(a, b, z)
    return knots[-1][1]


def _uv(px, py, width, height):
    # Source coordinates index pixels from the top left; Blender indexes
    # normalized image space from the bottom left.
    px = min(width - 1.0, max(0.0, px))
    py = min(height - 1.0, max(0.0, py))
    return ((px + 0.5) / width, 1.0 - (py + 0.5) / height)


def project_hair(x, y, z):
    fy = 279.0 - (z - 0.952) / 0.00323
    front = _uv(245.0 + x / 0.0032, fy, 450, 656)
    back = _uv(211.0 - x / 0.0032, fy, 450, 656)

    sy = 601.0 - (z - 0.952) * (601.0 - 130.0) / (1.643 - 0.952)
    scale = (767.0 - 218.0) / (0.35 + 0.302)
    sx_head = 218.0 + (y + 0.302) * scale

    # Follow the sweep of the large side lock, not the contour of the
    # neck. Each row is affine in depth, so there is no fold at the ear.
    # aft_px is the correspondence at model depth +0.29, not a UV clamp.
    aft_px = _profile(z, (
        (0.30, 694.0), (0.45, 836.0), (0.65, 906.0),
        (0.80, 844.0), (0.96, 755.0), (1.12, 728.0),
    ))
    lock_scale = _profile(z, (
        (0.30, 200.0), (0.45, 400.0), (0.65, 628.0),
        (0.85, 700.0), (1.12, scale),
    ))
    sx_lock = aft_px + (y - 0.29) * lock_scale
    head = _ramp(0.96, 1.19, z)
    sx = sx_lock + head * (sx_head - sx_lock)

    # Register the part locally. On the side drawing the root is forward
    # of the profile midpoint; the highest point of the skull is not the
    # part. Preserve the nose/occiput registration below the crown.
    root = (_ramp(1.45, 1.60, z)
            * (1.0 - _ramp(0.09, 0.29, abs(y))))
    sx += root * (378.0 - (218.0 + 0.302 * scale))
    side = _uv(sx, sy, 1024, 1536)

    # Shift the angular axis aft as the hair falls behind the shoulders.
    # Use exclusive adjacent-view transitions (no three-way bangs).
    axis_y = 0.024 + 0.105 * (1.0 - _ramp(0.73, 1.06, z))
    angle = degrees(atan2(abs(x), axis_y - y))
    to_side = _ramp(44.0, 60.0, angle)
    to_back = _ramp(127.0, 149.0, angle)
    wf = 1.0 - to_side
    wb = to_back

    # Low frontal projections near the sagittal plane would land on the
    # apron, and low central rear projections on the bow. Prefer the
    # swept side lock there instead of mixing in extended dark pigment.
    lower = 1.0 - _ramp(0.84, 0.97, z)
    wf *= 1.0 - lower * (1.0 - _ramp(0.24, 0.38, abs(x)))
    bow = 1.0 - _ramp(0.065, 0.14, abs(z - 0.635))
    wb *= 1.0 - bow * (1.0 - _ramp(0.16, 0.27, abs(x)))

    # A single projector owns the common part and the aerial curl.
    # This also removes the angular singularity at the crown pole.
    crown = (_ramp(1.47, 1.59, z)
             * (1.0 - _ramp(0.065, 0.21, hypot(x, y - axis_y))))
    own = max(crown, _ramp(1.625, 1.654, z))
    wf += (1.0 - wf) * own
    wb *= 1.0 - own
    ws = max(0.0, 1.0 - wf - wb)
    return [front, side, back, (wf, ws, wb)]
