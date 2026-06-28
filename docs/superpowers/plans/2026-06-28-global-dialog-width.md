# Global Dialog Width + Content Scaling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every in-game dialog renders at one globally-configurable screen-width percentage (default 75%), with inner content scaling to that width while frame chrome stays crisp.

**Architecture:** A reusable `ScaleContainer` wraps each dialog's content and applies a uniform `Control.scale = s`. The shared `dialog_frame()` / `level_frame()` build chrome at the *target* width (`design_width × s`) but lay content out at its authored `design_width`, so content looks identical to today, just resized. `s = global_pct / design_pct`, where `design_pct` is each dialog's current (authored) width as a code constant. The per-dialog `width_pct` workbench knob is removed; one global `frame.width_pct` replaces it.

**Tech Stack:** Godot 4.6, GDScript. Tests = headless SceneTree suites via `make test-fast` / `make test`.

**Spec:** `docs/superpowers/specs/2026-06-28-global-dialog-width-design.md`

**Key facts (verified):**
- Shared frame: `Kit.dialog_frame(content, width, opts)` at `games/grove/tools/ui_workbench_kit.gd:1962`. Content path: `card → inner → scroll(ScrollContainer) → rows(VBox) → [spacer, content]`. Chrome (card min size, banner, ✕) all sized from `width`. Relayout closure (lines 2064-2073) reads `rows.size.y`.
- Level frame: `Kit.level_frame(content, width, opts)` at line 2841; `content` is a direct `card` child with `SIZE_EXPAND_FILL`.
- Shared frame config: `_frame_cfg(cfg)` (line 3342) = `cfg.dialog` merged with `cfg.frame`. The "frame" param block is at `ui_workbench_view.gd:296`.
- `design_pct` per dialog (current authored width = JSON saved `width_pct`): dialog/mail 75, daily 75, bag 75, shop 85, tiers 85, vault 80, settings 50, level 50, info 58. Mystery: `reveal_width(vw)=min(560,max(360,vw*0.94))` (`login_mystery.gd:81`).
- `project.godot` uses `stretch=canvas_items`/`expand` at 1080 base → viewport width is effectively constant 1080 at runtime.
- Per-dialog `width_pct` slider rows in `ui_workbench_view.gd`: lines 2342, 2366, 2380, 2388, 2540, 2586, 2595, 2646, 2810 (confirm each maps to a dialog at edit time; keep exactly one on the Frame item).
- Runtime callers (read `cfg.<id>.width_pct`): inbox.gd:60, login.gd:56, shop.gd:186 + shop.gd:495 (info), settings.gd:65, vault.gd:69, ladder.gd:56, gen_lines.gd:56, bag_overlay.gd:129, level_popup.gd:66, map.gd:1963 (+ check map.gd:2882).
- Tests: grove suites extend `games/grove/tests/grove_test_base.gd`; UI suite `grove_ui_tests.gd`. Engine suites under `engine/tests/`.

---

## Task 1: `ScaleContainer` component

**Files:**
- Create: `engine/scripts/ui/scale_container.gd`
- Test: `engine/tests/scale_container_tests.gd`

A `Container` that scales its single child uniformly. The child is laid out at `width / s` (so its authored sizes/wrapping are preserved) and rendered at `scale = s`. Reports the child's *scaled* height as its own min height so a parent `ScrollContainer` scrolls correctly.

- [ ] **Step 1: Write the failing test** (`engine/tests/scale_container_tests.gd`)

