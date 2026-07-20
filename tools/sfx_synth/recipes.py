"""Per-cue recipes — the authored 'plan'. Each recipe(rng, v) -> mono float
array (pre-normalize). `v` is the 0-based variant index (see VARIANTS).
Variation across `v` shifts scale degree / micro-params so takes differ.

Melodic rules (docs/design/sfx-style-guide.md): every tuned cue sits on the
C-major pentatonic; the merge combo ladder is BAKED as discrete notes
(merge_note_1..10) played untransposed, so a fast streak is a real melody."""
from tools.sfx_synth.primitives import (
    NOTE, SR, kalimba, mallet, bell, woodknock, water_plip, noise_texture,
    pad, place, air,
)
import numpy as np

_RING = ["C5", "D5", "E5", "G5", "A5", "C6"]

# The combo melody — one baked note per streak degree (feel.gd indexes these).
LADDER = ["C5", "D5", "E5", "G5", "A5", "C6", "D6", "E6", "G6", "A6"]


def _deg(base, v, ring=_RING):
    return NOTE[ring[(ring.index(base) + v) % len(ring)]]


def merge_note(rng, v):
    """THE merge sound: degree `v` of the pentatonic ladder, exact pitch."""
    return air(rng, kalimba(rng, NOTE[LADDER[v % len(LADDER)]],
                            dur=0.38, tau=0.14, detune=0.0), 0.14)


def merge_shine(rng, v):
    """Soft shimmer layered on tier>=4 merges — rides on top of the note."""
    buf = np.zeros(int(SR * 0.4))
    buf = place(buf, bell(rng, NOTE["E6"], 0.30, tau=0.14) * 0.7, 0.0)
    buf = place(buf, bell(rng, NOTE["A6"], 0.26, tau=0.12) * 0.5, 0.02)
    return air(rng, buf, 0.14)


def merge_soft(rng, v):
    return air(rng, kalimba(rng, NOTE[["E5", "G5", "A5"][v % 3]],
                            dur=0.30, tau=0.11), 0.14)


def merge_success(rng, v):
    # a gentle rise — the SAME interval shape (a pentatonic fifth) in every take
    lo, hi = [("C5", "G5"), ("D5", "A5"), ("G5", "D6")][v % 3]
    buf = np.zeros(int(SR * 0.5))
    buf = place(buf, kalimba(rng, NOTE[lo], 0.28, tau=0.11), 0.0)
    buf = place(buf, kalimba(rng, NOTE[hi], 0.34, tau=0.13) * 0.95, 0.09)
    return air(rng, buf, 0.16)


def button_tap(rng, v):
    return woodknock(rng, freq=[175.0, 185.0, 196.0][v % 3])


def item_pickup(rng, v):
    return kalimba(rng, _deg("A5", v), dur=0.13, tau=0.05, attack=0.006)


def item_drop(rng, v):
    return kalimba(rng, _deg("E5", v), dur=0.15, tau=0.055, attack=0.007)


def bag_in(rng, v):
    return air(rng, mallet(rng, NOTE["C5"], dur=0.16, tau=0.06,
                           partials=(1, 2), amps=(1.0, 0.2)), 0.10)


def bag_out(rng, v):
    return air(rng, mallet(rng, NOTE["G5"], dur=0.16, tau=0.06,
                           partials=(1, 2), amps=(1.0, 0.2)), 0.10)


def star_earn(rng, v):
    return air(rng, bell(rng, NOTE["A5"], dur=0.30, tau=0.16), 0.18)


def star_pop(rng, v):
    return bell(rng, NOTE["E6"], dur=0.16, tau=0.08)


def water_pop(rng, v):
    return air(rng, water_plip(rng), 0.13, room=0.08)


def rain_refill(rng, v):
    buf = pad(rng, NOTE["C4"], 0.6, level=0.12)
    for i, nm in enumerate(["A5", "E5", "G5", "C6"]):
        buf = place(buf, water_plip(rng, f0=900 + 80 * i) * 0.7, 0.04 + i * 0.07)
    return air(rng, buf, 0.15)


def bramble_clear(rng, v):
    buf = noise_texture(rng, dur=0.14, tau=0.03, smooth=6, color=2.0)
    wk = woodknock(rng, 160.0, 0.12)
    n = min(len(buf), len(wk))
    return air(rng, (buf[:n] + wk[:n]) * 0.6, 0.12)


def tidy_poof(rng, v):
    return air(rng, noise_texture(rng, dur=0.28, tau=0.10, smooth=20), 0.15)


def giver_cheer(rng, v):
    buf = np.zeros(int(SR * 0.4))
    for i, nm in enumerate(["E6", "G6", "C6"]):
        buf = place(buf, bell(rng, NOTE[nm], 0.22, tau=0.1) * 0.9, i * 0.06)
    return air(rng, buf, 0.18)


