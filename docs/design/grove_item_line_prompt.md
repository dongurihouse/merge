# Grove Item Line Prompt

Use this as the default prompt scaffold whenever generating Grove / Acorn Forest merge-line art.
It encodes the rules learned from the Farm, Orchard, Garden, Mill, and Gate line pass.

## Copy-Paste Prompt

```text
Generate a production-ready 2D game asset sheet for the [ZONE] [LINE_NAME] line, matching the clean cozy Grove / Acorn Forest merge-game asset style.

Canvas: exact 1024x1536 PNG, arranged as a 3 columns x 4 rows grid with generous gutters.
Background: solid flat #FF00FF only.
Style: cozy hand-painted game icons, crisp continuous dark outline, simple readable silhouettes, warm painterly color blocking. No cast shadow, no contact shadow, no drop shadow, no floor shadow, no ground smudge, no reflection, no background texture, no glow, no sparkles, no particles, no smoke, no aura, no detached FX, no text, no labels, no watermark.
Sizing: all 12 elements must have the same visual footprint and fill the same amount of each grid cell. Early tiers may be simpler, but they must not be smaller than later tiers. Center every item.

Create exactly one clean cutout-friendly item per cell, in this order:
1. [TIER_01]
2. [TIER_02]
3. [TIER_03]
4. [TIER_04]
5. [TIER_05]
6. [TIER_06]
7. [TIER_07]
8. [TIER_08]
9. [TIER_09]
10. [TIER_10_HIGH_TIER]
11. [TIER_11_HIGH_TIER]
12. [TIER_12_HIGH_TIER]

Important constraints:
- One connected object per cell only. No scenes, furniture, built-in architecture, full environments, bundles, crossed tools, piles, clusters, jars/containers unless the line is specifically about containers, or unrelated props.
- Keep details broad and attached. Avoid many tiny leaves, stems, fronds, crumbs, loose seeds, labels, tassels, hairline decorations, thin strings, thin legs, thin antennae, or small separated parts.
- Use vibrant, funny, mysterious, or premium-feeling colors on tiers 10-12, but do it through silhouette, material, palette, and one bold central motif rather than visual effects.
- By default, high-tier items with a natural emblem slot should use one clear Grove acorn emblem on tiers 10-12. Replace an existing central decorative motif with the acorn; do not add dangling acorns, corner badges, floating acorns, or extra symbols. If the item family is organic and has no natural emblem slot, omit the acorn rather than forcing awkward placement.
- Make this line visually different from the previous nearby line: choose a different dominant silhouette/material family, not another set of the same jars, bottles, packages, medallions, baskets, boards, or pots unless that object type is the line's explicit identity.
- For food, fruit, vegetables, seeds, plants, or animals: show whole intact objects only. No cut-open interiors, slices, repeated same fruit, loose garnish, or piles unless explicitly requested.

Output only the image sheet. Do not add explanatory text in the image.
```

## Fill-In Notes

- `[ZONE]`: Farm, Orchard, Garden, Mill, Gate, or a future map.
- `[LINE_NAME]`: the line identity, such as `Orchard Tools`, `Gate Bells`, or `Farm Hearth Ember`.
- `[TIER_01]` through `[TIER_12]`: define the actual objects before generation. Keep them in one family but change silhouette, color, material, or motif enough that each tier reads at board size.
- Tiers 10-12 should be the strongest board-read: bolder palette, clearer silhouette, and one large motif.

## Acceptance Checklist

Before accepting a generated sheet, verify:

- The sheet is 3x4 and row-major, with 12 readable objects.
- The background is flat magenta or can be normalized to exact `#FF00FF`.
- No shadows, no grounding, no sparkles, no glow, no smoke, and no detached FX.
- All tiers have comparable visual size.
- Each tier is mostly one connected object with a clean outline.
- High tiers are distinct without becoming more complex to cut.
- Acorn emblems, when used, sit in natural emblem slots on higher tiers only.
- The line does not accidentally repeat the object language of the previous line.
