# Generator mastery (+ the Scissors) — design (2026-07-26)

**Status: rev 3.** Rollout step 2 of `2026-07-26-progression-systems-design.md`. All numbers are
provisional dials — the step-2 `grove_sim` re-pass owns finals.

## 1 · Scope

- Mastery covers the 8 base generator lines, `ZONE_BASE_LINES = [1, 2, 3, 4, 6, 7, 16, 18]`.
  State is keyed by line id: one meter per line, shared by all its generators, surviving
  merge/sell/bag/re-birth.
- No meter: specials (5, 8, 17, 19), coins (9), drops (10/12/13), treats (71–75).
- Home board only. Rush has its own spawner (`explore_rush.gd:652`) and is untouched.
- Bursts, the paid boost, and generator tiers are untouched — mastery moves pop **tiers** only.

## 2 · The meter

Unit: tier-1 equivalents, `G.tier_clicks(t) = 2^(t-1)` (content.gd:556). Never resets, no cap.
Rank is derived from the meter, the pop window from rank + live asks — never stored.

Exactly two credit sites:

| Feed | Credit | Site |
|---|---|---|
| Fence delivery of an own-line piece at tier t | `+tier_clicks(t)` | `BoardActions.deliver_quest` (board_actions.gd:22–35) |
| Craft merge — each ingredient credits its own line at the shared tier t | `+tier_clicks(t)` per piece | `BoardActions.apply_recipe` (lifted from board.gd:3126–3136, §6) |

- An ingredient that is itself a special credits nothing (its cost was credited when crafted).
- Nothing else credits: sells (board.gd:4000), retire (board_actions.gd:141), generator sells,
  collects, stash, sweeps, any future consumer.
- Mastery mints no coins; rank-ups pay nothing; no combo/chain credit anywhere in this design.

## 3 · The ladder

`MASTERY_THRESHOLDS := [20, 60, 150, 350, 800, 1700, 3400, 6500]` (grove_data.gd). Each rank
moves only the pop tier window: `lo(r) = 1 + r ÷ 2`, `hi(r) = 4 + (r + 1) ÷ 2` (integer division).

| Rank | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|---|---|---|---|---|---|---|---|---|---|
| Pops land | t1–t4 | t1–t5 | t2–t5 | t2–t6 | t3–t6 | t3–t7 | t4–t7 | t4–t8 | t5–t8 |

**Tier roll.** Always one draw: width-4 windows walk the shipped `TIER_ODDS = [0.65, 0.25, 0.09,
0.01]`, width-5 windows walk `MASTERY_TIER_ODDS_5 := [0.65, 0.25, 0.06, 0.03, 0.01]`; the result
is offset by the window low. Rank 0 is today's roll byte-for-byte.

**Ask-band clamp.** `band` = highest tier among the line's **own** live asks (the runtime `quests`
array via `G.quest_item`; an ask for a special is not an ask for its ingredients). With own asks
the window slides down, shape preserved: `slide = max(0, lo(rank) − max(1, band − 3))`, effective
window `[lo − slide, hi − slide]`. No own asks (e.g. a comeback line re-birthed as an ingredient
tool): no slide. Recomputed once per `_pop_seed` call — one window per burst.

- Pops never mint t9+ (`hi` caps at 8); t9–t12 stay merge-made.
- Applies only to `_pop_seed` → `roll_spawn`. `roll_item_tier` consumers (accumulator/treat) and
  `bramble_seed` untouched.
- `ASK_TIER_WEIGHT` stays 0.0; its pin (mechanics_tests.gd:417) stays.

**RNG law.** Zero added draws at every rank — the window changes the mapping, never the count.
Draw order stays contractual (board_logic.gd:120–124); rank-0 streams are byte-identical to today.

## 4 · The Scissors

Splits one piece into two of one tier lower — the bridge down when an unclamped window sits above
a low ingredient ask.

- Tool pseudo-line `SCISSORS_LINE := 14`, code 1401. Registered in `is_valid_item_code`
  (content.gd:1264 — else the load prune at board_model.gd:513 deletes it), kind `"scissors"`.
  Never merges, never sells (trash-hidden set, board.gd:2160), bag-storable. Tap selects; **drag
  is the only verb**.
- Drop on a content-line piece of tier ≥ 2: target becomes t−1; a twin (same line, t−1) lands on
  the nearest empty ground cell (Manhattan from the target, ties by cell scan order — no RNG
  draw); the scissors is consumed. Refuse with the wobble, no loss: full board, tier-1 target,
  generators, tools, coins, treats. Splitting a currently-asked piece is allowed. No mastery
  credit for splits.
