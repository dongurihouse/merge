# Weather Hours — spec (2026-07-26)

**Status: draft 6 — dials set from the sim re-pass and a measured patch calibration.**
Builds §4 / rollout step 5 of
`2026-07-26-progression-systems-design.md`. Code anchors: `engine/scripts/ui/ambient.gd`,
`engine/scripts/core/board_logic.gd`, `engine/scripts/core/content.gd`,
`games/grove/tools/grove_sim.gd`.

Dials are **sim-set** as of draft 6 (§7 water runaway, §11 table); the §10 sweep is the
gate for any further change.

---

## 1 · Scope

Ships: the hourly sky (3 skies), one lane patch, Sunbeam/Rain merge gifts, the starfall
drop, lane marker + info-bar line + patch rendering, debug lever, tests, sim re-pass.
Removes the
win-back rain beat (§2).

Home board only. Rush: untouched (separate scene, no coupling). Map: cosmetic skins only —
no gifts, no patch.

Excluded: soil execution (§4 defines only Rain's dormant hook), festival sky,
magnet/mirror skies, Wild piece, the water stall's daily free rain.

---

## 2 · Clock and roll

- Hour index: `int(unix_time / Tune.SECS_PER_HOUR)`. Deterministic, offline-correct, no
  server. No per-player salt — every player shares the hour's sky.
- **Upgrades the shipped roll in `Ambient.weather_now()`; not a second roll.**
  `hash(hour)` → sky; salted re-hashes (`hash(hour * K + SALT_*)`) → skin, lane.
- The four shipped cosmetic states become skins, riding the existing `WeatherLayer`:

| Sky (share) | Skins | Gift |
|---|---|---|
| **Sunbeam** (45) | clear 70 · breeze 30 | in-patch coin drops up (§4) |
| **Rain** (45) | rain 85 · snow 15 | in-patch water drops; in-patch soil waters free (§4) |
| **Starfall** (10) | starlit (new) | one high-tier piece falls on the lane (§5) |

- Gate: `Save.ftue_seen("merge") and Save.ftue_seen("gen_tap")`, and
  `Features.on("weather_hours")` (new flag + `docs/FEATURES.md` line). Below the gate:
  skins render; no marker, patch, gifts, or star. The cosmetic `ambient_weather`
  flag never gates gifts.
- Clock skew: accepted. `paid_hour` is monotonic (no backward re-pay); forward = waiting.
- **Win-back removal.** Delete: `Ambient.check_winback` / `winback_active` and their
  `weather_now()` override; the board full-can grant + `board.winback.rained` toast; the
  map stamp; the `winback_rain_beat` flag + `docs/FEATURES.md` line; `WINBACK_HOURS`,
  `WINBACK_RAIN_SECS`; `board.winback.*` strings; `last_seen` writes (no reader remains).
  Economy-neutral: offline regen (+1 / 2 min, capped) fills the can after ~3⅓ h away.
  Stale `winback_until` / `last_seen` save keys stay unread.
- Look consequence: rain-family visuals go ~10% → ~45% of hours; `RAIN_VEIL` alpha becomes
  an art dial (Q1).

---

## 3 · Patch

- Model space (`cell.x` = row 0..8, `cell.y` = col 0..6): Sunbeam and Starfall project one
  **column** (9 cells); Rain one **row** (7 cells). Fixed for the hour; moves with the next
  sky.
- **Lane roll — playable lanes only.** The salted hour roll picks uniformly among lanes
  holding **≥ `LANE_MIN_OPEN` (5) open cells** at the player's current level, not over the
  whole axis range. A uniform roll makes early hours dead: at level 2 only 5 of 7 columns
  and 5 of 9 rows contain any open cell at all, so **36% of hours land a lane with zero
  open cells** — no merge can happen there, so the sky gives nothing in the hours right
  after the FTUE gate opens. Openness comes from `G.MIN_LEVEL` vs the player's level (not
  live board occupancy), so the lane is stable for the whole hour and identical in the sim.
  If no lane clears the bar (very early boards), fall back to the lane with the **most**
  open cells, ties broken by the roll — the sky always projects somewhere.
