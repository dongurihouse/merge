# Generator mastery (+ the Scissors) — full design (2026-07-26)

**Status: draft for Dev review.** This is rollout **step 2** of
`2026-07-26-progression-systems-design.md` (§3 owns the intent, §7 the economy laws); this doc
grounds that sketch in shipped code and makes every mechanic implementable. Companions:
`docs/design/picturebook_lines_recipes.md` (roster intent; its line ids for shells/corals/koi/tea
cups are stale — shipped ids are 16/17/18/19), `2026-06-29-per-generator-boost-design.md` (the
temporary boost this system must compose with).

All numbers are **provisional dials** — the step-2 `grove_sim` re-pass owns the finals (§10).

---

## 1 · What this is

A permanent, per-line growth track. Using a line productively fills its meter; meter ranks make the
line's generator pop better — bigger bursts, and a rising **tier floor** so pops start at t2…t5
instead of t1. At a t5 floor a t12 trophy costs 128 pops, not 2048 — mastery is the road to tier 12,
and the reason an ingredient line keeps mattering for its whole craft afterlife. The Scissors ships
with it as the bridge back down: a tool that splits one piece into two of one tier lower, so high
floors can never strand a low-tier ingredient ask.

There is no permanent per-line growth in the game today (the permanent burst-upgrade ladder was
replaced by the temporary per-cell boost in commit `4d75ec04`; nothing named mastery exists in code).

## 2 · Scope — what masters and what does not

- **The 8 base generator lines master** — `ZONE_BASE_LINES = [1, 2, 3, 4, 6, 7, 16, 18]`
  (glowshroom, wildberries, snowballs, woolens, desert fruits, sand, shells, koi). Mastery state is
  keyed by **line id**, not by generator instance: every generator of a line shares one meter, and
  the meter survives the generator being merged, sold, bagged, shelved, or re-birthed.
- **The 4 crafted specials (5, 8, 17, 19) have no meter.** They have no generator, so every reward
  on the ladder is meaningless for them — and no value is lost: crafting a special credits both
  ingredient pieces to their own base lines (§3), so a special's full click cost lands on base-line
  meters. Delivering or consuming the special itself credits nothing further (no double counting).
- Coins (line 9), chest/water/acorn drops (10/12/13), and treat lines (71–75) never master.
- **The Rush is out by construction** — it has its own spawner (`explore_rush.gd:652`, no
  `BoardLogic`/`BoardModel`), so floors and burst ranks cannot leak into it. Rush-won pieces landing
  on the home board are ordinary pieces; delivering one later credits normally.

## 3 · The meter

**Unit: tier-1 equivalents**, via the existing `G.tier_clicks(t) = 2^(t-1)` (content.gd:556) — the
same unit quest rewards are already priced in. The meter only counts **value productively used**:

| Feed | Credit | Hook (the only two credit sites) |
|---|---|---|
| **Fence delivery** of an own-line piece at tier t | `+tier_clicks(t)` | `BoardActions.deliver_quest` (board_actions.gd:22–35, `code` at :26) |
| **Craft consumption** — an own-line piece consumed as a craft ingredient at tier t | `+tier_clicks(t)` per piece, each ingredient crediting its own line | the recipe merge, lifted to `BoardActions.apply_recipe` (§7; today inline at board.gd:3126–3136) |

Rules:

- A craft's two ingredients are always the same tier (`_recipe_merge_code`, board.gd:3116–3123);
  both credit. If an ingredient is itself a special (tea cups consume spices), that ingredient
  credits nothing — its own cost was credited when it was crafted. The chain sums exactly to the
  item's click cost; nothing is counted twice and nothing leaks.
- **Everything else credits nothing**, by whitelist: the two sites above are the only credit points.
  Selling (`_grant_sale`, board.gd:4000), retire-line bulk sells (board_actions.gd:141), generator
  sells, collects, stashing, Shelf sweeps, and any future consumption path (expeditions, residents)
  all stay at zero unless a future spec adds them to this law.
- The meter never resets and has no cap; rank is **derived** from the meter, never stored.
- Meters move only on the home board. Deliveries are single-piece today (`quest_item`,
  content.gd:547), so a delivery credits one piece's value.

