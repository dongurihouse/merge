# Home hub re-skin + home_asset intake — Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Process `home_asset.png` into the kit and re-skin the hub (`map.gd`) to match `home.png`, with piggy in the bottom bar, the side rail moved top-right, board-consistent button sizing, a counted mail badge, and a ~15% larger level display.

**Architecture:** Asset intake is data (`home.plan.json` + `make intake`); the re-skin is mostly free because `Look.icon`/`nav_bar`/`hud` already prefer kit art. Code changes are confined to `map.gd` (nav + rail) and `hud.gd` (level badge). Verification is the engine/grove guard suites plus `GAME=grove make shot-map` screenshot comparison to `home.png`.

**Tech Stack:** Godot 4.6 (GDScript), headless tooling (`slice_islands.gd`, `make intake`, `grove_shot.gd`).

**Spec:** `docs/superpowers/specs/2026-06-18-home-hub-reskin-design.md`

---

### Task 0: Warm the worktree + baseline green

**Files:** none (environment).

- [ ] **Step 1: Warm the import cache** (fresh-worktree grove-compile gotcha — const chains crash otherwise).

Run: `godot --headless --path . --import 2>&1 | tail -5`

- [ ] **Step 2: Baseline test sweep.**

Run: `make test`
Expected: all suites PASS (no FAIL/crash in the timing table).

---

### Task 1: Slice `home_asset.png` to scratch, read the indices

**Files:** Read-only discovery (writes only to `/tmp/peek/`).

- [ ] **Step 1: Slice to scratch.**

Run:
```bash
godot --headless --path . -s res://games/tools/slice_islands.gd -- \
  games/grove/assets/_new/home_asset.png /tmp/peek/cell_
```
Expected: prints `n -> x,y wxh (px=count)` per island, top→bottom / left→right.

- [ ] **Step 2: Inspect each slice.** Read `/tmp/peek/cell_<n>.png` (use the Read tool on the PNGs) and build the index→piece table. Identify and EXCLUDE: the baked section-label text islands, and every section-10 "assembled example" island.

- [ ] **Step 3: Record the mapping** as a scratch note (kept islands → intended name/path), following the spec's output table. No commit (discovery only).

---

### Task 2: Author `home.plan.json` and run intake

**Files:**
- Create: `games/grove/assets/_new/home.plan.json`
- Produces (paths from Task 1 mapping): `ui/shared/panel_pill.png`, `ui/shared/panel_parchment.png`, `ui/shared/btn_round.png`, `ui/shared/icon_*.png`, `ui/currency/icon_*.png`, `ui/nav/nav_*.png`, `ui/kit/strip_*.png`, `ui/kit/cta_green.png`, `ui/kit/tab_caption.png`.

- [ ] **Step 1: Write the plan.** `category: "sheet"`, `params.min_area` tuned to drop the label text, one `outputs` entry per kept island with `"island"`, `"name"`, `"path"`, and `"post": "icon:<px>"` for square icons (frames/strips keep their shape — no `post`). `archive: "_originals/ui/home_asset.png"`. Follow the schema in `docs/design/asset-intake.md` and the `shop.plan.json` precedent.

- [ ] **Step 2: Run intake for this plan.**

Run: `make intake PLAN=home.plan.json`
Expected: outputs written, raw moved to `_originals/ui/`, plan moved to `_new/_processed/`, reimport ran with no error. (On tool failure the runner skips and leaves the raw — fix the plan and rerun.)

- [ ] **Step 3: Verify the outputs landed.**

Run: `ls games/grove/assets/ui/shared games/grove/assets/ui/nav games/grove/assets/ui/currency games/grove/assets/ui/kit | sort`
Expected: every path from the plan present; `games/grove/assets/_new/home_asset.png` gone; `_new/_processed/home.plan.json` present.

- [ ] **Step 4: Tests still green.**

Run: `make test-fast`
Expected: PASS.

