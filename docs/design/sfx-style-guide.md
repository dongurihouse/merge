# Acorn Forest: Merge! — SFX style guide

The single source of truth for sound direction, the cue palette, per-cue loudness targets,
and the combo-melody system. The palette is **synthesized deterministically** by
`tools/sfx_synth` (`make sfx` re-bakes everything); do not drop in foreign one-off samples.

## 1. Evaluation of the first palette (2026-06) — what was wrong

The first bake got the *idea* right (one shared pentatonic key, mallet/bell family) but the
result read as rough, punchy, and — on a merge streak — out of tune. Root causes, measured
in the old `primitives.py` / `feel.gd`:

1. **Baked-in roughness.** Every tone ran through `tanh(x * 1.3–1.4)` saturation, which adds
   hard odd harmonics; attacks were 0.5–4 ms (a click, not a touch); the `air()` room impulse
   was raw unsmoothed noise (an audible hiss tail); and *every* cue normalized to the same
   −3 dBFS peak, so a button tick hit as hard as a fanfare.
2. **The combo "melody" could not harmonize — three compounding detunes.**
   - The tier base pitch `0.95 + 0.03*tier` multiplied the root by a non-musical factor
     (tier 2 ≈ +17 cents off-key — between piano keys).
   - `Audio.play` added ±35 cents of *random* pitch jitter to every trigger. A melody whose
     notes are each randomly up to 35 cents flat/sharp sounds sour by construction.
   - The ladder itself was `pitch_scale` resampling of one sample by up to +21 semitones —
     chipmunk artifacts and a decay that shrinks as the pitch rises.
   - `merge_success` baked a **two-note interval** per variant and round-robined three
     different intervals, so consecutive streak steps played different dyads, each shifted
     off-key by a different amount.
3. **Role confusion.** Merges, bag in/out, undo, and UI confirms all shared the same mallet
   timbre; `invalid` was still a musical (pentatonic-adjacent) note; `item_slide` was plain
   noise hiss.

## 2. How a cozy merge game should sound (direction)

Genre references: Merge Mansion / Merge Dragons (merge chains as rising tuned notes),
Triple Town, Two Dots (combo = a pentatonic run of *pre-tuned discrete notes*), Unpacking
(soft foley for handling), Animal Crossing (UI as felt/wood, nothing above a whisper).

Principles, in priority order:

1. **Touch, not impact.** Common actions (pickup, drop, tap) are *foley of soft materials* —
   felt, wood, water — with ≥6–10 ms attacks, no saturation edge, energy mostly below 4 kHz.
2. **One key, exact tuning.** Everything musical lives on C-major pentatonic (C D E G A).
   Melodic cues are **baked at exact note frequencies and played untransposed** — never
   pitch-warped, never pitch-jittered. Pentatonic guarantees any overlap harmonizes.
3. **The combo IS the melody.** Each consecutive merge in the streak window plays the *next
   baked note* of the ladder (degree = live combo count). Merge fast and you literally play
   a rising kalimba run; the streak lapsing resets to the root. Escalation of *tier* changes
   voicing (a soft octave-shimmer layer on big tiers), **never** the root pitch — so a
   streak across mixed tiers still plays one coherent run.
4. **Loudness maps to meaning.** Per-cue-class peak ceilings (see §4): frequent cues
   quietest, fanfares loudest. Nothing above −3 dBFS, UI ticks near −12.
5. **Variation via takes, not detune.** Hot *non-melodic* cues bake 3 take-variants
   (micro-param shifts) and keep a small ±12-cent pitch jitter; melodic cues get **zero
   pitch jitter** (gain jitter only).
6. **Short.** Feedback ≤0.35 s, foley ≤0.2 s, only fanfares may ring ≥1 s.

## 3. The cue palette

| Cue | Role / sound | Notes |
|---|---|---|
| `merge_note` ×10 | THE merge sound: one soft kalimba note per combo degree | C5 D5 E5 G5 A5 C6 D6 E6 G6 A6 — exact Hz, played by index, no jitter |
| `merge_shine` | Additive shimmer layered on tier ≥4 merges | soft bell dyad (E6+A6), quiet, rides on top of the note |
| `merge_soft` ×3 | legacy family for non-board "small confirm" call sites | single soft kalimba E5/G5/A5 takes (no dyads) |
| `merge_success` ×3 | legacy family for non-board "big confirm" call sites | gentle two-note rise, all takes same interval shape, in key |
| `button_tap` ×3 | felt-covered wood "tup" | duller, softer than before; no click transient |
| `item_pickup` ×3 / `item_drop` ×3 | tiny woody touch up / down | pickup slightly brighter than drop |
| `item_slide` | short soft brush | darker, quieter |
| `invalid_soft` | muted damped double-thud | deliberately NON-musical (dull, inharmonic) |
| `water_pop`, `rain_refill` | plip / plips over pad | unchanged roles, softened |
| `tidy_poof`, `bramble_clear` | air puff / twig snap in leaves | softened noise |
| `bag_in` / `bag_out` | low/high soft pluck pair | distinct (duller) from merge family |
| `coin_earn`, `star_pop`, `star_earn`, `giver_cheer` | sparkle family | bells softened |
| `undo` | small descending pair | in key, quiet |
| `unlock`, `quest_complete`, `level_complete` | fanfares | pad + arpeggio, softened bells |

## 4. Peak targets (bake-time normalize, per cue)

- UI ticks (`button_tap`, `item_slide`): **−12 dBFS**
- Foley (`item_pickup`, `item_drop`, `bag_*`, `tidy_poof`, `invalid_soft`, `undo`): **−9 dBFS**
- Melodic feedback (`merge_note`, `merge_soft`, `merge_success`, `merge_shine`, `water_pop`,
  `star_pop`, `coin_earn`, `bramble_clear`): **−6 dBFS**
- Fanfares (`level_complete`, `quest_complete`, `unlock`, `rain_refill`, `star_earn`,
  `giver_cheer`): **−4 dBFS**

Call sites keep their existing relative `volume_db` offsets on top.

## 5. Engine playback rules

- `Audio.play(name, db, pitch)` — unchanged for non-melodic cues; per-trigger pitch jitter
  is now ±12 cents (was ±35).
- `Audio.play_note(name, idx, db)` — NEW: plays variant `idx` (clamped) of a melodic cue at
  exactly pitch 1.0, **no pitch jitter**, gain jitter only.
- `feel.gd` / `merge_fx.gd` merge sound: degree = live combo count (clamped 0..9) →
  `play_note("merge_note", degree)`; tier ≥4 additionally plays `merge_shine` quietly.
  The old tier→pitch curve and `pitch_scale` pentatonic ladder are deleted.
- `slot_reel.gd` reveal ladder: `play_note("merge_note", i)` per reveal index — same scale.

## 6. Verification (never eyeball / never just "it played")

`tools/sfx_synth/test_synth.py` measures the bake: FFT fundamental of each `merge_note`
within ±10 cents of its target Hz; attack (time to 90% of peak) ≥5 ms on musical cues;
per-class peak dBFS as §4; durations within budget; bake determinism. Engine tests pin the
manifest, `play_note` indexing/clamping, and the degree math. For human review, bake demo
renders (a fast combo run + a full soundboard) and hand them over.
