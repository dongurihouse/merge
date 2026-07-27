# Generator mastery (+ the Scissors) — design (2026-07-26)

**Status: rev 7.** Rollout step 2 of `2026-07-26-progression-systems-design.md`. All numbers are
provisional dials — the step-2 `grove_sim` re-pass owns finals. Rev 7 closes the §8 I2 residual with
`LEVEL_WATER_GIFT` 40 → 32 and records that the residual was never mastery-specific.

## 0 · Summary

A permanent per-line growth track. Using a line productively — delivering its pieces to the fence,
or consuming them as craft ingredients — fills that line's meter. Meter ranks raise the line's pop
**tier window**, from today's t1–t4 up to t5–t8, so a mastered line's generator starts producing
where it used to take four merges to reach. At a t5 floor a t12 trophy costs 128 pops instead of
2048. Bursts are untouched — burst power stays what the player buys (the boost); tier power is
what a line earns.

The Scissors ships with it: a cheap shop tool that splits one piece into two of one tier lower —
the bridge back down when a high window sits above a low ingredient ask.

What gets built:

| Piece | Where |
|---|---|
| Meter + 8-rank ladder + window/clamp math | new `engine/scripts/core/mastery.gd`, dials in `grove_data.gd` (§2, §3) |
| Credits at exactly two sites (delivery, craft) | `board_actions.gd` — includes lifting `_apply_recipe` out of the board scene (§2, §6) |
| Windowed tier roll, zero added RNG draws | `board_logic.roll_tier_window` + `roll_spawn` params (§3) |
| The Scissors item, split verb, shop row | `content.gd`, `board_actions.split_piece`, `board.gd` release ladder, `shop.gd` (§4) |
| Save keys, no migration | grove blob (§5) |
| Ring, trim, rank-up card, info-bar row | `board.gd` + the §7 mocks as composition authority |
| Sim wiring + the gate battery | `grove_sim.gd` (§6, §8) |

Not in this step: the Shelf (step 1), combos (step 3), improvements/weather (steps 4–5).

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

`MASTERY_THRESHOLDS := [20, 60, 150, 350, 650, 1150, 1900, 3000]` (grove_data.gd). Each rank
moves only the pop tier window: `lo(r) = 1 + r ÷ 2`, `hi(r) = 4 + (r + 1) ÷ 2` (integer division).

| Rank | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|---|---|---|---|---|---|---|---|---|---|
| Threshold | — | 20 | 60 | 150 | 350 | 650 | 1150 | 1900 | 3000 |
| Pops land | t1–t4 | t1–t5 | t2–t5 | t2–t6 | t3–t6 | t3–t7 | t4–t7 | t4–t8 | t5–t8 |
| Pop cost 💧 | 1 | 1 | 2 | 2 | 4 | 4 | 7 | 7 | 12 |

Ranks 1–4 are unchanged. Ranks 5–8 were compressed from `800 / 1700 / 3400 / 6500`: at those
numbers rank 8 was dead content — the best-fed line ends a 60-day book near 3400 and nothing ever
crossed 6500 (measured, §8).

**Pop cost.** A pop is charged `G.pop_cost(lo)` off the **effective** window low (after the
ask-band slide below), driven by `POP_COST_BY_TIER_LOW := [POP_COST, 2, 4, 8, 16]`. Rank 0 and the
flag off pay exactly `POP_COST` — unmastered play is unchanged. A raised window hands each pop
`tier_clicks(lo) = 2^(lo-1)` times the tier-1 value, so a flat cost let mastery collapse the water
sink (§8); pricing the pop off its floor keeps water buying the same VALUE at every rank. The curve
IS `tier_clicks(lo)` — a pop costs exactly what its floor is worth. An earlier curve shaved the top
two lows (8→7, 16→12) to hand ranks 6–8 some water back; weather-hours' water faucet erased that
margin, so the shave is gone. Mastery's reward is the LABOR: up to 16× fewer taps and ~70% fewer
merges per delivery, plus the wider odd-rank window.

- A burst is priced once (one window per `_pop_seed` call) and clamped by `water / pop_cost`, so it
  can never overdraw the can.
- The empty-water surfaces mean "can't pay the pop you just tried", not `water <= 0` — a mastered
  can floors at `cost − 1`, and §10's no-silent-wall rule still has to fire there.
- No entry may exceed `tier_clicks(lo)`: charging more water than the pop is worth would make
  mastery a punishment (pinned in mastery_tests).

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

