# UI / Backend Separation

> A phased plan to split `engine/scripts/` into a clean three-layer stack — **core** (backend:
> data, logic, services), **ui** (presentation), **scenes** (the view+controller scene scripts) —
> and to lift the gameplay logic still stranded in the two scene giants (`board.gd`, `map.gd`) down
> into backend modules. The dependency graph is **already one-way** (no backend script imports a UI
> script); this plan makes that layering *explicit, enforced, and complete*.

**Status:** Phases 1–3 **done 2026-06-15** (folder split, pure-logic lift, MIXED-func split — all suites green); next: **Phase 4** (optional: win-back + economy).
Each phase ends **green on the headless suites** (`smoke`, `mechanics_tests`, `grove_tests`,
`save_tests`, `layout_tests`, plus the `layering_tests` guard) — run with `make test`
(suites live in `engine/tests/` + `games/grove/tests/`).

---

## 1 · The invariant

**`core/` never imports `ui/` or `scenes/`.** Imports flow strictly downward
(`scenes → ui → core`). This already holds today (verified by grepping every `preload` edge), so
the split is about *expressing* it, not creating it.

The invariant even **forces** placement: `audio.gd`/`music.gd` are core services that read
`tuning.gd`, so `tuning` must live in `core/` — it cannot drift up to `ui/` without creating a
`core → ui` edge.

**Guard test (add in Phase 1):** a ~15-line headless suite that scans `engine/scripts/core/*.gd`
for any `preload("res://engine/scripts/ui/…")` or `…/scenes/…` and fails if found. Makes the
separation permanent and self-policing.

---

## 2 · Target layout

```
engine/scripts/
  core/    game · features · save · content · board_model · layout · tuning · audio · music
           board_logic.gd   (NEW — board run logic; map progression folded into content.gd)
  ui/      skin · fx · ui_font · hud · shop · ambient · debug
  scenes/  board · map
```

Per-file assignment (the 18 existing files):