```gdscript
extends SceneTree
## Unit tests for ScaleContainer: it scales its child and reports the scaled footprint.

const ScaleContainer = preload("res://engine/scripts/ui/scale_container.gd")

var _pass := 0
var _fail := 0
func ok(c: bool, l: String) -> void:
	if c: _pass += 1; print("  PASS  ", l)
	else: _fail += 1; print("  FAIL  ", l)

func _initialize() -> void:
	print("ScaleContainer tests")
	var root := Control.new()
	root.size = Vector2(300, 600)
	get_root().add_child(root)

	var sc := ScaleContainer.new()
	sc.scale_factor = 2.0
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(sc)

	var child := Control.new()
	child.custom_minimum_size = Vector2(100, 50)   # authored size
	sc.add_child(child)

	# force a couple of layout passes
	for i in 4:
		root.size = Vector2(300, 600)
		await process_frame

	ok(is_equal_approx(child.scale.x, 2.0), "child rendered at scale_factor")
	ok(is_equal_approx(child.scale.y, 2.0), "child scaled uniformly (y)")
	# child laid out at container_width / s
	ok(is_equal_approx(child.size.x, sc.size.x / 2.0), "child width = container width / scale")
	# container reports scaled height upward
	ok(sc.get_combined_minimum_size().y >= 50.0 * 2.0 - 1.0, "min height >= child height x scale")

	# scale 1.0 is an identity pass-through
	var sc1 := ScaleContainer.new()
	sc1.scale_factor = 1.0
	root.add_child(sc1)
	var c1 := Control.new(); c1.custom_minimum_size = Vector2(80, 40); sc1.add_child(c1)
	for i in 4:
		await process_frame
	ok(is_equal_approx(c1.scale.x, 1.0), "identity scale leaves child unscaled")

	print("  %d passed, %d failed" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
```

- [ ] **Step 2: Run, verify it fails**

Run: `godot --headless --path . -s res://engine/tests/scale_container_tests.gd`
Expected: FAIL — can't preload `scale_container.gd` (does not exist).

- [ ] **Step 3: Implement `engine/scripts/ui/scale_container.gd`**

```gdscript
@tool
extends Container
## Uniformly scales its single Control child by `scale_factor`, preserving the child's
## authored pixel sizes. The child is laid out at (this.width / scale_factor) so its
## contents wrap and size exactly as at that width, then rendered at `scale_factor`.
## The container reports the child's *scaled* laid-out height as its own minimum height,
## so a parent ScrollContainer scrolls the scaled footprint correctly. scale_factor == 1
## is a transparent pass-through (no visual or layout change).
class_name ScaleContainer

@export var scale_factor: float = 1.0:
	set(v):
		var nv: float = maxf(0.01, v)
		if is_equal_approx(nv, scale_factor):
			return
		scale_factor = nv
		queue_sort()
		update_minimum_size()

func _child() -> Control:
	for c in get_children():
		if c is Control and not c.is_set_as_top_level():
			return c
	return null

func _get_minimum_size() -> Vector2:
	var c := _child()
	if c == null:
		return Vector2.ZERO
	# Width 0 → we EXPAND_FILL to the scroll width. Height = child's ACTUAL laid-out
	# height × scale (handles wrapping text, which combined_minimum_size cannot).
	return Vector2(0.0, c.size.y * scale_factor)

func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		var c := _child()
		if c == null:
			return
		var s: float = maxf(0.01, scale_factor)
		if not c.resized.is_connected(_on_child_resized):
			c.resized.connect(_on_child_resized)
		c.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		c.scale = Vector2(s, s)
		c.position = Vector2.ZERO
		# Lay the child out at our width in its own (unscaled) space; let it choose its
		# own height (containers size to their content's min height for the given width).
		var w: float = size.x / s
		c.size = Vector2(w, c.get_combined_minimum_size().y)

func _on_child_resized() -> void:
	update_minimum_size()
```

- [ ] **Step 4: Run, verify it passes**

Run: `godot --headless --path . -s res://engine/tests/scale_container_tests.gd`
Expected: PASS (4+ assertions). If the wrapping-height assertion is flaky, add another `await process_frame` cycle in the test (deferred layout convergence) — do NOT loosen the assertion.

- [ ] **Step 5: Register the suite + run fast sweep**

Add `scale_container_tests` to the engine suite list if `engine/tools/run_suites.py` enumerates explicitly (check; it may auto-discover `*_tests.gd`). Then:
Run: `make test-fast`
Expected: all suites pass, including the new one.

- [ ] **Step 6: Commit**

```bash
git add engine/scripts/ui/scale_container.gd engine/tests/scale_container_tests.gd
git commit -m "feat(ui): ScaleContainer — uniform child scaling with scaled-footprint min size"
```

---

## Task 2: `Kit` helpers — design baselines + global frame width

**Files:**
- Modify: `games/grove/tools/ui_workbench_kit.gd` (near `_frame_cfg`, line 3342)
- Test: `engine/tests/dialog_width_tests.gd`

- [ ] **Step 1: Write the failing test** (`engine/tests/dialog_width_tests.gd`)

