# Cell improvements (Soil · Magnet) — spec (2026-07-26)

Draft 5. Rollout step 4 of `2026-07-26-progression-systems-design.md`; supersedes its §6
where they differ. All numbers are provisional dials — the `grove_sim` re-pass owns finals.
Acorns = `currencies.diamonds` (`save.gd:145-160`). Home board only (Rush is a separate
scene, `explore_rush.gd:65` — no flag needed).

## Summary — what is being built

Two buildable cell improvements on the home merge board, behind a feature flag:

- **Soil** (max 9; first three free, then coins; 3 ranks): any eligible piece resting on it
  grows +1 tier on an offline-capable timer — 10 s at tier 1 up to 48 h for t11→t12. Pieces
  are never locked; changing one restarts the clock, with a confirm at t7+. Watering (board
  water) halves a step once; acorns finish it now.
- **Magnet** (max 3; acorns; rankless): a passive 3×3 field — matching pieces inside it
  auto-merge, guarded so it never eats quest-asked codes, growing pieces, or a live chain.
- Around them: a Build mode (leaf button → pads → two-card sheet), Move / Demolish verbs,
  an FTUE beat at ~L6, per-count price ladders as the standing coin sink plus a premium
  magnet sink, save state riding the board dict, a new test suite, and a `grove_sim`
  re-pass. Mocks: `games/grove/assets/_concepts/ui/improvements_v1/`.

## 1 · Placement

- Two types: **Soil** — a resting piece grows a tier on a timer. **Magnet** — matching
  pieces inside its range merge automatically.
- Build on any unsealed, empty cell. Caps: **9 Soil · 3 Magnets**.
- One payment builds: pad → two-card sheet → pay → built. **Soil: the first three are free,
  then a coin ladder. Magnet: acorns** (§6). Price keyed to the count of that type currently
  on the board — `Save.spend(n, "improvement")` for coins, `Save.spend_diamonds(n)` for
  Magnets.
