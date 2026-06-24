"""Render every recipe to mono 44.1k Int16 WAVs + manifest.json.

Deterministic: each cue/variant gets its own rng seeded from a base + index,
so output is byte-stable and appending a cue never shifts existing ones.
Hot cues bake 3 variants; others bake one. Usage:  python3 -m tools.sfx_synth.bake
"""
import os
import sys
import json
import numpy as np
from scipy.io import wavfile
from tools.sfx_synth import recipes as R
from tools.sfx_synth.primitives import SR, normalize

BASE_SEED = 1729
DEFAULT_OUT = os.path.join("games", "grove", "assets", "music", "sfx")


def _write(path, sig):
    sig = normalize(sig, peak_dbfs=-3.0)
    wavfile.write(path, SR, (sig * 32767).astype(np.int16))


def bake(out_dir=DEFAULT_OUT):
    os.makedirs(out_dir, exist_ok=True)
    manifest = {}
    for i, name in enumerate(R.CUES):
        fn = R.RECIPES[name]
        if name in R.HOT:
            manifest[name] = 3
            for v in range(3):
                rng = np.random.default_rng(BASE_SEED + i * 10 + v)
                _write(os.path.join(out_dir, f"{name}_{v + 1}.wav"), fn(rng, v))
        else:
            manifest[name] = 1
            rng = np.random.default_rng(BASE_SEED + i * 10)
            _write(os.path.join(out_dir, f"{name}.wav"), fn(rng, 0))
    with open(os.path.join(out_dir, "manifest.json"), "w") as f:
        json.dump({"cues": manifest}, f, indent=2, sort_keys=True)
    return manifest


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_OUT
    m = bake(out)
    print(f"baked {sum(m.values())} files for {len(m)} cues -> {out}")
