# Weather Hours — full spec (2026-07-26)

**Status: draft 1, for Dev review.** Expands §4 + rollout step 5 of
`2026-07-26-progression-systems-design.md` (the parent design) into a buildable spec.
Companions: `engine/scripts/ui/ambient.gd` (the shipped cosmetic hourly roll this system
absorbs), `engine/scripts/core/board_logic.gd` (the merge-drop rolls), `engine/scripts/core/content.gd`
(active lines + asks), `games/grove/tools/grove_sim.gd` (the economy sim that owns the finals).

All numbers in this doc are **PROVISIONAL** dials — the grove_sim re-pass (§10) owns the finals.

---

## 1 · Scope

What ships in this one Dev task (own worktree, per the parent's §8): the hourly **sky**
(three skies over the shipped deterministic roll), the **patch** (one lane of soft light),
the two **gift merges** (Sunbeam coins, Rain water), the **starfall drop**, the banner /
HUD chip / patch UI, the debug lever, headless suites, and the sim re-pass.

**Home board only, structurally.** The Rush is its own scene (`explore_rush.gd`) with zero
`board.gd` coupling — it simply never mounts any of this. The map keeps what it has today:
the shared cosmetic look (`Ambient.build_weather`), no gifts, no patch.

Not in this spec: soil/improvement execution (step 4 owns it — §4 here pins only Rain's
contract with soil so either ship order works), the festival sky, magnet/mirror skies, the
Wild piece (all parked in the parent §9), and any change to the water stall's daily free
rain (`2026-07-25-free-rain-priority-design.md` stands untouched).

---

## 2 · The clock — one roll, one sky

One grove day = one real hour. The hour index is the shipped idiom:
`int(unix_time / Tune.SECS_PER_HOUR)` — deterministic, offline-correct, no server
(`Ambient.weather_now`, `tuning.gd` §Ambient).

**This is an upgrade of the shipped roll, not a second one.** `hash(hour)` picks the hour's
**sky**; salted re-hashes (`hash(hour * K + SALT_*)`, the `ambient.gd` per-stream idiom)
pick the **skin** and the **lane** independently. The hash is unsalted by player —
**world weather, kept deliberately**: every grove shares the same sky this hour, exactly as
the shipped cosmetic roll already behaves.

The four shipped cosmetic states become the skies' **skins** — what the hour looks like,
riding the existing `WeatherLayer` on board and map:

| Sky (share) | Skins (sub-roll) | The gift |
|---|---|---|
| **Sunbeam** (45) | clear 70% · breeze 30% | in-patch merges drop richer coins more often (§4) |
| **Rain** (45) | rain 85% · snow 15% | in-patch merges shake water loose; in-patch soil waters itself (§4) |
| **Starfall** (10) | starlit *(new glimmer look)* | once this hour, a high-tier piece falls onto the lane (§5) |

- **Laws.** Never a penalty — weather only gives. Every hour has exactly one sky; a session
  sees one or two turns; every login feels different.
- **Win-back** keeps its spirit: a ≥48 h return forces the **Rain sky** (rain skin) for its
  60 s (`winback_until` — "it rained while you were away", and now the first minute back
  also drips). For that minute the **whole board counts as the patch** — the forced minute
  rides another hour's lane roll, whose axis may not even be Rain's, and sixty seconds of
  board-wide sips is bounded generosity. The hour's rolled sky resumes after; a pending
  starfall waits out the minute (§5 trigger reads the live sky).
- **Clock skew, stance: accepted** (no server). Backwards: the §5 `paid_hour` guard is
  monotonic, nothing re-pays. Forwards: indistinguishable from waiting.
- **Gate.** The sky goes live once both FTUE verbs are taught —
  `Save.ftue_seen("merge") and Save.ftue_seen("gen_tap")` (the hand-hint pair) — and
  `Features.on("weather_hours")` (Rule N4; one registry line in `docs/FEATURES.md`).
  Below the gate the world shows looks only: skins keep rendering, no banner, no chip, no
  patch, no gifts, no star. The shipped `ambient_weather` flag stays a separate, look-only kill switch
  — turning it off empties the `WeatherLayer` and must never turn gifts off.
- **Flagged look consequence:** rain-family visuals rise from ~10% of hours today
  (rain 8 + snow 2) to ~45%. The `RAIN_VEIL` alpha becomes an explicit art-pass dial; the
  share split itself is Dev question 1 (§13).

---

## 3 · The patch — the lane

The sky projects one soft spatial effect onto a single lane of the board, seeded per hour:
stable while you play, moved by the next sky.

- **Model space.** `cell.x` is the row (0..8), `cell.y` is the column (0..6)
  (`board_model.gd`). **Sunbeam and Starfall** light one **column** (9 cells — a beam down
  the board); **Rain** drifts across one **row** (7 cells — a cloud crossing). The lane
  index is the hour's salted roll over the axis' range.
- **Landscape transposes the display, not the model** (`_disp_cols`/`_cell_pos`) — the
  patch is drawn from `_cell_pos` + cell size like every cell, so it transposes for free.
  Player-facing copy stays portrait-voiced ("a beam down the board").
- **The wash covers the whole lane**, locked/bramble cells included — it is light, not
  state. Gifts only ever fire from merges, and merges only happen on open cells, so no
  per-cell gating exists anywhere.
- **"In the patch" has one meaning:** the merge's *produced piece lands on the lane* (the
  landing cell of `_commit_merge`). One pure predicate — `Sky.in_patch(state, cell)` —
  shared by the board and the sim. Aiming the result *into* the light is the player's
  micro-skill.
