# Feature Level Gating — design (2026-07-29)

Gates five shipped features behind level thresholds and gives each a wordless, board-taught
reveal. Companion: `2026-07-26-progression-systems-design.md` (the sky-gives / ground-works split
these five come from), `2026-07-23-ftue-hand-hint-design.md` (the teach overlay).

---

## 1 · The two states

Every gated feature is in exactly one of three states:

| State | Meaning | Source |
|---|---|---|
| dormant | below its level; the rules do not run | `FeatureGate.armed(id) == false` |
| armed | rules live, player not yet shown | `armed(id) and not revealed(id)` |
| revealed | the teach has completed | `Save.ftue_seen("unlock_" + id)` |

Armed is not revealed. A feature may sit armed for several sessions until the board produces the
situation its teach needs.

---

## 2 · The table

`games/grove/grove_data.gd`, beside `MIN_LEVEL` and `SCENE_END_LEVEL`:

```gdscript
const FEATURE_LEVEL := {
	"weather":  4,
	"cascade":  7,
	"mastery": 10,
	"soil":    13,
	"magnet":  18,
	"rush":    22,
}
```

`content.gd` re-exports it as `G.FEATURE_LEVEL`, exactly as it re-exports `MIN_LEVEL`.

The first four land on `MIN_LEVEL` board-growth beats (L4 / L7 / L10 / L13) so a new verb arrives
on the same level as a new ring of cells. L16 is the last beat; magnet and rush sit past it and
are spaced by input cost alone. Ordering throughout is by input cost: features needing no new
gesture first (weather, cascade, mastery), then a new verb (soil, magnet), then a new scene
(rush).

Coin clock: `coins_at_level(L) = (L-1)²`. At the pacing calculator's 152 quest-coins/day ceiling,
the six gates fall on ceiling-days 0.06 / 0.24 / 0.53 / 0.95 / 1.9 / 2.9. Real play is lossier;
multiply by the productive-pop fraction `grove_sim` measures.

---

## 3 · `core/feature_gate.gd`

New module. Imports `content`, `save`, `features`. Never imports `ui/` or `scenes/`.

```gdscript
armed(id)        -> Features.on(<flag>) and G.level() >= G.FEATURE_LEVEL[id] and <extra>
revealed(id)     -> Save.ftue_seen("unlock_" + id)
mark_revealed(id)
```

An unknown id pushes a warning and returns `false` from `armed` — the inverse of `Features.on`,
because an unknown gate must fail closed, not leak an ungated feature. An id with no flag in the
table below skips the `Features.on` term; `rush` is the only one.

`<extra>` per feature — every condition shipping today survives as an AND term:

| id | flag | extra | read site |
|---|---|---|---|
| `weather` | `weather_hours` | merge + gen_tap FTUE seen | `core/sky.gd` `gate_open()` |
| `cascade` | `cascade` | — | `scenes/board.gd` `_prepare_chain()` |
| `mastery` | `mastery` | — | reveal only; accrual unconditional |
| `soil` | `improvements` | `Save.board_tutorial_seen()` | `scenes/board.gd` `_maybe_soil_ftue()` |
| `magnet` | `improvements` | — | `scenes/board.gd` `_blocked_seed_drop_lines()` |
| `rush` | — | `Bucket.cells_total() > 0` | `scenes/map.gd`, `ui/residents.gd` |

`_maybe_soil_ftue`'s literal `G.level() < 6` is deleted; the table supplies 13.

`_blocked_seed_drop_lines()` withholds `MAGNET_SEED_LINE` until `armed("magnet")`. No new gate
code: an unarmed magnet cannot drop because it is not in the weighted table.

### Mastery clamp

The meter accrues from L1, unchanged. `Mastery.rank()` returns `min(true_rank, 1)` while
`not revealed("mastery")`, and the true rank after. `rank_for_meter()` is untouched — the clamp
is on the save-reading accessor only, so pure-rule callers keep their arithmetic.