- [ ] **Step 5: Commit.**

```bash
git add games/grove/assets/ui games/grove/assets/_new games/grove/assets/_originals
git commit -m "Process home_asset.png into the UI kit"
```

---

### Task 3: Baseline screenshot — confirm the "free" re-skin

**Files:** none (verification; `grove_shot.gd` already supports a map shot).

- [ ] **Step 1: Capture the hub.**

Run: `GAME=grove make shot-map`
Expected: a PNG under the shot output dir.

- [ ] **Step 2: Compare to `home.png`.** Read both. Confirm the new kit art now drives the currency pill, currency icons, nav icons, and round buttons. Note any icon that resolved to a glyph fallback (means a name mismatch) — fix the path/name in `home.plan.json` mapping and re-run Task 2 if needed.

---

### Task 4: Level display ~15% larger (`hud.gd`)

**Files:**
- Modify: `engine/scripts/ui/hud.gd` (the `lv_px := 88.0` in `build`, and `_lv_font_size`).

- [ ] **Step 1: Enlarge the badge.** Change `var lv_px := 88.0` to `var lv_px := 100.0`.

- [ ] **Step 2: Scale the number.** In `_lv_font_size`, bump the returns ~15%: `>=100 → 25`, `>=10 → 32`, else `41`.

- [ ] **Step 3: Tests.**

Run: `make test-grove && make test-fast`
Expected: PASS (incl. any HUD/level-badge guard).

- [ ] **Step 4: Screenshot check.**

Run: `GAME=grove make shot-map`
Expected: the top-left "15" badge reads ~15% larger, digits still centered in the medal.

- [ ] **Step 5: Commit.**

```bash
git add engine/scripts/ui/hud.gd
git commit -m "Enlarge the HUD level badge ~15%"
```

---

### Task 5: Bottom bar — board sizing, realign, add piggy (`map.gd`)

**Files:**
- Modify: `engine/scripts/scenes/map.gd` — `_build_chrome` (`NavBar.build` specs), and remove the piggy from `_build_liveops_rail`.

- [ ] **Step 1: Re-spec the nav row.** In `_build_chrome`, change the `NavBar.build` specs to the board's sizing and a centered primary, order `gear · shop · Play(leaf) · map · piggy`:
  - gear `px: 140`, shop `px: 140`, Play(leaf) `px: 184`, map `px: 140`, piggy `px: 140`.
  - piggy spec: `{"icon": "nav_piggy.png", "px": 140.0, "label": tr("Vault"), "action": _open_vault}`.
  - Update `_shop_btn = nav.buttons[1]` (shop is now index 1) and `FX.breathe_once(nav.buttons[2])` (Play is index 2).

- [ ] **Step 2: Move the piggy pip to the nav button.** After building nav, create `_piggy_pip = Look.badge("dot")`, `Look.attach_badge(nav.buttons[4], _piggy_pip)`, then `_refresh_piggy_pip()`. Keep `_piggy_pip` as the member the refresh uses.

- [ ] **Step 3: Remove the piggy from the rail.** Delete the piggy block in `_build_liveops_rail` (`map.gd:1486-1492`) so the rail is Daily/Free/Inbox only. Leave `_refresh_piggy_pip` itself intact (now drives the nav pip).

- [ ] **Step 4: Tests.**

Run: `make test-grove && make test-fast`
Expected: PASS. (If a placement/ui guard asserts the old nav order/count, update it to the new 5-button centered layout.)

- [ ] **Step 5: Screenshot check.**

Run: `GAME=grove make shot-map`
Expected: bottom bar = gear · shop · Play(centered, large) · map · piggy, all board-sized; piggy carries its ready-pip.

- [ ] **Step 6: Commit.**

```bash
git add engine/scripts/scenes/map.gd engine/scripts/ui games/grove/tests
git commit -m "Bottom bar: board sizing + centered Play + piggy button"
```

