# Synth-baked, juicy SFX — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the 8 thin SFX with a synth-generated, key-tuned ~21-event palette that varies per trigger, treating audio as another type of juice.

**Architecture:** An offline deterministic Python generator (`tools/sfx_synth/`) bakes a C-pentatonic palette of mono WAVs plus a `manifest.json` into `games/grove/assets/music/sfx/`. The runtime `audio.gd` is reworked to load by manifest (fixing the hardcoded-list foot-gun) and to add live variation — round-robin variants + per-trigger pitch/gain jitter. The 7 already-coded-but-inert cues activate automatically once baked; a few genuinely-silent events get new call sites.

**Tech Stack:** Python 3 (numpy, scipy.io.wavfile, scipy.signal), Godot 4.6 GDScript, the project's headless SceneTree test runner.

**Reference:** spec at `docs/superpowers/specs/2026-06-24-synth-sfx-juice-design.md`.

---

## Conventions (read once)

- **Always work in a git worktree**, never `main` directly. The execution skill creates it.
- After every change run `make test-fast` (engine suites, parallel, seconds).
- Python generator tests are pure (`python3 tools/sfx_synth/test_synth.py`) — no Godot.
- Godot suites: `extends SceneTree`, `_initialize()`, an `ok(cond,label)` helper, end with
  `print("== %d passed, %d failed ==" % [_pass,_fail])` then `quit(0 if _fail==0 else 1)`.
- After baking new/changed audio, run `make import` so the `.import` sidecars exist (headless
  `load()` needs them); commit the WAVs **and** their `.import` files.

## File structure (decomposition)

| File | Responsibility |
|---|---|
| `tools/sfx_synth/primitives.py` | Pure DSP building blocks (tones, shapers, air, normalize). No cue knowledge. |
| `tools/sfx_synth/recipes.py` | The authored "plan" — one recipe fn per cue, in terms of primitives. |
| `tools/sfx_synth/bake.py` | Renders recipes → WAVs + `manifest.json`. Deterministic. |
| `tools/sfx_synth/test_synth.py` | Pure-python tests: format contract + determinism. |
| `games/grove/assets/music/sfx/*.wav` + `manifest.json` | Baked palette (committed). |
| `engine/scripts/core/audio.gd` | Manifest loader + per-trigger variation (reworked). |
| `engine/scripts/core/tuning.gd` | `class Audio` gains jitter/variant dials. |
| `engine/tests/sfx_tests.gd` | Asserts palette loads, no inert fallbacks, jitter bounded. |
| `Makefile` | `sfx` + `sfx-test` targets; `sfx_tests` added to `ENGINE_TESTS`. |

---

## Task 1: DSP primitives

**Files:**
- Create: `tools/sfx_synth/__init__.py` (empty)
- Create: `tools/sfx_synth/primitives.py`
- Test: `tools/sfx_synth/test_synth.py` (created here, grown later)

- [ ] **Step 1: Write the failing test**

Create `tools/sfx_synth/test_synth.py`:

```python
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
    # determinism: same seed -> identical samples
    a = P.mallet(np.random.default_rng(9), P.NOTE["C5"])
    b = P.mallet(np.random.default_rng(9), P.NOTE["C5"])
    _check(np.array_equal(a, b), "same seed -> identical output", state)
    # normalize hits the target peak
    n = P.normalize(P.mallet(rng, P.NOTE["A4"]), peak_dbfs=-3.0)
    peak_db = 20 * np.log10(np.max(np.abs(n)) + 1e-12)
    _check(abs(peak_db - (-3.0)) < 0.2, "normalize hits -3 dBFS", state)


if __name__ == "__main__":
    state = [0, 0]  # [pass, fail]
    test_primitives(state)
    print("== %d passed, %d failed ==" % (state[0], state[1]))
    raise SystemExit(0 if state[1] == 0 else 1)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd <repo> && python3 -m tools.sfx_synth.test_synth`
Expected: FAIL — `ModuleNotFoundError: tools.sfx_synth.primitives`.

- [ ] **Step 3: Write the primitives**

Create empty `tools/sfx_synth/__init__.py`. Create `tools/sfx_synth/primitives.py`:

```python
"""Deterministic DSP building blocks for the cozy SFX palette.

Pure numpy/scipy. Every generator takes an explicit `rng`
(numpy.random.Generator) so the bake is reproducible. Output is mono float64
in roughly [-1, 1]; the bake normalizes + writes Int16 WAVs.
"""
import numpy as np
from scipy.signal import fftconvolve

SR = 44100

# C-major pentatonic (C D E G A) across octaves — the spec's shared key.
NOTE = {
    "C4": 261.63, "D4": 293.66, "E4": 329.63, "G4": 392.00, "A4": 440.00,
    "C5": 523.25, "D5": 587.33, "E5": 659.25, "G5": 783.99, "A5": 880.00,
    "C6": 1046.50, "D6": 1174.66, "E6": 1318.51, "G6": 1567.98,
}


def t(dur):
    return np.linspace(0, dur, int(SR * dur), endpoint=False)


def fades(x, fin=0.004, fout=0.012):
    n = len(x)
    ai, ao = min(int(SR * fin), n // 2), min(int(SR * fout), n // 2)
    if ai:
        x[:ai] *= np.linspace(0, 1, ai)
    if ao:
        x[-ao:] *= np.linspace(1, 0, ao)
    return x


def env_exp(dur, tau, attack=0.005):
    tt = t(dur)
    e = np.exp(-tt / tau)
    a = min(int(SR * attack), len(e) // 2)
    if a:
        e[:a] *= np.linspace(0, 1, a)
    return e


def mallet(rng, freq, dur=0.28, tau=0.10, partials=(1, 2, 3, 4.2),
           amps=(1.0, 0.45, 0.22, 0.1), detune=0.004, attack=0.004):
    """Soft tuned mallet/marimba tone; higher partials decay faster."""
    tt = t(dur)
    out = np.zeros_like(tt)
    for p, amp in zip(partials, amps):
        f = freq * p * (1 + rng.uniform(-detune, detune))
        out += amp * np.sin(2 * np.pi * f * tt) * np.exp(-tt / (tau / (0.5 + 0.5 * p)))
    out = np.tanh(out * 1.4)
    return fades(out * env_exp(dur, tau * 2.2, attack), fin=attack)


def bell(rng, freq, dur=0.32, tau=0.16, attack=0.002):
    """Glassy inharmonic tone — coin/star sparkle, songbird."""
    tt = t(dur)
    out = np.zeros_like(tt)
    for p, amp in zip((1.0, 2.76, 5.40, 8.93), (1.0, 0.5, 0.28, 0.12)):
        out += amp * np.sin(2 * np.pi * freq * p * tt) * np.exp(-tt / (tau / (0.6 + 0.4 * p)))
    return fades(out * env_exp(dur, tau, attack), fin=attack)


def woodknock(rng, freq=210.0, dur=0.12):
    """UI 'tok': noise transient + low damped woody modes."""
    tt = t(dur)
    body = (np.sin(2 * np.pi * freq * tt) * np.exp(-tt / 0.02)
            + 0.5 * np.sin(2 * np.pi * freq * 2.7 * tt) * np.exp(-tt / 0.012))
    nz = np.diff(np.concatenate([[0.0], rng.standard_normal(len(tt))]))
    click = nz * np.exp(-tt / 0.004) * 0.6
    return fades(np.tanh((body + click) * 1.3), fin=0.0005)


def water_plip(rng, f0=1100.0, f1=360.0, dur=0.16):
    """Resonant downward pitch-drop 'bloop' — synth's strong suit."""
    tt = t(dur)
    k = np.log(f0 / f1) / dur
    inst = f0 * np.exp(-k * tt)
    phase = 2 * np.pi * np.cumsum(inst) / SR
    body = np.sin(phase) * np.exp(-tt / 0.05)
    click = rng.standard_normal(len(tt)) * np.exp(-tt / 0.002) * 0.25
    return fades(np.tanh((body + click) * 1.2), fin=0.0008)


def noise_texture(rng, dur=0.20, tau=0.05, smooth=12, color=1.0):
    """Filtered-noise burst for foliage/poof/twig (synth's weak suit, best effort).
    `color`>1 brightens (less smoothing); a crack uses a fast tau."""
    tt = t(dur)
    nz = rng.standard_normal(len(tt))
    k = max(1, int(smooth / color))
    nz = np.convolve(nz, np.ones(k) / k, mode="same")
    return fades(np.tanh(nz * 2.0) * np.exp(-tt / tau), fin=0.001)


def pad(rng, freq, dur, level=0.18, attack=0.18, detune=0.008):
    """Soft sustained bed under a fanfare."""
    tt = t(dur)
    out = np.zeros_like(tt)
    for d in (-detune, 0.0, detune):
        out += np.sin(2 * np.pi * freq * (1 + d) * tt)
    out /= 3
    a = int(SR * attack)
    e = np.ones_like(tt)
    e[:a] = np.linspace(0, 1, a)
    e *= np.exp(-np.maximum(tt - dur * 0.6, 0) / 0.4)
    return fades(out * e * level)


def place(buf, seg, at):
    i = int(SR * at)
    end = i + len(seg)
    if end > len(buf):
        buf = np.concatenate([buf, np.zeros(end - len(buf))])
    buf[i:end] += seg
    return buf


def air(rng, x, amount=0.20, room=0.13):
    """Tiny decaying-noise room IR → natural tail/air. Lengthens x by `room`."""
    n = int(SR * room)
    ir = rng.standard_normal(n) * np.exp(-np.linspace(0, 1, n) * 6)
    ir = np.convolve(ir, np.ones(24) / 24, mode="same")
    wet = fftconvolve(x, ir)
    out = np.zeros(len(wet))
    out[:len(x)] += x
    out += wet / (np.max(np.abs(wet)) + 1e-9) * amount
    return out


def normalize(x, peak_dbfs=-3.0):
    x = np.asarray(x, dtype=np.float64)
    return x / (np.max(np.abs(x)) + 1e-9) * (10 ** (peak_dbfs / 20))
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m tools.sfx_synth.test_synth`
Expected: `== 4 passed, 0 failed ==`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add tools/sfx_synth/__init__.py tools/sfx_synth/primitives.py tools/sfx_synth/test_synth.py
git commit -m "feat(sfx): DSP primitive toolkit for synth SFX"
```

---

## Task 2: Cue recipes

**Files:**
- Create: `tools/sfx_synth/recipes.py`
- Test: `tools/sfx_synth/test_synth.py` (extend)

- [ ] **Step 1: Write the failing test** — append to `test_synth.py`, and add the call in `__main__`.

Add this function:

```python
def test_recipes(state):
    from tools.sfx_synth import recipes as R
    _check(len(R.CUES) == 21, "21 cues defined", state)
    _check(R.HOT.issubset(set(R.CUES)), "every hot cue is a known cue", state)
    rng = np.random.default_rng(3)
    for name in R.CUES:
        sig = R.RECIPES[name](rng, 0)
        _check(sig.ndim == 1 and len(sig) > 0 and np.all(np.isfinite(sig)),
               f"recipe '{name}' renders finite mono audio", state)