**Rank pacing (measured, 16 sim seeds × 60 days).** Rank tracks how much of the book a line is
USED across, not when it arrives. Early lines are craft ingredients for the whole book; late lines
arrive with little runway left. This ordering is the craft web working as designed, not a defect —
do not "fix" it with per-line thresholds.

| Line | Zone | End-of-book meter (min/med/max) | Rank | Reaches r8 |
|---|---|---|---|---|
| Wild berries (2) | P1 | 2816 / 3344 / 3800 | 7–8 | 14/16 seeds |
| Glow-mushrooms (1) | P1 | 2488 / 2704 / 3032 | 7–8 | 1/16 |
| Snow & ice (3) | P2 | 2008 / 2616 / 3152 | 7–8 | 1/16 |
| Woolens (4) | P2 | 880 / 1712 / 2080 | 5–7 | — |
| Sand sculptures (7) | P3 | 936 / 1472 / 1848 | 5–6 | — |
| Shells (16) | P4 | 264 / 496 / 792 | 3–5 | — |
| Desert fruits (6) | P3 | 144 / 336 / 528 | 2–4 | — |
| Koi (18) | P5 | 64 / 208 / 488 | 2–4 | — |

Wild berries tops the ladder because it feeds three of the four specials (winter berries, spices,
tea cups). Desert fruits sits low for a mid-book line because it feeds none. Rank 8 is the devoted
top line's goal, reached late in the book, and a second line reaches it on a lucky run.

## 4 · The Scissors

Splits one piece into two of one tier lower — the bridge down when an unclamped window sits above
a low ingredient ask.

- Tool pseudo-line `SCISSORS_LINE := 14`, code 1401. Registered in `is_valid_item_code`
  (content.gd:1264 — else the load prune at board_model.gd:513 deletes it), kind `"scissors"`.
  Never merges, never sells (trash-hidden set, board.gd:2160), bag-storable. Tap selects; **drag
  is the only verb**.
- Drop on a content-line piece of tier ≥ 2: target becomes t−1; a twin (same line, t−1) lands on
  the nearest empty ground cell (Manhattan from the target, ties by cell scan order — no RNG
  draw; the scissors source cell can be the freed landing spot on a full board); the scissors is
  consumed. Refuse with the wobble, no loss: no freed cell to receive the twin, tier-1 target,
  generators, tools, coins, treats. Splitting a currently-asked piece is allowed. No mastery credit
  for splits.
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

`godot --headless --path . -s res://games/grove/tools/grove_sim.gd -- 60 <seed>`, seeds 42 / 7 / 99
(robustness swept over 100 seeds × both states of the `mastery` flag). Status: **passing**; the rev-6
I2 residual is closed by `LEVEL_WATER_GIFT` 40 → 32 (`grove_data.gd`).

1. **Time-to-rank — PASS.** The §3 pacing table is the measured result. Rank 8 is reached by wild
   berries on 14 of 16 seeds; nothing reached it at the old 6500 threshold.