---

### Task 6: Side rail — top-right, board-sized, caption tabs, mail count (`map.gd`)

**Files:**
- Modify: `engine/scripts/scenes/map.gd` — `_build_liveops_rail`, `_rail_button`, `_place_rail`, `_refresh_liveops_badges`.

- [ ] **Step 1: Resize + reframe the rail buttons.** In `_rail_button`, take an icon id (not an emoji glyph), build the round button at `px = 140` using `Look.kit("shared/btn_round.png")`, place a kit icon via `Look.icon(id, px*0.5)` centered, and add a caption tab below using `Look.title_ribbon(label)` or the sliced `ui/kit/tab_caption.png`. Keep `MOUSE_FILTER_IGNORE` on the icon/caption (single-input-surface).

- [ ] **Step 2: Map rail entries to kit icons.** In `_build_liveops_rail`: Daily → the kit's chest/gift icon, Free → faucet/gift icon, Inbox → `mail`. Use the icon ids that resolve to the sliced `ui/shared/icon_*.png` (fall back to the existing emoji only if a specific icon is absent).

- [ ] **Step 3: Anchor top-right, stack downward.** Rewrite `_place_rail` to anchor `(1,0)` top-right and stack DOWN from a top offset clear of the wallet pill (`top := EDGE_MARGIN + safe_top + PILL_SLOT_H + gap`), `step = px + gap + caption_h`. Set `px = 140` and the start offset in `_build_liveops_rail`.

- [ ] **Step 4: Mail count badge.** Keep `_inbox_badge = Look.badge("pill", 0)`; confirm `_refresh_liveops_badges` sets its child Label to `inbox.unread_count()` (the red disc + white number, like the reference). Ensure it pins to the icon's top-right via `attach_badge`.

- [ ] **Step 5: Tests.**

Run: `make test-grove && make test-fast`
Expected: PASS. (Update any rail-position/size guard to the new top-right, 140px layout.)

- [ ] **Step 6: Screenshot check.**

Run: `GAME=grove make shot-map`
Expected: rail = Daily/Free/Inbox stacked top-right, 140px, caption tabs beneath, mail showing a red count badge — matching `home.png`.

- [ ] **Step 7: Commit.**

```bash
git add engine/scripts/scenes/map.gd games/grove/tests
git commit -m "Side rail: top-right, board-sized, caption tabs, mail count badge"
```

---

### Task 7: Full verification + polish pass

**Files:** any small tuning to `map.gd` / `hud.gd` / `home.plan.json` revealed by the comparison.

- [ ] **Step 1: Full sweep.**

Run: `make test`
Expected: every suite PASS in the timing table.

- [ ] **Step 2: Side-by-side.** Capture `GAME=grove make shot-map`, read it next to `home.png`. Verify all six: re-skinned pill/icons, larger level badge, piggy in bottom bar, board-sized centered nav, rail top-right with caption tabs, mail count badge. Tune offsets/sizes where they drift from the reference; re-run the relevant task's screenshot step.

- [ ] **Step 3: Commit any polish.**

```bash
git add -A
git commit -m "Polish: align hub to home.png reference"
```

- [ ] **Step 4: Hand off for merge.** Summarize the branch `worktree-home-reskin` state and tell the user it is ready to merge (do NOT merge — the user merges from the primary tree per the dh/merge worktree flow).

---

## Self-review

- **Spec coverage:** intake (Task 1–2), free re-skin (Task 3), level badge (Task 4), piggy→bottom bar + board sizing/realign (Task 5), rail top-right + size + caption + mail count (Task 6), verify (Task 7). All spec sections mapped.
- **No pytest invented** — uses the project's `make test*` / `make intake` / `make shot-map`, matching `CLAUDE.md`.
- **Order:** intake first (art must exist before the re-skin reads it); level badge (independent) before the map nav/rail changes; rail last (depends on piggy already removed from it in Task 5).