- **Improvements overlap** (parent §6 law, restated): a built cell inside the patch enjoys
  both effects independently; there is no same-type overlap to reason about.

---

## 4 · Sunbeam and Rain — the gift merges

Baseline today, which stays exactly as-is off-patch and under every other sky: a merge
rolls a **c1 coin drop at `COIN_DROP_RATE` 0.10** and a **chest/water/acorn special at
`SPECIAL_DROP_RATE` 0.02** (`board.gd` `_after_merge` → `BoardLogic`), each landing only if
a free cell exists (`pick_drop_cell` returns its no-cell sentinel on a crowded board — the
drop silently no-ops; shipped behavior, unchanged).

| In the patch… | The roll | The drop |
|---|---|---|
| **Sunbeam** | the coin roll runs at `SKY_COIN_RATE` 0.35 *(replaces the 0.10)* | and the coin lands as **c2** (worth 4, one cell) |
| **Rain** | **one extra, independent roll** at `SKY_WATER_RATE` 0.35 *(the baseline coin + special rolls stay untouched)* | a **water special t1** — tap-collect +8 water, banking **over the cap** (the shipped over-cap path) |

- The parent's "rate and count up" ships as the **c1 → c2 upgrade**, not as two pieces:
  drops compete for free cells, and one richer coin beats two clutter pieces on the crowded
  boards where Sunbeam should feel best. (`SKY_COIN_TIER` stays a dial.)
- Water is already first-class (cap 100, +1 per 2 min offline-inclusive regen, pops cost
  1) — Rain tops up the pop budget in sips. The stall's daily **free rain** (full-can
  refill via `Claims "refill_water"`) is a different faucet with a different name and is
  untouched; the sky gives sips, the stall gives the can.
- **The soil contract (dormant until Improvements ship):** while Rain holds, a growing soil
  cell *inside the patch* fires its once-per-growth watering for free — automatically, on
  starting growth in the patch or on the patch arriving over it. Nothing else about soil is
  this spec's business; the hook ships inert if weather lands before step 4.
- Starfall hours grant **no per-merge bonus** — that sky's whole gift is the star (§5).

---

## 5 · Starfall — the owed star

All state lives in one grove-blob sub-dict (§8). The machine:

1. **Arm.** The home board is open during a Starfall hour, the §2 gate is open, and
   `hour > sky.paid_hour`.
2. **Trigger.** The board has been live ≥ `STAR_DELAY` 10 s inside this hour (the banner
   has spoken), no modal is open, the input gate `animating` is false, and the live sky
   reads Starfall (the win-back minute defers, mid-hour entry still pays). On trigger,
   stamp `sky.paid_hour = hour` **at roll time** — a restart never re-rolls a paid hour.
