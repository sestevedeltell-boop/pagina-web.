"""Oleaje de la piscina y del jacuzzi (numpy).

La superficie del agua es una rejilla; en cada fotograma se le da la altura de una suma de ondas
con la dispersión del agua real (gravedad + tensión superficial). Las ondas reales son las que
dibujan las cáusticas del fondo (Cycles, "shadow caustics")."""
import numpy as np


def spectrum(seed, n, lmin, lmax, slope, wind, spread):
    r = np.random.default_rng(seed)
    lam = np.exp(r.uniform(np.log(lmin), np.log(lmax), n))
    k = 2 * np.pi / lam
    ang = wind + r.normal(0, spread, n)
    a = slope / k * r.uniform(.5, 1.2, n)
    w = np.sqrt(9.81 * k + 7.4e-5 * k ** 3)
    ph = r.uniform(0, 2 * np.pi, n)
    return np.stack([k * np.cos(ang), k * np.sin(ang), a, w, ph], 1)


POOL = spectrum(11, 56, .12, 1.4, .0065, .6, .8)     # brisa suave
SPA_CALM = spectrum(5, 40, .06, .5, .012, 0., 3.)
SPA_JETS = spectrum(6, 70, .04, .35, .05, 0., 3.)


def waves(x, y, t, spec):
    h = np.zeros_like(x)
    for kx, ky, a, w, ph in spec:
        h += a * np.sin(kx * x + ky * y - w * t + ph)
    return h


def spa_height(x, y, t, cx, cy, boil, jets):
    """Jacuzzi: calma + burbujeo (ondas cortas y anillos que salen de cada boquilla)."""
    h = waves(x, y, t, SPA_CALM)
    if boil > 0:
        h += boil * waves(x, y, t * 1.7, SPA_JETS)
        for (jx, jy) in jets:
            r = np.hypot(x - jx, y - jy)
            h += boil * .006 * np.exp(-r / .35) * np.sin(r * 55 - t * 30)
        r0 = np.hypot(x - cx, y - cy)
        h += boil * .004 * np.exp(-r0 / .5) * np.sin(r0 * 40 - t * 24)
    return h