```

In `__main__`, add `test_recipes(state)` after `test_primitives(state)`.

- [ ] **Step 2: Run to verify it fails**

Run: `python3 -m tools.sfx_synth.test_synth`
Expected: FAIL — `ModuleNotFoundError: tools.sfx_synth.recipes`.

- [ ] **Step 3: Write the recipes**

Create `tools/sfx_synth/recipes.py`:

```python
"""Per-cue recipes — the authored 'plan'. Each recipe(rng, v) -> mono float
array (pre-normalize). `v` is the 0-based variant index (hot cues bake 3).
Variation across `v` shifts scale degree / micro-params so takes differ."""
from tools.sfx_synth.primitives import (
    NOTE, SR, mallet, bell, woodknock, water_plip, noise_texture, pad,
    place, air,
)
import numpy as np

# scale-degree rings used for per-variant pitch choice
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
    buf = noise_texture(rng, dur=0.14, tau=0.03, smooth=6, color=2.0)  # snap
    return air(rng, np.tanh((buf + woodknock(rng, 160.0, 0.12)[:len(buf)]) * 1.1), 0.14)


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


# Ordered cue list (stable — the bake seeds per-index, so appending is safe).
CUES = [
    "button_tap", "invalid_soft", "merge_soft", "merge_success",
    "item_pickup", "item_drop", "bag_in", "bag_out",
    "star_earn", "star_pop", "water_pop", "rain_refill",
    "bramble_clear", "tidy_poof", "giver_cheer", "coin_earn",
    "unlock", "quest_complete", "undo", "item_slide", "level_complete",
]
# Cues baked with 3 round-robin take-variants (the high-frequency cues).
HOT = {"button_tap", "merge_soft", "merge_success", "item_pickup", "item_drop"}

