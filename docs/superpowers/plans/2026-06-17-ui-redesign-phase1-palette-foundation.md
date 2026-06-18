# UI Redesign — Phase 1: Palette Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure `grove_palette.gd` into semantic role tiers (the light warm-neutral palette), shift the board off its single olive field, and guard the figure/ground relationships with a headless test plus a measured screenshot — the foundation every later phase depends on.

**Architecture:** The grove palette is a flat list of ~30 named colours consumed engine-wide via `Game.PALETTE` (aliased `const Pal = Game.PALETTE`; `board.gd` re-aliases `Pal.GROUND`, `Pal.BRAMBLE_BG`, etc.). This phase *adds* a semantic role-tier layer (`SURFACE`, `LOCKED`, `ACCENT_CTA`, …) alongside the raw names, and re-points the four board-surface consts (`GROUND`, `GROUND_EDGE`, `BRAMBLE_BG`, `BRAMBLE_EDGE`) to the new light-neutral / muted values — so the board shifts to the new look without touching `board.gd` yet. A new headless guard (`engine/tests/palette_tests.gd`, modelled on `layering_tests.gd`) asserts the role tokens exist and that the depth relationships hold (surface desaturated, locked recedes, green reclaimed as an accent). A measured screenshot sampler proves the rendered board reads as a light warm neutral, not olive.

**Tech Stack:** Godot 4.6 / GDScript. Headless `SceneTree` test scripts run via `make test-one` / `make test-grove`. Real-renderer quiet screenshots via `make shot-grove` (window born minimized — never steals focus). Spec: [`docs/superpowers/specs/2026-06-17-ui-language-redesign-design.md`](../specs/2026-06-17-ui-language-redesign-design.md).

---

## Phased rollout (this plan = Phase 1 of 4)

The full redesign is decomposed into four independently-shippable phases (the sequence approved during brainstorming). Each phase is its own plan + execution cycle; later phases are scoped at the end of this document and will be expanded into full plans **after Phase 1 lands** (their exact edits depend on the role tokens this phase introduces, and on a close read of the large scene scripts).

1. **Palette foundation** ← *this plan* — role tiers + board surface shift + guards.
2. **Board** — apply the three planes to cells/locked/items: contact-shadow grounding, `ITEM_BOX` + optical scale, recessive Sunk locked-state, near-unlock hint, micro-label placement.
3. **HUD + order strip + navigation** — shape-collapse, remove `chapter_label`, enlarged order avatars, single-row nav with one green primary-destination per page.
4. **Shop / overlay inheritance** — verify shop and overlays pick up the role tiers; reconcile any per-scene hardcoded colours.

---

## File Structure (Phase 1)