- Lane openness changes only on level-up, so the lane may shift mid-hour when the player
  levels; that is the one allowed mid-hour move, and it moves patch + marker together.
- Landscape transposes display only (via `_cell_pos`); the model lane is unchanged.
- The wash draws over the whole lane, locked cells included. No per-cell gating: gifts
  fire only from merges, and merges happen only on open cells.
- **In-patch = the merge's produced piece lands on a lane cell** (the landing cell of
  `_commit_merge`). One predicate `Sky.in_patch(state, cell)`, used by board and sim.
- An improvement cell in the patch gets both effects independently (parent §6).

---

## 4 · Sunbeam and Rain

Baseline, unchanged off-patch and under every other sky: merge rolls c1 coin at
`COIN_DROP_RATE` 0.10 and a special at `SPECIAL_DROP_RATE` 0.02; a drop without a free
cell no-ops (`pick_drop_cell` sentinel).

| In-patch | Roll | Drop |
|---|---|---|
| **Sunbeam** | coin roll at `SKY_COIN_RATE` 0.35 (replaces 0.10) | coin lands as **c2** (worth 4) |
| **Rain** | extra independent roll at `SKY_WATER_RATE` 0.15; baseline rolls untouched | **water special t1** (+8 on tap, banks over cap) |

- c2 upgrade instead of two c1 pieces: one cell, same value (Q2).
- Soil hook, dormant until step 4: a growing soil cell in-patch during Rain fires its
  once-per-growth watering free.
- Starfall hours: no per-merge bonus.

---

## 5 · Starfall

State in `Save.grove().sky`.

1. **Arm:** home board open, Starfall hour, gate open, `hour > sky.paid_hour`.
2. **Trigger:** board live ≥ `STAR_DELAY` 10 s this hour, no modal open, `animating`
   false, live sky = Starfall. Stamp `sky.paid_hour = hour` at roll time — restarts never
   re-roll a paid hour.
3. **Roll** (hour-salted RNG, never `board.rng`): line uniform from the Active set —
   `G.active_lines(level)` + ingredient lines of live asks (`G.quest_needed_lines`),
   content lines only (all span t1–t12). Tier menu {t8 80 · t9 15 · t10 5} minus every
   (line, tier) currently asked (`BoardLogic.asked_items`, new pure helper from the
   `quests.gd` avoid-set idiom); renormalize. Empty line menu → drop line, repick. All
   lines empty → step the menu down (t7, t6, … single tier, uniform line). Nothing at
   t1 → the hour pays nothing.
4. **Land:** free open cell on the lane (RNG pick); else `pick_drop_cell` from lane
   centre; board full → **owed**: `sky.owed.append(code)`, lands on the first
   `_after_board_change` with a free cell, any hour, persists across restarts, queues.
   The lane marker shows a star pip while owed.
5. Landed, the piece is ordinary — merges, sells, delivers to later asks. The skip rule
   only blocks asks live at roll time.

- Offline Starfall hours never pay.
- The generator pop-ceiling guard stays untouched. The star is the only high-tier faucet:
  ≤1 piece, ~10% of hours, witnessed hours only, sellable — the sim prices it (§10).

---

## 6 · UI

