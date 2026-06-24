"""Per-cue recipes — the authored 'plan'. Each recipe(rng, v) -> mono float
array (pre-normalize). `v` is the 0-based variant index (hot cues bake 3).
Variation across `v` shifts scale degree / micro-params so takes differ."""
from tools.sfx_synth.primitives import (
    NOTE, SR, mallet, bell, woodknock, water_plip, noise_texture, pad,
    place, air,
)
import numpy as np

_RING = ["C5", "D5", "E5", "G5", "A5", "C6"]


def _deg(base, v, ring=_RING):
    return NOTE[ring[(ring.index(base) + v) % len(ring)]]


def merge_soft(rng, v):
    return air(rng, mallet(rng, _deg("E5", v), dur=0.30, tau=0.11), 0.18)


def merge_success(rng, v):
    lo = [("G5", "C6"), ("A5", "C6"), ("E5", "A5")][v % 3]
    buf = np.zeros(int(SR * 0.5))
    buf = place(buf, mallet(rng, NOTE[lo[0]], 0.26, tau=0.10), 0.0)
    buf = place(buf, mallet(rng, NOTE[lo[1]], 0.34, tau=0.13) * 0.95, 0.085)
    return air(rng, buf, 0.20)


def button_tap(rng, v):
    return woodknock(rng, freq=[200.0, 210.0, 225.0][v % 3])


def item_pickup(rng, v):
    return mallet(rng, _deg("A5", v), dur=0.14, tau=0.05, attack=0.002)


def item_drop(rng, v):
    return mallet(rng, _deg("E5", v), dur=0.16, tau=0.06)


def bag_in(rng, v):
    return air(rng, mallet(rng, NOTE["C5"], dur=0.16, tau=0.06,
                           partials=(1, 2), amps=(1.0, 0.25)), 0.10)


def bag_out(rng, v):
    return mallet(rng, NOTE["G5"], dur=0.16, tau=0.06)


def star_earn(rng, v):
    return air(rng, bell(rng, NOTE["A5"], dur=0.30, tau=0.16), 0.22)


def star_pop(rng, v):
    return bell(rng, NOTE["E6"], dur=0.16, tau=0.08)


def water_pop(rng, v):
    return air(rng, water_plip(rng), 0.15, room=0.08)


def rain_refill(rng, v):
    buf = pad(rng, NOTE["C4"], 0.6, level=0.12)
    for i, nm in enumerate(["A5", "E5", "G5", "C6"]):
        buf = place(buf, water_plip(rng, f0=900 + 80 * i) * 0.7, 0.04 + i * 0.07)
    return air(rng, buf, 0.18)


def bramble_clear(rng, v):
    buf = noise_texture(rng, dur=0.14, tau=0.03, smooth=6, color=2.0)
    wk = woodknock(rng, 160.0, 0.12)
    n = min(len(buf), len(wk))
    return air(rng, np.tanh((buf[:n] + wk[:n]) * 1.1), 0.14)


def tidy_poof(rng, v):
    return air(rng, noise_texture(rng, dur=0.28, tau=0.10, smooth=20), 0.18)


def giver_cheer(rng, v):
    buf = np.zeros(int(SR * 0.4))
    for i, nm in enumerate(["E6", "G6", "C6"]):
        buf = place(buf, bell(rng, NOTE[nm], 0.22, tau=0.1) * 0.9, i * 0.06)
    return air(rng, buf, 0.22)


def coin_earn(rng, v):
    buf = np.zeros(int(SR * 0.42))
    buf = place(buf, bell(rng, NOTE["E6"], 0.22), 0.0)
    buf = place(buf, bell(rng, NOTE["A5"], 0.30) * 0.9, 0.07)
    return air(rng, buf, 0.22)


def invalid_soft(rng, v):
    buf = np.zeros(int(SR * 0.34))
    buf = place(buf, mallet(rng, NOTE["D4"], 0.22, tau=0.07, attack=0.006), 0.0)
    buf = place(buf, mallet(rng, NOTE["C4"], 0.26, tau=0.09) * 0.85, 0.06)
    return air(rng, buf, 0.12)


def unlock(rng, v):
    buf = np.zeros(int(SR * 0.55))
    for i, nm in enumerate(["C5", "E5", "G5"]):
        buf = place(buf, mallet(rng, NOTE[nm], 0.34, tau=0.14), i * 0.10)
    return air(rng, buf, 0.24)


def quest_complete(rng, v):
    buf = pad(rng, NOTE["C4"], 0.65, level=0.12)
    for i, nm in enumerate(["G5", "A5", "C6"]):
        buf = place(buf, bell(rng, NOTE[nm], 0.4, tau=0.2) * 0.85, i * 0.12)
    return air(rng, buf, 0.24)


def undo(rng, v):
    buf = np.zeros(int(SR * 0.30))
    buf = place(buf, mallet(rng, NOTE["G5"], 0.18, tau=0.07), 0.0)
    buf = place(buf, mallet(rng, NOTE["E5"], 0.20, tau=0.08) * 0.9, 0.05)
    return air(rng, buf, 0.12)


def item_slide(rng, v):
    return noise_texture(rng, dur=0.08, tau=0.025, smooth=10, color=1.5) * 0.6


def level_complete(rng, v):
    buf = pad(rng, NOTE["C4"], 1.25, level=0.16)
    for i, nm in enumerate(["C5", "E5", "G5", "A5", "C6"]):
        buf = place(buf, bell(rng, NOTE[nm], 0.6 - i * 0.05, tau=0.22) * (0.8 + 0.05 * i), i * 0.11)
    buf = place(buf, mallet(rng, NOTE["G5"], 0.5, tau=0.2) * 0.5, 0.55)
    return air(rng, buf, 0.28, room=0.22)


CUES = [
    "button_tap", "invalid_soft", "merge_soft", "merge_success",
    "item_pickup", "item_drop", "bag_in", "bag_out",
    "star_earn", "star_pop", "water_pop", "rain_refill",
    "bramble_clear", "tidy_poof", "giver_cheer", "coin_earn",
    "unlock", "quest_complete", "undo", "item_slide", "level_complete",
]
HOT = {"button_tap", "merge_soft", "merge_success", "item_pickup", "item_drop"}

RECIPES = {name: globals()[name] for name in CUES}