RECIPES = {name: globals()[name] for name in CUES}
```

- [ ] **Step 4: Run to verify it passes**

Run: `python3 -m tools.sfx_synth.test_synth`
Expected: `== 27 passed, 0 failed ==` (4 + 2 + 21), exit 0.

- [ ] **Step 5: Commit**

```bash
git add tools/sfx_synth/recipes.py tools/sfx_synth/test_synth.py
git commit -m "feat(sfx): cue recipes for the 21-event palette"
```

---

## Task 3: Bake + manifest (deterministic, format contract)

**Files:**
- Create: `tools/sfx_synth/bake.py`
- Test: `tools/sfx_synth/test_synth.py` (extend)

- [ ] **Step 1: Write the failing test** — append to `test_synth.py`, add to `__main__`.

```python
def test_bake(state, tmp):
    from tools.sfx_synth import bake, recipes as R
    bake.bake(tmp)                                   # render into a temp dir
    import os, json
    from scipy.io import wavfile
    names = json.load(open(os.path.join(tmp, "manifest.json")))["cues"]
    _check(set(names) == set(R.CUES), "manifest lists every cue", state)
    # core one-shot is <=0.6s (spec); a soft air tail extends a few cues, so the
    # enforced ceiling is 0.7s. The 3 deliberate fanfares get a longer budget.
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
    # determinism: a second bake yields identical bytes
    tmp2 = tmp + "_b"
    bake.bake(tmp2)
    a = wavfile.read(os.path.join(tmp, "merge_success_1.wav"))[1]
    b = wavfile.read(os.path.join(tmp2, "merge_success_1.wav"))[1]
    _check(np.array_equal(a, b), "bake is deterministic", state)
```

In `__main__`, add:

```python
    import tempfile, os
    test_bake(state, os.path.join(tempfile.mkdtemp(), "sfx"))
