import math


def _uv(x, z):
    return 245.0 + x / 0.00320, 279.0 - (z - 0.952) / 0.00323


def _fade(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


def _wash(dx, dv, width, height):
    a, b = dx / width, dv / height
    return math.exp(-(a * a + b * b))


def _glaze(rgb, pigment, amount):
    return tuple(c + amount * (p - c) for c, p in zip(rgb, pigment))


def complexion(x, y, z):
    u, v = _uv(x, z)
    h = abs(u - 245.0)
    front = _fade(0.015, 0.19, -y)
    rgb = (0.985, 0.875, 0.811)
    if not front:
        return rgb

    # Cream through the central planes; leave a peach turn along the jaw.
    rgb = _glaze(rgb, (1.0, 0.934, 0.878),
                 front * 0.80 * _wash(h, v - 234.0, 72.0, 53.0))
    rgb = _glaze(rgb, (1.0, 0.83, 0.755),
                 front * 0.32 * _wash(h, v - 274.0, 52.0, 11.0))

    # Oblique watercolor patches rather than circles under the eyes.
    q = h - 42.0
    cheek = v - 248.0 + 0.12 * q
    rgb = _glaze(rgb, (1.0, 0.726, 0.692),
                 front * 0.54 * _wash(q, cheek, 23.0, 9.5))
    for offset in (-4.2, 0.0, 4.2):
        stroke = _wash(q - offset + 0.62 * cheek, cheek, 0.70, 1.85)
        rgb = _glaze(rgb, (0.984, 0.699, 0.66), front * 0.22 * stroke)

    # Broken warm lid wash, not a second ink contour.
    eye = h - 41.0
    arch = 203.5 + 0.013 * eye * eye - 0.06 * eye
    rgb = _glaze(rgb, (0.94, 0.727, 0.684),
                 front * 0.29 * _wash(eye, v - arch, 19.0, 3.5))
    lower = 242.3 - 0.012 * eye * eye
    rgb = _glaze(rgb, (1.0, 0.958, 0.906),
                 front * 0.22 * _wash(eye, v - lower, 14.0, 2.0))

    rgb = _glaze(rgb, (1.0, 0.758, 0.686),
                 front * 0.44 * _wash(h, v - 244.6, 5.3, 3.4))
    rgb = _glaze(rgb, (1.0, 0.969, 0.891),
                 front * 0.56 * _wash(u - 244.4, v - 242.8, 2.2, 1.35))
    return _glaze(rgb, (.88,.65,.61), .26*_fade(266,280,v))


def sculpt_face(x, y, z):
    u, v = _uv(x, z)
    h = abs(u - 245.0)
    # Compact support below the blink sweep, clear of side locks and neck.
    w = (_fade(0.055, 0.21, -y) * _fade(243.0, 251.5, v)
         * (1.0 - _fade(279.0, 285.0, v))
         * (1.0 - _fade(53.0, 65.0, h)))
    if not w:
        return x, y, z

    cheek = _wash(h - 41.0, v - 255.0, 19.0, 11.0)
    jaw = _wash(h - 22.0, v - 272.0, 15.0, 8.5)
    chin = _wash(h, v - 277.0, 22.0, 7.5)
    # Keep the lip contact patch fixed so the separate smile stays seated.
    free = _fade(1.0, 2.2, math.hypot((u - 246.1) / 6.5,
                                       (v - 258.8) / 3.0))
    w *= free
    dx = math.tanh(x / 0.036) * (0.0046 * cheek - 0.0025 * jaw)
    return (x + w * dx,
            y - w * (0.0054 * cheek + 0.0028 * chin),
            z + w * (0.0013 * cheek + 0.0020 * chin))


def smile(x, y, z):
    # Reverse the old arch about its corner height, retaining ribbon thickness.
    dx = x - 0.0035
    t = min(1.0, abs(dx) / (4.1 * 0.00320))
    shoulder = t * t * (2.0 - t)
    old_center = 1.015 + (2.35 * 0.00323) * (1.0 - shoulder)
    new_center = 1.015 + 0.00323 * (0.25 + 1.32 * shoulder)
    return 0.0035 + 1.09 * dx, y, new_center + (z - old_center)
