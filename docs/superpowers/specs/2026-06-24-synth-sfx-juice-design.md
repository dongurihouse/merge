# Synth-baked, juicy SFX — design

**Date:** 2026-06-24 · **Status:** approved design, pre-plan · **Topic:** audio / SFX redesign

## Context

The grove ships 8 SFX that actually play, 2 ambient music takes, and a clean
`audio.gd` / `music.gd` helper layer ([grove_spec §10](../../design/grove_spec.md)).
An audit (2026-06-24) found the current SFX feel "boring," and traced it to two
root causes that are independent of the source files:

1. **No runtime variation.** Every trigger plays the *identical* sample at a
   *fixed* pitch — zero round-robin variants, zero per-trigger jitter (no `randf`
   in any `Audio.play` call site). The same press sounds byte-identical every
   time, which reads as "cheap."
2. **No musical tuning + unused palette.** The spec wants organic forest one-shots
   tuned to one **C / A-minor pentatonic key** so nothing sounds sour over the
   music bed. The current cues are not key-tuned, and the spec's organic palette
   (water plips, twig-snaps, songbird trills) sits inert in `assets/_concepts/sfx/`.

The audit also found a **loader foot-gun**: `audio.gd` loads only 8 hardcoded
names from `music/sfx/`, so the 15 finished WAVs in `_concepts/sfx/` can never
load. Seven of them are *already wired* with `Audio.has(name)` fallbacks that
therefore always lose — e.g. the water tap plays a generic `item_drop`, never a
water plip.

**Decision (owner, 2026-06-24):** redesign the whole ~20-event palette with
**pure procedural synthesis** (numpy/scipy), and treat audio as **another type of
juice** — a first-class peer to the visual `FX` / `Look` vocabulary
([grove_spec §12](../../design/grove_spec.md)), not a bolted-on `play()`. A
proof-of-concept synth demo cleared the owner's quality bar.

## Goals

- Replace the 8 thin cues and **voice the full ~20-event palette** from one
  coherent synth toolkit, all tuned to C-pentatonic.
- Make every cue **rich** (layered) and **alive** (varies per trigger).
- Fix the loader foot-gun so cues load by convention, not a hardcoded list.
- Keep the existing `audio.gd` API and graceful-degradation behaviour.

## Non-goals (deferred)

- SFX/Music **bus split**, a global volume slider, and **ducking** under fanfares
  — single Master bus stays for now.
- Calm-Mode audio softening.
- Any AI text-to-SFX or sampled/CC foley. Synth-only.
- Music (`amb_grove*`) redesign — out of scope; this is SFX only.
- `roof_open` / `room_complete` cues — they belong to the retired interiors model
  ([grove_spec §8/§10](../../design/grove_spec.md)); not voiced.

## Architecture — two halves, mirroring the art pipeline

The project's load-bearing rule (CLAUDE.md asset-intake): *scripts are
deterministic; all judgment lives in an authored recipe.* Audio adopts the same
split.

```
tools/sfx_synth/            offline, deterministic  ──make sfx──▶  assets/music/sfx/*.wav  (committed)
  primitives.py   DSP building blocks                                        │
  recipes.py      per-cue authored "plan" (judgment)                         ▼
  bake.py         renders recipes → WAVs                          engine/scripts/core/audio.gd
                                                                  loads + adds live juice (variation)
```

- **Offline generator** bakes WAVs; same seed → identical bytes; output committed
  to git (like other processed assets). New `make sfx` target sits alongside
  `make decor` / `make icon`.
- **Runtime player** loads the baked cues and adds the *live* juice: variant
  selection + pitch/gain jitter + tier response.

## The generator — `tools/sfx_synth/`

**`primitives.py`** — deterministic DSP, seeded `numpy.random.default_rng`:
- Tone generators: `mallet`, `bell`, `pluck`, `woodknock`, `water`, `pad`,
  `noise_texture`.
- Shapers: `adsr`, `air` (short decaying-noise room tail), `saturate` (soft
  tanh warmth), `fades` (anti-click), `normalize` (peak −3 dBFS).
- `NOTE` table: C-major-pentatonic frequencies across octaves (C D E G A).

