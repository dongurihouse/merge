# Rush FX workbench — split + per-effect knobs — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the UI workbench trigger each of the 7 Rush screen-juice effects individually, with a per-effect intensity knob (three for treefall), and have the saved knobs drive the live Expedition Rush.

**Architecture:** Effects in `rush_fx.gd` gain optional tuning params (defaults reproduce today's hardcoded values exactly, so every existing caller keeps working). `fx.gd` gets two additive params (`squash_pop` strength, `tick` dur). The workbench `rush_fx` element stores its demo context and exposes `_rush_fx_play(id)`, with a ▶ per effect plus knob sliders. `explore_rush.gd` reads the saved knobs and forwards them.

**Tech Stack:** Godot 4.6 GDScript; headless SceneTree test suites run via `engine/tools/run_suites.py`; config persisted in `games/grove/tools/ui_workbench_settings.json`.

**Defaults that reproduce today exactly** (so nothing changes until a slider moves):

| Knob key | Default | Reproduces |
|---|---|---|
| `merge_burst_count` | 20 | `clampi(20 + (tier-3)*4, 4, 40)` == old `clampi(8+tier*4, 8, 28)` |
| `score_tick_ms` | 400 | `400/1000 == Tune.TICK_T_COUNT (0.4)` |
| `score_pulse_pct` / `mult_pop_pct` | 100 | `100/100 == strength 1.0` (unchanged squash) |
| `combo_heat_size` | 24 | `clampi(24 + combo*3, 24, 54)` == old |
| `timer_low_secs` | 10 | old hardcoded threshold 10 |
| `treefall_debris` / `treefall_shake` / `treefall_hitstop_ms` | 18 / 16 / 60 | old `burst 18`, `shake 16.0`, `hitstop 0.06` |

Run after every step: `python3 engine/tools/run_suites.py <suite>` for the touched suite; `make test-fast` for engine slices; `make test` before merge.

---

### Task 1: `fx.gd` — `squash_pop` strength + `tick` dur (additive, backward-compatible)

**Files:**
- Modify: `engine/scripts/ui/fx.gd` (`squash_pop` ~192-204, `tick` ~483-498)
- Test: `engine/tests/fx_juice_tests.gd`

- [ ] **Step 1: Write failing tests** — append inside `_initialize()` in `engine/tests/fx_juice_tests.gd`, just before the final `print` summary line (find where it prints the pass/fail totals; put these above it):

```gdscript
	# --- squash_pop strength scales the impact pose (default 1.0 unchanged) -----------
	Save.set_setting("calm", false)
	var sps := Control.new(); sps.size = Vector2(80, 80); get_root().add_child(sps)
	FX.squash_pop(sps, 1.0)
	ok(sps.scale.is_equal_approx(Tune.SQUASH_K[0]), "squash_pop: strength 1.0 keeps the default squash pose")
	var sph := Control.new(); sph.size = Vector2(80, 80); get_root().add_child(sph)
	FX.squash_pop(sph, 0.5)
	var half := Vector2.ONE + (Tune.SQUASH_K[0] - Vector2.ONE) * 0.5
	ok(sph.scale.is_equal_approx(half), "squash_pop: strength 0.5 halves the deviation from rest")
	sps.queue_free(); sph.queue_free()

	# --- tick accepts a duration param; flag-off path snaps regardless --------------
	Features.FLAGS["wallet_tick"] = false
	var tl := Label.new(); tl.text = "0"; get_root().add_child(tl)
	FX.tick(tl, 1250, 0.2)
	ok(tl.text == "1250", "tick: flag off snaps to the value (custom dur accepted, no crash)")
	tl.queue_free()
	Features.FLAGS["wallet_tick"] = true
```

- [ ] **Step 2: Run, verify it fails**

Run: `python3 engine/tools/run_suites.py engine/tests/fx_juice_tests`
Expected: CRASH/FAIL — parse error `Invalid argument count` / `squash_pop()` called with 2 args, or `tick()` with 3.

- [ ] **Step 3: Implement** — in `engine/scripts/ui/fx.gd`.

Change `squash_pop` signature and scale lines:

```gdscript
static func squash_pop(node: Control, strength := 1.0) -> void:
	if not (node and is_instance_valid(node)):
		return
	node.pivot_offset = _center_pivot(node)
	if calm():
		var c := node.create_tween()
		c.tween_property(node, "scale", Vector2.ONE + (Tune.SQUASH_CALM - Vector2.ONE) * strength, Tune.POP_T_OUT).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		c.tween_property(node, "scale", Vector2.ONE, Tune.POP_T_SETTLE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		return
	node.scale = Vector2.ONE + (Tune.SQUASH_K[0] - Vector2.ONE) * strength
	var t := node.create_tween()
	for i in range(1, Tune.SQUASH_K.size()):
		t.tween_property(node, "scale", Vector2.ONE + (Tune.SQUASH_K[i] - Vector2.ONE) * strength, Tune.SQUASH_T[i - 1]).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
```

Change `tick` signature and the count tween duration:

```gdscript
static func tick(label: Label, to_value: int, dur := Tune.TICK_T_COUNT) -> void:
	if not Features.on("wallet_tick"):
		label.text = str(to_value)
		return
	var from := int(label.text) if label.text.is_valid_int() else 0
	var tw := label.create_tween()
	tw.tween_method(func(v: float) -> void: label.text = str(int(v)), float(from), float(to_value), dur)
```
(Leave the chip-pop tail of `tick` unchanged.)

- [ ] **Step 4: Run, verify it passes**

Run: `python3 engine/tools/run_suites.py engine/tests/fx_juice_tests`
Expected: PASS (all squash_pop/flash/shake/hitstop tests + the 3 new ones).

- [ ] **Step 5: Commit**

```bash
git add engine/scripts/ui/fx.gd engine/tests/fx_juice_tests.gd
git commit -m "fx: add squash_pop strength + tick dur (backward-compatible)"
```

---

### Task 2: `rush_fx.gd` — KNOBS table, `knob()` helper, `from_config` resolves knobs

**Files:**
- Modify: `engine/scripts/ui/rush_fx.gd` (after `EFFECTS`, and in `from_config`)
- Create: `engine/tests/rush_fx_tests.gd`
- Modify: `Makefile` (add the new suite to `ENGINE_TESTS`)

- [ ] **Step 1: Create the failing suite** — `engine/tests/rush_fx_tests.gd`:

```gdscript
extends SceneTree
## Headless tests for engine/scripts/ui/rush_fx.gd — the rush screen-juice registry: knob
## defaults/overrides, the knob() reader, and each effect honouring its tuning param.
##   godot --headless --path . -s res://engine/tests/rush_fx_tests.gd

const RushFx = preload("res://engine/scripts/ui/rush_fx.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const Features = preload("res://engine/scripts/core/features.gd")
const Save = preload("res://engine/scripts/core/save.gd")

var _pass := 0
var _fail := 0
func ok(cond: bool, label: String) -> void:
	if cond: _pass += 1; print("  PASS  ", label)
	else: _fail += 1; print("  FAIL  ", label)

func _initialize() -> void:
	# defaults: from_config with no rush_fx block returns every knob at its KNOBS default
	var d := RushFx.from_config({})
	ok(int(d.get("merge_burst_count", -1)) == RushFx.KNOBS["merge_burst_count"], "from_config: merge_burst_count defaults")
	ok(int(d.get("treefall_shake", -1)) == RushFx.KNOBS["treefall_shake"], "from_config: treefall_shake defaults")
	ok(bool(d.get("enabled", false)), "from_config: master enabled still defaults on")
	# overrides: a saved value wins
	var o := RushFx.from_config({"rush_fx": {"merge_burst_count": 7, "treefall_hitstop_ms": 120}})
	ok(int(o["merge_burst_count"]) == 7, "from_config: saved knob overrides the default")
	ok(int(o["treefall_hitstop_ms"]) == 120, "from_config: saved treefall_hitstop_ms overrides")
	ok(int(o["combo_heat_size"]) == RushFx.KNOBS["combo_heat_size"], "from_config: unmentioned knob keeps its default")
	# knob() reader
	ok(RushFx.knob(o, "merge_burst_count") == 7, "knob(): reads a present value")
	ok(RushFx.knob({}, "timer_low_secs") == RushFx.KNOBS["timer_low_secs"], "knob(): falls back to KNOBS default")
	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
```

- [ ] **Step 2: Run, verify it fails**

Run: `python3 engine/tools/run_suites.py engine/tests/rush_fx_tests`
Expected: CRASH — parse error `KNOBS` not found / `knob()` not found.

- [ ] **Step 3: Implement** — in `engine/scripts/ui/rush_fx.gd`, add after the `EFFECTS` const:

```gdscript
# id → default value for the per-effect intensity / feel knobs. The workbench edits these and
# saves them into the same rush_fx config block; the game reads them via from_config + knob().
# Defaults reproduce today's hardcoded numbers exactly (see the effect fns below).
const KNOBS := {
	"merge_burst_count": 20,
	"score_tick_ms": 400,
	"score_pulse_pct": 100,
	"mult_pop_pct": 100,
	"combo_heat_size": 24,
	"timer_low_secs": 10,
	"treefall_debris": 18,
	"treefall_shake": 16,
	"treefall_hitstop_ms": 60,
}

## Read a numeric knob from a resolved opts dict, falling back to its KNOBS default.
static func knob(opts: Dictionary, id: String) -> int:
	return int(opts.get(id, KNOBS.get(id, 0)))
```

Then extend `from_config` so it also resolves the knobs (add the loop before `return d`):

```gdscript
static func from_config(cfg: Dictionary) -> Dictionary:
	var r: Dictionary = cfg.get("rush_fx", {}) if cfg is Dictionary else {}
	var d := defaults()
	for k in d.keys():
		if r.has(k):
			d[k] = bool(r[k])
	for k in KNOBS.keys():
		d[k] = int(r.get(k, KNOBS[k]))
	return d
```

(Leave `defaults()` returning just the booleans — `from_config` layers the knobs on top.)

- [ ] **Step 4: Add the suite to the Makefile** — in `Makefile`, append ` engine/tests/rush_fx_tests` to the end of the `ENGINE_TESTS :=` line.

- [ ] **Step 5: Run, verify it passes**

Run: `python3 engine/tools/run_suites.py engine/tests/rush_fx_tests`
Expected: PASS (8 assertions).

- [ ] **Step 6: Commit**

```bash
git add engine/scripts/ui/rush_fx.gd engine/tests/rush_fx_tests.gd Makefile
git commit -m "rush_fx: KNOBS table + knob() reader + from_config resolves knobs"
```

---

### Task 3: `rush_fx.gd` — parameterize the 7 effect functions (optional params, defaults = today)

**Files:**
- Modify: `engine/scripts/ui/rush_fx.gd` (the effect fns ~51-90)
- Test: `engine/tests/rush_fx_tests.gd`

- [ ] **Step 1: Write failing tests** — append in `_initialize()` of `engine/tests/rush_fx_tests.gd`, before the summary `print`:

```gdscript
	# effects honour their params. Enable the gating flags + non-calm so the effect bodies run.
	Save.set_setting("calm", false)
	Features.FLAGS["celebrate_bursts"] = true
	# merge_burst: count + (tier-3)*4 → at count 20, tier 3 == 20 (today's value)
	var mh := Control.new(); get_root().add_child(mh)
	RushFx.merge_burst(mh, Vector2(10, 10), 3, 20)
	var pcount := 0
	for ch in mh.get_children():
		if ch is GPUParticles2D: pcount = int((ch as GPUParticles2D).amount)
	ok(pcount == FX.amount_for(20), "merge_burst: particle amount tracks the count knob (tier 3, count 20)")
	mh.queue_free()
	# cell_pop strength flows to squash_pop (pct 50 → half deviation)
	var cp := Control.new(); cp.size = Vector2(80, 80); get_root().add_child(cp)
	RushFx.cell_pop(cp, 50)
	ok(not cp.scale.is_equal_approx(Vector2.ONE), "cell_pop: applies a scaled squash (pct 50)")
	cp.queue_free()
	# treefall_crack accepts debris/shake/hitstop without error and bursts on the host
	var th := Control.new(); get_root().add_child(th)
	var tb := Control.new(); tb.size = Vector2(100, 100); get_root().add_child(tb)
	RushFx.treefall_crack(th, tb, Vector2(20, 20), true, 9, 24.0, 0.04)
	var has_burst := false
	for ch in th.get_children():
		if ch is GPUParticles2D: has_burst = true
	ok(has_burst, "treefall_crack: debris bursts with custom params (silent)")
	th.queue_free(); tb.queue_free()
```

- [ ] **Step 2: Run, verify it fails**

Run: `python3 engine/tools/run_suites.py engine/tests/rush_fx_tests`
Expected: CRASH — `merge_burst()`/`cell_pop()`/`treefall_crack()` called with too many args.

- [ ] **Step 3: Implement** — replace the effect fns in `engine/scripts/ui/rush_fx.gd` with these parameterized versions (signatures append optional params so existing callers keep working):

```gdscript
## A puff of leaves where two tiles fused; `count` is the base, the result tier nudges it.
static func merge_burst(host: Node, gpos: Vector2, tier: int, count := 20) -> void:
	FX.burst(host, gpos, LEAF, clampi(count + (tier - 3) * 4, 4, 40))

## Roll the score label up to `to_value` over `ms` milliseconds (vs a hard snap).
static func score_tick(label: Label, to_value: int, ms := 400) -> void:
	if label != null and is_instance_valid(label):
		FX.tick(label, to_value, maxf(0.01, ms / 1000.0))

## Pop a cell at `pct` strength (100 = the default squash). Used by score_pulse + mult_pop.
static func cell_pop(cell: Control, pct := 100) -> void:
	if cell != null and is_instance_valid(cell):
		FX.squash_pop(cell, maxf(0.0, pct / 100.0))

## The COMBO callout; `base_size` is the floor, the streak grows it (gold → straw → hot-orange).
static func combo_heat(host: Control, gpos: Vector2, combo: int, base_size := 24) -> void:
	var col := GOLD if combo < 5 else (STRAW if combo < 8 else HOT)
	var sz := clampi(base_size + combo * 3, base_size, base_size + 30)
	FX.floating_text(host, gpos, "COMBO ×%d" % combo, col, sz)

## The clock under `threshold` seconds: redden toward hot + a heartbeat pop. Call once per whole
## second; pass the seconds left. Above the threshold it restores the resting ink colour.
static func timer_low(label: Label, secs_left: int, silent: bool = false, threshold := 10) -> void:
	if label == null or not is_instance_valid(label):
		return
	if secs_left > threshold:
		label.add_theme_color_override("font_color", INK)
		return
	var warm := clampf(float(threshold - secs_left) / float(maxi(1, threshold)), 0.0, 1.0)
	label.add_theme_color_override("font_color", INK.lerp(HOT, warm))
	FX.squash_pop(label)
	if not silent:
		Audio.play("button_tap", -8.0, 1.4 + warm * 0.4)

## The timber LANDS with a crack — debris burst + jolt + a brief freeze, all tunable.
static func treefall_crack(host: Node, board: Control, gpos: Vector2, silent: bool = false, debris := 18, shake_amp := 16.0, hitstop_secs := 0.06) -> void:
	FX.burst(host, gpos, STRAW, debris)
	FX.shake(board, shake_amp)
	FX.hitstop(hitstop_secs)
	if not silent:
		Audio.play("tidy_poof", -1.0, 0.65)
```

- [ ] **Step 4: Run, verify it passes**

Run: `python3 engine/tools/run_suites.py engine/tests/rush_fx_tests`
Expected: PASS (all assertions).

- [ ] **Step 5: Confirm no caller broke** (existing callers omit the new params → defaults reproduce today)

Run: `python3 engine/tools/run_suites.py games/grove/tests/grove_explore_tests games/grove/tests/grove_workbench_tests`
Expected: PASS for both (no signature breakage).

- [ ] **Step 6: Commit**

```bash
git add engine/scripts/ui/rush_fx.gd engine/tests/rush_fx_tests.gd
git commit -m "rush_fx: parameterize the 7 effects (optional params, defaults reproduce today)"
```

---

### Task 4: `ui_workbench_view.gd` — knob params, per-effect ▶ Replay, knob rows

**Files:**
- Modify: `games/grove/tools/ui_workbench_view.gd` (`_params["rush_fx"]` ~the rush_fx entry; preview build ~752-803; sidebar ~2061-2066; add `_rush_fx_play` + `_rush_fx_ctx`)
- Test: `games/grove/tests/grove_workbench_tests.gd`

- [ ] **Step 1: Write failing tests** — add a method in `games/grove/tests/grove_workbench_tests.gd` and call it from the suite's `_initialize()` (find where other `_test_*` methods are invoked and add `_test_rush_fx_knobs()` alongside them). Use the file's existing `ok`/`fresh` helpers and the view instantiation pattern already used for the workbench (search the file for `ui_workbench_view` / `UiWorkbench` to copy how it builds the view; the view exposes `_selected`, `_build()`, `_rebuild_sidebar()`, `_sidebar_body`, and `_params`).

```gdscript
func _test_rush_fx_knobs() -> void:
	fresh("rush_fx_knobs")
	var view = load("res://games/grove/tools/UiWorkbench.tscn").instantiate()
	get_root().add_child(view)
	if view.get_child_count() == 0:
		view._ready()
	# params carry every rush_fx knob, defaulted from RushFx.KNOBS
	var p: Dictionary = view._params["rush_fx"]
	for k in RushFx.KNOBS.keys():
		ok(p.has(k) and int(p[k]) == int(RushFx.KNOBS[k]), "rush_fx params include knob %s at its default" % k)
	# selecting rush_fx builds a ▶ Replay per effect + the knob sliders
	view._selected = "rush_fx"
	view._rebuild_sidebar()
	var replays := view._sidebar_body.find_children("RushFxReplay_*", "Button", true, false)
	ok(replays.size() == RushFx.EFFECTS.size(), "one ▶ Replay button per effect (%d)" % RushFx.EFFECTS.size())
	var sliders := view._sidebar_body.find_children("*", "HSlider", true, false)
	ok(sliders.size() == RushFx.KNOBS.size(), "one knob slider per knob (%d)" % RushFx.KNOBS.size())
	# firing one effect does not error and does not require the toggle on
	view._params["rush_fx"]["merge_burst"] = false
	view._rush_fx_play("merge_burst")
	ok(true, "per-effect replay fires without error even when the effect toggle is off")
	view.queue_free()
```

Add `const RushFx = preload("res://engine/scripts/ui/rush_fx.gd")` near the top of the test file if not already present.

- [ ] **Step 2: Run, verify it fails**

Run: `python3 engine/tools/run_suites.py games/grove/tests/grove_workbench_tests`
Expected: FAIL — params lack knob keys / no `RushFxReplay_*` buttons / `_rush_fx_play` not found.

- [ ] **Step 3a: Add knob params** — in `games/grove/tools/ui_workbench_view.gd`, find the `"rush_fx": { ... }` entry in `_params` and add the nine knob keys with their defaults:

```gdscript
		"rush_fx": {
			"enabled": true, "merge_burst": true, "score_tick": true, "score_pulse": true,
			"mult_pop": true, "combo_heat": true, "timer_low": true, "treefall_crack": true,
			"merge_burst_count": 20, "score_tick_ms": 400, "score_pulse_pct": 100, "mult_pop_pct": 100,
			"combo_heat_size": 24, "timer_low_secs": 10,
			"treefall_debris": 18, "treefall_shake": 16, "treefall_hitstop_ms": 60,
		},
```

(These keys are NOT in `TEST_KEYS["rush_fx"]`, so they persist with the toggles. Confirm `TEST_KEYS` has no `rush_fx` entry, or an entry that does not list these keys.)

- [ ] **Step 3b: Add the knob-row map** — near the other rush_fx constants at the top of the file, add:

```gdscript
# per-effect knob slider specs for the rush_fx inspector: effect id → [[param, lo, hi], …]
const RUSH_FX_KNOBS := {
	"merge_burst": [["merge_burst_count", 4, 40]],
	"score_tick": [["score_tick_ms", 80, 600]],
	"score_pulse": [["score_pulse_pct", 40, 180]],
	"mult_pop": [["mult_pop_pct", 40, 180]],
	"combo_heat": [["combo_heat_size", 18, 60]],
	"timer_low": [["timer_low_secs", 3, 20]],
	"treefall_crack": [["treefall_debris", 4, 40], ["treefall_shake", 0, 40], ["treefall_hitstop_ms", 0, 160]],
}
var _rush_fx_ctx: Dictionary = {}
```

- [ ] **Step 3c: Refactor the preview build** — in the `"rush_fx":` branch of the gallery element builder (~752-803), store the demo refs in `_rush_fx_ctx`, point the Replay button at `_rush_fx_play("__all__")`, and REMOVE the auto-fire. Replace the `var fxp ... fire.call_deferred()` block (from `var fxp: Dictionary = p` through `fire.call_deferred()`) with:

```gdscript
				_rush_fx_ctx = {
					"score_label": demo.get_meta("score_label"), "mult_label": demo.get_meta("mult_label"),
					"time_label": demo.get_meta("time_label"), "score_cell": demo.get_meta("score_cell"),
					"mult_cell": demo.get_meta("mult_cell"), "tile_a": ta, "tile_b": tb,
					"wrap": wrap, "demo": demo, "tile_ctr": tile_ctr, "tile_px": tpx,
				}
				btn.text = "▶  Replay all"
				btn.pressed.connect(func() -> void: _rush_fx_play("__all__"))
```

- [ ] **Step 3d: Add `_rush_fx_play`** — add this method (near `_rebuild_sidebar` or the other rush_fx code):

```gdscript
# Fire one rush_fx effect (or "__all__") on the live demo context, reading the current knob
# values from _params. A single id fires regardless of its toggle (an explicit test trigger);
# "__all__" respects the enabled toggles, mirroring the game.
func _rush_fx_play(which: String) -> void:
	if _rush_fx_ctx.is_empty():
		return
	var p: Dictionary = _params["rush_fx"]
	var c := _rush_fx_ctx
	var sl: Label = c.get("score_label")
	var ml: Label = c.get("mult_label")
	var tl: Label = c.get("time_label")
	if sl != null: sl.text = "0"
	if ml != null: ml.text = "×1.0"
	if tl != null: tl.text = "0:30"
	var want := func(id: String) -> bool:
		return which == id or (which == "__all__" and RushFx.on(p, id))
	if c.get("tile_a") != null: FX.squash_pop(c["tile_a"])
	if c.get("tile_b") != null: FX.squash_pop(c["tile_b"])
	if want.call("merge_burst"): RushFx.merge_burst(c["wrap"], c["tile_ctr"], 3, int(p["merge_burst_count"]))
	if want.call("score_tick"): RushFx.score_tick(sl, 1250, int(p["score_tick_ms"]))
	elif which == "__all__" and sl != null: sl.text = "1,250"
	if want.call("score_pulse"): RushFx.cell_pop(c.get("score_cell"), int(p["score_pulse_pct"]))
	if ml != null: ml.text = "×2.0"
	if want.call("mult_pop"): RushFx.cell_pop(c.get("mult_cell"), int(p["mult_pop_pct"]))
	if want.call("combo_heat"): RushFx.combo_heat(c["wrap"], c["tile_ctr"] - Vector2(0.0, c["tile_px"]), 6, int(p["combo_heat_size"]))
	if tl != null: tl.text = "0:06"
	if want.call("timer_low"): RushFx.timer_low(tl, 6, true, int(p["timer_low_secs"]))
	if want.call("treefall_crack"): RushFx.treefall_crack(c["wrap"], c["demo"], c["tile_ctr"], true, int(p["treefall_debris"]), float(p["treefall_shake"]), int(p["treefall_hitstop_ms"]) / 1000.0)
```

- [ ] **Step 3e: Rebuild the sidebar block** — replace the `"rush_fx":` branch in `_rebuild_sidebar()` (~2061-2066) with per-effect groups (label + toggle + ▶ + knob sliders):

```gdscript
		"rush_fx":
			_group_header("Saved to config", true)
			_sidebar_body.add_child(_toggle_row("All effects (master)", "enabled"))
			_section_header("Each effect — flip · tune · ▶ to feel it (the game honours these)")
			for e in RushFx.EFFECTS:
				var fid := String(e.get("id", ""))
				_section_header(String(e.get("label", fid)))
				_sidebar_body.add_child(_toggle_row("On", fid))
				var rb := Button.new()
				rb.name = "RushFxReplay_%s" % fid
				rb.text = "▶  Replay"
				rb.set_meta("wb_active", true)
				rb.add_theme_font_size_override("font_size", 16)
				rb.pressed.connect(func() -> void: _rush_fx_play(fid))
				_sidebar_body.add_child(rb)
				for spec in RUSH_FX_KNOBS.get(fid, []):
					_sidebar_body.add_child(_slider_row(spec))
```

- [ ] **Step 4: Run, verify it passes**

Run: `python3 engine/tools/run_suites.py games/grove/tests/grove_workbench_tests`
Expected: PASS (params carry knobs; N replay buttons; sliders present; per-effect play no error).

- [ ] **Step 5: Commit**

```bash
git add games/grove/tools/ui_workbench_view.gd games/grove/tests/grove_workbench_tests.gd
git commit -m "workbench(rush_fx): per-effect ▶ Replay + knob sliders, knobs persisted"
```

---

### Task 5: `explore_rush.gd` — forward the saved knobs to the live rush

**Files:**
- Modify: `engine/scripts/scenes/explore_rush.gd` (`_merge` ~273-292, `_drop_timber` ~331-337, `_refresh_readouts` ~446-447)
- Test: `games/grove/tests/grove_explore_tests.gd`

- [ ] **Step 1: Write failing tests** — add a method to `games/grove/tests/grove_explore_tests.gd` and call it from `_initialize()` (alongside the other `_test_*` calls). It checks both the resolve (behavioral) and that each call site reads a knob (source-contains, since `_merge`/`_drop_timber` need a full live grid to trigger):

```gdscript
func _test_rush_fx_knob_forwarding() -> void:
	# the resolved opts the scene reads carry the knobs (overrides honoured)
	var RushFx = load("res://engine/scripts/ui/rush_fx.gd")
	var opts: Dictionary = RushFx.from_config({"rush_fx": {"treefall_shake": 33}})
	ok(RushFx.knob(opts, "treefall_shake") == 33, "from_config carries a saved knob the scene can read")
	# each gated call site forwards a knob value (guards the wiring without a live grid)
	var src := FileAccess.get_file_as_string("res://engine/scripts/scenes/explore_rush.gd")
	for needle in [
		"RushFx.knob(_fx, \"merge_burst_count\")",
		"RushFx.knob(_fx, \"score_tick_ms\")",
		"RushFx.knob(_fx, \"score_pulse_pct\")",
		"RushFx.knob(_fx, \"mult_pop_pct\")",
		"RushFx.knob(_fx, \"combo_heat_size\")",
		"RushFx.knob(_fx, \"timer_low_secs\")",
		"RushFx.knob(_fx, \"treefall_debris\")",
		"RushFx.knob(_fx, \"treefall_shake\")",
		"RushFx.knob(_fx, \"treefall_hitstop_ms\")",
	]:
		ok(src.find(needle) != -1, "explore_rush forwards %s" % needle)
```

- [ ] **Step 2: Run, verify it fails**

Run: `python3 engine/tools/run_suites.py games/grove/tests/grove_explore_tests`
Expected: FAIL — the `RushFx.knob(_fx, …)` needles are absent from explore_rush.gd.

- [ ] **Step 3: Implement** — in `engine/scripts/scenes/explore_rush.gd`, update each gated call site to pass the knob.

In `_merge`, replace the relevant lines:

```gdscript
	if RushFx.on(_fx, "merge_burst"):
		RushFx.merge_burst(self, ctr, int(win.tier), RushFx.knob(_fx, "merge_burst_count"))
	if RushFx.on(_fx, "score_pulse"):
		RushFx.cell_pop(_score_cell, RushFx.knob(_fx, "score_pulse_pct"))
	if RushFx.on(_fx, "mult_pop") and _mult > pre_mult + 0.001:
		RushFx.cell_pop(_mult_cell, RushFx.knob(_fx, "mult_pop_pct"))
```

and the combo + score-tick lines in `_merge`:

```gdscript
	if _combo >= 3:
		if RushFx.on(_fx, "combo_heat"):
			RushFx.combo_heat(self, ctr - Vector2(0, 42), _combo, RushFx.knob(_fx, "combo_heat_size"))
		else:
			FX.floating_text(self, ctr - Vector2(0, 42), "COMBO ×%d" % _combo, GOLD, 26)
	...
	if RushFx.on(_fx, "score_tick"):
		RushFx.score_tick(_lbl_score, Explore.score(), RushFx.knob(_fx, "score_tick_ms"))
	elif _lbl_score != null:
		_lbl_score.text = str(Explore.score())
```

In `_drop_timber`, the crack branch:

```gdscript
	if RushFx.on(_fx, "treefall_crack"):
		RushFx.treefall_crack(self, _board, _board.global_position + col_local, false, RushFx.knob(_fx, "treefall_debris"), float(RushFx.knob(_fx, "treefall_shake")), RushFx.knob(_fx, "treefall_hitstop_ms") / 1000.0)
	else:
		FX.shake(_board)
```

In `_refresh_readouts`, the timer urgency call:

```gdscript
			if RushFx.on(_fx, "timer_low"):
				RushFx.timer_low(_lbl_time, s, false, RushFx.knob(_fx, "timer_low_secs"))
```

- [ ] **Step 4: Run, verify it passes**

Run: `python3 engine/tools/run_suites.py games/grove/tests/grove_explore_tests`
Expected: PASS (resolve + all 9 forwarding needles).

- [ ] **Step 5: Commit**

```bash
git add engine/scripts/scenes/explore_rush.gd games/grove/tests/grove_explore_tests.gd
git commit -m "explore_rush: forward saved rush_fx knobs into the live effects"
```

---

### Task 6: Full sweep + visual verification

**Files:** none (verification only)

- [ ] **Step 1: Full test sweep**

Run: `make test`
Expected: every suite passes (engine + grove), 0 failed. If a fresh worktree shows texture-only failures, run `make import` first (the `.ctex` cache is per-checkout), then re-run.

- [ ] **Step 2: Capture the new sidebar** — reuse the temp full-workbench capture approach (instantiate the view, `_selected = "rush_fx"`, screenshot, crop the left ~380px). Confirm visually: a ▶ Replay per effect and a slider under each (three under Treefall crack). Delete the temp capture tool after; do not commit it.

```bash
make import >/dev/null 2>&1   # only if textures are missing in this worktree
# (write a temp SceneTree tool that sets _selected="rush_fx" and saves a PNG, run via `make shot TOOL=… ARGS=…`, then rm it)
```

- [ ] **Step 3: Spot-check the live wiring** — capture an Expedition Rush via the existing `rush_shot.gd` (or `make`-driven rush capture) with a tweaked config to confirm a knob visibly changes the live effect (e.g. set `treefall_shake` high and observe a stronger jolt). This is a confidence check; the automated guard is Task 5.

- [ ] **Step 4: Commit any verification tooling kept** (none expected — temp capture tools are deleted).

---

## Notes for the executor

- `_apply_edit()` rebuilds the preview (and thus `_rush_fx_ctx`) on every toggle/slider change; that is fine — there is no auto-fire, so rebuilding just resets the demo. The per-effect ▶ buttons live in the sidebar and persist across preview rebuilds.
- Effect signature changes are append-only with defaults equal to today's values, so the build stays green after Task 3 even before Tasks 4–5 pass the knobs.
- The Task 4 test counts knob sliders by type (`find_children("*", "HSlider", …)`) because the UI workbench `_slider_row` does not name its `HSlider`. With `rush_fx` selected, the only sliders in the sidebar are the knob sliders, so the count is exact.