```gdscript
extends SceneTree
const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")
var _pass := 0
var _fail := 0
func ok(c: bool, l: String) -> void:
	if c: _pass += 1; print("  PASS  ", l)
	else: _fail += 1; print("  FAIL  ", l)

func _initialize() -> void:
	print("dialog width helpers")
	# default global width = 75 when no config present
	ok(is_equal_approx(Kit.frame_width_pct({}), 75.0), "default global width_pct = 75")
	# frame block supplies the global
	ok(is_equal_approx(Kit.frame_width_pct({"frame": {"width_pct": 60}}), 60.0), "frame.width_pct read")
	# design baselines exist for every dialog id
	for id in ["dialog", "daily", "bag", "shop", "tiers", "vault", "settings", "level", "info"]:
		ok(Kit.DIALOG_DESIGN_PCT.has(id) and float(Kit.DIALOG_DESIGN_PCT[id]) > 0.0, "design_pct for %s" % id)
	# scale = global / design
	ok(is_equal_approx(Kit.dialog_content_scale({"frame": {"width_pct": 75}}, "shop"), 75.0 / 85.0), "shop scale = 75/85")
	ok(is_equal_approx(Kit.dialog_content_scale({"frame": {"width_pct": 75}}, "dialog"), 1.0), "mail scale = 1.0")
	print("  %d passed, %d failed" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
```

- [ ] **Step 2: Run, verify it fails**

Run: `godot --headless --path . -s res://engine/tests/dialog_width_tests.gd`
Expected: FAIL — `DIALOG_DESIGN_PCT` / `frame_width_pct` / `dialog_content_scale` undefined.

- [ ] **Step 3: Add helpers to `ui_workbench_kit.gd`** (place just above `_frame_cfg`)

```gdscript
## Each dialog's AUTHORED width as a % of the screen — the baseline its content (fonts, cells,
## padding) was tuned at. Content scales by global_width_pct / design_pct so every dialog renders
## at the single global width while keeping its proportions. This is a code constant (same category
## as cell sizes), NOT a workbench knob — the only width KNOB is the global frame.width_pct.
const DIALOG_DESIGN_PCT := {
	"dialog": 75.0, "daily": 75.0, "bag": 75.0,
	"shop": 85.0, "tiers": 85.0, "vault": 80.0,
	"settings": 50.0, "level": 50.0, "info": 58.0,
}

## The ONE global dialog width, as a % of the screen — read from the shared frame config
## (cfg.frame.width_pct, falling back through cfg.dialog for back-compat). Default 75.
static func frame_width_pct(cfg: Dictionary) -> float:
	return clampf(float(_frame_cfg(cfg).get("width_pct", 75.0)), 30.0, 100.0)

## The content scale for a dialog id = global width / the dialog's authored design width.
static func dialog_content_scale(cfg: Dictionary, id: String) -> float:
	var design: float = float(DIALOG_DESIGN_PCT.get(id, 75.0))
	return frame_width_pct(cfg) / maxf(1.0, design)
```

- [ ] **Step 4: Run, verify it passes** — `godot --headless --path . -s res://engine/tests/dialog_width_tests.gd` → PASS.

- [ ] **Step 5: Commit**

```bash
git add games/grove/tools/ui_workbench_kit.gd engine/tests/dialog_width_tests.gd
git commit -m "feat(kit): design-width baselines + global frame width helpers"
```

---

## Task 3: Scale content inside `dialog_frame` (crisp chrome)

**Files:**
- Modify: `games/grove/tools/ui_workbench_kit.gd:1962` (`dialog_frame`)
- Test: extend `engine/tests/dialog_width_tests.gd`

`dialog_frame` receives `width` = design width and `opts.content_scale` = s. Chrome is built at `target = width * s` (crisp at the real on-screen width); the inner `content` is wrapped in a `ScaleContainer(s)`.

- [ ] **Step 1: Add a failing integration assertion** to `dialog_width_tests.gd` `_initialize` (before the summary):

