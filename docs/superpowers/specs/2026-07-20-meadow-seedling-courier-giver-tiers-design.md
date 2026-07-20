# Meadow Seedling Courier Giver Tiers Design

**Status:** Approved by the owner on 2026-07-20 for the first-zone sheet.

## Goal

Create the first of five quest-giver tier sheets: a single Meadow/forest
"Seedling Courier" character that evolves cleanly from tier 1 through tier
12 without changing identity.

## Deliverable

- One raw `1024x1536` PNG under
  `games/grove/assets/_new/quest_givers_meadow_tiers_v1/`.
- Three columns by four rows, row-major: tier 1 at top-left, tier 12 at
  bottom-right.
- A flat `#FF00FF` background, generous gutters, and a complete portrait in
  every cell. The final runtime cutout contract is `256x256` transparent
  character busts with a rounded authored base.

## Art direction

Use Meadow Sky + Cut-Paper Playground: matte hand-cut cardstock, broad rounded
silhouettes, a fine warm cut edge, thin locally darker edge, restrained paper
fiber, and the fixed Meadow palette. Do not use painterly, clay, glossy,
sticker-outline, or heavy-black-outline rendering. The generated color sprite
contains no baked shadow, glow, particles, text, labels, or detached effects.

The same waist-up courier occupies a matched visual footprint in every cell.
Costume silhouette, attached accessories, and material treatment carry the
progression; overall scale does not.

## Tier progression

1. Leaf-hooded child with plain moss tunic.
2. Leaf hood gains a stitched warm-cream collar.
3. Small attached seed-satchel and coral sprout pin.
4. Layered leaf cape with one berry clasp.
5. Flower-trimmed hood and a richer sage satchel.
6. Courier badge becomes a simple acorn-shaped clasp.
7. Short attached acorn-topped staff and slate-green shoulder cape.
8. Oak-leaf mantle with a gold-edged acorn clasp.
9. Tall leaf-and-acorn hood with a single broad folded paper shoulder panel.
10. Ceremonial oakwarden mantle, one integrated gold acorn emblem.
11. Rich cream-and-sage steward cape, larger integrated acorn emblem.
12. Grand Meadow steward: oak-canopy hood, warm-cream collar, muted coral
    flower trim, and one central integrated acorn emblem.

## Acceptance criteria

- Exactly twelve distinct, recognizable stages of the same character.
- All portraits have comparable scale, a full rounded base, and visible key
  color on all four sides within their cell.
- No subject pixel touches a 3x4 cell boundary.
- The raw sheet is genuinely `1024x1536`; its key field is uniform `#FF00FF`.
- The sheet is visually reviewed at full size and as 256px cells before any
  later slicing or runtime integration.

## Scope boundary

This task creates only the first-zone concept/source sheet. It does not slice
the twelve tiers, replace the current five-face pool, modify `bust.gd`, or
wire tier-based portraits into the game.