- Resolution: new release-ladder branch after the recipe branch (board.gd:2862); same predicate in
  the drag-target highlight (board.gd:1735).
- Shop: coin card, `SCISSORS_COST := 40`, always stocked, hidden until
  `Mastery.any_rank_at_least(2)`. Board-opened shop places like the info-bar buy chip
  (board.gd:2404–2453 — first empty ground cell, else bag, refuse before spend); map-opened shop
  banks `scissors_pending`, drained on board entry (the `water_pending` pattern, save.gd:472).
- Price floor (unit-tested, not sim-hoped): `SCISSORS_COST > max over tiers×bands of
  [2·sell(t−1) − sell(t)]` — 28 today under the linear `sell_reward` (content.gd:1220); 40 holds.

## 5 · Save

Grove blob, additive keys, defaulted on read by the deep-merge load (save.gd:98–105) — no schema
bump, no migration. Existing saves read as zeros.

```
mastery          : { "<line id>": int }   # meter, tier-1 equivalents
mastery_seen     : { "<line id>": int }   # highest rank already celebrated
scissors_pending : int
```

Board and bag blobs untouched. Persistence rides `_after_board_change → _persist` (board.gd:1011);
both credit sites sit before it.

## 6 · Code map

| Unit | Owns |
|---|---|
| `games/grove/grove_data.gd` | Dials: `MASTERY_THRESHOLDS`, `MASTERY_TIER_ODDS_5`, `SCISSORS_LINE`, `SCISSORS_COST` (re-exported through content.gd) |
| **new** `engine/scripts/core/mastery.gd` | Static module (the `bucket.gd` shape) over `Save.grove()`: `meter/rank`, the `lo/hi` closed forms, `ask_band(line, quests)`, `window(line, quests)` (§3 slide applied), `credit_delivery(code)` / `credit_craft(a_code, b_code)` (return `{line: ranks_gained}`), `any_rank_at_least(r)`. Pure over injected quests — headless-testable |
| `board_logic.gd` | One shared windowed roller `roll_tier_window(rng, lo, width)` (single draw; defaults reproduce today's stream); `roll_spawn` gains `tier_lo := 1, tier_hi := 4` |
| `content.gd` | Scissors code in `is_valid_item_code` / `special_kind` / `item_display_name` |
| `board_actions.gd` | `deliver_quest` calls `Mastery.credit_delivery`, returns `rank_ups`; `_apply_recipe` lifted here as `apply_recipe(board, from, target) -> {code, consumed}` + credit; new `split_piece(board, from, target) -> {twin_cell}` |
| `board.gd` | Orchestration only: window args into `roll_spawn` (:3029), release-ladder branch + ghost, ring/trim/rank-up/info-bar/shop wiring. Burst selection (:2995) untouched |
| `features.gd` | `"mastery": true`, `"scissors": true`; off = rank 0 everywhere = byte-identical spawns |
| `grove_sim.gd` | Calls `Mastery.credit_*` at the fused craft-and-deliver site (:827–841) and `roll_tier_window` instead of the hand-mirrored tier walk (:1051–1072). Burst mirror (:937–945) unchanged |

## 7 · UI

Mocks (composition authority for the builder):
`games/grove/assets/_concepts/screens/mastery_{ring_trim, infobar, rankup, shop, split_ghost}_v1_1080x1920.png`
(+ `.prompt.txt` sidecars).

- **Ring:** thin `draw_arc` around each of the line's generators, color `G.LINES[line].color`;
  stroke ≈5% of cell size; fills clockwise from 12 o'clock over a faint warm-cream track at low
  opacity; fill = progress within the current rank; absent at meter 0; full and steady at rank 8.
  New Control on the focus_ring pattern (`mouse_filter = IGNORE`, never child 0 —
  piece_view.gd:461), refreshed on the `_refresh_boost_indicator` beat (board.gd:1643). No numbers
  on the board.
- **Trim:** at ranks 2/4/6/8 — ribbon → bronze → silver → gold blossom — one shared 4-frame
  overlay set on the 512² generator canvas (art guide §5), composited over any generator sprite,
  anchored at the sprite's bottom-left, ≈⅓ sprite width. Later gilds Shelf rows and Collection
  entries (forward hook).
- **Rank-up:** the `retire_offer.gd` template (Overlay.modal, dismissable, standard dialog frame):
  the line's generator sprite hero-sized, one ink line in the exact form
  *"<Line name> — pops now land tX–tY."*, **Continue** (action green), `FX.burst` confetti.
  Deferred until the triggering action's FX settle; multiple ranks in one credit collapse to the
  highest; queued behind the level-up popup (board.gd:3798).
- **Info bar** (generator selected): tier moves into the name line (`_gen_info_text`,
  board.gd:2250); the second line becomes the mastery row at the same height: eight round pips
  (filled = line color, hollow = ink outline on cream) · slim `Kit.progress_bar` ≈170×14 px at
  base canvas (cream track, line-color fill) to the next threshold · the next-reward string. The
  tray must not grow (action_bar.gd:95–111; `board_hud_layout_tests` stays green). Items and empty
  cells unchanged.
- **Scissors in shop:** a QUICK HELP row below Coin Pouch, caption "SCISSORS": icon · ink text
  *"Cuts a piece into two of a tier lower."* · green price pill with the coin icon and 40.
- **Scissors on board:** dragging over an eligible piece shows the split preview (telegraph seam,
  board.gd:2696–2716): two twin ghosts at ≈50% alpha side-by-side in the target cell, the
  original faded beneath, a dashed cream outline on the cell; drop = snip, halves pop apart;
  ineligible = the refuse wobble, no ghost.
- **Strings** (`games/grove/strings.json`): next-reward forms `next: pops reach tX` (odd ranks) /
  `next: pops start at tX` (even ranks); `shop.scissors.*`; the rank-up line. **Art** (guide
  intake): `tool_scissors` piece sprite and `shop_scissors` icon — matte cut-paper scissors,
  structural-slate blades `#3F6D7D`, coral handles `#D87865`; 4 trim frames.

## 8 · Sim gates (block the merge)

Run ≥ 3 seeds × 60 days, mastery credits + windowed roller wired in (§6):

1. Time-to-rank: typical lines reach rank 4–6 by book end, koi/shells ~7, rank 8 post-book —
   thresholds move if not.
2. Invariant Z (sink > faucet) and P1/P2 hold; report the book-length compression from rising
   windows.
3. I1 zero jams; the bot buys scissors when a strand would otherwise jam.
4. No profitable split→sell loop exists.

## 9 · Tests

- **`engine/tests/mastery_tests.gd` (new, pure):** threshold monotonicity; `lo/hi` closed forms
  reproduce the §3 table; `MASTERY_TIER_ODDS_5` sums to 1 and decays; slide cases (clamped,
  no-own-asks unclamped, retroactive rise, reach ranks never clamp); band from a quests fixture
  (own asks only); credit math (delivery, craft both lines, nested special credits once, sum
  equals click cost); split value neutrality; the scissors price-floor inequality over all
  tiers × bands.
- **RNG byte-identity:** extend the mechanics_tests.gd:413 pattern — default window reproduces
  today's exact stream; one tier draw at every rank.
- **`grove_board_actions_tests.gd`:** deliver credits + `rank_ups`; `apply_recipe` parity with the
  old inline behavior + credits; retire/sell/collect credit nothing; `split_piece` placement
  determinism, full-board and tier-1 refusals.
- **`grove_shop_tests.gd`:** row hidden below rank 2; buy places / banks pending; refuse before
  spend.
- **Flow (board suite):** a ranked line's pops land inside its window; rank-up card fires once per
  rank (`mastery_seen`); scissors branch ordering (merge and recipe still win their cases).
- **Layout:** `board_hud_layout_tests` unchanged; rank-up card is dismissable (no
  `modal_dismiss_tests` case needed).
- Inner loop `make test-fast`; full `make test` + §8 before merge.

## 10 · Rollout

Step 2, one worktree. Independent of the Shelf (step 1, unbuilt) — the trim gilding on Shelf rows
is a forward hook for whichever lands second. Lands before combos (step 3); chain/scissors
interaction is step-3 scope.

## 11 · Dev calls

1. Craft-consumption credit (parent §10.1) — the §2 whitelist.
2. Specials have no meter; their cost credits their ingredients at craft time.
3. Scissors at 40 coins (floor ~30 forced by the linear sell curve; cheaper means bending
   `sell_reward`).
4. No retro seed — existing saves start at rank 0.
5. Trim art is one generic 4-frame set, not per-line.
