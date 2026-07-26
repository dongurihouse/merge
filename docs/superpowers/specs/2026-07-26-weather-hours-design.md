# Weather Hours — spec (2026-07-26)

**Status: draft 3, for Dev review.** Builds §4 / rollout step 5 of
`2026-07-26-progression-systems-design.md`. Code anchors: `engine/scripts/ui/ambient.gd`,
`engine/scripts/core/board_logic.gd`, `engine/scripts/core/content.gd`,
`games/grove/tools/grove_sim.gd`.

All numbers **PROVISIONAL** — the grove_sim re-pass (§10) owns finals.

---

## 1 · Scope

Ships: the hourly sky (3 skies), one lane patch, Sunbeam/Rain merge gifts, the starfall
drop, banner + HUD chip + patch rendering, debug lever, tests, sim re-pass. Removes the
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
  skins render; no banner, chip, patch, gifts, or star. The cosmetic `ambient_weather`
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
  **column** (9 cells); Rain one **row** (7 cells). Lane index = salted hour roll over the
  axis range. Fixed for the hour; moves with the next sky.
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
| **Rain** | extra independent roll at `SKY_WATER_RATE` 0.35; baseline rolls untouched | **water special t1** (+8 on tap, banks over cap) |

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
   HUD chip shows a star pip while owed.
5. Landed, the piece is ordinary — merges, sells, delivers to later asks. The skip rule
   only blocks asks live at roll time.

- Offline Starfall hours never pay.
- The generator pop-ceiling guard stays untouched. The star is the only high-tier faucet:
  ≤1 piece, ~10% of hours, witnessed hours only, sellable — the sim prices it (§10).

---

## 6 · UI

- **Banner:** full-width cut-paper strip under the HUD (unlock-bar deckle recipe): sky
  icon · name · one line. Lines (`board.sky.*`): Sunbeam *"Sunbeam — merges in the beam
  drop coins."* · Rain *"Rain — merges shake water loose."* · Starfall *"Starfall — a
  star is on its way."* Slides down on
  `offset_top`, self-dismisses after `BANNER_SECS` 2.5 (`create_timer` idiom). Mounted as
  a free-floating child of `Grove` — never a `_stack` row (reflows the board). Anchored at
  `Look.safe_top + Hud.bottom_px()`. Plays on board entry (deferred tail;
  `_maybe_offer_retirement` guards: in-tree, no modal, not over FTUE) and on each hour
  turn. Z: named constant in the 40–100 band.
- **Chip:** sky icon by the top info bar (`Hud.build` cluster); tap replays the banner
  line; carries the owed-star pip.
- **Patch:** soft-edged low-alpha wash under pieces; warm shaft (Sunbeam), cool drift +
  drawn droplets (Rain), faint glimmer (Starfall). A self-drawing Control — particles are
  unreliable under Control parents (`gen_sparkle.gd` rule). Slow breathe via looping
  tween; no `_process`. Mounts in `board_area` right after the slot block at z 0 (pieces
  are z 0; positive z would cover them). Re-inserted on `_rebuild_all`; rect re-derived
  from `_cell_pos` + cell size on reflow/orientation change. Colors — Meadow Sky roles at
  `PATCH_ALPHA` via `Color(Pal.X, α)` (SSOT suite forbids typed hex): Sunbeam = reward
  gold; Rain = receding blue, plus sparse sky-blue droplet ticks; Starfall = warm cream
  with gold star glints.
- **Hour turn:** handler beside `_tick_water` on the 1 Hz tick. On hour change: rebuild
  `WeatherLayer` (`debug_refresh_weather` pattern), move the patch, play the banner,
  re-arm §5.
- **Star FX:** `MoveFx.apply(…, "arc")` + trail from above the lane's top edge; then the
  `_drop_special_near` landing recipe (`LandFx` + neighbour ripple).
- **Strings:** `board.sky.*` in `games/grove/strings.json` via `Strings.t` (engine cannot
  reference `res://games/`).
- **Art:** star chip reuses `ui/shared/icon_star.png`; new sun + raincloud glyphs via the
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
  `state(now, forced := "") → {sky, skin, lane_axis, lane}`, `in_patch(state, cell)`,
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
- ● `engine/scripts/ui/sky_banner.gd` · ● `engine/scripts/ui/sky_patch.gd` — §6.
- `engine/scripts/ui/hud.gd` — chip + owed pip.
- `engine/scripts/scenes/board.gd` — entry banner in the deferred tail; hour check beside
  `_tick_water`; patch insert in `_rebuild_all` + reflow; gifts in `_after_merge` via ➋;
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
- **Scene suite** — ● `games/grove/tests/grove_sky_tests.gd` (+ `GROVE_TESTS` in the
  Makefile, + CLAUDE.md suite line, + `make import` for the `.uid`): banner mounts on
  entry and self-dismisses; chip replays; patch sits after the slot block and survives
  `_rebuild_all` + orientation flip (`is_equal_approx` — Control geometry is float32);
  forced `star` hour lands a real model piece (model asserts, not visibility); ≥48 h-away
  load fills water by plain regen, no forced sky, no toast, stale `winback_until` ignored;
  open modal defers the star.
- **Shots:** add the three skies + patch to the shot set (`shot_base.gd` already forces
  weather).
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
| `SKY_WATER_RATE` | 0.35 | in-patch water roll (t1 = +8, over-cap) |
| `STAR_TIER_WEIGHTS` | 80 · 15 · 5 | t8 · t9 · t10 |
| `STAR_DELAY` | 10 s | live seconds before the star falls |
| `BANNER_SECS` | 2.5 | banner self-dismiss |
| `PATCH_ALPHA` | Rain · Star 0.10–0.15; Sunbeam ~0.30 | gold-on-cream needs ~0.30 + same-hue edge deepening to read (mock-validated) |
| `RAIN_VEIL` alpha | existing | art dial — rain-family hours ×4.5 |

---

## 12 · Open questions

1. Sky shares 45/45/10 → rain-family looks ~45% of hours (vs ~10%). Keep, or tilt sunnier
   (e.g. 50/35/15)?
2. Sunbeam "count up" = c1→c2 upgrade, not two pieces — confirm.
3. Starfall: witnessed hours only, owed instead of forfeit — confirm.
4. Gate = both FTUE verbs seen — earlier/later?
