# Generator rank ramps — 8 recolors per line (mastery §7 trim)

Candidate art for generator mastery ranks 1–8: **the same generator sprite, recolored**, muted at
rank 1 to vivid at rank 8. Not yet approved; nothing loads these at runtime.

## How they are made

`rank_ramp_lines.py <src.png> <outdir> <stem>` — reads a shipped generator sprite and writes
`<stem>_r1..r8.png` plus a labelled review strip. Only H/S/V of visible pixels move; alpha and
every shape are untouched, so all 8 ranks are provably the same object.

```bash
python3 rank_ramp_lines.py \
  games/grove/assets/items/generator/gen_fairy_hollow_glowshroom.png /tmp/out glowshroom
```

**Do not generate these with an image model.** A redraw drifts the silhouette — the 2026-07-26
Codex attempt changed spot count, spot positions, cap dome, and stump proportions between cells,
which fails the "exactly the same object" requirement. The recolor is deterministic: same source +
same curve = identical bytes.

## The per-line color scheme

Each line gets its own curve because one global curve leaves pale lines unchanged — multiplying
the saturation of a near-white pixel is a no-op, so Snow & Ice barely moved across 8 ranks. Pale
lines get an **additive** chroma lift plus a value fall, so they deepen into their own hue.

| Line | Reads as | sat × (r1→r8) | sat + (r1→r8) | value (r1→r8) |
|---|---|---|---|---|
| Glow-mushrooms | pale lilac → royal violet | 0.78 → 1.98 | — | 1.05 → 0.96 |
| Wild Berries | soft sage/plum → deep green + grape | 0.78 → 1.92 | → 0.02 | 1.05 → 0.95 |
| Snow & Ice | near-white → glacier blue | 0.85 → 2.40 | → 0.30 | 1.05 → 0.88 |
| Woolens | oat cream → warm amber | 0.82 → 2.10 | → 0.17 | 1.05 → 0.92 |
| Desert Fruits | pale clay → hot terracotta | 0.78 → 1.90 | → 0.02 | 1.05 → 0.96 |
| Sand Sculptures | bone beige → golden sand | 0.85 → 2.00 | → 0.13 | 1.05 → 0.93 |
| Shells | driftwood tan → deep sea blue + gold | 0.82 → 2.10 | → 0.15 | 1.05 → 0.92 |
| Koi | dusty coral → vermilion | 0.80 → 1.70 | — | 1.06 → 0.94 |

Rank 1 sits slightly below the shipped art (still a proper object, not drained); the shipped art
sits around rank 3–4; rank 8 is the vivid top. Two earlier anchorings were rejected: rank 4 =
shipped drained ranks 1–2 to near-stone, and rank 1 = shipped made ranks 1–4 indistinguishable.

## Known blemishes (fix before shipping)

- **Snow & Ice** dome drifts minty green at ranks 6–8 (its base hue is blue-green; additive chroma
  exaggerates the green). Needs a hue nudge toward blue for this line.
- **Sand Sculptures** at rank 8 reads gold rather than sand — acceptable as "golden sand", or pull
  the top end back.

## If approved

Ranks land as `items/generator/<gen>_r<N>.png` and supersede the generic 4-frame trim overlay in
§7 of `docs/superpowers/specs/2026-07-26-generator-mastery-design.md` (the spec says the trim is
one shared overlay set; a full per-rank recolor replaces that). Update the spec in the same pass.