```gdscript
	# dialog_frame: chrome sized to design_width * content_scale; content wrapped in a ScaleContainer
	var body := VBoxContainer.new()
	var lbl := Label.new(); lbl.text = "hello"; body.add_child(lbl)
	var design_w := 400.0
	var dlg: Control = Kit.dialog_frame(body, design_w, {"content_scale": 1.5, "banner_text": "X"})
	get_root().add_child(dlg)
	for i in 4: await process_frame
	var card := dlg.get_child(0)   # PanelContainer
	ok(card.custom_minimum_size.x >= design_w * 1.5 - 1.0, "chrome width = design x content_scale (target)")
	var found_scaler := _find_scaler(dlg)
	ok(found_scaler != null, "content wrapped in a ScaleContainer")
	ok(found_scaler == null or is_equal_approx(found_scaler.scale_factor, 1.5), "scaler uses content_scale")
	dlg.queue_free()
```

And add this helper method to the test script:

```gdscript
func _find_scaler(n: Node):
	if n.get_class() == "Container" and "scale_factor" in n:
		return n
	for c in n.get_children():
		var r = _find_scaler(c)
		if r != null: return r
	return null
```

(`ScaleContainer` instances expose `scale_factor`; the duck-typed check avoids importing the class name.)

- [ ] **Step 2: Run, verify the new assertions fail**

Run: `godot --headless --path . -s res://engine/tests/dialog_width_tests.gd`
Expected: FAIL on "chrome width = design x content_scale" (chrome currently uses raw `width`) and "content wrapped in a ScaleContainer".

- [ ] **Step 3: Implement in `dialog_frame`**

At the top of `dialog_frame` (after the existing `var on_close ...` opt reads, before `var wrap := Control.new()`), add:

```gdscript
	var content_scale: float = maxf(0.01, float(opts.get("content_scale", 1.0)))
	var target_w: float = width * content_scale
```

Replace every chrome use of `width` with `target_w`:
- `card.custom_minimum_size = Vector2(width, 0)` → `Vector2(target_w, 0)` (line ~2022)
- `wrap.custom_minimum_size.x = width` → `target_w` (line ~2024)
- the `_banner(..., width, ...)` call → pass `target_w` (line ~2053)

Wrap the content before it goes into `rows`. Replace (lines ~2048-2049):

```gdscript
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_child(content)
```

with:

```gdscript
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if is_equal_approx(content_scale, 1.0):
		rows.add_child(content)             # identity → unchanged (mail/daily/bag stay byte-identical)
	else:
		var scaler := ScaleContainer.new()  # res://engine/scripts/ui/scale_container.gd
		scaler.scale_factor = content_scale
		scaler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scaler.add_child(content)
		rows.add_child(scaler)
```

Add a preload near the top of the file (with the other consts) if `ScaleContainer`'s `class_name` is not globally resolved in this context:

```gdscript
const ScaleContainer = preload("res://engine/scripts/ui/scale_container.gd")
```

- [ ] **Step 4: Run, verify pass** — `godot --headless --path . -s res://engine/tests/dialog_width_tests.gd` → PASS.

- [ ] **Step 5: Run fast sweep** — `make test-fast` → all pass (verifies no regression for existing dialog tests, which pass `content_scale` default 1.0 = identity).

- [ ] **Step 6: Commit**

```bash
git add games/grove/tools/ui_workbench_kit.gd engine/tests/dialog_width_tests.gd
git commit -m "feat(kit): dialog_frame scales content, builds chrome at target width"
```

---

## Task 4: Scale content inside `level_frame`

**Files:**
- Modify: `games/grove/tools/ui_workbench_kit.gd:2841` (`level_frame`)

Mirror Task 3 for the level frame.

- [ ] **Step 1: Implement**

After `var top_pad := ...` reads, add:

```gdscript
	var content_scale: float = maxf(0.01, float(opts.get("content_scale", 1.0)))
	var target_w: float = width * content_scale
```

Replace chrome `width` with `target_w`:
- `card.custom_minimum_size = Vector2(width, 0)` → `Vector2(target_w, 0)` (line ~2868)
- `wrap.custom_minimum_size.x = width` → `target_w` (line ~2873)

Replace `card.add_child(content)` (line ~2870) with:

```gdscript
	if is_equal_approx(content_scale, 1.0):
		card.add_child(content)
	else:
		var scaler := ScaleContainer.new()
		scaler.scale_factor = content_scale
		scaler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scaler.add_child(content)
		card.add_child(scaler)
```

Note: `level_dialog` sets `bar.custom_minimum_size.x = width * 0.78` (line ~2953). Because the caller passes `design_width` (= width here), this stays correct and scales with the content. No change needed.

