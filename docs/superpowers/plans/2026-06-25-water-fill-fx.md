# Water Fill FX Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a standalone Godot water-fill FX demo with a half-filled glass box, a growing/falling droplet, impact ripples, increased fluid motion, and damping back to calm.

**Architecture:** Put the animated/drawn water effect in a focused `Control` script so it can be tested without launching the demo runner. Add a standalone `SceneTree` tool that hosts the effect in a live window or renders a deterministic horizontal frame strip for visual verification. Add Makefile targets that match the existing `fx` and screenshot conventions.

**Tech Stack:** Godot 4.6 GDScript, code-drawn `Control`, existing `quiet_godot.sh` screenshot pattern, existing `engine/tools/run_suites.py` test runner.

## Global Constraints

- No gameplay integration.
- No new raster art or imported assets.
- No full fluid solver; this is a stylized surface simulation.
- No shader dependency for this version.
- Live command must be `make water-fx`.
- Capture command must be `make shot-water-fx OUT=/tmp/water_fill_demo.png`.
- Capture output must be a horizontal frame strip.
- Run `make test-fast` after implementation.

---

### Task 1: Testable Water Effect Component

**Files:**
- Create: `engine/scripts/ui/water_fill_effect.gd`
- Create: `engine/tests/water_fill_effect_tests.gd`
- Modify: `Makefile`

**Interfaces:**
- Produces: `WaterFillEffect`, a `Control` with:
  - `const LOOP_SECONDS: float`
  - `const IDLE_ENERGY: float`
  - `const IMPACT_ENERGY: float`
  - `func advance_for_test(delta: float) -> void`
  - `func set_time_for_test(value: float) -> void`
  - `func trigger_impact_for_test() -> void`
  - `func energy_for_test() -> float`
  - `func wave_height_for_test(unit_x: float) -> float`
  - `func drop_state_for_test() -> Dictionary`
- Consumes: only Godot built-ins.

- [ ] **Step 1: Write the failing test**

Create `engine/tests/water_fill_effect_tests.gd`:

```gdscript
extends SceneTree
## Headless tests for the code-drawn water fill FX component.
##   godot --headless --path . -s res://engine/tests/water_fill_effect_tests.gd

const WaterFillEffect = preload("res://engine/scripts/ui/water_fill_effect.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _initialize() -> void:
	var fx: Control = WaterFillEffect.new()
	fx.size = Vector2(640, 520)
	root.add_child(fx)
	await process_frame

	ok(is_equal_approx(fx.energy_for_test(), WaterFillEffect.IDLE_ENERGY),
		"starts at idle wave energy")

	fx.trigger_impact_for_test()
	ok(fx.energy_for_test() > WaterFillEffect.IDLE_ENERGY * 3.0,
		"impact injects substantially more wave energy")

	var center_wave := fx.wave_height_for_test(0.5)
	var edge_wave := fx.wave_height_for_test(0.1)
	ok(absf(center_wave - edge_wave) > 3.0,
		"impact wave is localized around the droplet hit point")

	for i in 180:
		fx.advance_for_test(1.0 / 60.0)
	ok(fx.energy_for_test() < WaterFillEffect.IDLE_ENERGY + 0.8,
		"wave energy damps back near idle")

	fx.set_time_for_test(0.9)
	var growing := fx.drop_state_for_test()
	ok(bool(growing.visible) and float(growing.radius) > 7.0,
		"droplet grows before falling")

	fx.set_time_for_test(1.8)
	var falling := fx.drop_state_for_test()
	ok(bool(falling.visible) and float(falling.y) > float(growing.y),
		"droplet falls downward after growing")

	fx.set_time_for_test(2.25)
	var after_hit := fx.drop_state_for_test()
	ok(not bool(after_hit.visible),
		"droplet disappears into the water after impact")

	fx.queue_free()
	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
```

- [ ] **Step 2: Register the test suite in the fast engine set**