**Pacing check** (design intent, not a promise — the sim owns the real curve): decomposing the
picture-book click model (~18.1K tier-1 equivalents per full restoration, specials' cost flowing to
their ingredients) lands roughly: koi ~5.1K and shells ~3.4K (rank 7), wildberries ~2.4K and sand
~2.1K (rank 6), snowballs/woolens ~1.5–2K (rank 5–6), glowshroom/desert fruits ~0.4–0.9K (rank
4–5). That matches the parent's intent: steady use reaches rank 4–6, devoted lines reach 7, and
rank 8 (6500) is post-book. Caveat: that model is intent-stage; shipped asks draw from a t4–t12
bell (`gen_quest`, content.gd:674–683), so the sim re-pass must reproduce this shape from live play
(§10).

## 4 · The ladder — 8 ranks

Thresholds step ~×2.2 and start low. `MASTERY_THRESHOLDS := [20, 60, 150, 350, 800, 1700, 3400,
6500]` (grove_data.gd, beside the other pacing dials).

| Rank | Threshold | Permanent reward | Mechanically |
|---|---|---|---|
| 1 | 20 | Better burst odds | burst step +1 (§4a) |
| 2 | 60 | Pops land t2–t5 | floor entitlement t2 (§4b) |
| 3 | 150 | Bursts sometimes add a bonus piece | bonus-piece chance 0.15 (§4a) |
| 4 | 350 | Pops land t3–t6 | floor entitlement t3 |
| 5 | 800 | Bigger bursts — triples common | burst step +2 (total) |
| 6 | 1700 | Pops land t4–t7 | floor entitlement t4 |
| 7 | 3400 | Pops lean toward asked tiers | per-line ask-tier lean 0.35 (§4c) |
| 8 | 6500 | Pops land t5–t8 | floor entitlement t5 |

Closed forms (pure, unit-tested): `floor_rank(r) = 1 + r ÷ 2` (integer division, so ranks 2/4/6/8
give floors 2/3/4/5), `burst_step(r) = (r ≥ 1) + (r ≥ 5)`.

### 4a · Burst rewards, grounded in the shipped tables

Shipped burst machinery (charged pops only, board.gd:2995–3000): an unboosted pop rolls
`GEN_TIER_BURST_ODDS[generator tier]` = `[[0.80,0.15,0.05], [0.50,0.35,0.15], [0.20,0.45,0.35]]`
for 1/2/3 pieces; a boosted pop rolls `BURST_ODDS_BOOST = [0.20,0.45,0.35]` — which is **identical
to the tier-3 row**, so a paid boost on a tier-3 generator is already a no-op. The parent sketch's
burst rewards are re-grounded against these tables:

- **Burst table step.** The pop's odds row index becomes
  `min(generator_tier − 1 + burst_step(rank), 2)`. At rank 1 a tier-1 generator bursts like tier-2
  (doubles 15%→35% — "doubles pop more often"); at rank 5 every generator of the line uses the top
  row (triples at 35% — "triples common").
- **Bonus piece (rank 3).** After the burst-count roll, one extra roll at
  `MASTERY_BONUS_PIECE := 0.15` adds one piece — **free** (no water cost), bounded by open cells,
  placed through the same `roll_spawn`. Effective burst can reach 4; `BURST_MAX` stays 3 for the
  table itself.