2. **I2 (per-map level-gift ÷ water spend < 0.30 on maps 3+) — PASS after the gift re-tune.**

   **The residual was NOT mastery-specific.** At `LEVEL_WATER_GIFT = 40` the rule failed at least as
   often with the flag OFF as ON: **unmastered play failed seed 3 map 3 at 0.32** (seed 57 passing),
   mastered play failed seed 57 map 3 at 0.37 (seed 3 passing). Over 100 seeds the FAIL rate was 11%
   (ON) and **17% (OFF)**, and the p90 worst map-3+ ratio was 0.31 / 0.32 — *above* the 0.30 limit
   for more than a tenth of seeds in **both** configurations. Mastery only redistributes level-ups
   across a map boundary (seed 57 ends at level 71 either way, total gift unchanged); the flat 40💧
   gift had no headroom in either configuration.

   **The pop-cost lever was exhausted** — no entry may exceed `tier_clicks(lo)` (pinned by
   mastery_tests) or mastery becomes a punishment — so the lever used was the gift. Measured,
   100 seeds per cell, both flag states; a *real* breach is one whose failing map spent ≥1000💧 of
   its own water (a page actually played through, not a tail sample):

   | `LEVEL_WATER_GIFT` | mastery | I2 sim FAILs | of which real | worst real map3+ | p90 worst map3+ | self-sustain avg |
   |---|---|---|---|---|---|---|
   | 40 (was) | ON | 11% | 7 | 0.38 | 0.31 | 34% |
   | 40 (was) | OFF | 17% | 15 | 0.39 | 0.32 | 50% |
   | 36 | ON | 7% | 1 | 0.33 | 0.30 | 31% |
   | 36 | OFF | 4% | 3 | 0.32 | 0.28 | 46% |
   | **32 (shipped)** | ON | 3% | 1 | 0.36 | **0.26** | 28% |
   | **32 (shipped)** | OFF | 1% | 0 | 0.30 | **0.25** | 43% |
   | 31 | ON / OFF | 4% / 2% | 0 / 0 | 0.25 / 0.29 | 0.24 / 0.26 | 27% / 42% |
   | 30 | ON / OFF | 8% / 1% | 2 / 0 | 0.32 / 0.26 | 0.24 / 0.23 | 26% / 41% |
   | 29 | ON / OFF | 5% / 1% | 2 / 0 | 0.31 / 0.26 | 0.24 / 0.22 | 25% / 40% |
   | 28 | ON / OFF | 1% / 2% | 0 / 0 | 0.25 / 0.25 | 0.23 / 0.23 | 25% / 39% |
   | 24 | ON / OFF | 2% / 1% | 0 / 0 | 0.25 / 0.23 | 0.18 / 0.19 | 22% / 37% |

   Real breaches collapse from 22 per 200 runs at 40 to 1 at 32, and are **flat within noise for
   every value below 32**, so 32 is the largest value that buys the whole improvement; cutting
   further only costs a player-facing reward. 36 is not enough — it fails 4 of the 8 gate seeds with
   mastery ON and sits at p90 0.30, exactly on the limit. **Verdict at 32, worst map-3+ ratio over
   the 8 gate seeds (57 / 42 / 7 / 99 / 3 / 11 / 23 / 88), all passing both ways:**

   | mastery | 57 | 42 | 7 | 99 | 3 | 11 | 23 | 88 |
   |---|---|---|---|---|---|---|---|---|
   | ON | 0.25 | 0.21 | 0.17 | 0.22 | 0.23 | 0.15 | 0.16 | 0.15 |
   | OFF | 0.19 | 0.22 | 0.22 | 0.21 | 0.24 | 0.21 | 0.19 | 0.29 |

   **Residual that no gift value closes (reported, not fixed).** 1–3% of seeds still FAIL I2 on the
   **last** map with a denominator below one session of water: `map_spend` accrues from pops only
   (grove_sim.gd:1128), so a page finished out of a banked coin wallet books its gift against a tiny
   or zero spend — worst observed `224💧 / 0💧`, which the sim scores 999.0 and hard-fails. Dropping
   the gift to 24 does not remove it (2/100). This is a denominator artifact of I2, not
   self-sustain; closing it needs a minimum-spend floor on the I2 denominator — a metric change and
   an owner call, PARKED. Mastery ON carries more of these than OFF because it finishes late pages
   in fewer taps.

   Maps 1–2 stay the reported-WARN onboarding band, 0.63 / 0.25 average at 32 (0.79 / 0.31 at 40).
3. **I1 zero jams — PASS**, no-strand PASS, no stalls — on every seed of every cell above (0/0/0
   over 1,600 sweep runs). The smaller gift does **not** starve the early game: book runway moves
   26.8→27.7 days (ON) and 19.2→20.2 (OFF), end level is unchanged (~74), and water self-sustain
   *improves* in both configurations (34%→28% ON, 50%→43% OFF).
4. No profitable split→sell loop: pinned by the `SCISSORS_COST` floor test, not the sim.

**What a flat pop cost did** (the state this replaced): book water spend fell 68% (map-1 spend
1566 → 557💧), I2 FAILED on maps 3/4/5 on all three seeds (ratios 0.50–0.95), and the 60-day book
finished on **day 4**. With the §3 cost it finishes day 23–34 against the unmastered 21–25.

**Known consequence — the book runs ~30% longer under mastery.** Cause is measured and is NOT the
pop cost: §6's bonus-generator/chest coins are 85% of all coins earned in the unmastered baseline
and are minted **per tap and per merge**, both of which mastery cuts ~70% (merges 9322 → 2723 on
seed 42). Total water and total clicks delivered are within 2% of baseline — only the tap-priced
faucet shrinks. Re-pricing the §6 faucets off water spent (or delivered clicks) rather than raw tap
count is the fix; it is a §6/§7 faucet pass, not a mastery dial, and stays parked in BACKLOG.

## 9 · Tests

