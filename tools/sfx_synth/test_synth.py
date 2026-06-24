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


if __name__ == "__main__":
    state = [0, 0]  # [pass, fail]
    test_primitives(state)
    print("== %d passed, %d failed ==" % (state[0], state[1]))
    raise SystemExit(0 if state[1] == 0 else 1)