- **Boost composition (amends the boost's semantics — Dev call §13.3).** A boosted pop takes the
  top table row as today **and** gains the 0.15 bonus-piece chance even below rank 3. Mastery rank 3
  and a live boost do not stack the bonus chance (max, not sum). This restores the boost's value on
  tier-3 generators (broken today) and keeps it purchasable on rank-5+ lines, where the table
  advantage saturates. Generator merging keeps value below rank 5 and always keeps its
  board-space value; the saturation at rank 5 is accepted and flagged.

### 4b · The floor rule

- **Entitlement vs effective.** The rank grants a floor entitlement (t2/t3/t4/t5). The effective
  floor is computed per pop:
  `effective = rank_floor` when the line has **no own live asks**, else
  `effective = clamp(band − 3, 1, rank_floor)`, where **band = the highest tier among the line's own
  live asks** (the runtime `quests` array read through `G.quest_item`; an ask for a special is not
  an ask for its ingredients). New helper — nothing suitable exists; `BoardLogic.wanted_tiers` is
  clamped to t≤4 for spawn bias and must not be reused for this (board_logic.gd:79).
- **A comeback line re-birthed as an ingredient tool has no own asks** — its floor applies
  unclamped, and the Scissors is the bridge down to low ingredient tiers (§5). If the band is low,
  the floor waits and unlocks retroactively as bands climb; nothing is stored — it is recomputed
  from rank + live asks at pop time, once per `_pop_seed` call (one floor for the whole burst).
- **Mechanics: a window shift, not new odds.** `roll_tier` keeps its single draw over `TIER_ODDS =
  [0.65, 0.25, 0.09, 0.01]`; the result is shifted by `effective − 1`, so pops land in
  `[floor, floor+3]` on the same decaying curve. Floor 1 is the identity (today's t1–t4). Maximum
  window is t5–t8: **pops can never mint t9+** — the t9 capstone and t10–t12 trophies stay
  merge-made.
- Shipped asks reach t12, so `band − 3` can reach t9; the rank cap (t5) always binds first. (The
  parent's "ask bands cap at t8" describes the intent-stage recipe doc, not shipped code — the rule
  needs no amendment, the cap just binds earlier.)
- The floor applies **only to generator pops** (`_pop_seed` → `roll_spawn`). `roll_item_tier`
  consumers (accumulator/treat collects) and `bramble_seed` are untouched.

### 4c · Rank 7 — the ask-tier lean

The parked global dial stays parked: `ASK_TIER_WEIGHT` remains 0.0 (grove_data.gd:196; pinned by
mechanics_tests.gd:417 — that pin survives). Rank 7 arms a **separate per-line** dial,
`MASTERY_ASK_TIER_WEIGHT := 0.35`: with that probability, the rolled tier is replaced by a uniform
pick among the line's own asked tiers **that fall inside the current pop window** `[floor,
floor+3]` (the shipped block at board_logic.gd:135–144 with the 1..4 clamp generalized to the
window). The `wanted_tiers` dict build at board.gd:3017 — today gated on the global dial — gains
"or the popping line is rank 7". The global-dial history (front-loads spend ~3×) is exactly why
this ships per-line, top-rank only, and why the sim re-pass gates it (§10).

### The RNG law (hard rule)

The board RNG is seeded and persisted, and draw order is contractual (board_logic.gd:120–124;
byte-identity test mechanics_tests.gd:413–421). Therefore: **every mastery mechanic adds RNG draws
only when explicitly armed** — by a rank, or by a live boost. The floor shift adds none, ever
(post-roll arithmetic). The bonus piece adds one draw only at rank 3+ or under a live boost (the
§4a composition — the boost is player-armed state, so its stream may change); the lean adds one
only at rank 7 with candidates in window. A rank-0 line's **unboosted** pop stream stays
byte-identical to today — extended tests assert this (§11).

## 5 · The Scissors

Crafts merge two ingredient pieces at the **same tier**, so an unclamped floor (a comeback line at
rank 4+ popping t3+) would make a t2/t3 ingredient ask impossible. The Scissors is the load-bearing
bridge and ships in the same task.

- **Item.** New tool pseudo-line `SCISSORS_LINE := 14`, code 1401 (the id space beside chest 10 /
  water 12 / acorn 13, per the rule at grove_data.gd:347). Registered in `is_valid_item_code`
  (content.gd:1264 — otherwise the save-load prune at board_model.gd:513 deletes it), kind
  `"scissors"`. Never merges, never sells (joins the trash-hidden set, board.gd:2160), not
  collectable on tap — tap selects and shows its info line; **drag is its only verb**. Storable in
  the bag like any code.
- **Use.** Drag the scissors onto any content-line piece (a line with a zone row — bases and
  specials alike) of tier ≥ 2: the target becomes tier−1 and a twin (same line, tier−1) lands on
  the **nearest empty ground cell** (Manhattan distance from the target, ties by cell scan order —
  deterministic, no RNG draw). The scissors is consumed. Needs one empty ground cell; on a full
  board, and over ineligible targets (tier 1, generators, tools, coins, treats), the ghost shakes
  its head and the drag snaps back — no snip, no loss. Splitting a currently-asked piece is allowed
  (bridging down is the tool's purpose). No mastery credit for splitting; value-neutral by
  construction (`2^(t-1) = 2 · 2^(t-2)`).
  - Resolution: one new branch in the release ladder after the recipe branch (board.gd:2862), plus
    the same predicate in the drag-target highlight (board.gd:1735).
- **Acquisition.** A shop row (shop.gd `_quick_help_section` shape, coin-priced, always in stock —
  there is no stock system and none is built). `SCISSORS_COST := 40` coins. The row is hidden until
  any line reaches rank 2 (`Mastery.any_rank_at_least(2)`) — before floors exist the tool is
  meaningless, and this satisfies "never required before rank 2 exists" (a strand needs rank 4).
  Buying from the board-opened shop places it like the info-bar buy chip (first empty ground cell,
  else bag, refuse-before-spend — the recipe at board.gd:2404–2453); from the map-opened shop it
  banks `scissors_pending` (the `water_pending` pattern, save.gd:472–489), drained on board entry.
- **The arbitrage guard is a price floor, not a sim hope.** Sell prices are **linear in tier**
  (`sell_reward = round(tier × band)`, content.gd:1220; bands ≤ 2.8) while a split doubles piece
  count — so split→sell profits `≈ (t−2) × band` per snip, up to 28 coins at t12. The law:
  `SCISSORS_COST > max over t,band of [2·sell(t−1) − sell(t)]`, asserted exactly as a **unit test**
  over all tiers and bands (40 > 28 holds). If the Dev wants the scissors cheaper than ~30, the
  sell curve has to bend instead — flagged (§13.4).

## 6 · Data model & save

Per-line state lives in the grove blob (per-cell `BoardModel` state is wrong for it — mastery must
survive sell/bag/merge/re-birth). Additive keys, defaulted on read via the deep-merge load
(save.gd:98–105); **no schema bump, no migration**:

```
Save.grove()["mastery"]       : { "<line id>": int }   # meter, tier-1 equivalents
Save.grove()["mastery_seen"]  : { "<line id>": int }   # highest rank already celebrated
Save.grove()["scissors_pending"] : int                 # map-shop purchases awaiting board entry
```

Rank, floors, burst step, and lean are all derived from the meter — never stored. Existing saves
read as all-zeros and simply start climbing; there is no historical per-line delivery ledger to
seed from, so no retro credit (§13.5). Board and bag blobs are untouched. Persistence rides the
existing `_after_board_change → _persist` fan-out (board.gd:1011, both credit sites already sit
before it).

## 7 · Architecture — where the code lands

| Unit | Owns |
|---|---|
| `games/grove/grove_data.gd` | The dials: `MASTERY_THRESHOLDS`, `MASTERY_BONUS_PIECE`, `MASTERY_ASK_TIER_WEIGHT`, `SCISSORS_LINE`, `SCISSORS_COST` (re-exported through content.gd like every other table) |
| **new** `engine/scripts/core/mastery.gd` | Static module (the `bucket.gd` shape) over `Save.grove()`: `meter/rank/floor_rank/burst_step`, `ask_band(line, quests)`, `effective_floor(line, quests)`, `ask_lean_weight(line)`, `credit_delivery(code)` / `credit_craft(a_code, b_code)` (both return `{line: ranks_gained}` for the scene to celebrate), `any_rank_at_least(r)`. Pure over injected quests — headless-testable |
| `board_logic.gd` | `roll_spawn` gains `tier_floor := 1` (post-roll shift; default keeps today's byte stream) and the lean's window filter; `wanted_tiers` gains window bounds |
| `content.gd` | **One shared burst roller**: `pop_burst_count(gen_tier, burst_step, boosted, rng)` replacing the two-table ternary at board.gd:2995–3000, so board and sim roll identical bursts. Scissors code registered in `is_valid_item_code` / `special_kind` / `item_display_name` |
| `board_actions.gd` | `deliver_quest` calls `Mastery.credit_delivery` and returns `rank_ups`; **`_apply_recipe` is lifted here** as `apply_recipe(board, from, target) -> {code, consumed}` + credit (today it is scene-inline at board.gd:3126 with no test seam — this matches how deliver/retire/sell already live in the pure layer); new `split_piece(board, from, target) -> {twin_cell}` for the Scissors |
| `board.gd` | Orchestration only: floor/lean args into `roll_spawn` (:3017, :3029), burst call swap (:2995), release-ladder branch + ghost telegraph, ring/trim/rank-up/info-bar/shop wiring |
| `features.gd` | `"mastery": true`, `"scissors": true` (rule N4); off = rank 0 everywhere = byte-identical spawns |
| `grove_sim.gd` | Calls the same `Mastery.credit_*` at its fused craft-and-deliver site (:827–841) and the extracted burst/tier helpers instead of its hand-mirrored copies (:937–945, :1051–1072) — the mirror-drift class dies here |

## 8 · UI

- **The ring.** A thin `draw_arc` ring in the line's color (`G.LINES[line].color` — the shipped
  per-line palette, read exactly as piece_view.gd:297 does) around each of the line's generators,
  filling clockwise with progress **within the current rank**; full and steady at rank 8; absent
  while the meter is 0 (zero FTUE clutter). New small Control on the focus_ring pattern
  (`mouse_filter = IGNORE`, never child 0 — piece_view.gd:461), refreshed on the
  `_refresh_boost_indicator` beat (board.gd:1643). No numbers on the board. (No radial-progress
  component exists today; this is the first.)
- **The trim.** At floors 2/4/6/8 the generator gains an art trim — ribbon → bronze → silver → gold
  blossom — as **one shared set of four overlay frames** on the 512² generator canvas (art guide
  §5), composited over any generator's sprite; not per-line art (8 lines × 4 states of bespoke art
  is an intake sweep for another day — §13.6). The same frames later gild Shelf rows and Collection
  entries (forward hook; whichever of step 1/step 2 lands second wires it).
- **Rank-up.** The `retire_offer.gd` template (Overlay.modal + art + one line + one CTA,
  dismissable): generator art, *"Berry Bush — pops now land t3–t6."*, **Continue**, with
  `FX.burst` confetti. Fired deferred after the triggering action's FX settle; multiple ranks in
  one credit collapse into the highest; queued behind the level-up popup when both fire
  (board.gd:3798).
- **Info bar.** When a generator is selected, the tier moves up into the name line
  (`_gen_info_text`, board.gd:2250 — "Berry Bush · T2 · Boosted · 4 left") and the second line
  (today "Tier N · description", board.gd:2206) becomes the mastery row: eight rank pips, a slim
  `Kit.progress_bar` to the next threshold, and the next reward in six words. Same single-row
  height — the tray is fixed-height and must not grow (action_bar.gd:95–111;
  `board_hud_layout_tests` stays green). Items and empty cells are unchanged.
- **Shop row.** Scissors art, price, one line: *"Cuts a piece into two of a tier lower."* Standard
  card dict; `price_icon: "coin"`.
- **Scissors in hand.** Dragging over an eligible piece ghosts the two half-tier sprites (the
  telegraph seam, board.gd:2696–2716); drop plays a snip and the halves pop apart; ineligible → the
  existing refuse wobble.
- **Strings** in `games/grove/strings.json`: `board.info.mastery_next_*` (one per rank),
  `shop.scissors.*`, the rank-up card lines.
- **Art intake** (implementation-time, per the art guide's workflow): `tool_scissors` piece sprite +
  `shop_scissors` icon (512² masters → 256 runtime), 4 trim frames.

## 9 · Economy guards (this step's slice of parent §7)

- Mastery feeds on productive use only — the two whitelisted credit sites; selling never.
- Floors respect asks: `min(rank floor, own band − 3)`, unclamped only when no own asks exist.
- Pops never mint above t8; t9+ stays merge-made.
- Scissors is never a sell arbitrage — the price-floor inequality is a unit test, not a tuning hope.
- The lean ships per-line at rank 7 only; the global dial stays 0.0 and its test pin stays.
- Combo/chain credit for splits and echoes: nothing here grants any — steps 3/4 own those verbs.
- The clock stays quests-only: mastery mints no coins; rank-ups pay nothing.

## 10 · The grove_sim re-pass (gates this step's merge)

Add mastery state + the shared rollers to the sim (§7), then re-run the standard battery
(3 seeds × 60 days minimum — single-seed diffs conflate change with RNG drift) and report:

1. **Time-to-rank curve** per line — the §3 shape must emerge from live play: typical lines rank
   4–6 by book end, koi/shells ~7, rank 8 post-book. Thresholds move if not.
2. **Faucet inflation bounded.** Floors cut pops-per-delivery (that is the point), which speeds the
   coin faucet and the quest clock. Invariant Z (sink > faucet) and the P1/P2 pile checks must
   hold; report the book-length change (the ~19K-click arc will compress for mastered lines — the
   Dev accepts a number, the sim reports it).
3. **Rank-7 lean bounded.** The global dial front-loaded spend ~3× at 0.6; per-line at 0.35 must
   show no such front-load (this gate is why the lean ships at top rank only).
4. **No jams** (I1) with floors active — high-tier boards must not deadlock ingredient asks;
   scissors purchases must appear in the bot's ladder when a strand would otherwise jam.
5. **Scissors economics:** the bot never finds a profitable split→sell loop (belt-and-suspenders on
   top of the §5 unit test).

Invocation unchanged: `godot --headless --path . -s res://games/grove/tools/grove_sim.gd -- <days>
<seed>`. The 2026-07-25 level-gates re-derivation (approved for planning) moves where levels sit on
the arc; mastery reads live asks and zone functions only, so the two land independently — but the
sim re-pass should run on whichever gate table is live when this merges.

## 11 · Testing

- **`engine/tests/mastery_tests.gd` (new, pure):** threshold monotonicity; rank/floor/burst-step
  closed forms; band from a quests fixture (own asks only; specials don't proxy to ingredients);
  effective-floor clamp incl. the no-own-asks unclamped case and retroactive rise; credit math
  (delivery, craft both-lines, nested special credits once, sum equals click cost); split value
  neutrality; the **scissors arbitrage inequality over all tiers × bands**; burst composition
  (gen tier × step × boost, max-not-sum bonus).
- **RNG byte-identity:** extend the mechanics_tests.gd:413 pattern — rank-0 lines and
  `tier_floor = 1` produce today's exact stream; each armed effect adds only its documented draw.
- **`grove_board_actions_tests.gd`:** deliver credits + returns rank_ups; lifted `apply_recipe`
  parity with the old inline behavior + credits; retire/sell/collect credit nothing; `split_piece`
  placement determinism, full-board and tier-1 refusals.
- **`grove_shop_tests.gd`:** row hidden below rank 2; buy places / banks pending; refuse before
  spend.
- **Flow (board suite):** floor applied to a real pop window; lean respects the window; rank-up
  card fires once per rank (`mastery_seen`); boost+mastery burst on a live board; scissors
  drag-branch ordering (merge and recipe still win their cases).
- **Layout:** `board_hud_layout_tests` unchanged (info row height); `modal_dismiss_tests` untouched
  (the rank-up card is dismissable).
- Inner loop `make test-fast`; full `make test` + the §10 sim battery before merge.

## 12 · Rollout & dependencies

Ships as parent step 2, one worktree. Independent of step 1 (the Shelf — not yet built): meters
feed from deliveries and crafts regardless; the shelf-row/Collection trim gilding is a one-line
forward hook for whichever lands second. Lands before step 3 (combos) — the ladder-outline and
chain rules will meet the scissors and rank-up timing in that spec, not this one.

## 13 · Dev review — confirm these calls

1. **Craft-consumption credit** is a new law (parent §10.1) — restated here as the whitelist in §3.
2. **Specials have no meter** (§2) — their cost credits their ingredients at craft time. The parent
   said "each line's meter"; this narrows it to the 8 base lines.
3. **Burst grounding + boost composition** (§4a) — table-steps for ranks 1/5, and the boost gains
   the bonus-piece chance so it stays worth buying at generator tier 3 / rank 5+ (a semantics
   amendment to the 06-29 boost design's out-of-scope line).
4. **Scissors at 40 coins**, forced ≥ ~30 by the linear sell curve. Cheaper requires bending
   `sell_reward` — a bigger change, not proposed.
5. **No retro seed** — existing mid-arc saves start at rank 0 (no per-line history exists; early
   thresholds are low, so catch-up is fast).
6. **Trim art is one generic 4-frame overlay set**, not per-line bespoke art.

Parent §10.2 (soil FTUE level) is step-4 scope and stays there.