- **`engine/tests/mastery_tests.gd` (new, pure):** threshold monotonicity + the eight-rank ladder;
  `lo/hi` closed forms reproduce the §3 table; `MASTERY_TIER_ODDS_5` sums to 1 and decays; slide
  cases (clamped, no-own-asks unclamped, retroactive rise, reach ranks never clamp); band from a
  quests fixture (own asks only); credit math (delivery, craft both lines, nested special credits
  once, sum equals click cost); split value neutrality; the scissors price-floor inequality over
  all tiers × bands.
- **Pop cost (economy guard, same suite):** rank 0 costs exactly `POP_COST`; the curve never falls
  and never exceeds `tier_clicks(lo)`; a low below/above the table clamps to the first/last entry;
  the dearest window still fits in `WATER_CAP` (16💧 of 100, so the top rank is always poppable
  from a full can); the cost reads the EFFECTIVE window, so an ask-band slide back to t1 charges
  `POP_COST` again.
- **RNG byte-identity:** extend the mechanics_tests.gd:413 pattern — default window reproduces
  today's exact stream; one tier draw at every rank.
- **`grove_board_actions_tests.gd`:** deliver credits + `rank_ups`; `apply_recipe` parity with the
  old inline behavior + credits; retire/sell/collect credit nothing; `split_piece` placement
  determinism, full-board-with-no-freed-cell and tier-1 refusals.
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

## 12 · Implementation directions (for the implementing agent)

**Workspace.** Branch `feat/generator-mastery` from latest `main` in a NEW worktree outside the
repo: `git worktree add /Users/xup/dh/merge-wt-mastery -b feat/generator-mastery` (in-repo
worktrees get wiped by other agents). Seed the import cache before the first run:
`rsync -a --delete /Users/xup/dh/merge/.godot/ /Users/xup/dh/merge-wt-mastery/.godot/`.
**Do not merge to main and do not remove the worktree** — implementation ends with the branch
committed in place; code review happens in the worktree.

**Order** — each step lands with its tests green (`make test-fast`, a few seconds) before the next:

1. Dials in `grove_data.gd` + content.gd re-exports (§6); new `engine/tests/mastery_tests.gd`
   with the threshold/closed-form tests (§9); register the suite beside the other engine suites
   in the `engine/tools/run_suites.py` list the Makefile drives.
2. `engine/scripts/core/mastery.gd` (§6 API) + credit/band/slide unit tests.
3. `roll_tier_window` + the `roll_spawn` params (§3) + the RNG byte-identity tests (extend the
   mechanics_tests.gd:413 pattern).
4. Credits: `deliver_quest`; lift `_apply_recipe` to `BoardActions.apply_recipe` (parity test
   first, then add credits); the never-credit tests (§9).
5. Scissors: content registration, `split_piece`, release-ladder branch + highlight, shop row +
   `scissors_pending`, the price-floor unit test.
6. UI: ring, trim attach, rank-up card, info-bar row, strings — the §7 mocks are the composition
   authority.
7. Sim wiring (§6 grove_sim row), then the §8 battery:
   `godot --headless --path . -s res://games/grove/tools/grove_sim.gd -- 60 <seed>` for 3 seeds;
   include the reports in the handoff.
8. Full `make test` green before handoff.

**Repo rules that bite:**

- Engine code never references `games/` directly (`layering_tests`) — read through `G` /
  `Game.DATA`.
- RNG draw order is contractual (board_logic.gd:120–124); the §3 zero-added-draws law is a gate,
  not a preference.
- Fast parse check: `godot --headless --check-only --script <file.gd>`. Suites only via
  `make test-fast` / `make test` — a bare foreground `godot -s` run can hang a shell.
- New `.gd` files: run `make import` before committing so `.uid` sidecars exist and are committed.
- Tests comparing Control positions/sizes use `is_equal_approx` (float32 truncation).
- Headless runs: `is_visible_in_tree()` is false for root children; dispatch notifications with
  `obj.notification(what)`, never by calling `_notification()` directly.
- Everything ships behind the two `features.gd` flags (§6); flags off = byte-identical spawns.
- No art generation in this task: the ring is code-drawn; the trim overlay loads
  `ui/kit/mastery_trim_{1..4}.png` and stays hidden while those are absent; the shop row uses an
  existing kit icon as placeholder. Art lands separately via the art guide's intake (then
  `make bake-textures` for any sprite drawn in a dialog — `kit_bake_tests` enforces it).
- A parallel task is changing the boost/burst behavior — burst code stays untouched here (§1
  law); keep clear of board.gd:2995 and the burst constants.
- Commits: small, one per step above, conventional prefixes.