3. **Roll** (hour-salted RNG, never `board.rng`): pick a line uniformly from the **Active
   set** — `G.active_lines(level)` plus the ingredient lines of live asks
   (`G.quest_needed_lines`), real content lines only (every content line spans t1–t12, so
   the tier menu below is always valid). From that line's menu **{t8 80 · t9 15 · t10 5}**,
   remove every (line, tier) an active quest asks *right now* —
   `BoardLogic.asked_items(quests)`, the `quests.gd` avoid-set idiom promoted to a pure
   helper — renormalize, pick. A line with an empty menu is dropped and the line pick
   repeats; if every line is exhausted, the tier menu steps down (t7, then t6, … —
   single-tier menus, uniform line pick); if even t1 yields nothing (theoretical), the hour
   pays nothing — the sky never blocks.
4. **Land.** Prefer a free open cell **on the lane** (RNG pick among them); else
   `pick_drop_cell` from the lane's centre; if the board is truly full, the star goes
   **owed** — `sky.owed.append(code)` — and lands on the first `_after_board_change` with a
   free cell, any hour, any sky, surviving restarts. Owed stars queue (rare). The HUD chip
   wears a small star pip while one is owed.
5. **Landed, the piece is ordinary in every way** — it merges, sells, and delivers to a
   *later* ask. The skip rule only stops the sky from finishing a *current* ask outright
   (parent law: a sky must never complete a top ask).

- **Only witnessed hours pay.** Offline Starfall hours never accrue and never pay
  retroactively — the sky gives to whoever is standing in the grove.
- **Faucet honesty.** Generators still cannot pop above the `TIER_ODDS` band — the pinned
  economy guard and its test stay untouched. The star is a **new, deliberately bounded
  faucet**: ≤1 piece, ~10% of hours, witnessed hours only. It is also sellable (it is
  ordinary), so the sim prices its full injection (§10).

---

## 6 · UI