- **Move:** a built improvement relocates to another unsealed, empty cell for a small flat
  coin fee; Soil rank travels with it; a running clock on the source clears (the t7+ warning
  applies, §3). **Demolish:** free, no refund — building again later pays that count slot's
  price again. There is no type-swap verb (it would bypass the Magnet's acorn price).

## 2 · Model & laws

`BoardModel.improvements: Dictionary` — cell → `{kind, rank, code, ends_at, watered}`, the
`gens` trio shape (`board_model.gd:13-24`). Serialized as flattened
`[[row, col, kind, rank, code, ends_at, watered], …]` inside `to_dict()`/`from_dict()`
(`board_model.gd:493-557`), tolerant parse, rides `g["board"]` — no new `_persist()` key,
no `SCHEMA_VERSION` bump (a bump wipes saves, `save.gd:49-58`).

Laws (each tested, §9):

1. Piece truth stays in `board.items[cell]`; improvement rows never copy a piece.
2. Pieces are never locked; the Soil clock reacts to changes instead (§3).
3. Improved cells are ordinary ground — spawns and drops land on them; on Soil, any arrival
   starts growing. Exception: generator auto-placement (`seed_gens`, self-dup
   `board.gd:3076`, birth-on-tap) skips improved cells. Manual gen drops allowed.
4. No randomness, ever (the RNG stream is persisted and order-sensitive, `board.gd:983`).
   All ordering, timing, and selection below is deterministic; auto-merges roll no drops.
5. No path calls `G.earn_coins`/`Save.earn_coins` (sim invariant Y, `save.gd:118-124`).
6. Beats: Soil reconcile + Magnet scan in `_after_board_change()` (`board.gd:1011`);
   countdown display on the 1 Hz board Timer (`board.gd:362-366`); completion authority is
   the `ends_at` unix stamp, checked on tick and in `_load_state` (offline-inclusive, the
   `regen_ts` pattern `board_logic.gd:13-20`).

Pure rules in `engine/scripts/core/improvements.gd` (`resident_bucket.gd` shape: statics,
time injected). Dials in `grove_data.gd`, read through `content.gd`. All behind
`Features.on("improvements")`.

## 3 · Soil

- Any eligible piece resting on Soil is growing, however it arrived. No plant verb, no
  cancel verb.
- Eligible: tiered line piece below `G.merge_top(code)` (`content.gd:1390`; specials cap
  t3). Not coins (line 9), chests (10), collectables (12/13), generators. Ineligible sits,
  no ring.
- Reconcile each `_after_board_change()`: same code → clock runs; new eligible occupant →
  fresh clock, `watered` cleared; empty or ineligible → activity cleared.
- Completion at `ends_at`: +1 tier in place (rank 3: +2), clamped to `merge_top`; land
  bounce (`board.gd:3049-3067` trio); fresh clock starts at the new tier.
- Curve — time per step, by the tier grown **from**:

| From | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Time | 10 s | 45 s | 3 min | 15 min | 30 min | 1 h | 4 h | 8 h | 16 h | 24 h | 48 h |

- Ranks: r2 times −30% · r3 +2 tiers per completion.
- No ask interplay — growth ignores the fence.
- Selecting a growing piece → info-bar grow row: *"Growing to t8 — 2h 18m"*
  (`residents.gd:648` format) + two chips (`ActionBar.action_chip`, pattern
  `board.gd:2118-2124`):
  - **💧 −10** — spend `SOIL_WATER_COST := 10` board water, once per step: remaining time
    halves. Via the scene `water` field + `_update_water_hud`, then `_after_board_change()`.
  - **🌰 finish** — `Save.spend_diamonds(max(1, ceil(remaining_secs / 1800.0)))` — 1 acorn
    per started 30 min (1 h → 2, 48 h → 96).
- On the piece: thin progress ring (1 Hz); a countdown chip ("2h") when the step ≥ 15 min.
- **t7+ warning:** any player action that resets or consumes a piece growing from tier ≥ 7 —
  move, merge, deliver, sell, stash — first shows a confirm (`Overlay.modal`, dismissable):
  *"This restarts 6h of growing. Move it anyway?"* — Keep growing (default) / Move it.
  Nothing below t7. No automatic path needs it (Magnets skip growing pieces).
- Weather seam (dormant): module exposes `apply_water(activity, now)`; the 💧 chip pays and
  calls it; Rain (step 5) calls it free per `2026-07-26-weather-hours-design.md` §4.

## 4 · Magnet

- **No ranks — one range: the full 3×3 from purchase.** Off-board and sealed cells are not
  in range. Shown as a faint field on selection and in build mode.
- The Magnet's own cell is ordinary ground: pieces may be placed on it, spawn there, or rest
  there; a piece on the Magnet cell is inside the range and auto-merges like any other (a
  pair including it lands on the Magnet cell — it is the nearest cell).
- When two same-code `can_merge` pieces (`board_model.gd:305-311`) sit inside one Magnet's
  range, they auto-merge: both slide to the pair cell nearer the Magnet (tie → lower board
  index, `board_model.gd:37`), then standard merge FX at reduced scale (`GridFx.play_merge`
  dialog-muted, `grid_fx.gd:27`).
- Cadence: scan in `_after_board_change()`; one merge per ~0.3 s, model-committed before its
  FX (per-merge `animating` stays under the 0.6 s watchdog, `board.gd:412-419`); loops until
  no pair remains. Order: lowest tier, then board index. Overlapping ranges: each Magnet
  scans independently, in board-index order; a pair must fit inside a single Magnet's range.
- Guards (each tested):
  - never a quest-asked code — `_asked_codes` (`board.gd:1512-1518`) lifted into a
    `quests.gd` static (step-2 mastery's `ask_band` derives from the same primitive);
  - never a piece growing on Soil;
  - hold fire while a chain is armed — the scene's `chain_armed_cell()` seam (cascade spec
    §4); resume on the next fan-out;
  - no combo bump, no coin/special drop rolls, no chain credit; bramble opening
    (`openable_brambles`) and the fan-out refreshes still fire;
  - kind-uniform otherwise: coins, chests, specials auto-merge like anything (cascade R5).
- Pair scan: new `board_logic.gd` static `range_pairs(board, cells: Array) -> Array` of
  `[cell_a, cell_b]`. Validate against a known-positive and a known-negative fixture.

## 5 · Build mode, UI, FTUE

- **Build button:** small leaf overlaid on a board-area corner; hidden until the FTUE beat;
  bottom bar unchanged (`board.gd:1869-1891`).
- **Build mode:** dim one step (hand-hint veil recipe minus cutouts, `hand_hint.gd:128-192`);
  every empty unsealed cell becomes a pad (new `Kit.slot_cell` state,
  `ui_kit.gd:5891-5906`); built cells highlight → rank view; occupied and sealed cells show
  nothing. Outside build mode: built-cell art + 1–3 leaf rank pips only.
- **Sheet:** `Overlay.modal` (`overlay.gd:47-71`) + the shop offer-card grid
  (`shop.gd:292-413`). Two cards — Soil *"A piece resting here grows."* · Magnet *"Matching
  pieces in its range merge themselves."* Each shows count vs cap ("Soil · 3/9"), greys at
  cap. Tap = spend + build (direct-spend, no nested confirm; unaffordable = grey 0.45,
  pressable, wallet wiggle `shop.gd:603-609`).
- **Cell view** (tap a built cell in build mode): Soil shows its rank ladder with the next
  price on the bag-slot gold tile (`bag_overlay.gd:77-103`, "Max" at top); both types show
  **Move** (pay the fee, then tap a destination pad) and **Demolish**. Rank-up:
  `FX.celebrate_at`, no modal.
- **FTUE (~L6):** arms at level ≥ 6, `ftue_seen("soil")` (`save.gd:288-300`); calm-moment
  deferred beat (retirement-offer template `board.gd:3938-3964`, gated on
  `board_tutorial_seen`). One-line card — *"You can tend the ground now — pick a spot for
  some soil."* — then build mode opens (the first Soil build is one of the three free ones);
  `HandHint.present` (`hand_hint.gd:53-71`) taps a suggested empty cell; the player's tap
  builds it. The Build button appears with the beat.
- Visuals (normative for mocks and implementation; palette roles per the art guide §3):
  - Build button: round warm-cream leaf button, ~90 px, pinned to the board area's
    bottom-right corner.
  - Buildable pad: dashed warm-cream cut-paper outline inset in the cell, small garden-green
    **+** centered.
  - Soil cell: rounded matte earth patch, desaturated gold-brown, deckled cut-paper edge, one
    same-hue shadow plane.
  - Magnet cell: horseshoe pebble in structural slate, inset on the cell.
  - Soil rank pips: 1–3 garden-green leaf pips, bottom-left corner of the cell. Magnet has
    no pips.
  - Growing piece: thin garden-green progress ring, clockwise; small warm-cream time chip
    with ink text ("2h") at the piece's top-right when the step ≥ 15 min; sprout wiggle.
  - Magnet range field: translucent garden-green cut-paper field (~15% opacity) over the
    range cells, under the pieces.
  - Grow row: info tray title *"Growing to t8 — 2h 18m"*; chips 💧 droplet **−10** ·
    🌰 acorn **8**.
  - Sheet card: type art · name · verb line · count vs cap ("0/9") · price pill — Soil:
    "Free" while free builds remain, then the coin price; Magnet: acorn icon + acorn price.
  - Warning card: *"This restarts 6h of growing. Move it anyway?"* — **Keep growing**
    (action green, default) · **Move it** (quiet cream).
- Raster masters (produced through the art pipeline, `docs/design/art-style-guide.md`; 512²
  transparent, at `games/grove/assets/ui/kit/`): `cell_soil.png` · `cell_magnet.png` ·
  `build_leaf.png` · `pip_leaf.png`. Everything else — pads, ring, time chip, range field,
  veils, sheet chrome — is code-drawn.
- Mocks: `games/grove/assets/_concepts/ui/improvements_v1/` — one PNG + prompt sidecar per
  surface (build mode · build sheet · soil growing · magnet range · t7+ warning).

## 6 · Dials (provisional)

| Dial | Value |
|---|---|
| Soil builds (Nth) | 1–3 **free** · then 500 · 1 000 · 2 000 · 4 000 · 8 000 · 16 000 coins |
| Magnet builds (Nth) | **25 · 50 · 100 acorns** |
| Move fee | 100 coins, flat |
| Demolish | free, no refund |
| Soil ranks | r2 600 · r3 1 500 coins |
| `SOIL_WATER_COST` | 10 water — sim revisits the flat halve at t10+ (worth 24 h at t11) |
| Acorn finish | `max(1, ceil(remaining / 30 min))` |

Prices key to the count of that type currently on the board (demolish decrements). Consts in
`grove_data.gd` beside `BOOST_COST` (`grove_data.gd:232`); nothing in `economy_tuning.json`
unless the owner wants a live dial.

## 7 · Sim re-pass (gates the merge)

Run: `godot --headless --path . -s res://games/grove/tools/grove_sim.gd -- [days] [seed]`.

- coin spends (paid Soils, ranks, moves) into a new `improve_spend` counter folded into
  `coin_sink` (`grove_sim.gd:337`) and the Z report (`:341`); Magnet acorns into the D
  diamond ledger; the bot buys greedily (boost-buy block as template) → I3 runway.
- I1 zero jams at full build-out (12 improved cells).
- Soil as a bounded faucet — 9 cells on the §3 curve to t12; re-confirm Y and faucet drift;
  price the t10+ watering halve.
- Magnet is value-neutral (merges only what exists); assert no ledger moves beyond normal
  merge accounting.

## 8 · Persistence

- Rows ride `g["board"]`; defaulted on read; cloud save unchanged.
- Tolerant load: invalid-cell rows dropped; activity reconciled against `items[cell]` as on
  any board change (covers `_purge_above_level_content`, `board.gd:774-822`).
- Store `ends_at` stamps, never remaining-seconds.

## 9 · Tests

New `games/grove/tests/grove_improvements_tests.gd` on `grove_test_base.gd` (pure rules +
real-scene via manual `_ready`, `grove_test_base.gd:438-441`, and `_tap_board` `:126-134`);
`range_pairs` units in `engine/tests/`. Add the suite to `GROVE_TESTS` in the Makefile and
the `CLAUDE.md` suite list in the same commit.

Cover: build flows — three free Soils then the coin ladder, Magnet acorn spend, cap
refusals, count math across demolish · move — fee, Soil rank travels, source clock clears,
t7+ warning on a t7+ move · demolish free/no refund · pads only on empty+unsealed · spawn on
Soil grows; gen auto-place skips · clock reconcile matrix
(arrive/leave/replace/merge-onto/complete; `watered` per step) · curve incl. ranks and
`merge_top` clamps · water-once + finish price · offline completion via stamp · t7+ warning
on every reset path, absent below t7 · magnet 3×3 from purchase; a piece on the Magnet cell
auto-merges · auto-merge order, landing cell, loop-until-done · all five guards (asked code
· growing piece · armed chain · no credit/no RNG, `rng.state` byte-identical ·
kind-uniformity) · save round-trip, tolerant load, purge self-heal · `range_pairs`
known-positive/negative · FTUE once-only.

## 10 · Implementation directions (for the implementing agent)

Work happens in a fresh **out-of-tree** worktree; the branch stays **unmerged** — review
happens in the worktree before merge. Never edit the main checkout (a hook blocks it).

```
git -C /Users/xup/dh/merge worktree add -b improvements /Users/xup/dh/wt-improvements main
rsync -a --delete /Users/xup/dh/merge/.godot/ /Users/xup/dh/wt-improvements/.godot/
```

The rsync seeds the import cache — without it the first test run does a slow full reimport.

Read before coding: this spec end to end; `docs/design/board_decomposition.md` (layering
`scenes/ → ui/ → core/`, frozen `_persist()` key set, RNG discipline); the §2 anchors in
their files.

Build in commit-sized steps, each green (`feat(improvements): …` messages):

1. `Features` flag `improvements` (+ `docs/FEATURES.md` row) · dials in `grove_data.gd`
   re-exported through `content.gd` · pure rules module `engine/scripts/core/improvements.gd`
   with unit tests in the new suite `games/grove/tests/grove_improvements_tests.gd`.
2. `BoardModel.improvements` + `to_dict`/`from_dict` rows + reconcile helper; save
   round-trip and tolerant-load tests.
3. Soil runtime in `board.gd`: reconcile in `_after_board_change()`, completion on the 1 Hz
   tick + `_load_state`, land-bounce, info-bar grow row (`ActionBar.action_chip`), water and
   acorn-finish spends, t7+ warning (`Overlay.modal`), ring + time chip rendering.
4. `board_logic.range_pairs` (+ known-positive/negative tests) · Magnet scan/execute loop
   with all five guards · pull FX.
5. Build mode: leaf button, pads (`Kit.slot_cell` new states), two-card sheet (shop
   offer-card grid), cell view (Soil ranks · Move · Demolish), spend paths.
6. FTUE beat (`ftue_seen("soil")`, retirement-offer template, `HandHint`).
7. Register the suite in `GROVE_TESTS` (Makefile) **and** the `CLAUDE.md` suite list — same
   commit.
8. `grove_sim` additions (§7), run the re-pass, paste the invariant numbers into the final
   commit message.

Hard rules (violations fail review): never bump `SCHEMA_VERSION`; zero RNG draws in any
improvement path (the byte-identity test pins it); never call `G.earn_coins`/
`Save.earn_coins`; reuse the named shared components — no bespoke modals, chips, cells, or
keyers; all dials in `grove_data.gd`, none inline.

**Assets — do not generate any.** The four raster masters (§5) are produced separately
through the art pipeline and land at `games/grove/assets/ui/kit/`: `cell_soil.png`,
`cell_magnet.png`, `build_leaf.png`, `pip_leaf.png`. Do not generate, draw, edit, or
download art of any kind. Wire the exact paths; if a master is not present yet, put a
placeholder behind the same seam — an existing kit icon or a flat tinted rect — so the real
file swaps in with zero code change. Everything else is code-drawn per §5. When a master is
first drawn in a top-level dialog, add its bake target per the art guide §8
(`make bake-textures`).

Process: run `make test-fast` after every change and the full `make test` before handing
off — always in the **foreground** (a backgrounded run never returns to an agent). A plain
`godot -s` foreground run times out at 2 min — parse-check with
`godot --headless --check-only --script <file>` and run suites only via `make`. After adding
any new `.gd`, run `make import` before committing so its `.uid` lands in the same commit.
Capture proof of the new surfaces (`make shot-grove OUT=…` from the worktree) and list the
capture paths in the handoff note.

Done = full `make test` green in the worktree, sim invariants pasted, captures listed,
branch pushed-in-place and left unmerged for review.

## 11 · Open questions

1. t5 grow step = 30 min — interpolated between the pinned 15 min and 1 h.
