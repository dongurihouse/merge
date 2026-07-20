"""Deterministic DSP building blocks for the cozy SFX palette.

Pure numpy/scipy. Every generator takes an explicit `rng`
(numpy.random.Generator) so the bake is reproducible. Output is mono float64
in roughly [-1, 1]; the bake normalizes + writes Int16 WAVs.

Style rules (docs/design/sfx-style-guide.md): soft attacks (>=6 ms on musical
tones), no hard saturation edge, smoothed room air, energy mostly below 4 kHz.
"""
import numpy as np
from scipy.signal import fftconvolve

SR = 44100

# C-major pentatonic (C D E G A) across octaves — the spec's shared key.
NOTE = {
    "C4": 261.63, "D4": 293.66, "E4": 329.63, "G4": 392.00, "A4": 440.00,
    "C5": 523.25, "D5": 587.33, "E5": 659.25, "G5": 783.99, "A5": 880.00,
    "C6": 1046.50, "D6": 1174.66, "E6": 1318.51, "G6": 1567.98, "A6": 1760.00,
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


def soft(x, drive=0.7):
    """Gentle peak rounding: normalize then a low-drive tanh (mostly linear).
    Replaces the old hard `tanh(x * 1.4)` that added the rough odd-harmonic edge."""
    p = np.max(np.abs(x)) + 1e-9
    return np.tanh(x / p * drive) / np.tanh(drive)


def kalimba(rng, freq, dur=0.36, tau=0.14, attack=0.008, detune=0.002):
    """Warm plucked tine — the melodic voice of the palette. Near-pure tone
    (fundamental + one soft slightly-inharmonic partial + a whisper of sparkle),
    soft 8 ms attack, exponential ring. No saturation edge."""
    tt = t(dur)
    f = freq * (1 + rng.uniform(-detune, detune))
    out = (1.00 * np.sin(2 * np.pi * f * tt) * np.exp(-tt / tau)
           + 0.22 * np.sin(2 * np.pi * f * 2.02 * tt) * np.exp(-tt / (tau * 0.45))
           + 0.05 * np.sin(2 * np.pi * f * 5.4 * tt) * np.exp(-tt / (tau * 0.18)))
    return fades(soft(out) * env_exp(dur, tau * 2.2, attack), fin=attack)


def mallet(rng, freq, dur=0.28, tau=0.10, partials=(1, 2, 3, 4.2),
           amps=(1.0, 0.35, 0.14, 0.05), detune=0.004, attack=0.008):
    """Soft tuned mallet/marimba tone; higher partials decay faster."""
    tt = t(dur)
    out = np.zeros_like(tt)
    for p, amp in zip(partials, amps):
        f = freq * p * (1 + rng.uniform(-detune, detune))
        out += amp * np.sin(2 * np.pi * f * tt) * np.exp(-tt / (tau / (0.5 + 0.5 * p)))
    return fades(soft(out) * env_exp(dur, tau * 2.2, attack), fin=attack)


def bell(rng, freq, dur=0.32, tau=0.16, attack=0.004):
    """Glassy inharmonic tone — coin/star sparkle, songbird. Softened highs."""
    tt = t(dur)
    out = np.zeros_like(tt)
    for p, amp in zip((1.0, 2.76, 5.40, 8.93), (1.0, 0.38, 0.16, 0.05)):
        out += amp * np.sin(2 * np.pi * freq * p * tt) * np.exp(-tt / (tau / (0.6 + 0.4 * p)))
    return fades(out * env_exp(dur, tau, attack), fin=attack)


def woodknock(rng, freq=185.0, dur=0.12, attack=0.003):
    """UI 'tup': felt-covered wood — low damped modes, no click transient."""
    tt = t(dur)
    body = (np.sin(2 * np.pi * freq * tt) * np.exp(-tt / 0.028)
            + 0.35 * np.sin(2 * np.pi * freq * 2.7 * tt) * np.exp(-tt / 0.014))
    thump = np.sin(2 * np.pi * freq * 0.5 * tt) * np.exp(-tt / 0.02) * 0.3
    return fades(soft(body + thump) * env_exp(dur, 0.05, attack), fin=attack)


def water_plip(rng, f0=1100.0, f1=360.0, dur=0.16):
    """Resonant downward pitch-drop 'bloop' — synth's strong suit."""
    tt = t(dur)
    k = np.log(f0 / f1) / dur
    inst = f0 * np.exp(-k * tt)
    phase = 2 * np.pi * np.cumsum(inst) / SR
    body = np.sin(phase) * np.exp(-tt / 0.05)
    click = rng.standard_normal(len(tt)) * np.exp(-tt / 0.002) * 0.1
    return fades(soft(body + click, drive=0.9), fin=0.002)


def noise_texture(rng, dur=0.20, tau=0.05, smooth=12, color=1.0, attack=0.004):
    """Filtered-noise burst for foliage/poof/twig. `color`>1 brightens."""
    tt = t(dur)
    nz = rng.standard_normal(len(tt))
    k = max(1, int(smooth / color))
    nz = np.convolve(nz, np.ones(k) / k, mode="same")
    return fades(soft(nz, drive=1.1) * np.exp(-tt / tau), fin=attack)


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


def air(rng, x, amount=0.16, room=0.13):
    """Tiny decaying-noise room IR → natural tail/air. Lengthens x by `room`.
    IR is heavily smoothed so the tail is a warm bloom, not hiss."""
    n = int(SR * room)
    ir = rng.standard_normal(n) * np.exp(-np.linspace(0, 1, n) * 6)
    ir = np.convolve(ir, np.ones(64) / 64, mode="same")
    wet = fftconvolve(x, ir)
    out = np.zeros(len(wet))
    out[:len(x)] += x
    out += wet / (np.max(np.abs(wet)) + 1e-9) * amount
    return out


def normalize(x, peak_dbfs=-3.0):
    x = np.asarray(x, dtype=np.float64)
    return x / (np.max(np.abs(x)) + 1e-9) * (10 ** (peak_dbfs / 20))