**The banner.** A full-width cut-paper strip slides down under the HUD and self-dismisses
in ~`BANNER_SECS` 2.5 s: sky icon · name · one line (*"Rain — merges shake water
loose."*). Build: the unlock bar's deckle-surface recipe (`unlock_bar.gd`), mounted as a
**free-floating child of `Grove`** — never a `_stack` row, which would reflow and shrink
the board — anchored at `Look.safe_top + Hud.bottom_px()`, animated on `offset_top`, timed
dismiss via the `login_mystery.gd` create-timer idiom. Plays on board entry (deferred tail,
with the `_maybe_offer_retirement` calm-moment guards: in-tree, no modal open, never over
the FTUE) and once more on each hour turn. Z is a **named constant** in the 40–100 band
(above `HUD_WALLET_Z` 40, far below `HAND_HINT_Z` 500) — the layering suite scans bare
`z_index` literals.

**The chip.** A small sky icon sits by the top info bar all hour (mounted from `Hud.build`'s
cluster); tapping it replays the banner line. It carries the §5 owed-star pip.

**The patch.** A soft-edged, low-alpha wash on the lane, under the pieces: a warm shaft for
Sunbeam, a cool drift with sparse drawn droplets for Rain, a faint glimmer for Starfall.
Implementation is a **self-drawing Control** — the `gen_sparkle.gd` guidance is
load-bearing: particles do not render reliably under Control parents — breathing on a slow
looping tween (no `_process`). It mounts into `board_area` **right after the slot block at
z 0** (resting pieces are z 0 too; any positive z would ride above them — the
`_open_bramble` `move_child` comment is the canonical insert), gets re-inserted by
`_rebuild_all()` (which frees every child, often), and re-derives its rect from
`_cell_pos` + cell size on reflow and orientation flips. Every color is a palette role with
alpha — `Color(Pal.…, α)` — because the palette SSOT suite fails re-typed hex.

**The sky turn, mid-session.** The board's 1 Hz `tick` Timer gains a sibling handler: when
the cached hour index changes — cross-fade the `WeatherLayer` (the `debug_refresh_weather`
rebuild-in-place), move the patch, play the banner once, re-arm §5.

**The star.** The piece arcs in from above the lane's top edge with
`MoveFx.apply(…, "arc")` + its trail knob (the shipped comet — control point lifted, eased
into the landing), then the standard `LandFx` + neighbour ripple of the
`_drop_special_near` recipe.

**Copy & art.** Strings under a new `board.sky.*` subtree in `games/grove/strings.json`,
read via `Strings.t` — engine code cannot hardcode `res://games/` (the layering suite
enforces it). Three small sky icons (sun · raincloud · star) go through the art-intake
pipeline (`docs/design/art-style-guide.md`); until intake lands, the chip and banner draw
code glyphs.

**Debug.** The shipped Weather debug action stays the lever; `WEATHER_DEBUG_STATES` maps
old and new: `clear`/`breeze` force Sunbeam in that skin, `rain`/`snow` force Rain in that
skin (so `shot_base.gd`'s forced `"rain"` still forces the same rainy look), and a new
`star` forces Starfall. Forcing a sky forces its gifts — that is the manual test lever.

---

## 7 · Economy guards (cross-cutting laws)

- **Weather never punishes** — every effect is strictly additive; no sky raises a cost,
  blocks an action, or worsens a roll.
- **The clock is quests only** — sky coins and water land via `Save.add_coins` /
  `Save.add_water`, never `G.earn_coins` (the sim's Y invariant).
- **A sky never completes a top ask outright** — the §5 skip rule, applied at roll time.
- **Water gifts respect the water-gift ratio** (`WATER_REWARD_MAX_RATIO` 0.3 — the I2
  tripwire). I2 is already RED on maps 3–4 (`docs/BACKLOG.md`), so the re-pass judges the
  **delta against the shipped baseline**, not the absolute.
- **The star is the only high-tier faucet**, bounded by §5; the generator pop-ceiling
  guard and its pinned test stay untouched.
- **No draw ever comes from `board.rng`.** The board stream is seeded, persisted, and
  order-load-bearing; the sky rolls on its own hour-seeded RNG, and a byte-identity test
  pins the board stream with the sky live (§10).

---

## 8 · Data, persistence, determinism

- The hour's `{sky, skin, lane}` is **derived, never stored** — a pure function of the
  hour index, recomputable anywhere (board, map, sim, tests).
- One grove-blob sub-dict, defaulted on read, no schema bump (the `vault()` /
  `bag_slots()` pattern): `g["sky"] = {"paid_hour": -1, "owed": []}` — `paid_hour` int
  (monotonic pay guard), `owed` an array of item codes. Persisted through the existing
  `_persist()` beat. Nothing else is stored.

---

## 9 · Architecture (per-file; ● = new)

- ● `engine/scripts/core/sky.gd` — pure statics, no scene deps: `hour_index(now)`,
  `state(now, forced := "") → {sky, skin, lane_axis, lane}`, `in_patch(state, cell)`,
  `star_pick(hour, actives, asked) → code | 0`, `gate_open()`. Everything
  headless-testable in isolation.
- `engine/scripts/core/board_logic.gd` — ➊ `asked_items(quests) → Dictionary` (pure
  avoid-set); ➋ the merge-drop rolls **lift out of the scene** into one pure
  `roll_merge_drops(produced, rng, sky_state, in_patch) → Array[code]` that `board.gd`
  *and* `grove_sim` both call — retiring the sim's inline re-implementation and its
  silent-divergence risk.
- `games/grove/grove_data.gd` + `content.gd` re-exports (the `COIN_DROP_RATE` pattern) —
  every §11 dial. Probabilities are game data; `Tune.Ambient` keeps look dials only, and
  its three roll thresholds retire into the sky shares.
- `engine/scripts/ui/ambient.gd` — `weather_now()` delegates to `Sky.state` for the skin
  (map + shot callers unchanged); `build_weather` gains the `starlit` kind (within the ≤2
  emitters / ≤80 particles budget); the debug cycle grows per §6; win-back forces the Rain
  sky.
- ● `engine/scripts/ui/sky_banner.gd` · ● `engine/scripts/ui/sky_patch.gd` — §6.
- `engine/scripts/ui/hud.gd` — the sky chip + owed pip in the cluster.
- `engine/scripts/scenes/board.gd` — the wiring only: entry banner in the deferred tail;
  hour-turn check beside `_tick_water`; patch insert in `_rebuild_all` + reflow; gift rolls
  in `_after_merge` via ➋; §5 trigger + owed landing in `_after_board_change`; the star
  drop through the `_drop_special_near` path generalized to any code, with `"arc"`.
- `engine/scripts/core/features.gd` — `"weather_hours"` (Rule N4) + its `docs/FEATURES.md`
  line.
- `games/grove/strings.json` — the `board.sky.*` subtree.
- `games/grove/tools/grove_sim.gd` — §10's sim work.

---

## 10 · Testing & the sim re-pass

- **Pure (engine suite — runs in `make test-fast`).** ● `engine/tests/sky_tests.gd`: same
  hour → identical `{sky, skin, lane}` (determinism); shares flip at the exact thresholds;
  lane stays in range per axis; `in_patch` row/column truth table; `star_pick` skips asked
  pairs, renormalizes, steps the menu down, and returns 0 on a fully-asked candidate space;
  the gate; owed-queue order; `asked_items` shape; `roll_merge_drops` in/out-patch × three
  skies, including Rain's both-drops hour.
- **Byte-identity pin.** With the sky live, the board RNG stream is untouched — the
  `mechanics_tests` no-extra-draws precedent extended to weather.
- **Scene suite.** ● `games/grove/tests/grove_sky_tests.gd`, registered in the Makefile's
  `GROVE_TESTS` and CLAUDE.md's suite line, `.uid` generated via `make import` before
  commit: the banner mounts on entry and self-dismisses; the chip exists and replays; the
  patch node sits after the slot block, survives `_rebuild_all` and an orientation flip
  (geometry via `is_equal_approx` — Control geometry is float32); a forced-`star` hour
  lands a real model piece (model asserts, not visibility — headless); the win-back minute
  forces Rain then hands back; an open modal defers the star trigger.
- **Screenshots.** The shot tools already force weather (`shot_base.gd`); add the three
  skies + patch to the shot set for human eyes.
- **The sim re-pass (gates the merge).** `grove_sim` models skies across its sessions
  (hours derived from session time), adopts ➋, and adds the star injection — expected
  value ≈ share × (0.80·2⁷ + 0.15·2⁸ + 0.05·2⁹) ≈ **17 t1-eq per witnessed hour** at the
  §11 dials, plus its coin value when sold. Run a **multi-seed sweep** (≥8 seeds × 7
  days) — single-seed diffs conflate the change with RNG drift — and compare I2 · Y · Z
  and the coin/water faucet totals against the shipped baseline. Finals overwrite §11.

---

## 11 · Dials (all PROVISIONAL — the sim re-pass owns finals)

| Dial | Value | Meaning |
|---|---|---|
| `SKY_SHARES` | 45 · 45 · 10 | Sunbeam · Rain · Starfall share of hours |
| `SKY_SKIN_SPLIT` | 70/30 · 85/15 | clear/breeze inside Sunbeam · rain/snow inside Rain |
| `SKY_COIN_RATE` | 0.35 | in-patch coin-drop chance (baseline 0.10) |
| `SKY_COIN_TIER` | 2 | in-patch coins land as c2 (worth 4) |
| `SKY_WATER_RATE` | 0.35 | in-patch extra water roll (t1 water = +8, over-cap) |
| `STAR_TIER_WEIGHTS` | 80 · 15 · 5 | t8 · t9 · t10 |
| `STAR_DELAY` | 10 s | live-board seconds before the star falls |
| `BANNER_SECS` | 2.5 | banner self-dismiss |
| `PATCH_ALPHA` | 0.10–0.15 | lane wash alpha per sky (art pass) |
| `RAIN_VEIL` alpha | (existing) | now an explicit art dial — rain-family hours ×4.5 |

---

## 12 · Out of scope

Festival sky, Magnet/Mirror skies, the Wild piece (parent §9 — parked/cut). Soil execution
(step 4; only §4's dormant contract is ours). Map-side gifts (cosmetics only). Rush,
entirely. The water stall's free-rain flow. Retuning baseline drop rates off-patch.

---

## 13 · Open questions for Dev review

1. **Sky shares.** 45/45/10 makes rain-family *looks* ~45% of hours (~10% today). Fine, or
   tilt sunnier — e.g. 50/35/15 — accepting fewer water-gift hours?
2. **Sunbeam's "count up"** ships as the c1→c2 upgrade (one cell, double value) rather
   than two c1 pieces — confirm the reading of the parent line.
3. **Starfall halves:** only witnessed hours pay (no offline accrual), and an unlandable
   star goes owed instead of forfeit — confirm both.
4. **The gate** (both FTUE verbs seen, then weather begins) — earlier or later? The
   parent left the analogous soil beat at ~L6 open too.