Consequence, and the reason the clamp exists: `Shop.scissors_available()` reads
`Mastery.any_rank_at_least(2)`, which therefore cannot fire in the same beat as the mastery
reveal. Banked overflow carries, so rank 2 arrives shortly after on its own.

---

## 4 · `ui/teach_registry.gd`

New module. Replaces the hand-maintained pair `board.gd::_hand_hint_eligible()` /
`_hand_hint_ledger_complete()`, whose in-code warning states that a teach added to one and
forgotten in the other silently never appears, with no error and no failing test.

One ordered spec array per scene. Each entry:

```gdscript
{"id": String, "ledger": String, "gate": Callable, "ready": Callable, "rects": Callable, "gesture": String}
```

Two derived readers, both over the same array:

- `eligible(specs)` → the id of the first entry with `not Save.ftue_seen(ledger)` and
  `gate.call()` and `ready.call()`; `""` when none.
- `complete(specs)` → true when every entry's `ledger` is seen. Ledger-only: no board scan, safe
  to call on every mutation before `_maybe_hand_hint`'s frame await.

The two cannot disagree, because there is one list.

`board.gd` supplies six specs in this order: `merge`, `gen_tap`, `weather`, `cascade`, `soil`
(two beats behind one ledger key, as shipped), `magnet`. `map.gd` supplies one: `rush`.

**Mastery is not in the registry.** Its reveal is a reward beat with no gesture (§5), fired from
the generator-tap path, so it neither competes for the registry's single-teach-at-a-time slot nor
blocks a later spec while it plays.

`_hand_hint_rects()`'s per-id branches move into each spec's `rects` Callable. `_end_hand_hint`,
`_dismiss_hand_hint` and the retarget path are unchanged.

---

## 5 · The reveals

Every reveal follows: **watch** (a predicate over the live board) → **stage** (create the
situation only if it will not arise) → **point** (`HandHint`, input-transparent, loops until the
gesture happens) → **bank** (the real action writes the ledger). No modal, no dismiss button, and
no explanatory copy beyond the one floater soil already ships.

### cascade — L7

- **watch** `BoardLogic.chain_path` returns a run of ≥ `CHAIN_MIN_N` from a live mergeable pair —
  the same predicate `_prepare_chain` computes.
- **stage** none. At 25+ open cells chains are frequent, and a chain the player built teaches
  better than a planted one.
- **point** `GESTURE_DRAG` on the chain's first pair, with `_show_cascade_drag_guides()` lighting
  the full ladder ahead of the hand.
- **bank** the chain runs.

### weather — L4

- **watch** the hour's roll has landed on a lane clearing `LANE_MIN_OPEN`, the patch is rendering,
  and a mergeable pair sits inside it.
- **stage** none. The roll recurs hourly; a lane with no pair waits for the next hour.
- **point** `GESTURE_DRAG` on the pair inside the patch.
- **bank** a merge lands in the patch.

### mastery — L10

The only reveal with no gesture to teach: the player already taps generators and the meter has
been filling since L1. It is a reward beat, not a hand hint.

- **watch** the first generator tap after arming, on a line whose meter is > 0.
- **point** the `MasteryRing` animates in with a fill-sweep from 0 to its banked value, in the
  `ui/mastery_rankup.gd` celebration vocabulary.
- **bank** the sweep completes; the rank clamp lifts.

`_attach_mastery_chrome` gains the `revealed("mastery")` condition; today it attaches silently
whenever `meter(line) > 0`.

### soil — L13

Mechanism unchanged and already shipping (`_maybe_soil_ftue` grants the seed, ledger key
`soil_seed`, two beats `soil_seed` → `soil_place`). Only the level moves, 6 → 13.

### magnet — L18

- **watch** arming returns `MAGNET_SEED_LINE` to the drop table; the seed arrives as loot from a
  merge.
- **stage** the drop gets a real window first, so the loot path is the common one: grant a seed
  directly only once `MAGNET_STAGE_MERGES := 40` merges have passed since arming with no magnet
  seed ever held. New dial in `grove_data.gd`. (Soil grants immediately on reaching its level
  because it has no drop-first path to wait for; magnet does, so it waits.)