| Layer | Files |
|---|---|
| **core/** (9) | `game` `features` `save` `content` `board_model` `layout` `tuning` `audio` `music` |
| **ui/** (7) | `skin` `fx` `ui_font` `hud` `shop` `ambient` `debug` |
| **scenes/** (2) | `board` `map` |

---

## 3 · New backend modules (the extraction)

Both are **stateless static** modules: they take `BoardModel` / `unlocks` / RNG / params and return
**decision data** (codes, cells, success flags, deltas). They touch **no Node/Control and do no Save
writes** — the scene calls Save and animates *after* the backend returns.

### `core/board_logic.gd` — extracted from `board.gd`
The run logic `BoardModel` doesn't own (it owns structural merge/move/swap/brambles/gens already).
- ✅ **Phase 2:** `regen`, `find_mergeable_pair`, `dist_to`, `dist_to_gen`, `bag_capacity`.
- ✅ **Phase 3:** `roll_spawn` + `wanted_lines` (the spawn cell/line/tier RNG decision),
  `rolls_coin_drop`, `quest_payable`. (Map's `chapter_gift` + `variant_by_id` went to `content.gd`.)

### Map progression → folded into `content.gd` (no separate `home_logic.gd`)
`content.gd` already **is** the progression backend (`zone_done`, `cheapest_spot_cost`, `spot_variants`,
`wayside_available`…), so map's pure queries live there next to their siblings, not in a new module.
- ✅ **Phase 2:** `zone_for_id`, `zone_unlocked`, `owned_count`, `zone_stars_left`, `frontier_zone`,
  `is_cheapest_open` (all `(…, unlocks)` statics); map keeps thin wrappers.
- ⏳ **Phase 3:** the command logic of `_on_spot_tap` / `_apply_variant` (validate+spend → result)
  also lands in `content.gd` (or a small home-command helper if it grows).

### Later (Phase 4)
- ambient **win-back** trigger → fold into core (`save`/`content`); leaves `ambient.gd` pure view.
- shop **purchase logic** → `core/economy.gd`; economy *numbers* (coin/cash packs) → `Game.DATA`.

---

## 4 · Phases

### Phase 1 — Folder split (mechanical, no logic change) · 1 session · LOW risk
1. Create `engine/scripts/{core,ui,scenes}/`; `git mv` the 18 files per the table in §2.
2. Sweep every `preload("res://engine/scripts/X.gd")` to its new path. Blast radius:
   - **18 scripts** (intra-engine preloads)
   - **2 scenes**: `engine/scenes/Board.tscn`, `engine/scenes/Map.tscn` (`script` ext_resource paths)
   - **4 tests**: `tests/{grove_tests,layout_tests,mechanics_tests,save_tests}.gd`
   - **6 tools**: `tools/{click_back,click_spot,click_wayside,grove_shot,grove_sim,map_shot}.gd`
3. Add the **guard test** (§1).
4. Verify: all four suites green; guard green. **No behavior change.**

> **✅ Done 2026-06-15.** 18 files → core/(9) · ui/(7) · scenes/(2) + 17 `.uid` companions; 26 files
> swept (0 unlayered refs left); `tests/layering_tests.gd` added. Results: layering **27/0**,
> smoke **OK**, mechanics **34/0**, layout **21/0**, save **26/0**, grove **304/0**. Uncommitted.

> Delivers ~80% of the "clean separation" win on its own, fully reversible and verifiable.

### Phase 2 — Lift the already-clean logic · 1 session · LOW risk
Move the pure, zero-Node funcs into core, scene calls them; behavior-identical.
- board: `_apply_regen`, `_hint_pair` (search core), distance math, `_bag_capacity` → `board_logic`
- map: the progression queries → folded into `content.gd` (see §3)

> **✅ Done 2026-06-15.** `core/board_logic.gd` added (5 funcs); 6 progression queries folded into
> `content.gd`; board.gd + map.gd reduced to thin wrappers. `_hint_pair` was actually MIXED (wiggles
> nodes) — split so the search is pure in core, the rock stays in the scene. Results: layering
> **29/0**, smoke **OK**, mechanics **34/0**, grove **304/0**, save **26/0**, layout **21/0**. Uncommitted.

### Phase 3 — Split the MIXED cores · multi-session · MEDIUM risk
One function at a time, each with a before/after behavior check. Backend returns decision data; view
keeps Save + tweens.
- board: `_pop_seed`, `_after_merge`, `_on_giver_tap` (and the routing in `_on_release` / `_release_gen`)
- map: `_on_spot_tap`, `_apply_variant`

> **✅ Done 2026-06-15.** All five MIXED funcs split — every game *decision* now comes from core
> (`board_logic` / `content` / `board_model` / `Save`); the scenes only animate + orchestrate. Finding:
> Phases 1–2 + prior model work had already pushed most logic down, so the remaining slivers were
> small — the one substantial extraction was `_pop_seed`'s RNG spawn roll. `_on_release`/`_release_gen`
> were left as-is: pure input dispatch whose decisions are already model calls. Results: layering
> **29/0**, smoke **OK**, mechanics **34/0**, grove **304/0**, save **26/0**, layout **21/0**. Uncommitted.

### Phase 4 — win-back + economy · optional · LOW risk
Fold ambient win-back and shop purchase logic into core (see §3 "Later").

---

## 5 · Out of scope (parked)

- **Relocating `board`/`map` from `engine/` to `games/grove/`.** That's the *engine-vs-game* axis
  crossing this *ui-vs-backend* axis. Scenes stay in `engine/scripts/scenes/` for this plan;
  relocating to `games/` is a separate future call. (Same deferral rationale as the tuning sweep:
  game scenes living in `engine/` is a known, separately-tracked smell.)

---

## 6 · Evidence (profiling, 2026-06-15)

- **board.gd** (2130 lines, 70 funcs): **46 VIEW · 23 LOGIC · 5 MIXED.** `BoardModel` already owns
  all structural ops; residual scene-logic is run/economy/progression. The 5 MIXED funcs all follow
  *input → decide → animate*, so they split cleanly.
- **map.gd** (1535 lines): ~13 pure query funcs ready to lift as-is; 3 MIXED taps
  (`_on_spot_tap`, `_apply_variant`, `_on_wayside_tap`) are *validate+spend → rebuild*.
