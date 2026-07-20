"""Render every recipe to mono 44.1k Int16 WAVs + manifest.json.

Deterministic: each cue/variant gets its own rng seeded from a base + index,
so output is byte-stable. Variant counts come from recipes.VARIANTS (the
merge_note ladder bakes 10 degrees; hot foley cues bake 3 takes); peak levels
come from recipes.PEAKS (loudness maps to meaning — spec §4).
Usage:  python3 -m tools.sfx_synth.bake
"""
import os
import sys
import json
import numpy as np
from scipy.io import wavfile
from tools.sfx_synth import recipes as R
from tools.sfx_synth.primitives import SR, normalize

BASE_SEED = 1729
SEED_STRIDE = 16   # > max variant count so cue seeds never collide
DEFAULT_OUT = os.path.join("games", "grove", "assets", "music", "sfx")


def _write(path, sig, peak_dbfs):
    sig = normalize(sig, peak_dbfs=peak_dbfs)
    wavfile.write(path, SR, (sig * 32767).astype(np.int16))


def bake(out_dir=DEFAULT_OUT):
    os.makedirs(out_dir, exist_ok=True)
    manifest = {}
    for i, name in enumerate(R.CUES):
        fn = R.RECIPES[name]
        count = R.VARIANTS.get(name, 1)
        peak = R.PEAKS.get(name, -6.0)
        manifest[name] = count
        for v in range(count):
            rng = np.random.default_rng(BASE_SEED + i * SEED_STRIDE + v)
            out = os.path.join(out_dir, f"{name}.wav" if count == 1
                               else f"{name}_{v + 1}.wav")
            _write(out, fn(rng, v), peak)
    with open(os.path.join(out_dir, "manifest.json"), "w") as f:
        json.dump({"cues": manifest}, f, indent=2, sort_keys=True)
    return manifest


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_OUT
    m = bake(out)
    print(f"baked {sum(m.values())} files for {len(m)} cues -> {out}")