- [ ] **Step 2: Run fast sweep** — `make test-fast` → all pass.

- [ ] **Step 3: Commit**

```bash
git add games/grove/tools/ui_workbench_kit.gd
git commit -m "feat(kit): level_frame scales content, builds chrome at target width"
```

---

## Task 5: Add global `frame.width_pct`; rewire workbench

**Files:**
- Modify: `games/grove/tools/ui_workbench_view.gd` (params @296/312/348/355/359/368/411/415/421/437; `_dlg_px` @594-595; slider rows @2342/2366/2380/2388/2540/2586/2595/2646/2810; preview builds @776/802/812/824/934/943/951/965/984; Frame preview @768)

- [ ] **Step 1: Add `width_pct` to the frame block** (`ui_workbench_view.gd:297`)

In the `"frame": { ... }` dict, add `"width_pct": 75,` as the first field.

- [ ] **Step 2: Remove per-dialog `width_pct` defaults** from each dialog block in `_params`: `dialog` (312), `daily` (348), `shop` (355), `level` (359), `tiers` (368), `settings` (411), `vault` (415), `info` (421 — becomes `{}` or drop the key), `bag` (437). Delete the `"width_pct": NN,` entry from each.

- [ ] **Step 3: Repoint `_dlg_px` to design baselines + add the scale helper** (replace lines 594-595)

```gdscript
func _dlg_px(id: String) -> float:
	# preview at the dialog's AUTHORED width (design baseline); content_scale resizes to the global width.
	return PHONE_W * float(Kit.DIALOG_DESIGN_PCT.get(id, 75.0)) / 100.0

func _dlg_scale(id: String) -> float:
	return Kit.dialog_content_scale(_params, id)
```

- [ ] **Step 4: Inject `content_scale` into each preview's opts.** For every preview build that calls a dialog builder with `_dlg_px("<id>")`, set the matching `content_scale` on its opts dict just before the call. The `<id>` is the `_dlg_px` argument. Examples:
  - mail (776): `opts["content_scale"] = _dlg_scale("dialog")`
  - daily (802): `dopts["content_scale"] = _dlg_scale("daily")`
  - shop (812): `sopts["content_scale"] = _dlg_scale("shop")`
  - level (824): `lo["content_scale"] = _dlg_scale("level")`
  - tiers (934): `topts["content_scale"] = _dlg_scale("tiers")`
  - settings (943): `setopts["content_scale"] = _dlg_scale("settings")`
  - vault (951): `vopts["content_scale"] = _dlg_scale("vault")`
  - info (965): `iopts["content_scale"] = _dlg_scale("info")`
  - bag (984): `bopts["content_scale"] = _dlg_scale("bag")`

- [ ] **Step 5: Remove per-dialog width sliders; add the global one.** Delete the `_slider_row(["width_pct", 40, 100])` line in each per-dialog sidebar section (2342, 2366, 2380, 2388, 2540, 2586, 2595, 2646, 2810 — verify each is a per-dialog section at edit time). In the **Frame** sidebar item's section, add exactly one:

```gdscript
	_sidebar_body.add_child(_slider_row(["width_pct", 30, 100]))   # GLOBAL dialog width — % of screen (all dialogs)
```

