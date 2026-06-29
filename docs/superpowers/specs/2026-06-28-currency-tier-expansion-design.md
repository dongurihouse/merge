# Currency Tier Expansion Design

## Goal

Add 9 more playable tiers for board coins and acorn drops, with one generated 3 column x 6 row source sheet and shipped per-tier PNGs wired into the existing board item paths.

## Scope

- Coins extend from tier 3 to tier 12.
- Acorn drops extend from tier 3 to tier 12.
- Chest, key, water, spark, and wildcard behavior stay unchanged, except that wildcard already remains a 12-tier special.
- The source art sheet contains exactly 18 cells, row-major:
  - cells 1-9: `coin_4` through `coin_12`
  - cells 10-18: `acorn_4` through `acorn_12`

## Art Direction

Use the existing Grove item-line rule: flat solid `#FF00FF` background, no visible grid, no text, no shadows, no glow, no particles, crisp outline, broad details, one centered cutout-friendly object per cell, and matched visual footprint across cells.

Coins should remain soft-currency gold tokens. Higher tiers can gain richer silhouette, embossed rim detail, and premium metal treatments, but should still read as coins rather than chests, medals, or piles.

Acorns should remain premium acorn drops. Higher tiers can progress through polished, capped, carved, gilded, and jewel-inlaid acorns, but should stay as single whole acorns rather than clusters or bags.

## Gameplay

Coins use an explicit value table rather than unlimited exponential growth:

`1, 5, 25, 100, 250, 500, 1000, 2500, 5000, 10000, 25000, 50000`

Acorns use an explicit premium drop table:

`1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000`

The values preserve the existing first three tiers and give higher tiers a merge bonus without making a tier-12 board pickup explode the economy.

## Hookup

- Update `games/grove/grove_data.gd`:
  - `COIN_TOP = 12`
  - `COIN_VALUES` includes tiers 1-12
  - acorn special item line 13 overrides `"top": 12`
  - `SPECIAL_COLLECT["acorn"]` includes tiers 1-12
- Add or update source art under `games/grove/assets/_new/currency_tiers_v1/`.
- Slice into:
  - `games/grove/assets/items/coin/coin_4.png` through `coin_12.png`
  - `games/grove/assets/items/acorn/acorn_4.png` through `acorn_12.png`
- Run `make import` so Godot sidecars exist.

## Verification

- `make test-one SUITE=engine/tests/mechanics_tests`
- `make test-one SUITE=games/grove/tests/grove_info_bar_tests`
- `make test-fast`
- A local image QC pass verifies the source sheet dimensions, alpha output, and all new 18 target PNGs.