- **Modify:** `games/grove/grove_palette.gd` — add the semantic role-tier block; re-point the four board-surface consts. (One responsibility: the grove's colour skin.)
- **Create:** `engine/tests/palette_tests.gd` — headless guard for the role tokens + depth relationships.
- **Create:** `games/grove/tools/shot_sample.gd` — headless PNG sampler that measures a captured board screenshot.
- **Modify:** `Makefile` — register `palette_tests` in `ENGINE_TESTS`.

---

## Task 1: Palette role tiers + headless guard

**Files:**
- Create: `engine/tests/palette_tests.gd`
- Modify: `games/grove/grove_palette.gd` (append role-tier block after line 34; re-point `GROUND`/`GROUND_EDGE`/`BRAMBLE_BG`/`BRAMBLE_EDGE` at lines 15-18)
- Modify: `Makefile:6` (`ENGINE_TESTS`)

- [ ] **Step 1: Write the failing guard test**

Create `engine/tests/palette_tests.gd`:

```gdscript
extends SceneTree
## Headless guard for the UI-redesign palette role tiers.
##   godot --headless --path . -s res://engine/tests/palette_tests.gd
## Proves grove_palette.gd carries the semantic role tokens and that the
## figure/ground relationships hold: the surface is a desaturated stage,
## locked recedes below it, and green is reclaimed as an accent (no longer
## the play surface). See docs/superpowers/specs/2026-06-17-ui-language-redesign-design.md.

const PAL := preload("res://games/grove/grove_palette.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _dist(a: Color, b: Color) -> float:
	return sqrt(pow(a.r - b.r, 2.0) + pow(a.g - b.g, 2.0) + pow(a.b - b.b, 2.0))

func _initialize() -> void:
	print("== Palette role-tier guard ==")
	var c := (PAL as GDScript).get_script_constant_map()
	var roles := ["SCREEN_BG", "SURFACE", "SURFACE_FRAME", "CELL_EMPTY", "LOCKED",
		"LOCKED_GLYPH", "NEAR_UNLOCK", "NEAR_HINT", "CARD_PEDESTAL", "INK", "INK_MUTED",
		"ACCENT_CTA", "ACCENT_REWARD", "ACCENT_ALERT", "ACCENT_INFO"]
	for r in roles:
		ok(c.has(r), "role token present: %s" % r)
	var surface: Color = c.get("SURFACE", Color.BLACK)
	var locked: Color = c.get("LOCKED", Color.BLACK)
	var cta: Color = c.get("ACCENT_CTA", Color.BLACK)
	# Surface is a desaturated neutral stage, not a saturated green.
	ok(surface.s < 0.20, "SURFACE is desaturated (s=%.3f < 0.20)" % surface.s)
	ok(surface.v > 0.70, "SURFACE is mid-high value (v=%.3f > 0.70)" % surface.v)
	# Locked recedes BELOW the surface by value, while staying desaturated.
	ok(locked.v < surface.v, "LOCKED recedes by value (%.3f < %.3f)" % [locked.v, surface.v])
	ok(locked.s < 0.25, "LOCKED stays desaturated (s=%.3f < 0.25)" % locked.s)
	# Green is reclaimed as an accent — far from the surface...
	ok(_dist(cta, surface) > 0.30, "ACCENT_CTA distinct from SURFACE (d=%.3f)" % _dist(cta, surface))
	# ...and the old GROUND≈BTN_PRIMARY olive collision is gone.
	ok(_dist(c.get("GROUND", Color.BLACK), c.get("BTN_PRIMARY", Color.BLACK)) > 0.30,
		"GROUND vs BTN_PRIMARY collision resolved")
	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `make test-one SUITE=engine/tests/palette_tests`
Expected: FAIL — the role tokens do not exist yet, so the `role token present: …` lines print `FAIL` and the suite exits non-zero (`== 0 passed, 16 failed ==` or similar).

- [ ] **Step 3: Add the role-tier block and re-point the board consts**

In `games/grove/grove_palette.gd`, append this block after the last line (`const BTN_PRIMARY_EDGE := Color("#3C6037")`):

```gdscript

# --- UI redesign (2026-06-17): semantic role tiers --------------------------------
# Spec: docs/superpowers/specs/2026-06-17-ui-language-redesign-design.md
# Surface = the neutral stage; Locked recedes below it; accents are reserved for meaning.
const SCREEN_BG := Color("#F4EEDF")        # light warm cream chrome
const SURFACE := Color("#EDE6D2")          # light warm-neutral board field (the airy play stage)
const SURFACE_FRAME := Color("#E0D6BC")    # board border
const CELL_EMPTY := Color("#E7DFC9")       # an empty playable cell (inset on the surface)
const LOCKED := Color("#D9D2BE")           # sealed/locked cell — whisper-quiet, recedes (Sunk plane)
const LOCKED_GLYPH := Color("#A99F86")     # the small low-contrast lock icon
const NEAR_UNLOCK := Color("#E4DCC4")      # a cell one merge from opening
const NEAR_HINT := Color("#8FAE6E")        # its faint green anticipation edge
const CARD_PEDESTAL := Color("#F2EFDC")    # pale disc under items in CARDS (orders/shop) — NOT the board
const INK_MUTED := Color("#7A7558")        # muted ink (INK already exists above)
# Accents — reserved, meaning only. Aliased to the established chrome colours.
const ACCENT_CTA := BTN_PRIMARY            # primary action / growth (leaf green #4E7C46)
const ACCENT_REWARD := STRAW               # reward / value (honey gold #E3B23C)
const ACCENT_ALERT := Color("#E24B4A")     # alert / new
const ACCENT_INFO := Color("#5FA8D8")      # info
```

Then re-point the four board-surface consts so the board adopts the new look. Change lines 15-18 from:

```gdscript
const GROUND := Color("#3F6B43")
const GROUND_EDGE := Color("#33402F")
const BRAMBLE_BG := Color("#4A5A3A")
const BRAMBLE_EDGE := Color("#33402F")
```

to:

```gdscript
const GROUND := Color("#EDE6D2")        # was olive #3F6B43 — now the light SURFACE
const GROUND_EDGE := Color("#E0D6BC")   # was #33402F — now SURFACE_FRAME
const BRAMBLE_BG := Color("#D9D2BE")    # was olive #4A5A3A — now the recessive LOCKED tone
const BRAMBLE_EDGE := Color("#CFC6B0")  # was #33402F — a muted edge so locked recedes
```

(Use literal hex rather than referencing `SURFACE` etc.: these consts appear *earlier* in the file than the new block, and GDScript forbids referencing a later constant.)

- [ ] **Step 4: Run the test to verify it passes**

Run: `make test-one SUITE=engine/tests/palette_tests`
Expected: PASS — `== 21 passed, 0 failed ==`, exit 0.

- [ ] **Step 5: Register the test and run the full suites**

In `Makefile` line 6, append ` engine/tests/palette_tests` to the end of the `ENGINE_TESTS :=` list (after `engine/tests/anchor_tests`).

Run: `make test`
Expected: every suite prints its `== N passed, 0 failed ==` and the run exits 0. Confirm no existing suite regressed from the palette value change (the grove suite in particular).

- [ ] **Step 6: Commit**

```bash
git add games/grove/grove_palette.gd engine/tests/palette_tests.gd Makefile
git commit -m "feat(palette): semantic role tiers + sage board surface (UI redesign P1)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: Measured screenshot — board reads light & warm, not olive

**Files:**
- Create: `games/grove/tools/shot_sample.gd`

- [ ] **Step 1: Write the sampler (the "test")**

Create `games/grove/tools/shot_sample.gd`:

```gdscript
extends SceneTree
## Loads a captured board PNG and proves the play field reads as a desaturated
## light warm stage (not the old saturated olive). Image.load_from_file works headless
## (it is the live-viewport get_image() that returns null headless, not file loads).
## Coordinates are FRACTIONAL so they survive resolution changes; nudge fx/fy if
## the board region moves.
##   godot --headless --path . -s res://games/grove/tools/shot_sample.gd -- /tmp/board_sage.png

func _avg_patch(img: Image, fx: float, fy: float, rad: int) -> Color:
	var w := img.get_width()
	var h := img.get_height()
	var cx := int(fx * w)
	var cy := int(fy * h)
	var acc := Color(0, 0, 0)
	var n := 0
	for y in range(cy - rad, cy + rad):
		for x in range(cx - rad, cx + rad):
			if x >= 0 and y >= 0 and x < w and y < h:
				acc += img.get_pixel(x, y)
				n += 1
	n = max(n, 1)
	return Color(acc.r / n, acc.g / n, acc.b / n)

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var path: String = args[0] if args.size() > 0 else "/tmp/board_sage.png"
	var img := Image.load_from_file(path)
	if img == null:
		print("  FAIL  could not load ", path)
		quit(1)
		return
	# A patch low-centre, inside the play field rather than on the locked frontier.
	var field := _avg_patch(img, 0.5, 0.62, 8)
	print("  field avg = %s (s=%.3f v=%.3f)" % [field, field.s, field.v])
	var pass_cond := field.s < 0.22 and field.v > 0.66
	if pass_cond:
		print("  PASS  board field reads as a desaturated light warm stage")
		print("== 1 passed, 0 failed ==")
		quit(0)
	else:
		print("  FAIL  board field still saturated/dark (olive regression?)")
		print("== 0 passed, 1 failed ==")
		quit(1)
```

- [ ] **Step 2: Capture the board with the real renderer**

Run: `make shot-grove MODE=fresh OUT=/tmp/board_sage.png`
Expected: a PNG written to `/tmp/board_sage.png` at full project resolution. The window is born minimized and never steals focus (quiet capture).

- [ ] **Step 3: Run the sampler against the capture**

Run: `godot --headless --path . -s res://games/grove/tools/shot_sample.gd -- /tmp/board_sage.png`
Expected: PASS — `field avg` reports low saturation (≈0.11) and high value (≈0.86), and `== 1 passed, 0 failed ==`.

If it FAILs because the sampled patch landed on a locked cell or chrome rather than the field, nudge `fx`/`fy` in the `_avg_patch(img, 0.5, 0.62, 8)` call to a point clearly inside the play field for the `fresh` board layout, then re-run.

- [ ] **Step 4: Commit**

```bash
git add games/grove/tools/shot_sample.gd
git commit -m "test(palette): measured screenshot guard for the sage board field (UI redesign P1)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-review (Phase 1)

- **Spec coverage:** Phase 1 covers spec §3 (semantic role tiers) and the Reference-instantiation palette for the surface/locked/accent tiers, plus success criteria 2 (locked quieter — value relationship guarded) and 4 (green only as a signal — collision guard) at the palette level. Criteria 1/3/5 (item pop, grounding, HUD legibility) are Phase 2-3 and are listed in the roadmap, not dropped.
- **Placeholder scan:** none — every step has exact code, paths, commands, and expected output.
- **Type consistency:** the guard reads role names via `get_script_constant_map()`; the names in the `roles` array exactly match the consts added in Task 1 Step 3 (`SCREEN_BG`, `SURFACE`, `SURFACE_FRAME`, `CELL_EMPTY`, `LOCKED`, `LOCKED_GLYPH`, `NEAR_UNLOCK`, `NEAR_HINT`, `CARD_PEDESTAL`, `INK`, `INK_MUTED`, `ACCENT_CTA`, `ACCENT_REWARD`, `ACCENT_ALERT`, `ACCENT_INFO`). `INK` is asserted present and is the pre-existing const (not re-added). `ACCENT_CTA`/`ACCENT_REWARD` alias the earlier `BTN_PRIMARY`/`STRAW` consts (defined above the new block — legal back-reference).

---

## Future phases (separate plans — outlines, not executable tasks)

These will each be written as their own full TDD plan after Phase 1 merges. Listed here so the whole arc is visible.

### Phase 2 — Board (cells / locked / items)
- **Files:** `engine/scripts/scenes/board.gd`, `engine/scripts/core/tuning.gd` (add the **Sunk** elevation tier + `ITEM_BOX`/optical-scale dials + locked-cell dials).
- **Work:** migrate `board.gd` from raw `GROUND`/`BRAMBLE_BG` to the `SURFACE`/`LOCKED` role names; apply contact-shadow grounding to items (no disc); single `ITEM_BOX` + per-item optical scale; recessive locked glyph (`LOCKED_GLYPH`) replacing the high-contrast badge; near-unlock hint tied to `BoardLogic.openable_for_hint`; one micro-label placement convention.
- **Verification:** extend `shot_sample.gd` to also assert a locked-frontier patch is lower-value than the field, and an item patch carries a saturated hue; plus the existing headless mechanics suites stay green.

### Phase 3 — HUD + order strip + navigation
- **Files:** `engine/scripts/ui/hud.gd`, `engine/scripts/scenes/board.gd`, `engine/scripts/scenes/map.gd`, `engine/scripts/ui/giver_stand.gd`, `engine/scripts/core/tuning.gd`.
- **Work:** collapse the HUD shape vocabulary (level token + wallet only); **remove `chapter_label`**; enlarge the order-card character avatar; unify the bottom chrome into one neutral nav row with exactly one green primary-destination per page (board = contextual gate pill; map = enter garden).
- **Verification:** `make shot-grove MODE=hud` + `make shot-map`; sampler asserts a single-row nav (no second row) and the absence of the chapter ribbon region; order-card avatar exceeds a minimum fraction of card height.

### Phase 4 — Shop / overlay inheritance
- **Files:** `engine/scripts/ui/shop.gd`, `engine/scripts/ui/vault.gd`, `engine/scripts/ui/settings.gd`, and a sweep of `engine/scripts/ui/*`.
- **Work:** confirm overlays read the role tiers; reconcile per-scene hardcoded `Color()` literals against the palette (toward success criterion 6).
- **Verification:** `make shot-grove MODE=shop` + `MODE=settings`; optionally a guard counting raw `Color("#…")` literals in `ui/`/`scenes/` and asserting it does not grow.