def coin_earn(rng, v):
    buf = np.zeros(int(SR * 0.42))
    buf = place(buf, bell(rng, NOTE["E6"], 0.22), 0.0)
    buf = place(buf, bell(rng, NOTE["A5"], 0.30) * 0.9, 0.07)
    return air(rng, buf, 0.18)


def invalid_soft(rng, v):
    # deliberately NON-musical: a muted damped double-thud, dull and low
    buf = np.zeros(int(SR * 0.30))
    buf = place(buf, woodknock(rng, 120.0, 0.14, attack=0.006), 0.0)
    buf = place(buf, woodknock(rng, 98.0, 0.16, attack=0.006) * 0.8, 0.07)
    return air(rng, buf, 0.08)


def unlock(rng, v):
    buf = np.zeros(int(SR * 0.55))
    for i, nm in enumerate(["C5", "E5", "G5"]):
        buf = place(buf, kalimba(rng, NOTE[nm], 0.34, tau=0.14), i * 0.10)
    return air(rng, buf, 0.20)


def quest_complete(rng, v):
    buf = pad(rng, NOTE["C4"], 0.65, level=0.12)
    for i, nm in enumerate(["G5", "A5", "C6"]):
        buf = place(buf, bell(rng, NOTE[nm], 0.4, tau=0.2) * 0.85, i * 0.12)
    return air(rng, buf, 0.20)


def undo(rng, v):
    buf = np.zeros(int(SR * 0.30))
    buf = place(buf, kalimba(rng, NOTE["G5"], 0.18, tau=0.07), 0.0)
    buf = place(buf, kalimba(rng, NOTE["E5"], 0.20, tau=0.08) * 0.9, 0.05)
    return air(rng, buf, 0.10)


def item_slide(rng, v):
    return noise_texture(rng, dur=0.09, tau=0.03, smooth=14, color=1.2) * 0.6


def level_complete(rng, v):
    buf = pad(rng, NOTE["C4"], 1.25, level=0.16)
    for i, nm in enumerate(["C5", "E5", "G5", "A5", "C6"]):
        buf = place(buf, bell(rng, NOTE[nm], 0.6 - i * 0.05, tau=0.22) * (0.8 + 0.05 * i), i * 0.11)
    buf = place(buf, kalimba(rng, NOTE["G5"], 0.5, tau=0.2) * 0.5, 0.55)
    return air(rng, buf, 0.22, room=0.22)


CUES = [
    "button_tap", "invalid_soft", "merge_note", "merge_shine",
    "merge_soft", "merge_success",
    "item_pickup", "item_drop", "bag_in", "bag_out",
    "star_earn", "star_pop", "water_pop", "rain_refill",
    "bramble_clear", "tidy_poof", "giver_cheer", "coin_earn",
    "unlock", "quest_complete", "undo", "item_slide", "level_complete",
]

# Baked take/degree counts per cue (1 unless listed). merge_note bakes the
# whole 10-degree ladder; the hot foley cues bake 3 takes each.
VARIANTS = {
    "merge_note": len(LADDER),
    "button_tap": 3, "merge_soft": 3, "merge_success": 3,
    "item_pickup": 3, "item_drop": 3,
}

# Per-cue peak ceilings (dBFS) — loudness maps to meaning (spec §4).
PEAK_UI = -12.0
PEAK_FOLEY = -9.0
PEAK_MELODIC = -6.0
PEAK_FANFARE = -4.0
PEAKS = {
    "button_tap": PEAK_UI, "item_slide": PEAK_UI,
    "item_pickup": PEAK_FOLEY, "item_drop": PEAK_FOLEY,
    "bag_in": PEAK_FOLEY, "bag_out": PEAK_FOLEY,
    "tidy_poof": PEAK_FOLEY, "invalid_soft": PEAK_FOLEY, "undo": PEAK_FOLEY,
    "merge_note": PEAK_MELODIC, "merge_shine": -10.0,
    "merge_soft": PEAK_MELODIC, "merge_success": PEAK_MELODIC,
    "water_pop": PEAK_MELODIC, "star_pop": PEAK_MELODIC,
    "coin_earn": PEAK_MELODIC, "bramble_clear": PEAK_MELODIC,
    "level_complete": PEAK_FANFARE, "quest_complete": PEAK_FANFARE,
    "unlock": PEAK_FANFARE, "rain_refill": PEAK_FANFARE,
    "star_earn": PEAK_FANFARE, "giver_cheer": PEAK_FANFARE,
}

RECIPES = {name: globals()[name] for name in CUES}