In `Makefile`, add `engine/tests/water_fill_effect_tests` to `ENGINE_TESTS`.

- [ ] **Step 3: Run test to verify it fails**

Run:

```bash
godot --headless --path . -s res://engine/tests/water_fill_effect_tests.gd
```

Expected: failure because `res://engine/scripts/ui/water_fill_effect.gd` does not exist.

- [ ] **Step 4: Write minimal implementation**

Create `engine/scripts/ui/water_fill_effect.gd` as a `@tool extends Control` node. It should implement the public test helpers above, draw the tank/water/droplet/splash in `_draw()`, update `_time`, `_energy`, `_impact_age`, and splash particles in `_process(delta)`, and keep all randomness deterministic by using fixed splash bit definitions.

Implementation requirements:

```gdscript
@tool
extends Control

const LOOP_SECONDS := 4.8
const IDLE_ENERGY := 2.2
const IMPACT_ENERGY := 18.0
const IMPACT_TIME := 2.05
const IMPACT_X := 0.52

func advance_for_test(delta: float) -> void
func set_time_for_test(value: float) -> void
func trigger_impact_for_test() -> void
func energy_for_test() -> float
func wave_height_for_test(unit_x: float) -> float
func drop_state_for_test() -> Dictionary
```

Use `queue_redraw()` after state changes. The water sample must combine two sine waves with a localized impact pulse:

```gdscript
var base := sin(unit_x * TAU * 1.25 + _time * 2.0) * _energy
base += sin(unit_x * TAU * 2.4 - _time * 3.1) * _energy * 0.35
var dist := absf(unit_x - IMPACT_X)
var impact := exp(-dist * dist * 58.0) * sin(_impact_age * 13.0) * _impact_envelope() * 12.0
return base + impact
```

- [ ] **Step 5: Run test to verify it passes**

Run:

```bash
godot --headless --path . -s res://engine/tests/water_fill_effect_tests.gd
```

Expected: all checks pass.

- [ ] **Step 6: Commit**

```bash
git add Makefile engine/scripts/ui/water_fill_effect.gd engine/tests/water_fill_effect_tests.gd
git commit -m "fx: add tested water fill effect"
```

### Task 2: Standalone Demo Runner and Capture Target

**Files:**
- Create: `engine/tools/water_fill_demo.gd`
- Modify: `Makefile`

**Interfaces:**
- Consumes: `WaterFillEffect` from `res://engine/scripts/ui/water_fill_effect.gd`.
- Produces:
  - `make water-fx`
  - `make shot-water-fx OUT=/tmp/water_fill_demo.png`

- [ ] **Step 1: Write the failing capture smoke test**

No separate unit file is needed; use the command as the test. Before creating the runner, run:

```bash
engine/tools/quiet_godot.sh --path . -s res://engine/tools/water_fill_demo.gd -- /tmp/water_fill_demo.png
```

Expected: failure because `res://engine/tools/water_fill_demo.gd` does not exist.

- [ ] **Step 2: Add Makefile targets**

Modify `.PHONY` to include `water-fx` and `shot-water-fx`.

Add:

```make
water-fx: ## watch the water-fill FX live (a real window; close it to quit)
	$(GODOT) --path $(PROJECT) -s res://engine/tools/water_fill_demo.gd

shot-water-fx: ## quiet frame strip of the water-fill FX: make shot-water-fx [OUT=/tmp/water_fill_demo.png]
	$(QUIET) --path $(PROJECT) -s res://engine/tools/water_fill_demo.gd -- $(or $(OUT),/tmp/water_fill_demo.png)
```

- [ ] **Step 3: Implement the runner**

Create `engine/tools/water_fill_demo.gd`:

