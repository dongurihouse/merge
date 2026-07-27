# Generator rank ramps — 8 recolors per line (mastery ranks)

Candidate art for generator mastery ranks 1–8: **the same generator sprite, recolored**, muted at
rank 1 to jewel-vivid at rank 8. Not yet approved; nothing loads these at runtime.

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
failing the "exactly the same object" requirement. The recolor is deterministic: same source +
same curve = identical bytes.

## The curve

Three terms, all ramping with rank:

1. **Saturation multiply** — the base drive, ×0.55 at rank 1 up to ×2.0–2.9 at rank 8 per line.
2. **Vibrance, weighted by the chroma already present** — an additive lift that ramps in across
   `s ∈ [0.08, 0.33]`. This weighting is load-bearing: an unweighted lift amplifies the faint
   off-hue in near-white paper into the wrong colour (it turned Snow & Ice's white dome lime, and
   in an earlier pass hot pink). Weighted, whites stay white and only real colour masses surge.
3. **Value lift** — brightness *rises* with rank (×1.02 → ×1.13–1.16). Darkening high ranks reads
   as duller, not richer; vivid needs luminance.

**Hue is locked.** Fanning hues apart made ranks colourful but destroyed line identity (ice went
hot pink, the shells lid purple, koi's water drop green). Pulling hues toward the line's identity
colour was worse — cream trim dragged through green. Identity survives only if hue does not move.

| Line | Rank 1 → rank 8 | sat × | vibrance | value |
|---|---|---|---|---|
| Glow-mushrooms | stone lilac → electric magenta, gold spots | 0.55 → 2.30 | 0.50 | 1.02 → 1.15 |
| Wild Berries | sage/tan → vivid orange basket, lime leaves, grape | 0.55 → 2.30 | 0.50 | 1.02 → 1.14 |
| Snow & Ice | grey-white → icy dome, vivid blue walls, gold trim | 0.55 → 2.90 | 0.62 | 1.02 → 1.13 |
| Woolens | oat cream → rich golden amber | 0.55 → 2.60 | 0.58 | 1.02 → 1.15 |
| Desert Fruits | pale clay → hot orange, vivid cacti | 0.55 → 2.25 | 0.48 | 1.02 → 1.14 |
| Sand Sculptures | bone beige → golden sand, blue spade | 0.55 → 2.50 | 0.55 | 1.02 → 1.14 |
| Shells | driftwood → gold basket, deep sea-blue lid | 0.55 → 2.60 | 0.58 | 1.02 → 1.14 |
| Koi | dusty coral → vermilion and gold | 0.55 → 2.20 | 0.46 | 1.02 → 1.16 |

Rank 1 is deliberately muted so the arc is dramatic; the shipped art sits around rank 3–4.
Two anchorings were rejected on the way: shipped-at-rank-4 drained ranks 1–2 to near-stone, and
shipped-at-rank-1 made ranks 1–4 indistinguishable.

## If approved

Ranks land as `items/generator/<gen>_r<N>.png` and supersede the generic 4-frame trim overlay in
§7 of `docs/superpowers/specs/2026-07-26-generator-mastery-design.md` (that section says the trim
is one shared overlay set; a full per-rank recolor replaces it). Update the spec in the same pass,
and note the sprites are generated, so regenerating beats hand-editing.

## The rank number badge

`rank_badge.py <ramp_dir> <stem> <out.png> [br|tr] [cream|gold|ink]` composites a rank numeral
onto each ramp step for review (`review/badged/`).

**Cream fill, ink numeral, bottom-right** is the pick: it matches the game's cream-pill/ink-text
language and stays legible on warm and cool lines at every rank. Alternatives kept beside it —
`_alt_gold_badge.png` sinks into the gold crescent and warm wood at ranks 7–8, `_alt_ink_badge.png`
reads but sits heavier. Bottom-right keeps it clear of the boost-taps badge, which the shipped
code hangs off the **top**-right (`board.gd` `_make_boost_badge`).

**The badge is not baked into the sprite.** It is drawn at runtime exactly like the boost badge —
the rank is data, and 64 sprites with baked numerals could not restyle or localise. The ramp PNGs
stay clean; only the review strips carry a composited numeral.
