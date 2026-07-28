# Generator stranding fix — prevent + sell redundant generators

> **Historical note (2026-07-27):** this design described the retired generator merge-tier ladder.
> Current generators no longer merge, self-duplicate, or expose redundant-generator selling; rank/mastery
> is the active progression system.

## Problem

Generators merge 2:1 up a short ladder (`GEN_TOP_TIER = 3`); a higher tier bursts more
items per tap. A below-top generator self-produces a same-tier duplicate at
`GEN_SELF_DUP_RATE` (0.5%/tap) as merge fuel. Because the duplicate spawns at the
**tapped** generator's tier ([board.gd `_self_dup_generator`](../../engine/scripts/scenes/board.gd)),
odd counts strand a low-tier copy: e.g. building one tier-3 wildflower generator consumes
four tier-1s (4→2→1), leaving an orphan tier-1 with no same-tier partner. It cannot merge
into the tier-3 (merge requires equal tiers), and a second tier-3 would be redundant, so
the orphan is permanent dead weight the player cannot remove (generators are not sellable
today — `board.gd` hides the info-bar sell button for them).

## Goals

1. **Prevent** new strands from forming during normal play.
2. **Clear** — let the player remove a redundant generator (the player's "sell it" ask).
3. **Account for all unmerged configurations**, including pre-existing saves, without a
   destructive save migration.

## Design

All new decision logic lives in pure statics (`BoardModel` / `BoardActions`) with headless
tests, matching the existing `board_actions` pattern; the `board.gd` scene only renders.

### 1. Prevent — self-dups feed the line's top lineage

Change the self-dup so the duplicate spawns at the **line's highest owned tier** (across
board + bag), and is skipped entirely when that top is already `GEN_TOP_TIER`.

- Every self-dup pairs with the top and merges up, so sub-top copies stop accumulating.
- Once a line reaches tier 3, **nothing of that line breeds** — even a leftover tier-1
  stops multiplying (its self-dup checks the line top, which is maxed). Clutter cannot grow.
- The climb is marginally faster, negligible on a 3-rung ladder.

New helper `BoardModel.top_gen_tier(line: int) -> int` (max tier among same-line generators
on the board and in the bag; 0 if none). Extract the self-dup into
`BoardActions.self_dup_generator(board, src) -> Dictionary` (`{landed, bagged}`, mirrors
`produce_due_generators`) so the tier decision is headless-tested; the scene keeps the
pop-in/render.

### 2. Clear — sell a redundant generator

A generator is **redundant** when a strictly-higher-tier generator of the same line exists
(board or bag): `BoardModel.is_redundant_gen(cell) -> bool`
(`gen_tier_at(cell) < top_gen_tier(line_of(cell))`).

The info bar already has a sell button (`_info_trash`) hidden for generators. Un-hide it in
`_select_generator` **only when `is_redundant_gen(cell)`**, showing a small coin payout.
`_on_trash_pressed` routes a redundant generator to `BoardActions.sell_generator`, which
guards on redundancy, calls `board.remove_gen(cell)`, and returns `{sold, coins}`; the scene
credits coins (`Save.add_coins`) and re-renders.

- Payout: new `GEN_SELL_COINS` dial in `grove_data.gd`, indexed by sellable tier (1..2),
  kept small so 0.5%/tap breeding cannot become a coin faucet. May be 0 (pure discard).
- The redundancy guard means the player can **never sell the highest/last generator of a
  line**, so quests that require that line stay satisfiable.

### 3. Account for all unmerged cases

Redundancy is computed live, so every configuration is covered with no save migration:

| Config | Behavior |
|---|---|
| `t1 + t3` (the reported case), `t1 + t2 + t3`, several `t1`s | every sub-top copy is redundant → sellable; none breed (line top maxed or higher exists) |
| top tier sitting in the **bag** | `top_gen_tier` is bag-aware, so a board leftover under a bagged top is still redundant + inert |
| two equal sub-top copies (`t2 + t2`, no higher) | not redundant, but a normal mergeable pair — existing merge gesture handles it; any leftover then becomes sellable |
| only one generator of a line | not redundant → not sellable; cannot reach zero |

**No silent auto-deletion on load.** Existing leftovers simply become sellable and stop
multiplying — the player keeps agency over removal.

## Out of scope (deferred)

- Selling a redundant generator **from the bag** (a small bag-overlay affordance). The
  board path covers the reported case; `top_gen_tier` is already bag-aware. Park for later.
- Drag-to-absorb (dragging the leftover onto its higher sibling) as an alternative to the
  sell button. The sell button is the chosen clear affordance.

## Tests (headless — board_actions / grove suites)

- `top_gen_tier`: bag-aware max across mixed lines; 0 when none.
- `is_redundant_gen`: true/false across `t1+t3`, `t1+t2+t3`, `t2+t2`, single, bagged-top.
- `self_dup_generator`: spawns at line top (not source tier); skips when line top is maxed;
  a sub-top leftover does not breed while a higher sibling exists.
- `sell_generator`: removes a redundant generator + credits `GEN_SELL_COINS`; guard blocks
  selling a non-redundant (last/highest) generator; line ownership preserved for quests.

## Touch list

- `engine/scripts/core/board_model.gd` — `top_gen_tier`, `is_redundant_gen`.
- `engine/scripts/core/board_actions.gd` — `self_dup_generator`, `sell_generator`.
- `engine/scripts/scenes/board.gd` — call the statics; un-hide sell for redundant generators;
  route `_on_trash_pressed`; refresh stale self-dup doc comments.
- `games/grove/grove_data.gd` — `GEN_SELL_COINS` dial; fix the stale "feeds another sub-max
  line" comment.
- Tests in `engine/tests/` and/or `games/grove/tests/`.