- **point** the soil beats against the magnet cell: `magnet_seed` → `magnet_place`.
- **bank** placed.

### rush — L22

The reveal only opens the door; `ExploreRush` teaches itself with `rush_merge` and
`rush_treefall`.

- **watch** a surface showing the Expedition chip is open and `Bucket.cells_total() > 0`.
- **point** the chip's first appearance wears `breathe_cta`, plus `GESTURE_TAP` on it.
- **bank** the Load out dialog opens.

---

## 6 · Retiring the Rush intro image

The full-screen `TutorialImage` modal at Rush start is removed; the two in-scene hand hints carry
the teach.

Deleted:

- `scenes/explore_rush.gd` — `RUSH_TUTORIAL_OVERLAY`, `RUSH_TUTORIAL_IMAGE`, `_open_rush_tutorial()`
  and its sibling accessor, the call site at `_ready`
- `core/explore.gd` — `RUSH_INTRO_SHOWS`, `rush_intro_should_show()`
- `core/save.gd` — `rush_intro_seen()`, `mark_rush_intro_seen()`
- `games/grove/tools/rush_shot.gd` — both call sites
- `games/grove/tests/grove_explore_tests.gd` — `_test_rush_intro_hint()` and its dispatch line
- `games/grove/tests/grove_rush_ftue_tests.gd:23` — the "spend the popup" setup line
- asset `ui/kit/tutorial/how_to_play_rush.png`

Kept: `ui/tutorial_image.gd` and `tutorial/how_to_play_board.png` — `board.gd` still opens the L1
how-to-play through them.

The orphan `rush_intro_seen` save key is dropped in `core/save_migrate.gd`.

GDScript self-calls to a deleted method are parse errors, so the `explore_rush.gd` removals land
as one edit covering func→next-func ranges.

---

## 7 · Debug

`ui/debug.gd` gains a feature-gate panel: per id, force-arm and force-reveal, plus a reset that
clears the six `unlock_*` ledger keys. Reaching L18 by play is not a test procedure.

---

## 8 · Verification

Headless assertions (`make test-grove`), no screenshot:

1. **Table** — walk L1→L28; each id's `armed()` flips at exactly `FEATURE_LEVEL[id]` and not one
   level earlier.
2. **No decorative entries** — every `FEATURE_LEVEL` id has a live read site; a table entry with
   no gate consumer fails.
3. **Fail closed** — `armed("nonexistent")` is false and warns.
4. **Registry sync** — `complete(specs)` is false whenever any spec's ledger key is unseen,
   derived from the spec array itself. This is the assertion the two-list design could not carry.
5. **Registry order** — at L22 with a fresh ledger, board's `eligible()` returns `merge`,
   `gen_tap`, `weather`, `cascade`, `soil`, `magnet` across successive banks, one at a time,
   never all at once.
   Also: a magnet seed forced onto the board at L17 produces no teach, because the spec's gate is
   unarmed even though its `ready()` is satisfied.
6. **Mastery clamp** — seed a meter past threshold 2: `rank()` reads 1 and
   `Shop.scissors_available()` is false before reveal; both lift after `mark_revealed("mastery")`.
7. **Magnet drop** — `pick_special_drop` never returns `MAGNET_SEED_LINE` below L18 across an RNG
   seed sweep, compared as distributions, not a single seed.
8. **Rush retirement** — no symbol named in §6 remains; `grove_rush_ftue_tests` passes without the
   popup-spend line.

One batched capture at the end (`make shot-batch`) for the two reveals whose quality is not
assertable — the cascade guide lighting the ladder, and the mastery fill-sweep. Owner's eye
required on both; neither is signed off on a passing suite.

---

## 9 · Out of scope

Re-tuning the six levels after playtest. `FEATURE_LEVEL` is one dict in game data so that moving
`soil: 13 → 11` is a data edit, not a code change.