Mocks (composition authority — geometry, tint strength, marker placement, info-bar line):
`docs/design/mocks/weather_hours/sunbeam.png` (top marker, column wash) ·
`rain.png` (left marker, row wash) · `starfall_star_and_column.png` (falling star + trail;
its banner/chip predate §6's marker — read it for the star only).

- **Lane marker (the only chrome — no banner, no HUD chip):** a small sky glyph on a
  cream chip (~half a cell), outside the board mat, aligned to the lane: column skies
  (Sunbeam, Starfall) sit centered above the lane column at the mat's top edge; Rain sits
  left of the lane row at the mat's left edge. Mounted beside `board_area`, positioned
  from `_cell_pos` (transposes with the board); `FX.pop_in` on entry and on hour turn;
  carries the owed-star pip (§5). Rebuilt with the patch on `_rebuild_all` / reflow.
- **Info bar:** tapping the marker sets the bottom info bar to glyph + line
  (`board.sky.*`): Sunbeam *"Sunbeam — merges in the beam drop coins."* · Rain *"Rain —
  merges shake water loose."* · Starfall *"Starfall — a star is on its way."* The next
  selection replaces it (existing info-bar behavior). No auto-announcement anywhere.
- **Patch:** soft-edged low-alpha wash under pieces; warm shaft (Sunbeam), cool drift +
  drawn droplets (Rain), faint glimmer (Starfall). A self-drawing Control — particles are
  unreliable under Control parents (`gen_sparkle.gd` rule). Slow breathe via looping
  tween; no `_process`. Mounts in `board_area` right after the slot block at z 0 (pieces
  are z 0; positive z would cover them). Re-inserted on `_rebuild_all`; rect re-derived
  from `_cell_pos` + cell size on reflow/orientation change. Colors — Meadow Sky roles at
  `PATCH_ALPHA` via `Color(Pal.X, α)` (SSOT suite forbids typed hex): Sunbeam = reward
  gold; Rain = receding blue, plus sparse sky-blue droplet ticks; Starfall = warm cream
  with gold star glints.
- **Measuring the wash — use warm shift (R−B), never luma.** Sunbeam needs α 0.55 where
  Rain reads at 0.13, because straw on the locked brown cells that dominate an early board
  *brightens*, while the same straw on cream cells *darkens*. The sign of a luma delta
  flips with the surface underneath, so a luma target does not carry between a mock and a
  capture, or between an early board and a late one. Measure `R−B` on the lane against its
  neighbours instead; it is signed the same way on both surfaces. (This cost a wrong
  calibration target: a max-luma rule picked the mock's brightest column, which was empty
  cream board, not its beam — the mock's actual beam is its *darkest* column.) Judge the
  final value by eye on a real capture as well: the lane should read as a warm column with
  the cell art under it still fully legible.
- **Hour turn:** handler beside `_tick_water` on the 1 Hz tick. On hour change: rebuild
  `WeatherLayer` (`debug_refresh_weather` pattern), move the patch + marker, re-arm §5.
- **Star FX:** `MoveFx.apply(…, "arc")` + trail from above the lane's top edge; then the
  `_drop_special_near` landing recipe (`LandFx` + neighbour ripple).
- **Strings:** `board.sky.*` in `games/grove/strings.json` via `Strings.t` (engine cannot
  reference `res://games/`).
- **Art:** the star marker reuses `ui/shared/icon_star.png`; new sun + raincloud glyphs via the
  art-intake pipeline (the sky raincloud stays distinct from the stall's watering-can
  `icon_rain`); code glyphs until intake lands.
- **Debug:** `WEATHER_DEBUG_STATES` — `clear`/`breeze` force Sunbeam in that skin,
  `rain`/`snow` force Rain in that skin, new `star` forces Starfall. Forcing a sky forces
  its gifts. `shot_base.gd`'s forced `"rain"` keeps working.

---

## 7 · Economy guards

- Weather only gives — no sky raises a cost, blocks an action, or worsens a roll.
- Sky coins/water land via `Save.add_coins` / `Save.add_water`, never `G.earn_coins`
  (Y invariant: the clock is quests only).
- A sky never completes a live ask (§5 skip rule).
- Water gifts respect `WATER_REWARD_MAX_RATIO` 0.3 (I2). I2 is already RED on maps 3–4
  (`docs/BACKLOG.md`) — judge the delta, not the absolute.
- **The water faucet runs away above `SKY_WATER_RATE` ≈ 0.2 — measured, keep it below.**
  Sky water buys pops, pops make merges, merges land in-patch and make more sky water. The
  loop is superlinear: cutting the rate 0.35 → 0.15 (2.3×) cut sky water 7–12×. Measured
  over 4 seeds × 7 days, sky water as a share of total water spend, against a no-weather
  control run:

  | rate | sky water share of spend | water self-sustain | total spend |
  |---|---|---|---|
  | control (no weather) | — | 52–58% | 3259–3553 |
  | 0.35 | 16.7–46.5% | 70–88% | 4305–7744 |
  | **0.15 (shipped)** | **5.3–8.1%** | **59–67%** | **3433–3919** |
  | 0.10 | 4.4–5.5% | 59–62% | 3259–4075 |

  At 0.35 water stops being the pacing constraint and total throughput roughly doubles. At
  0.15 the gift is felt and the economy sits near control. Any future change to
  `SKY_WATER_RATE`, in-patch geometry, or lane width re-opens this loop — re-run the sweep.
- **The two sky rates are deliberately asymmetric.** `SKY_COIN_RATE` stays 0.35 while
  `SKY_WATER_RATE` is 0.15: at equal rates sky coins measured only 2.3–5.8% of the coin
  faucet against water's 17–47%, because the coin economy is large and the water economy is
  small. Equal rates are not equal generosity — tune each against its own faucet.
- The star is the only high-tier faucet, bounded per §5.
- No draw from `board.rng` — hour-seeded RNG only; byte-identity test pins the board
  stream (§10).

---

## 8 · Data

- `{sky, skin, lane}` is derived from the hour index, never stored.
- `g["sky"] = {"paid_hour": -1, "owed": []}` in the grove blob — defaulted on read, no
  schema bump, persisted via the existing `_persist()`.

---

## 9 · Architecture (● = new)

- ● `engine/scripts/core/sky.gd` — pure statics: `hour_index(now)`,
  `state(now, level, forced := "") → {hour, sky, skin, lane_axis, lane}` — `level` drives
  the §3 playable-lane roll, so every caller (board, sim, tests) passes it —
  `in_patch(state, cell)`,
  `star_pick(hour, actives, asked) → code | 0`, `gate_open()`.
- `engine/scripts/core/board_logic.gd` — ➊ `asked_items(quests)`; ➋ merge-drop rolls
  lifted out of the scene into pure
  `roll_merge_drops(produced, rng, sky_state, in_patch) → Array[code]`, called by
  `board.gd` **and** `grove_sim` (retires the sim's inline copy).
- `games/grove/grove_data.gd` + `content.gd` re-exports — the §11 dials. `Tune.Ambient`
  keeps look dials only; its three roll thresholds retire.
- `engine/scripts/ui/ambient.gd` — `weather_now()` delegates to `Sky.state` (map + shot
  callers unchanged); `build_weather` gains `starlit` (≤2 emitters / ≤80 particles);
  debug cycle per §6; `check_winback` / `winback_active` deleted (§2).
- ● `engine/scripts/ui/sky_patch.gd` — §6: the lane wash + the lane marker (tap → info
  bar).
- `engine/scripts/scenes/board.gd` — hour check beside
  `_tick_water`; patch + marker insert in `_rebuild_all` + reflow; gifts in `_after_merge` via ➋;
  §5 trigger + owed landing in `_after_board_change`; star drop via `_drop_special_near`
  generalized to any code, with `"arc"`. Win-back grant, `_winback` toast, `last_seen`
  write deleted (§2).
- `engine/scripts/scenes/map.gd` — win-back stamp + `last_seen` write deleted (§2).
- `engine/scripts/core/features.gd` — `"weather_hours"` + `docs/FEATURES.md` line;
  `winback_rain_beat` removed.
- `games/grove/strings.json` — `board.sky.*` added; `board.winback.*` removed.
- `games/grove/tools/grove_sim.gd` — §10.

---

## 10 · Testing and sim re-pass

- **Engine suite (`make test-fast`)** — ● `engine/tests/sky_tests.gd`: hour determinism;
  share boundaries at thresholds; lane in range per axis; `in_patch` truth table;
  `star_pick` skips asked pairs, renormalizes, steps down, returns 0 when exhausted; gate;
  owed-queue order; `asked_items` shape; `roll_merge_drops` in/out-patch × three skies
  incl. Rain's both-drops case.
- **Byte-identity pin:** with the sky live, the board RNG stream is unchanged
  (`mechanics_tests` no-extra-draws precedent).
- **Lane-roll pin (§3):** at every level, the rolled lane holds ≥ `LANE_MIN_OPEN` open
  cells whenever any lane does; sweep ≥200 hours at levels 1/2/6/12/40 and assert **zero**
  dead lanes; the fallback picks the most-open lane when none clears the bar; board and sim
  derive the same lane for the same (hour, level).
- **Scene suite** — ● `games/grove/tests/grove_sky_tests.gd` (+ `GROVE_TESTS` in the
  Makefile, + CLAUDE.md suite line, + `make import` for the `.uid`): the marker sits
  outside the mat aligned to the lane on both axes, and its tap sets the info bar line;
  patch sits after the slot block and survives
  `_rebuild_all` + orientation flip (`is_equal_approx` — Control geometry is float32);
  forced `star` hour lands a real model piece (model asserts, not visibility); ≥48 h-away
  load fills water by plain regen, no forced sky, no toast, stale `winback_until` ignored;
  open modal defers the star.
- **Shots:** add the three skies + patch to the shot set (`shot_base.gd` already forces
  weather).
- **Sim fidelity (three rules the sweep depends on).** The sky roll is a pure function of
  the hour index, so the sim must **offset its starting hour per seed** — otherwise every
  seed replays one weather trajectory and the sweep measures it N times. (First cut walked
  hours 0–20 for every seed: 11 Sunbeam · 10 Rain · **0 Starfall**, reporting a confident
  `stars 0` for a faucet it could never sample — the first Starfall hour is 29.) The sim
  must also **apply the §2 gift gate** the board applies, and **report each sky faucet as a
  share of its own denominator** — a raw drop count reads 6× smaller than the water it
  grants.
- **Sim re-pass (gates the merge):** grove_sim models skies per hour, adopts ➋, adds star
  injection — EV ≈ 166 t1-eq per paid star ≈ 17 per witnessed hour at §11 dials, plus
  sell value. Multi-seed sweep (≥8 seeds × 7 days); compare I2 · Y · Z and coin/water
  faucet totals against baseline. Finals overwrite §11.

---

## 11 · Dials (PROVISIONAL)

| Dial | Value | Meaning |
|---|---|---|
| `SKY_SHARES` | 45 · 45 · 10 | Sunbeam · Rain · Starfall |
| `SKY_SKIN_SPLIT` | 70/30 · 85/15 | clear/breeze in Sunbeam · rain/snow in Rain |
| `SKY_COIN_RATE` | 0.35 | in-patch coin chance (base 0.10) |
| `SKY_COIN_TIER` | 2 | in-patch coin tier (worth 4) |
| `SKY_WATER_RATE` | 0.15 | in-patch water roll (t1 = +8, over-cap) — **sim-set, do not raise past ~0.2** (§7 runaway) |
| `STAR_TIER_WEIGHTS` | 80 · 15 · 5 | t8 · t9 · t10 |
| `STAR_DELAY` | 10 s | live seconds before the star falls |
| `LANE_MIN_OPEN` | 5 | min open cells for a lane to be rollable (§3) |
| `PATCH_ALPHA` | Sunbeam 0.55 · Rain 0.13 · Star 0.12 | Sunbeam needs ~2× the others to read on locked brown cells (§6 measurement note) |
| `RAIN_VEIL` alpha | existing | art dial — rain-family hours ×4.5 |

---

## 12 · Open questions

1. Sky shares 45/45/10 → rain-family looks ~45% of hours (vs ~10%). Keep, or tilt sunnier
   (e.g. 50/35/15)?
2. Sunbeam "count up" = c1→c2 upgrade, not two pieces — confirm.
3. Starfall: witnessed hours only, owed instead of forfeit — confirm.
4. Gate = both FTUE verbs seen — earlier/later?

Build to the spec as written; these are dial questions, not blockers.

---

## 13 · Implementation directions (for the implementing agent)

**Workspace.** Branch `feat/weather-hours` from latest `main` in a NEW worktree outside the
repo: `git worktree add /Users/xup/dh/merge-wt-weather -b feat/weather-hours` (in-repo
worktrees get wiped by other agents). Seed the import cache before the first run:
`rsync -a --delete /Users/xup/dh/merge/.godot/ /Users/xup/dh/merge-wt-weather/.godot/`.
**Do not merge to main and do not remove the worktree** — implementation ends with the
branch committed in place; code review happens in the worktree.

**NO ASSET GENERATION IN THIS TASK.** Do not generate, edit, or import any PNG, texture,
or art file, and do not run the art-intake pipeline. Art is produced separately by the
spec owner. Use placeholders:

- Lane marker glyphs: Starfall loads `ui/shared/icon_star.png` (exists). Sunbeam and Rain
  load `ui/kit/icon_sky_sun.png` / `ui/kit/icon_sky_rain.png`, which do **not** exist yet
  — resolve through the normal icon path, and when the texture is absent fall back to a
  code-drawn glyph (a filled circle with short rays for sun; a rounded cloud blob with two
  droplets for rain) in the §6 palette roles. Absent art must never spam load errors or
  leave an empty marker.
- Patch wash, droplet ticks, star glints, comet trail: all code-drawn — no textures.
- Wire the real icon paths now so dropping the PNGs in later needs no code change.

**Order** — each step lands with `make test-fast` green before the next:

1. Dials in `grove_data.gd` + `content.gd` re-exports (§11); `engine/scripts/core/sky.gd`
   (§9 API) + `engine/tests/sky_tests.gd` covering §10's pure list; register the suite in
   the Makefile's engine list.
2. `BoardLogic.asked_items` + `roll_merge_drops` (§9 ➊➋), lifting the merge-drop rolls out
   of `board.gd:_after_merge` — parity test first (identical drops with no sky), then the
   sky branches. Add the RNG byte-identity test (extend the `mechanics_tests.gd:413`
   pattern).
3. `Ambient` delegation to `Sky.state` + the `starlit` kind + the debug cycle (§6); the
   win-back deletions (§2) with the retirement test.
4. Save state (§8), the §5 starfall machine (trigger, roll, land, owed queue) in
   `board.gd`, star FX via `MoveFx` `"arc"`.
5. `engine/scripts/ui/sky_patch.gd` — wash + lane marker + info-bar tap; board wiring
   (`_rebuild_all` insert, reflow, 1 Hz hour check); `board.sky.*` strings.
6. `grove_sim` adopts ➋ and the star injection; run the §10 battery
   (`godot --headless --path . -s res://games/grove/tools/grove_sim.gd -- 7 <seed>`,
   ≥8 seeds) and include the reports in the handoff.
7. Full `make test` green before handoff.

**Repo rules that bite:**

- Engine code never references `games/` directly (`layering_tests`) — read through `G` /
  `Game.DATA`; new copy goes in `games/grove/strings.json` and is read via `Strings.t`.
- RNG draw order is contractual (`board_logic.gd:120–124`): the sky uses its own
  hour-seeded RNG, and the board stream must stay byte-identical (§7).
- Palette SSOT suite forbids re-typed hex — use `Color(Pal.ROLE, α)`.
- Layering suite forbids bare `z_index` literals above `MODAL_TOP_Z`; the patch sits at
  z 0 inside `board_area` (positive z would cover pieces).
- `_rebuild_all()` frees every `board_area` child — patch and marker must be re-inserted.
- Particles do not render reliably under `Control` parents (`gen_sparkle.gd`) — the patch
  self-draws.
- Fast parse check: `godot --headless --check-only --script <file.gd>`. Suites only via
  `make test-fast` / `make test`; a bare foreground `godot -s` can hang a shell. Run tests
  in the FOREGROUND.
- New `.gd` files: `make import` before committing so `.uid` sidecars exist and are
  committed.
- Control position/size comparisons in tests use `is_equal_approx` (float32).
- Headless: `is_visible_in_tree()` is false for root children; dispatch notifications with
  `obj.notification(what)`.
- Everything ships behind `features.gd` `"weather_hours"`; flag off = byte-identical
  behavior to today.
- Parallel tasks are live in this repo (mastery, cascades, cell improvements). Touch only
  what §9 lists; if a listed file already changed on `main`, rebase rather than revert.
- Commits: small, one per step above, conventional prefixes.