**`recipes.py`** — the authored judgment. One entry per cue describing its
layers (transient + body + tail), scale degree(s), envelope, and air amount.
Recipes are data; primitives are code. Stored as Python (expressive, lives with
the DSP — a deliberate divergence from the art pipeline's `plan.json`).

**`bake.py`** — renders every recipe to `assets/music/sfx/`. For *hot* cues
(`button_tap`, `merge_soft`, `merge_success`, `item_pickup`, `item_drop`) it
renders **3 take-variants** (`name_1.wav`, `name_2.wav`, `name_3.wav`) varied by
scale degree + micro-params; other cues render a single take. Deterministic seed
so re-running reproduces identical bytes.

**Output contract per cue** (matches [grove_spec §10](../../design/grove_spec.md)):
mono, 44.1 kHz, Int16; **≤0.6 s** (the `level_complete` / `quest_complete`
fanfares are the allowed exceptions); peak ≈ **−3 dBFS**; pitched content lands
on the shared key.

## Richness — the five juice levers

1. **Three layers per cue** — a snap *transient*, a tuned *body*, a soft *air
   tail* — never a single bare tone.
2. **Musical tuning** — every cue on C-pentatonic; rewards use intervals /
   arpeggios (`merge_success` = a two-note lift; `level_complete` = an ascending
   run), so the palette feels composed, not beepy.
3. **Tier-responsive merges** — timbre brightens and gains a sparkle layer as
   merge tier climbs (richer than today's fixed pitch bump).
4. **Variation** — baked 3-variant round-robin on hot cues **plus** runtime
   pitch (±cents) and gain (±dB) jitter on *every* trigger. No two presses
   identical.
5. **Shared air** — a faint common room tail glues the palette into one
   "sunlit field" space.

## Runtime rework — `engine/scripts/core/audio.gd`

- **Manifest/glob loader** replaces the hardcoded `FILES` array: scan
  `music/sfx/` for `*.wav`, group by base name (strip the `_N` variant suffix),
  cache the variant list per name. This permanently fixes the foot-gun and makes
  the spec's "drop a take in, zero code changes" promise true for *new names*,
  not just re-records.
- `play(name, volume_db = 0.0, pitch = 1.0)` keeps its signature. Every call:
  picks the next variant (round-robin per base name, so immediate repeats are
  avoided) and **always** layers `PITCH_JITTER_CENTS` + `GAIN_JITTER_DB` on top.
  The `pitch` / `volume_db` args set the *center* that jitter varies around —
  they do not disable jitter — so the tier-scaled merge keeps its deliberate
  pitch climb *and* still varies take-to-take.
- `has(name)` unchanged (now answers correctly for the whole palette).
- New dials in `tuning.gd` `class Audio`: `PITCH_JITTER_CENTS`,
  `GAIN_JITTER_DB`, `HOT_VARIANTS` (= 3). `VOICES` stays 8.
- Graceful degradation preserved: a missing cue is still silently skipped.

## The ~20-event palette

Grouped by synth timbre family. **Status** = `active` (plays today),
`activate` (call site exists with a fallback; lights up once the loader is fixed),
`add` (no call site yet — implementation adds one).

| Family | Event | Status | Call-site anchor / note |
|---|---|---|---|
| **Wood / UI** | `button_tap` | active | many sites |
| | `invalid_soft` | active | many sites (in-key low "no") |
| | `undo` | add | drag-away / revert moment |
| | `item_slide` | add | drag motion (throttled; soft) |
| **Pluck / mallet** | `merge_soft` | active | tier <4 merge |
| | `merge_success` | active | tier ≥4 merge, shop OK, reveal |
| | `item_pickup` | active | grab |
| | `item_drop` | active | place |
| | `bag_in` | activate | board.gd:2269 (fallback `item_pickup`) |
| | `bag_out` | activate | board.gd:2305 (fallback `item_drop`) |
| | `star_earn` | activate | board.gd:2218 (fallback `merge_soft`) |
| | `star_pop` | add | star counter increment |
| **Water** | `water_pop` | activate | board.gd:2021/2047 (water tap) |
| | `rain_refill` | activate | shop.gd:419, board.gd:305/659 |
| **Foliage / clear** | `bramble_clear` | activate | board.gd:2161 (fallback `tidy_poof`) |
| | `tidy_poof` | active | dismiss / cleanup |
| **Bell / fanfare** | `coin_earn` | add | harvest sell / coin grant |
| | `giver_cheer` | activate | board.gd:2445 (fallback `merge_success`) |
| | `unlock` | add | map/spot unlock (distinct from `level_complete`) |
| | `quest_complete` | add | quest fence fully metered |
| | `level_complete` | active | map gate fanfare |

Activating a cue = baking its WAV into `music/sfx/` so the loader finds it; the
existing `Audio.has(...)` branches then take their intended path automatically.
For `add` events, implementation locates the exact site (e.g. the sell/coin-grant
path, the quest-fence-complete signal) and inserts a `play(...)` call.

## Testing (headless)

A `sfx_tests` suite (engine, under the fast inner loop) asserts:
- **No silent fallbacks left**: every wired `Audio.play(...)` literal/branch
  resolves to a cue present in `music/sfx/`.
- **Variants load**: hot cues expose ≥`HOT_VARIANTS` takes; non-hot expose ≥1.
- **Generator determinism**: re-running `bake.py` yields stable file hashes.
- **Format contract**: every baked cue is mono / 44.1 k / Int16, ≤0.6 s
  (fanfares whitelisted), peak ≤ −3 dBFS within tolerance.
- Variation: `play` with default args produces a non-constant pitch/gain across
  N calls (jitter is live).

## File-by-file change summary

- **add** `tools/sfx_synth/{primitives,recipes,bake}.py`
- **add** `make sfx` target (Makefile)
- **add/replace** `games/grove/assets/music/sfx/*.wav` (baked palette, ~30 files)
- **edit** `engine/scripts/core/audio.gd` (glob loader + variation in `play`)
- **edit** `engine/scripts/core/tuning.gd` (`class Audio` dials)
- **edit** call sites for `add` events (board / shop / map — located in impl)
- **add** `engine/tests/sfx_tests.gd` + register in the suite runner
- **retire** `games/grove/assets/_concepts/sfx/` once its useful cues are baked
  (archived, not deleted, per the no-delete-raws rule)

## Locked decisions

- **3 variants for hot cues only** (~30 baked files, not ~60).
- **Recipes in Python**, not `plan.json`.
- **Synth-only**, full ~20-event palette, mono, C-pentatonic.