(The Frame item edits the `frame` block, so this slider drives `frame.width_pct`. Confirm the Frame item's section by the `preview_text`/`width` controls near `ui_workbench_view.gd:768`.)

- [ ] **Step 6: Point the Frame item's own preview at the global width** (line 768). Change `float(p.width)` so the frame preview uses the global width_pct (keep `p.width` px field as a fallback):

```gdscript
			var fr := Kit.dialog_frame(_frame_placeholder(), _dlg_px("dialog") * _dlg_scale("dialog"), fo)
```

(`_dlg_px("dialog") * _dlg_scale("dialog")` = `PHONE_W * frame_width_pct/100` = the global target px. `fo["content_scale"]` left at default 1.0 since the placeholder has no authored baseline.)

- [ ] **Step 7: Launch the workbench, verify the global slider drives all dialogs.** Use the project's quiet-godot pattern (no focus steal). Confirm: one width slider on the Frame item; none on individual dialogs; moving it resizes every dialog preview; content scales.

- [ ] **Step 8: `make test-grove`** (workbench/UI suites) → pass.

- [ ] **Step 9: Commit**

```bash
git add games/grove/tools/ui_workbench_view.gd
git commit -m "feat(workbench): single global dialog width on the Frame item; remove per-dialog width knobs"
```

---

## Task 6: Rewire runtime callers

**Files (each, the `width_pct` read near the cited line):** inbox.gd:60, login.gd:56, ladder.gd:56, gen_lines.gd:56, settings.gd:65, vault.gd:69, bag_overlay.gd:129, shop.gd:186, level_popup.gd:66, map.gd:1963 (+ inspect map.gd:2882).

**Mechanical recipe (same transform everywhere):** replace the per-dialog `width_pct`-from-config read + width calc with a design-width calc, and inject `content_scale` into the opts dict the caller already builds. `<id>` is the dialog's config id (the key it used in `cfg.get("<id>", ...)`); `<opts>` is the local opts dict passed to the builder.

Before (example, inbox.gd):
```gdscript
	var pct: float = float((cfg.get("dialog", {}) as Dictionary).get("width_pct", CARD_WIDTH_PCT))
	var width: float = vw * clampf(pct, 30.0, 100.0) / 100.0
	...
	var opts: Dictionary = Kit.dialog_opts_from_config(cfg)
```
After:
```gdscript
	var width: float = vw * Kit.DIALOG_DESIGN_PCT["dialog"] / 100.0
	...
	var opts: Dictionary = Kit.dialog_opts_from_config(cfg)
	opts["content_scale"] = Kit.dialog_content_scale(cfg, "dialog")
```

Per-caller `<id>` → builder opts var:
| File | id | opts var | builder |
|------|----|---------|---------|
| inbox.gd | `dialog` | opts | mail_dialog |
| login.gd | `daily` | dopts | daily_dialog |
| ladder.gd | `tiers` | topts | tiers_dialog |
| gen_lines.gd | `tiers` | (its opts) | tiers_dialog |
| settings.gd | `settings` | setopts | settings_dialog |
| vault.gd | `vault` | vopts | vault_dialog |
| bag_overlay.gd | `bag` | bopts | bag_dialog |
| shop.gd:186 | `shop` | sopts | shop_dialog |
| level_popup.gd | `level` | lo | level_dialog |
| map.gd:1963 | `tiers` | (its opts) | tiers_dialog |

- [ ] **Step 1:** For each row above, read the exact lines, apply the recipe (drop the now-unused `width_pct`-from-config read; the per-caller `CARD_WIDTH_PCT`/`WIDTH_PCT_DEF`/`SHOP_WIDTH_PCT`/`DEFAULT_WIDTH_PCT` constant is no longer the width source — leave the const or remove if unreferenced). After each file: `make test-fast`.

- [ ] **Step 2: Shop info sheet** (`shop.gd:495`). Currently:
```gdscript
	var width: float = host.get_viewport_rect().size.x * clampf(float(iopts.get("width_pct", 70)), 30.0, 100.0) / 100.0
```
Replace with design-width + scale (info baseline 58):
```gdscript
	var width: float = host.get_viewport_rect().size.x * Kit.DIALOG_DESIGN_PCT["info"] / 100.0
	iopts["content_scale"] = Kit.dialog_content_scale(cfg, "info")
```
And drop the now-dead `o["width_pct"]` set in `info_opts_from_config` (`ui_workbench_kit.gd:3453`) — replace it with `o["content_scale"]` is NOT needed there since the caller sets it; just delete line 3453. (Confirm `cfg` is in scope at shop.gd:495; if the info sheet uses a different cfg var, use that.)

- [ ] **Step 3: map.gd:2882** — inspect the dialog built there (first Explore flagged a mail/unlock dialog). If it computes a width from a per-dialog `width_pct`, apply the recipe with the appropriate id (`dialog`). If it already passes a fixed width unrelated to `width_pct`, leave it and note why.

- [ ] **Step 4: Full grove sweep** — `make test-grove` → pass.

- [ ] **Step 5: Commit**

```bash
git add engine/scripts/ui/*.gd engine/scripts/scenes/map.gd games/grove/tools/ui_workbench_kit.gd
git commit -m "feat(ui): all dialogs read the global frame width + scale content to it"
```

---

## Task 7: Mystery Spin (bespoke outlier)

**Files:** `engine/scripts/ui/login_mystery.gd` (~lines 60-61, 88-133)

The reveal dialog keeps its authored card layout (`reveal_width(vw)` as the design width) but renders at the global width via `content_scale`.

- [ ] **Step 1: Implement.** In `show_reveal` (~line 60) compute design + scale and pass scale into the frame opts. Keep `reveal_width(vw)` as the width handed to `build_reveal` (so the inner card sizing at line 112 is unchanged), and set `content_scale` on the `fo` opts dict used by `Kit.dialog_frame(body, width, fo)` (line ~133):

```gdscript
	var design_w: float = reveal_width(vw)
	var target_pct: float = Kit.frame_width_pct(frame_cfg)        # frame_cfg = the saved config passed in
	var content_scale: float = (vw * target_pct / 100.0) / maxf(1.0, design_w)
	# ... build_reveal(..., design_w, {... "content_scale": content_scale ...})
```
Thread `content_scale` into `build_reveal`'s `opts`/`fo` so the `dialog_frame` call receives it. (Read the function to wire `frame_cfg`/opts precisely.)

- [ ] **Step 2:** `make test-fast` → pass.

- [ ] **Step 3: Commit**

```bash
git add engine/scripts/ui/login_mystery.gd
git commit -m "feat(ui): Mystery Spin uses the global dialog width + content scaling"
```

---

## Task 8: Clean saved config

**Files:** `games/grove/tools/ui_workbench_settings.json`

- [ ] **Step 1:** Add `"width_pct": 75` to the `"frame"` object. Remove the `"width_pct"` key from `dialog`, `daily`, `shop`, `level`, `settings`, `vault`, `tiers`, `bag`, `info`. (Use the lines from the first exploration: 16, 87, 107, 258, 318, 482, 499, 511, 528 — re-grep before editing since line numbers drift.)

- [ ] **Step 2:** `make test` (full sweep) → pass.

- [ ] **Step 3: Commit**

```bash
git add games/grove/tools/ui_workbench_settings.json
git commit -m "chore(config): single global frame.width_pct; drop per-dialog width_pct"
```

---

## Task 9: Visual verification (REQUIRED — see the result)

**Files:** scratchpad render script (not committed).

Per the project rule, a user-visible change is not done until the real rendered result is produced and inspected. Render each dialog through the real game path at the default 75% and capture a screenshot.

- [ ] **Step 1:** Write a headless-but-real-renderer capture (use the transient `override.cfg` minimized-window pattern so no window steals focus — see global notes / `tools/quiet_godot.sh` if present) that opens, in turn: Mail, Daily, Shop, Settings, Vault, Discovery (tiers), Bag, Level, Info sheet, Mystery Spin. Save a PNG per dialog to the repo scratch dir.

- [ ] **Step 2:** Inspect each PNG (composite/measure — do not eyeball thumbnails). Confirm per dialog: frame ≈75% of the 1080 width; chrome (border/banner/✕) crisp; content proportionally scaled; no clipping/overflow; scroll where expected. Pay special attention to Settings/Level (≈1.5× up) and Mystery Spin (560px→~810px).

- [ ] **Step 3:** Deliver the screenshots to the user. Flag any dialog where the scale looks wrong; the fix knob is that dialog's `DIALOG_DESIGN_PCT` baseline (code constant) — adjust and re-render, do not reintroduce a per-dialog workbench setting.

- [ ] **Step 4:** `make test` (full) once more → green. Report the suite count.

---

## Self-review notes

- **Spec coverage:** global 75% (Tasks 5/6/8), content scaling crisp chrome (Tasks 1/3/4), remove per-dialog knob (Tasks 5/8), single global knob (Task 5), all dialogs incl. Level (Task 4/6) + Mystery (Task 7), scale-up-to-fill (no cap anywhere), verification (Task 9). ✔
- **Type consistency:** `scale_factor` (ScaleContainer), `content_scale` (opts key), `DIALOG_DESIGN_PCT` / `frame_width_pct` / `dialog_content_scale` (Kit) — used consistently across tasks.
- **Risk:** ScaleContainer wrapping-height convergence (Task 1) and Mystery's bespoke wiring (Task 7) — both covered by tests + Task 9 visual check.