```

- [ ] **Step 2: Run to verify it fails**

Run: `python3 -m tools.sfx_synth.test_synth`
Expected: FAIL — `ModuleNotFoundError: tools.sfx_synth.bake`.

- [ ] **Step 3: Write the bake**

Create `tools/sfx_synth/bake.py`:

```python
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
# default output: the live grove SFX dir
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
```

- [ ] **Step 4: Run to verify it passes**

Run: `python3 -m tools.sfx_synth.test_synth`
Expected: all pass, exit 0 (the bake test renders into a temp dir, not the repo).

- [ ] **Step 5: Commit**

```bash
git add tools/sfx_synth/bake.py tools/sfx_synth/test_synth.py
git commit -m "feat(sfx): deterministic bake + manifest with format-contract tests"
```

---

## Task 4: Bake the real palette + `make` targets

**Files:**
- Modify: `Makefile` (add `sfx`, `sfx-test`; add `sfx_tests` to `ENGINE_TESTS`)
- Create/replace: `games/grove/assets/music/sfx/*.wav` + `manifest.json` (+ `.import`)

- [ ] **Step 1: Add the Makefile targets**

In `Makefile`, append to the `## --- assets ---` block (near `import:`):

```makefile
sfx: ## bake the synth SFX palette into games/grove/assets/music/sfx/ then import
	python3 -m tools.sfx_synth.bake
	$(GODOT) --headless --path $(PROJECT) --import

sfx-test: ## pure-python tests for the SFX generator (no godot)
	python3 -m tools.sfx_synth.test_synth
```

- [ ] **Step 2: Add the new suite to the active engine list**

In `Makefile`, edit line 12 (`ENGINE_TESTS := ...`) and append ` engine/tests/sfx_tests` to the end of that list (it must be in the **active** list so `make test-fast` runs it — not `ENGINE_TESTS_DISABLED`).

- [ ] **Step 3: Bake the real palette**

Run: `make sfx`
Expected: `baked 31 files for 21 cues -> games/grove/assets/music/sfx`, then Godot import completes without error.

- [ ] **Step 4: Verify the files + manifest landed**

Run: `ls games/grove/assets/music/sfx/*.wav | wc -l && cat games/grove/assets/music/sfx/manifest.json | head`
Expected: `31`; manifest shows each cue with its variant count.

- [ ] **Step 5: Commit (WAVs + import sidecars + manifest)**

```bash
git add games/grove/assets/music/sfx Makefile
git commit -m "feat(sfx): bake the 21-cue synth palette + make sfx/sfx-test targets"
```

---

## Task 5: Manifest loader in `audio.gd`

Replaces the hardcoded 8-name `FILES` array (the foot-gun) with manifest-driven loading of every cue and its variants.

**Files:**
- Modify: `engine/scripts/core/audio.gd`
- Create: `engine/tests/sfx_tests.gd`

- [ ] **Step 1: Write the failing test**

Create `engine/tests/sfx_tests.gd`:

```gdscript
extends SceneTree
## Headless tests for the synth SFX palette + variation (audio.gd).
##   godot --headless --path . -s res://engine/tests/sfx_tests.gd

const Audio = preload("res://engine/scripts/core/audio.gd")
const Save = preload("res://engine/scripts/core/save.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond: _pass += 1; print("  PASS  ", label)
	else: _fail += 1; print("  FAIL  ", label)

func _initialize() -> void:
	Save.set_setting("sfx", true)

	# every cue in the palette is loaded (manifest-driven, not a hardcoded list)
	for name in ["button_tap", "invalid_soft", "merge_soft", "merge_success",
			"item_pickup", "item_drop", "bag_in", "bag_out", "star_earn",
			"star_pop", "water_pop", "rain_refill", "bramble_clear", "tidy_poof",
			"giver_cheer", "coin_earn", "unlock", "quest_complete", "undo",
			"item_slide", "level_complete"]:
		ok(Audio.has(name), "cue loaded: %s" % name)

	# the 7 previously-inert, fallback-wired cues now resolve (no silent fallback)
	for name in ["water_pop", "rain_refill", "bramble_clear", "star_earn",
			"bag_in", "bag_out", "giver_cheer"]:
		ok(Audio.has(name), "no-longer-inert: %s" % name)

	# hot cues expose 3 variants; a non-hot cue exposes 1
	ok(Audio.variant_count("button_tap") == 3, "button_tap has 3 variants")
	ok(Audio.variant_count("water_pop") == 1, "water_pop has 1 variant")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
```

- [ ] **Step 2: Run to verify it fails**

Run: `make test-one SUITE=engine/tests/sfx_tests`
Expected: FAIL — `variant_count` not defined / cues not loaded.

- [ ] **Step 3: Rework the loader**

Replace the body of `engine/scripts/core/audio.gd` above `play` with the manifest loader. New file content (lines 1–39 region):

```gdscript
extends RefCounted
## Tiny SFX helper (preload + static; no autoload needed).
##   const Audio = preload("res://engine/scripts/core/audio.gd")
##   Audio.play("merge_success")
## Loads every cue named in music/sfx/manifest.json (one or more take-variants
## each) and round-robins a small player pool so sounds can overlap. Missing
## cues are silently skipped. play() varies pitch/gain per trigger (the juice).

const Save = preload("res://engine/scripts/core/save.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Tune = preload("res://engine/scripts/core/tuning.gd").Audio

static var _sounds := {}      # name -> Array[AudioStream] (the variants)
static var _rr := {}          # name -> next variant index (round-robin)
static var _players: Array = []
static var _next := 0
static var _ready := false

static func _ensure() -> void:
	if _ready:
		return
	_ready = true
	var mpath := Game.sound("music/sfx/manifest.json")
	if mpath != "" and FileAccess.file_exists(mpath):
		var txt := FileAccess.get_file_as_string(mpath)
		var data: Dictionary = JSON.parse_string(txt) if txt != "" else {}
		var cues: Dictionary = data.get("cues", {})
		for name in cues:
			var count := int(cues[name])
			var variants: Array = []
			for v in range(count):
				var fn := "music/sfx/%s.wav" % name if count == 1 \
					else "music/sfx/%s_%d.wav" % [name, v + 1]
				var p := Game.sound(fn)
				if ResourceLoader.exists(p):
					variants.append(load(p))
			if not variants.is_empty():
				_sounds[name] = variants
	var root = Engine.get_main_loop().root
	for i in Tune.VOICES:
		var pl := AudioStreamPlayer.new()
		root.add_child(pl)
		_players.append(pl)

static func has(name: String) -> bool:
	_ensure()
	return _sounds.has(name)

static func variant_count(name: String) -> int:
	_ensure()
	return _sounds.get(name, []).size()
```

Task 6 rewrites `play` fully (adds variation). For now, keep the existing `play`
**valid** against the new Array-valued `_sounds` by changing its one stream-pick
line so the file stays runnable (so `make test-fast` passes after this task):

```gdscript
	pl.stream = _sounds[name][0]      # Task 6 replaces this with variant + jitter
```
Leave the rest of `play` as-is until Task 6.

- [ ] **Step 4: Run to verify it passes**

Run: `make test-one SUITE=engine/tests/sfx_tests`
Expected: `== 30 passed, 0 failed ==` (21 cues + 7 + 2), exit 0.

- [ ] **Step 5: Commit**

```bash
git add engine/scripts/core/audio.gd engine/tests/sfx_tests.gd
git commit -m "feat(sfx): manifest-driven loader (fixes the hardcoded-list foot-gun)"
```

---

## Task 6: Per-trigger variation in `play()`

**Files:**
- Modify: `engine/scripts/core/audio.gd` (`play`)
- Modify: `engine/scripts/core/tuning.gd` (`class Audio` dials)
- Modify: `engine/tests/sfx_tests.gd` (add variation asserts)

- [ ] **Step 1: Add the tuning dials**

In `engine/scripts/core/tuning.gd`, replace the `class Audio` body (lines ~105–107):

```gdscript
class Audio:
	# --- the SFX player pool -----------------------------------------------------------
	const VOICES := 8                    # round-robin player pool → max overlapping sounds
	# --- per-trigger "juice" variation -------------------------------------------------
	const PITCH_JITTER_CENTS := 35.0     # ± random detune per trigger (musical, subtle)
	const GAIN_JITTER_DB := 1.2          # ± random level per trigger
	const HOT_VARIANTS := 3              # baked take-variants for high-frequency cues
```

- [ ] **Step 2: Write the failing test** — append before the summary print in `sfx_tests.gd`:

```gdscript
	# jitter is bounded and actually varies (the #1 boring-fix)
	var pitches := {}
	for i in range(40):
		pitches[Audio.jitter_pitch(1.0)] = true
	ok(pitches.size() > 1, "jitter_pitch varies across calls")
	var within := true
	for p in pitches:
		if p < 0.95 or p > 1.06: within = false
	ok(within, "jitter_pitch stays within ~±35 cents of base")
```

- [ ] **Step 3: Run to verify it fails**

Run: `make test-one SUITE=engine/tests/sfx_tests`
Expected: FAIL — `jitter_pitch` not defined.

- [ ] **Step 4: Rewrite `play` + add `jitter_pitch`**

In `engine/scripts/core/audio.gd`, replace the `play` function with:

```gdscript
static func jitter_pitch(base: float) -> float:
	var cents := randf_range(-Tune.PITCH_JITTER_CENTS, Tune.PITCH_JITTER_CENTS)
	return base * pow(2.0, cents / 1200.0)

static func play(name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not Save.get_setting("sfx", true):
		return
	_ensure()
	var variants: Array = _sounds.get(name, [])
	if variants.is_empty():
		return
	var idx := int(_rr.get(name, 0))             # round-robin per name
	_rr[name] = (idx + 1) % variants.size()
	var pl: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	pl.stream = variants[idx]
	pl.pitch_scale = jitter_pitch(pitch)         # center on caller's pitch, jitter on top
	pl.volume_db = volume_db + randf_range(-Tune.GAIN_JITTER_DB, Tune.GAIN_JITTER_DB)
	pl.play()
```

- [ ] **Step 5: Run to verify it passes**

Run: `make test-one SUITE=engine/tests/sfx_tests`
Expected: `== 32 passed, 0 failed ==`, exit 0.

- [ ] **Step 6: Run the fast sweep (nothing else regressed)**

Run: `make test-fast`
Expected: all engine suites pass, `sfx_tests` included.

- [ ] **Step 7: Commit**

```bash
git add engine/scripts/core/audio.gd engine/scripts/core/tuning.gd engine/tests/sfx_tests.gd
git commit -m "feat(sfx): per-trigger pitch/gain jitter + round-robin variants"
```

---

## Task 7: Wire `coin_earn` (the silent sell)

The harvest-sell coin grant at `board.gd:2209` plays no dedicated sound.

**Files:**
- Modify: `engine/scripts/scenes/board.gd:2209`

- [ ] **Step 1: Locate the exact line**

Run: `grep -n 'Save.add_coins(G.coin_value(code))' engine/scripts/scenes/board.gd`
Expected: one hit (~line 2209) — the merchant sell.

- [ ] **Step 2: Add the cue** — insert a line immediately after the `Save.add_coins(...)` call:

```gdscript
	Save.add_coins(G.coin_value(code))
	Audio.play("coin_earn", -3.0)
```

- [ ] **Step 3: Verify it compiles + plays in the smoke test**

Run: `make test-one SUITE=engine/tests/smoke`
Expected: scene instantiates, no script error.

- [ ] **Step 4: Commit**

```bash
git add engine/scripts/scenes/board.gd
git commit -m "feat(sfx): coin_earn on harvest sell"
```

---

## Task 8: Distinct `unlock` cue (spot unlock ≠ map-gate fanfare)

`board.gd:2088` plays `level_complete` for the spot-unlock; give it the dedicated `unlock` cue so spot-unlock and the great-spirit gate sound different.

**Files:**
- Modify: `engine/scripts/scenes/board.gd:2088`

- [ ] **Step 1: Locate the line**

Run: `grep -n 'level_complete" if Audio.has("level_complete")' engine/scripts/scenes/board.gd`
Expected: one hit (~line 2088) — the spot-unlock fanfare.

- [ ] **Step 2: Swap to the unlock cue**

Replace:
```gdscript
	Audio.play("level_complete" if Audio.has("level_complete") else "merge_success", -3.0, 1.1)
```
with:
```gdscript
	Audio.play("unlock" if Audio.has("unlock") else "level_complete", -3.0)
```

- [ ] **Step 3: Verify**

Run: `make test-one SUITE=engine/tests/smoke`
Expected: no script error.

- [ ] **Step 4: Commit**

```bash
git add engine/scripts/scenes/board.gd
git commit -m "feat(sfx): distinct unlock cue for spot unlock"
```

---

## Task 9: Wire the remaining silent cues (`quest_complete`, `star_pop`, `undo`, `item_slide`)

These have baked cues but no call site. Wire each at the cleanest hook. `item_slide`
ships behind a **default-off** dial because a per-drag sound risks being annoying;
it is enabled only by flipping the dial after playtest.

**Files:**
- Modify: `engine/scripts/scenes/board.gd` (located hooks)
- Modify: `engine/scripts/core/tuning.gd` (`SLIDE_ENABLED` dial)

- [ ] **Step 1: quest_complete — fire when the gate becomes ready**

Run: `grep -n '_set_home_ready' engine/scripts/scenes/board.gd`
Find the function `_set_home_ready` (around board.gd:673). Add an edge-detected
cue: at the top of the function body, before it stores the new state, compare to
the prior. Add a static-style member near the other `var` declarations:

```gdscript
var _gate_was_ready := false
```
Then inside `_set_home_ready(ready: bool)` (use the actual param name from the
signature shown by grep), at the start:
```gdscript
	if ready and not _gate_was_ready:
		Audio.play("quest_complete", -2.0)
	_gate_was_ready = ready
```

- [ ] **Step 2: star_pop — on harvest delivery tick**

Run: `grep -n 'star_earn' engine/scripts/scenes/board.gd`
At the `star_earn` site (~board.gd:2218) the delivery already plays `star_earn`.
Leave `star_earn` as the main delivery cue; `star_pop` stays baked but **unwired**
for now (wiring both would double up). Note this in the commit. No code change in
this step — documented decision.

- [ ] **Step 3: undo — on bag-return / snap-back**

Run: `grep -n '_snap_back' engine/scripts/scenes/board.gd`
At the start of `_snap_back(...)` add:
```gdscript
	Audio.play("undo", -4.0)
```

- [ ] **Step 4: item_slide — behind a default-off dial**

In `tuning.gd` `class Audio`, add:
```gdscript
	const SLIDE_ENABLED := false         # per-drag slide tick (off by default; playtest before enabling)
```
Find the drag-move handler:
Run: `grep -n 'func _on.*drag\|func _drag\|NOTIFICATION_DRAG\|_gui_input' engine/scripts/scenes/board.gd | head`
At the chosen drag-motion hook, guard the cue:
```gdscript
	if Tune.SLIDE_ENABLED:
		Audio.play("item_slide", -10.0)
```
(If no clean single drag-motion hook exists, skip item_slide wiring this pass and
note it — the cue stays baked for later. Do not force a noisy hook.)

- [ ] **Step 5: Verify**

Run: `make test-one SUITE=engine/tests/smoke && make test-fast`
Expected: scene instantiates; all engine suites pass.

- [ ] **Step 6: Commit**

```bash
git add engine/scripts/scenes/board.gd engine/scripts/core/tuning.gd
git commit -m "feat(sfx): wire quest_complete + undo; item_slide behind a dial; star_pop deferred"
```

---

## Task 10: Archive the old concept SFX + full sweep

The 15 `_concepts/sfx/*.wav` are superseded by the baked palette. Per the
no-delete-raws rule, **archive** rather than delete.

**Files:**
- Move: `games/grove/assets/_concepts/sfx/` → `games/grove/assets/_archive/sfx_concepts_2026-06-24/`
- Modify: spec note (optional)

- [ ] **Step 1: Archive the concept dir**

```bash
mkdir -p games/grove/assets/_archive
git mv games/grove/assets/_concepts/sfx games/grove/assets/_archive/sfx_concepts_2026-06-24
```

- [ ] **Step 2: Confirm nothing references the concept path**

Run: `grep -rn '_concepts/sfx' engine/ games/ --include='*.gd'`
Expected: no hits (the loader reads `music/sfx/` only).

- [ ] **Step 3: Full sweep**

Run: `make test`
Expected: every suite (engine + grove) passes; the per-suite table shows
`sfx_tests` green and no regressions.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore(sfx): archive superseded concept SFX; full palette synth-baked"
```

---

## Manual listen-check (after Task 10)

Headless tests can't judge timbre. Before merging, bake to a scratch dir and
listen, or run the game and trigger: a merge chain (hear variation), a sell
(coin), a spot-unlock (unlock vs gate fanfare), an invalid move, a water tap.
This mirrors the demo step that set the aesthetic.

Run: `python3 -m tools.sfx_synth.bake /tmp/sfx_listen` then audition the WAVs.

---

## Self-review notes (filled during writing)

- **Spec coverage:** generator (T1–4), richness/variation (T1, T6), loader foot-gun
  fix (T5), full 20-event palette (T2 recipes + T4 bake + T7–9 wiring), testing
  (T1–3 python, T5–6 godot), out-of-scope items untouched (no bus split, no AI),
  cleanup/archive (T10). ✓
- **`roof_open`/`room_complete`** intentionally absent (retired interiors). ✓
- **Type/name consistency:** `_sounds` is `name -> Array` everywhere after T5;
  `play` (T6) reads it as an Array; `has`/`variant_count` match. `jitter_pitch`,
  `variant_count`, `CUES`, `HOT`, `RECIPES`, `manifest["cues"]` used consistently. ✓
- **Known judgment calls:** `star_pop` baked-but-unwired (avoids doubling with
  `star_earn`); `item_slide` default-off (annoyance risk). Both flagged in-task.
```
