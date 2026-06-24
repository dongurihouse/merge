#!/usr/bin/env python3
"""Pure-python tests for the SFX synth generator (numpy/scipy, no Godot)."""
import numpy as np
from tools.sfx_synth import primitives as P


def _check(cond, label, state):
    state[0 if cond else 1] += 1
    print(("  PASS  " if cond else "  FAIL  ") + label)


def test_primitives(state):
    rng = np.random.default_rng(1)
    sig = P.mallet(rng, P.NOTE["E5"], dur=0.30)
    _check(sig.ndim == 1, "mallet returns mono 1-D", state)
    _check(len(sig) == int(P.SR * 0.30), "mallet length matches dur", state)
    _check(np.all(np.isfinite(sig)), "mallet is finite (no nan/inf)", state)
    a = P.mallet(np.random.default_rng(9), P.NOTE["C5"])
    b = P.mallet(np.random.default_rng(9), P.NOTE["C5"])
    _check(np.array_equal(a, b), "same seed -> identical output", state)
    n = P.normalize(P.mallet(rng, P.NOTE["A4"]), peak_dbfs=-3.0)
    peak_db = 20 * np.log10(np.max(np.abs(n)) + 1e-12)
    _check(abs(peak_db - (-3.0)) < 0.2, "normalize hits -3 dBFS", state)


def test_recipes(state):
    from tools.sfx_synth import recipes as R
    _check(len(R.CUES) == 21, "21 cues defined", state)
    _check(R.HOT.issubset(set(R.CUES)), "every hot cue is a known cue", state)
    rng = np.random.default_rng(3)
    for name in R.CUES:
        sig = R.RECIPES[name](rng, 0)
        _check(sig.ndim == 1 and len(sig) > 0 and np.all(np.isfinite(sig)),
               f"recipe '{name}' renders finite mono audio", state)


def test_bake(state, tmp):
    from tools.sfx_synth import bake, recipes as R
    bake.bake(tmp)
    import os, json
    from scipy.io import wavfile
    names = json.load(open(os.path.join(tmp, "manifest.json")))["cues"]
    _check(set(names) == set(R.CUES), "manifest lists every cue", state)
    LONG = {"level_complete", "quest_complete", "rain_refill"}
    for name, count in names.items():
        _check(count == (3 if name in R.HOT else 1), f"{name} variant count", state)
        files = [f"{name}.wav"] if count == 1 else [f"{name}_{i}.wav" for i in (1, 2, 3)]
        for f in files:
            sr, data = wavfile.read(os.path.join(tmp, f))
            _check(sr == 44100 and data.dtype == np.int16 and data.ndim == 1,
                   f"{f} is mono/44.1k/int16", state)
            dur = len(data) / sr
            _check(dur <= (1.6 if name in LONG else 0.7), f"{f} within dur budget", state)
            peak = 20 * np.log10(np.max(np.abs(data)) / 32768 + 1e-12)
            _check(peak <= -2.8, f"{f} peak <= -3 dBFS", state)
    tmp2 = tmp + "_b"
    bake.bake(tmp2)
    a = wavfile.read(os.path.join(tmp, "merge_success_1.wav"))[1]
    b = wavfile.read(os.path.join(tmp2, "merge_success_1.wav"))[1]
    _check(np.array_equal(a, b), "bake is deterministic", state)


if __name__ == "__main__":
    state = [0, 0]  # [pass, fail]
    test_primitives(state)
    test_recipes(state)
    import tempfile, os
    test_bake(state, os.path.join(tempfile.mkdtemp(), "sfx"))
    print("== %d passed, %d failed ==" % (state[0], state[1]))
    raise SystemExit(0 if state[1] == 0 else 1)
