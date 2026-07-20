#!/usr/bin/env python3
"""Pure-python tests for the SFX synth generator (numpy/scipy, no Godot).

Beyond render sanity, this measures the style-guide contract (docs/design/
sfx-style-guide.md): the merge_note ladder is tuned within ±10 cents of its
target pentatonic pitch, musical attacks are soft (>=5 ms), and each cue class
normalizes to its own peak ceiling."""
import numpy as np
from tools.sfx_synth import primitives as P


def _check(cond, label, state):
    state[0 if cond else 1] += 1
    print(("  PASS  " if cond else "  FAIL  ") + label)


def _fundamental_hz(sig, sr=P.SR):
    """Dominant spectral peak, parabolically interpolated for sub-bin accuracy."""
    w = np.abs(np.fft.rfft(sig * np.hanning(len(sig))))
    i = int(np.argmax(w))
    if 0 < i < len(w) - 1:
        a, b, c = w[i - 1], w[i], w[i + 1]
        i = i + 0.5 * (a - c) / (a - 2 * b + c)
    return i * sr / len(sig)


def _attack_ms(sig, sr=P.SR):
    """Time to reach 90% of the absolute peak."""
    env = np.abs(sig)
    return np.argmax(env >= 0.9 * env.max()) / sr * 1000.0


def test_primitives(state):
    rng = np.random.default_rng(1)
    sig = P.kalimba(rng, P.NOTE["E5"], dur=0.30)
    _check(sig.ndim == 1, "kalimba returns mono 1-D", state)
    _check(len(sig) == int(P.SR * 0.30), "kalimba length matches dur", state)
    _check(np.all(np.isfinite(sig)), "kalimba is finite (no nan/inf)", state)
    a = P.kalimba(np.random.default_rng(9), P.NOTE["C5"])
    b = P.kalimba(np.random.default_rng(9), P.NOTE["C5"])
    _check(np.array_equal(a, b), "same seed -> identical output", state)
    n = P.normalize(P.mallet(rng, P.NOTE["A4"]), peak_dbfs=-3.0)
    peak_db = 20 * np.log10(np.max(np.abs(n)) + 1e-12)
    _check(abs(peak_db - (-3.0)) < 0.2, "normalize hits -3 dBFS", state)


def test_recipes(state):
    from tools.sfx_synth import recipes as R
    _check(len(R.CUES) == 23, "23 cues defined", state)
    _check(set(R.VARIANTS) <= set(R.CUES), "every variant cue is a known cue", state)
    _check(set(R.PEAKS) == set(R.CUES), "every cue has a peak target", state)
    _check(R.VARIANTS["merge_note"] == len(R.LADDER) == 10,
           "merge_note bakes the full 10-degree ladder", state)
    rng = np.random.default_rng(3)
    for name in R.CUES:
        sig = R.RECIPES[name](rng, 0)
        _check(sig.ndim == 1 and len(sig) > 0 and np.all(np.isfinite(sig)),
               f"recipe '{name}' renders finite mono audio", state)


def test_melody_tuning(state):
    """The combo melody contract: each baked degree is IN TUNE (±10 cents)."""
    from tools.sfx_synth import recipes as R
    for v, nm in enumerate(R.LADDER):
        rng = np.random.default_rng(100 + v)
        sig = R.merge_note(rng, v)
        hz = _fundamental_hz(sig)
        cents = 1200 * np.log2(hz / P.NOTE[nm])
        _check(abs(cents) < 10, f"merge_note[{v}] ({nm}) tuned to {cents:+.1f} cents", state)
    lo = R.merge_note(np.random.default_rng(50), 0)
    hi = R.merge_note(np.random.default_rng(51), 9)
    _check(_fundamental_hz(hi) > _fundamental_hz(lo) * 3,
           "ladder spans the full C5->A6 rise", state)


def test_softness(state):
    """No punch: musical cues reach peak no faster than ~5 ms."""
    from tools.sfx_synth import recipes as R
    rng = np.random.default_rng(7)
    for name in ["merge_note", "merge_soft", "merge_success", "item_pickup",
                 "item_drop", "undo", "unlock"]:
        ms = _attack_ms(R.RECIPES[name](rng, 0))
        _check(ms >= 5.0, f"'{name}' attack {ms:.1f} ms is soft (>=5 ms)", state)


def test_bake(state, tmp):
    from tools.sfx_synth import bake, recipes as R
    bake.bake(tmp)
    import os, json
    from scipy.io import wavfile
    names = json.load(open(os.path.join(tmp, "manifest.json")))["cues"]
    _check(set(names) == set(R.CUES), "manifest lists every cue", state)
    LONG = {"level_complete", "quest_complete", "rain_refill"}
    for name, count in names.items():
        _check(count == R.VARIANTS.get(name, 1), f"{name} variant count", state)
        files = [f"{name}.wav"] if count == 1 \
            else [f"{name}_{i + 1}.wav" for i in range(count)]
        for f in files:
            sr, data = wavfile.read(os.path.join(tmp, f))
            _check(sr == 44100 and data.dtype == np.int16 and data.ndim == 1,
                   f"{f} is mono/44.1k/int16", state)
            dur = len(data) / sr
            _check(dur <= (1.6 if name in LONG else 0.7), f"{f} within dur budget", state)
            peak = 20 * np.log10(np.max(np.abs(data)) / 32768 + 1e-12)
            want = R.PEAKS[name]
            _check(abs(peak - want) < 0.3, f"{f} peak {peak:.1f} ~= {want} dBFS", state)
    tmp2 = tmp + "_b"
    bake.bake(tmp2)
    a = wavfile.read(os.path.join(tmp, "merge_note_5.wav"))[1]
    b = wavfile.read(os.path.join(tmp2, "merge_note_5.wav"))[1]
    _check(np.array_equal(a, b), "bake is deterministic", state)


if __name__ == "__main__":
    state = [0, 0]  # [pass, fail]
    test_primitives(state)
    test_recipes(state)
    test_melody_tuning(state)
    test_softness(state)
    import tempfile, os
    test_bake(state, os.path.join(tempfile.mkdtemp(), "sfx"))
    print("== %d passed, %d failed ==" % (state[0], state[1]))
    raise SystemExit(0 if state[1] == 0 else 1)