```gdscript
extends SceneTree
## Standalone look-dev harness for the water fill effect.
##   make water-fx
##   make shot-water-fx OUT=/tmp/water_fill_demo.png

const WaterFillEffect = preload("res://engine/scripts/ui/water_fill_effect.gd")

const CELL := Vector2i(420, 420)
const FRAMES := 10
const STEP := 0.36

func _initialize() -> void:
	if FileAccess.file_exists("res://override.cfg"):
		_capture()
	else:
		_live()

func _live() -> void:
	DisplayServer.window_set_title("Water fill FX demo")
	var screen := DisplayServer.screen_get_size()
	var win := Vector2i(980, 760)
	if screen.x > 0 and screen.y > 0:
		win.x = mini(win.x, screen.x - 80)
		win.y = mini(win.y, screen.y - 100)
	DisplayServer.window_set_size(win)
	DisplayServer.window_set_position((screen - win) / 2)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED

	var bg := ColorRect.new()
	bg.color = Color("#182332")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var fx: Control = WaterFillEffect.new()
	fx.size = Vector2(660, 540)
	fx.position = (Vector2(win) - fx.size) * 0.5
	root.add_child(fx)

func _capture() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var args := OS.get_cmdline_user_args()
	var out: String = String(args[0]) if args.size() >= 1 else "/tmp/water_fill_demo.png"

	var vp := SubViewport.new()
	vp.size = CELL
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var bg := ColorRect.new()
	bg.color = Color("#182332")
	bg.size = Vector2(CELL)
	vp.add_child(bg)

	var fx: Control = WaterFillEffect.new()
	fx.size = Vector2(360, 360)
	fx.position = Vector2(30, 30)
	vp.add_child(fx)
	await process_frame

	var strip := Image.create(CELL.x * FRAMES, CELL.y, false, Image.FORMAT_RGBA8)
	for i in FRAMES:
		fx.set_time_for_test(float(i) * STEP)
		RenderingServer.force_draw()
		await create_timer(0.04).timeout
		var frame := vp.get_texture().get_image()
		frame.convert(Image.FORMAT_RGBA8)
		strip.blit_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), Vector2i(CELL.x * i, 0))

	var err := strip.save_png(out)
	print("WATER_FX_STRIP saved=%s err=%d frames=%d size=%dx%d" % [out, err, FRAMES, strip.get_width(), strip.get_height()])
	quit(0 if err == OK else 1)
```

- [ ] **Step 4: Run capture to verify it passes**

Run:

```bash
make shot-water-fx OUT=/tmp/water_fill_demo.png
```

Expected: output contains `WATER_FX_STRIP saved=/tmp/water_fill_demo.png err=0`; PNG exists and is a horizontal strip.

- [ ] **Step 5: Commit**

```bash
git add Makefile engine/tools/water_fill_demo.gd
git commit -m "fx: add water fill demo runner"
```

### Task 3: Verification and Final Polish

**Files:**
- Modify only if verification reveals a concrete issue:
  - `engine/scripts/ui/water_fill_effect.gd`
  - `engine/tools/water_fill_demo.gd`
  - `Makefile`

**Interfaces:**
- Consumes: Task 1 and Task 2 outputs.
- Produces: verified frame strip and green fast tests.

- [ ] **Step 1: Run the registered single suite**

```bash
godot --headless --path . -s res://engine/tests/water_fill_effect_tests.gd
```

Expected: all checks pass.

- [ ] **Step 2: Run the required fast suite**

```bash
make test-fast
```

Expected: all active engine suites pass.

- [ ] **Step 3: Capture and inspect the strip**

```bash
make shot-water-fx OUT=/tmp/water_fill_demo.png
```

Expected:

- PNG exists at `/tmp/water_fill_demo.png`.
- Width is greater than height.
- Early frame is calm half-filled water.
- Middle frame shows droplet impact and higher ripples.
- Late frame returns toward calm.

- [ ] **Step 4: Commit any verification polish**

Only if changes were required:

```bash
git add engine/scripts/ui/water_fill_effect.gd engine/tools/water_fill_demo.gd Makefile
git commit -m "fx: polish water fill verification"
```
