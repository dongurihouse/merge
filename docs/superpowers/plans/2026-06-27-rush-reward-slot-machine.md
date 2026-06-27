# Rush reward → slot-machine reveal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Rush "Trade" screen's three-box spend choice with a direct score→spirits conversion revealed as a slot-machine cascade (one reel per spirit), reusing the existing mystery-gift reel machinery.

**Architecture:** Extract the reel spin/land mechanic from `engine/scripts/ui/login_mystery.gd` into a shared `engine/scripts/ui/slot_reel.gd` (parametrised by a tile-builder Callable and a per-reel shine flag). The daily mystery reveal delegates to it (keeping its currency tiles + pick phase); the reworked `engine/scripts/scenes/explore_trade.gd` uses it with spirit tiles and no pick. Conversion is `n = max(1, floor(score / 200))` (0 when score ≤ 0); spirits are granted up front via `Habitat.grant_chest`, so the animation is purely cosmetic. `Done` skips the reveal to the end on first press, returns to the Map on the second.

**Tech Stack:** Godot 4 / GDScript. Headless SceneTree tests via `make test-grove` (grove suites) and `make test-fast` (engine suites); full sweep `make test`.

---

## Spec

`docs/superpowers/specs/2026-06-27-rush-reward-slot-machine-design.md`.

## File structure

- **Create** `engine/scripts/ui/slot_reel.gd` — shared reel: `build_reel`, `spin_reels` (with a `finish` handle), `shine`, `cell_stylebox`. The choreography + land juice, lifted from `login_mystery.gd`, with the tile content supplied by the caller.
- **Modify** `engine/scripts/ui/login_mystery.gd` — delegate reel build + spin to `slot_reel.gd`; keep reward semantics, the pick phase, captions, grant. Public API unchanged.
- **Modify** `engine/scripts/core/explore.gd` — add `TRADE_RATE` + `trade_count(score)`; remove `BOXES` + `buy_box` (Task 5).
- **Rewrite** `engine/scripts/scenes/explore_trade.gd` — drop the boxes; convert + reveal as spirit reels; dual-purpose `Done`; banner "Rewards".
- **Modify** `games/grove/tests/grove_explore_tests.gd` — new `trade_count` + `slot_reel` tests; rewrite the Trade seam + layout tests; drop the box-icon test.

Each task is one commit. Run the named suite after every task; `make test` before handoff.

---

### Task 1: Conversion model (`Explore.trade_count`)

**Files:**
- Modify: `engine/scripts/core/explore.gd` (add a constant + a pure function near the other run-state helpers, ~line 196+)
- Test: `games/grove/tests/grove_explore_tests.gd`

- [ ] **Step 1: Write the failing test**

Add this function to `games/grove/tests/grove_explore_tests.gd` (anywhere among the `_test_*` funcs):

```gdscript
func _test_trade_count() -> void:
	ok(Explore.trade_count(0) == 0, "no score yields no spirits")
	ok(Explore.trade_count(150) == 1, "a sub-rate score still yields one spirit (min 1)")
	ok(Explore.trade_count(199) == 1, "just under the rate yields one spirit")
	ok(Explore.trade_count(200) == 1, "exactly the rate yields one spirit")
	ok(Explore.trade_count(400) == 2, "double the rate yields two spirits")
	ok(Explore.trade_count(852) == 4, "852 converts to four spirits (remainder discarded)")
```

Register it: in `_initialize()` add `_test_trade_count()` immediately after the `_test_run_state()` line (line 15).

- [ ] **Step 2: Run the test to verify it fails**

Run: `make test-grove`
Expected: FAIL — `Invalid call. Nonexistent function 'trade_count' in base ...explore.gd` (or the suite errors out on the missing method).

- [ ] **Step 3: Add the constant + function**

In `engine/scripts/core/explore.gd`, near the box constants (the `const BOXES := [...]` block, ~line 43) add:

```gdscript
const TRADE_RATE := 200          # score → spirits at the Rewards screen: floor(score / TRADE_RATE), min 1 if any score
```

Then, with the other `static func` run-state helpers (after `buy_box`, ~line 216) add:

```gdscript
## Convert a run's score to a spirit count for the Rewards screen: floor(score / TRADE_RATE), but at
## least 1 whenever the run scored anything (a run always pays out); 0 only for a literal 0 score.
static func trade_count(score: int) -> int:
	if score <= 0:
		return 0
	return maxi(1, score / TRADE_RATE)
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `make test-grove`
Expected: PASS — all six `trade_count` assertions green.

- [ ] **Step 5: Commit**

```bash
git add engine/scripts/core/explore.gd games/grove/tests/grove_explore_tests.gd
git commit -m "feat(explore): add trade_count — direct score→spirit conversion (min 1)"
```

---

### Task 2: Shared reel module (`slot_reel.gd`)

Lift the reel build + spin + land juice out of `login_mystery.gd` into a reusable module, parametrised by a tile-builder and a per-reel shine flag, plus a `finish` handle for the skip-to-end.

**Files:**
- Create: `engine/scripts/ui/slot_reel.gd`
- Test: `games/grove/tests/grove_explore_tests.gd`

- [ ] **Step 1: Write the failing test**

Add to `games/grove/tests/grove_explore_tests.gd`:

```gdscript
func _test_slot_reel() -> void:
	var SlotReel: GDScript = load("res://engine/scripts/ui/slot_reel.gd")
	var mk := func(_sym, w: float, h: float) -> Control:
		var c := Control.new()
		c.custom_minimum_size = Vector2(w, h)
		return c
	# a built reel sits landed on its target tile
	var reel: Control = SlotReel.build_reel(["a", "b", "c"], "c", 80.0, 84.0, 0, mk, true)
	var tile_h: float = float(reel.get_meta("tile_h"))
	var n_syms: int = int(reel.get_meta("n_syms"))
	var band: Control = reel.get_meta("band")
	ok(is_equal_approx(band.position.y, -tile_h * float(n_syms - 1)), "a built reel is landed on its target tile")
	ok(bool(reel.get_meta("shine")) == true, "build_reel records the shine flag")
	# spinning zero reels lands immediately
	var fired := {"v": false}
	SlotReel.spin_reels(self, [], null, func() -> void: fired.v = true)
	ok(fired.v, "spinning zero reels fires on_all_landed at once")
	# finish() snaps every band to its landed tile and fires on_all_landed exactly once
	var host := Control.new()
	get_root().add_child(host)
	var r0: Control = SlotReel.build_reel(["a", "b"], "b", 80.0, 84.0, 0, mk, false)
	var r1: Control = SlotReel.build_reel(["a", "b"], "a", 80.0, 84.0, 1, mk, false)
	host.add_child(r0)
	host.add_child(r1)
	(r0.get_meta("band") as Control).position.y = 0.0
	(r1.get_meta("band") as Control).position.y = 0.0
	var done := {"n": 0}
	var handle: Dictionary = SlotReel.spin_reels(host, [r0, r1], null, func() -> void: done.n += 1)
	(handle["finish"] as Callable).call()
	var b0: Control = r0.get_meta("band")
	ok(is_equal_approx(b0.position.y, -float(r0.get_meta("tile_h")) * float(int(r0.get_meta("n_syms")) - 1)), "finish() snaps a reel to its landed tile")
	ok(done.n == 1, "finish() fires on_all_landed exactly once")
	host.queue_free()
```

Register it: in `_initialize()` add `_test_slot_reel()` right after `_test_trade_count()`.

- [ ] **Step 2: Run the test to verify it fails**

Run: `make test-grove`
Expected: FAIL — cannot load `res://engine/scripts/ui/slot_reel.gd` (file does not exist yet).

- [ ] **Step 3: Create `engine/scripts/ui/slot_reel.gd`**

```gdscript
extends RefCounted
## Shared slot-machine REEL mechanic — the spin choreography + land juice, factored out of the daily
## mystery reveal (ui/login_mystery.gd) so the Rush reward (scenes/explore_trade.gd) reuses the exact
## same "all reels whir → land left→right with a thunk + shine" feel. The CALLER supplies the per-tile
## content via a make_tile Callable (currency rows / spirit faces) and a per-reel `shine` flag; this
## module owns the band, the clipped window, the staggered tweens, the bounce/flash/chime/shine, plus a
## finish() handle that snaps every reel to its landed state (the Rush "Done = skip to the end" path).

const FX = preload("res://engine/scripts/ui/fx.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Pal = Game.PALETTE
const STRAW := Pal.STRAW
const CELL_ART := "res://games/grove/assets/ui/kit/daily_card.png"

# reel spin pacing (owner feel dial). Reels ALL start together and STOP one-by-one (left→right): reel i
# whirs longer → lands later; the last hangs an extra beat. cfg passed to spin_reels overrides any of these.
const REEL_SYMS := 10            # tiles per band (decoys + the target)
const REEL_SPIN := 1.0           # reel 0 spin time (sec)
const REEL_STAGGER := 0.45       # +spin time per reel index (gap between successive STOPS)
const REEL_ANTICIPATE := 0.5     # the LAST reel hangs a touch longer
const REEL_BLUR_ALPHA := 0.78    # band opacity while whirring fast; 1.0 when landed

# --- build --------------------------------------------------------------------------

## Build one reel LANDED on `target`. `pool` are the symbols whizzing past (decoys); `make_tile.call(
## symbol, win_w, win_h)` returns the Control for one tile's content (it gets centred in the window).
## `index` desyncs neighbours + lengthens the band (so reel i lands later). `shine_on_land` marks this
## reel to glow when it lands (premium / high tier). Metas: reward(=target), band, tile_h, n_syms,
## shine, selected, tap (a disabled full-rect button a caller may enable for a pick phase).
static func build_reel(pool: Array, target, cw: float, ch: float, index: int, make_tile: Callable, shine_on_land: bool) -> Control:
	var reel := Control.new()
	reel.custom_minimum_size = Vector2(cw, ch)
	reel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reel.set_meta("reward", target)
	reel.set_meta("selected", false)
	reel.set_meta("shine", shine_on_land)

	var bg := PanelContainer.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_theme_stylebox_override("panel", cell_stylebox())
	reel.add_child(bg)

	var inset: float = 8.0
	var win := Control.new()
	win.name = "ReelWin"
	win.clip_contents = true
	win.mouse_filter = Control.MOUSE_FILTER_IGNORE
	win.set_anchors_preset(Control.PRESET_FULL_RECT)
	win.offset_left = inset
	win.offset_top = inset
	win.offset_right = -inset
	win.offset_bottom = -inset
	reel.add_child(win)
	var win_w: float = cw - inset * 2.0
	var win_h: float = ch - inset * 2.0

	var syms: Array = _reel_symbols(pool, target, REEL_SYMS - 1, index * 3 + 1)
	var band := VBoxContainer.new()
	band.name = "ReelBand"
	band.add_theme_constant_override("separation", 0)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for s in syms:
		var tile := CenterContainer.new()
		tile.custom_minimum_size = Vector2(win_w, win_h)
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(make_tile.call(s, win_w, win_h))
		band.add_child(tile)
	band.custom_minimum_size = Vector2(win_w, win_h * syms.size())
	band.size = Vector2(win_w, win_h * syms.size())
	band.position = Vector2(0, -win_h * float(syms.size() - 1))
	win.add_child(band)
	reel.set_meta("band", band)
	reel.set_meta("tile_h", win_h)
	reel.set_meta("n_syms", syms.size())

	var tap := Button.new()
	tap.name = "ReelTap"
	tap.flat = true
	tap.focus_mode = Control.FOCUS_NONE
	tap.disabled = true
	tap.set_anchors_preset(Control.PRESET_FULL_RECT)
	reel.add_child(tap)
	reel.set_meta("tap", tap)
	return reel

# The reel's scroll symbols: `count` decoys (cycling the pool from `offset` for per-reel desync) then the
# TARGET as the last (landing) tile.
static func _reel_symbols(pool: Array, target, count: int, offset: int) -> Array:
	var syms: Array = []
	var src: Array = pool if not pool.is_empty() else [target]
	for j in count:
		syms.append(src[(j + offset) % src.size()])
	syms.append(target)
	return syms

## The shared parchment-cell stylebox (the daily_card look; a code fallback if the art is absent).
static func cell_stylebox() -> StyleBox:
	if ResourceLoader.exists(CELL_ART):
		var st := StyleBoxTexture.new()
		st.texture = load(CELL_ART)
		st.set_texture_margin_all(28.0)
		st.content_margin_left = 8
		st.content_margin_right = 8
		st.content_margin_top = 7
		st.content_margin_bottom = 7
		return st
	var cf := StyleBoxFlat.new()
	cf.bg_color = Color(Pal.CREAM, 0.9)
	cf.set_corner_radius_all(12)
	cf.set_border_width_all(1)
	cf.border_color = Color(Pal.BARK, 0.4)
	cf.content_margin_left = 8
	cf.content_margin_right = 8
	cf.content_margin_top = 7
	cf.content_margin_bottom = 7
	return cf

# --- spin ---------------------------------------------------------------------------

## Spin every reel at once; stop one-by-one (left→right). Returns {finish: Callable} — call finish() to
## SNAP all reels to their landed state immediately (kills the tweens, no cascade) and fire on_all_landed
## if it hasn't run (the Rush "Done = skip" path). cfg overrides: spin, stagger, anticipate (floats);
## total_cap (float, 0 = uncapped — compress the stagger so the whole cascade fits within total_cap sec).
static func spin_reels(host: Control, reels: Array, dialog: Control, on_all_landed: Callable, cfg: Dictionary = {}) -> Dictionary:
	var n: int = reels.size()
	var state := {"tweens": [], "landed": {}, "done": false}
	if n == 0:
		on_all_landed.call()
		state.done = true
		return {"finish": func() -> void: pass}
	var spin: float = float(cfg.get("spin", REEL_SPIN))
	var stagger: float = float(cfg.get("stagger", REEL_STAGGER))
	var anticipate: float = float(cfg.get("anticipate", REEL_ANTICIPATE))
	var cap: float = float(cfg.get("total_cap", 0.0))
	if cap > 0.0 and n > 1:
		var natural: float = spin + float(n - 1) * stagger + anticipate
		if natural > cap:
			stagger = maxf(0.0, (cap - spin - anticipate) / float(n - 1))
	var land_one := func(i: int) -> void:
		if state.landed.has(i):
			return
		state.landed[i] = true
		_land_reel(reels[i], i, n, dialog, false)
	for i in n:
		var reel: Control = reels[i]
		var band: Control = reel.get_meta("band")
		var tile_h: float = float(reel.get_meta("tile_h"))
		var n_syms: int = int(reel.get_meta("n_syms"))
		band.position.y = 0.0
		band.modulate.a = REEL_BLUR_ALPHA
		var landed_y: float = -tile_h * float(n_syms - 1)
		var dur: float = spin + float(i) * stagger + (anticipate if i == n - 1 else 0.0)
		var ri := i
		var t := host.create_tween()
		t.tween_property(band, "position:y", landed_y, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(band, "modulate:a", 1.0, dur * 0.4).set_delay(dur * 0.6)
		t.tween_callback(func() -> void: land_one.call(ri))
		if i == n - 1:
			t.tween_callback(func() -> void:
				if not state.done:
					state.done = true
					on_all_landed.call())
		state.tweens.append(t)
	var finish := func() -> void:
		for t in state.tweens:
			if t != null and t.is_valid():
				t.kill()
		for i in n:
			var reel: Control = reels[i]
			var band: Control = reel.get_meta("band")
			var tile_h: float = float(reel.get_meta("tile_h"))
			var n_syms: int = int(reel.get_meta("n_syms"))
			band.position.y = -tile_h * float(n_syms - 1)
			band.modulate.a = 1.0
			if not state.landed.has(i):
				state.landed[i] = true
				_land_reel(reel, i, n, dialog, true)
		if not state.done:
			state.done = true
			on_all_landed.call()
	return {"finish": finish}

# A reel lands: bounce + flash + escalating chime + shine (if its `shine` meta is set; the `top` meta
# shines hardest + shakes the dialog). `quiet` skips the bounce/flash/chime/shake (the skip-to-end snap)
# but still applies the shine, so the final picture matches a full cascade.
static func _land_reel(reel: Control, idx: int, total: int, dialog: Control, quiet: bool) -> void:
	if not is_instance_valid(reel):
		return
	var band: Control = reel.get_meta("band")
	if is_instance_valid(band):
		band.modulate.a = 1.0
	var top: bool = bool(reel.get_meta("top", false))
	if bool(reel.get_meta("shine", false)):
		shine(reel, top)
	if quiet:
		return
	reel.pivot_offset = Vector2(reel.size.x * 0.5, reel.size.y)
	reel.scale = Vector2(1.14, 0.82)
	var t := reel.create_tween()
	t.tween_property(reel, "scale", Vector2(0.96, 1.08), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(reel, "scale", Vector2.ONE, 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_flash(reel, top)
	if top and is_instance_valid(dialog):
		FX.shake(dialog, FX.Tune.SHAKE_BIG_AMP)
	Audio.play("merge_success", -4.0, 1.04 + float(idx) / float(maxi(1, total)) * 0.5)

# A quick impact flash over a landed reel (gold + bigger for the top prize); fades out fast.
static func _flash(reel: Control, strong: bool) -> void:
	var fl := ColorRect.new()
	fl.color = (Color(1, 0.95, 0.7, 0.85) if strong else Color(1, 1, 1, 0.6))
	fl.set_anchors_preset(Control.PRESET_FULL_RECT)
	fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reel.add_child(fl)
	if not reel.is_inside_tree():
		fl.queue_free()
		return
	var t := fl.create_tween()
	t.tween_property(fl, "modulate:a", 0.0, 0.26 if strong else 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_callback(fl.queue_free)

## The shine: a warm glow BEHIND the band that gently pulses + a one-shot sparkle burst on land. `strong`
## (the richest reel) glows warmer + bursts bigger. Public — login_mystery.reveal_static calls it too.
static func shine(reel: Control, strong: bool) -> void:
	if reel.has_node("Shine"):
		return
	var hi: float = 0.5 if strong else 0.34
	var glow := ColorRect.new()
	glow.name = "Shine"
	glow.color = Color(STRAW, hi)
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reel.add_child(glow)
	reel.move_child(glow, 1)
	if reel.is_inside_tree():
		var pt := glow.create_tween().set_loops()
		pt.tween_property(glow, "color:a", hi * 0.5, 0.8).set_trans(Tween.TRANS_SINE)
		pt.tween_property(glow, "color:a", hi, 0.8).set_trans(Tween.TRANS_SINE)
	FX.burst(reel, reel.size * 0.5, STRAW, 18 if strong else 11)
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `make test-grove`
Expected: PASS — the five `_test_slot_reel` assertions green.

- [ ] **Step 5: Commit**

```bash
git add engine/scripts/ui/slot_reel.gd games/grove/tests/grove_explore_tests.gd
git commit -m "feat(ui): add shared slot_reel module (build/spin/finish/shine)"
```

---

### Task 3: Delegate the mystery reveal to `slot_reel.gd`

Refactor `login_mystery.gd` so its reel build + spin route through `slot_reel.gd`. Its public API (`open`, `build_reveal`, `reveal_width`, `reveal_static`, `replay_spin`, `_reveal_card`, `reward_value`, `is_premium`, `enter_pick`) and all reel metas stay identical — verified by the existing `login_tests` + `grove_workbench_tests`.

**Files:**
- Modify: `engine/scripts/ui/login_mystery.gd`

- [ ] **Step 1: Add the SlotReel import + drop the moved constants**

In `engine/scripts/ui/login_mystery.gd`, after the existing `const Overlay = ...` line (~line 17) add:

```gdscript
const SlotReel = preload("res://engine/scripts/ui/slot_reel.gd")
```

Delete the now-shared constants: the `const CELL_ART := ...` line (~23) and the whole reel-pacing block `const REEL_SYMS ... const REEL_BLUR_ALPHA` (~29–33). (`OVERLAY_NAME`, `KIT_PATH` stay.)

- [ ] **Step 2: Route the reel build through SlotReel in `build_reveal`**

Replace the reel-construction loop (the `for i in options.size():` block that calls `_reel(...)`, ~lines 130–135) with:

```gdscript
	for i in options.size():
		var reel: Control = SlotReel.build_reel(options, options[i], cw, ch, i,
			func(sym, w, _h) -> Control: return _reward_amounts(load(KIT_PATH), sym, w),
			is_premium(options[i]))
		reel.set_meta("top", i == top_i)
		reel.set_meta("index", i)
		reels.append(reel)
		row.add_child(reel)
```

- [ ] **Step 3: Route the spin + shine + cell art through SlotReel**

In `open()`, change the spin call (~line 89) from `_spin_reels(overlay, reels, dialog, ...)` to:

```gdscript
	SlotReel.spin_reels(overlay, reels, dialog, func() -> void:
		enter_pick(reels, win, caption, claim, func(picked: Array) -> void:
			_grant_and_finish(overlay, picked, caption, on_done, false)))
```

In `replay_spin()`, change `_spin_reels(host, reels, null, ...)` to `SlotReel.spin_reels(host, reels, null, on_done if on_done.is_valid() else (func() -> void: pass))`.

In `reveal_static()`, change `shine(reel, ...)` to `SlotReel.shine(reel, bool((reel as Control).get_meta("top", false)))`.

In `_reveal_card()`, change `_cell_stylebox()` to `SlotReel.cell_stylebox()`.

- [ ] **Step 4: Delete the moved private functions**

Remove these now-duplicated functions from `login_mystery.gd` (they live in `slot_reel.gd` now): `_reel`, `_reel_symbols`, `_reel_tile`, `_cell_stylebox`, `_spin_reels`, `_land_reel`, `_flash`, `shine`. Keep everything else (`reward_value`, `is_premium`, `_top_value_index`, `_reward_amounts`, `_reveal_card`, `enter_pick`, `_set_reel_selected`, `_grant_and_finish`, `_dismiss`, `_celebrate`, `open`, `build_reveal`, `reveal_width`, `reveal_static`, `replay_spin`).

- [ ] **Step 5: Run the mystery + workbench tests to verify green**

Run: `make test-fast` (engine suites — includes `login_tests`)
Expected: PASS — the mystery reveal suite is unchanged in behaviour.

Run: `make test-grove` (includes `grove_workbench_tests`)
Expected: PASS — the workbench's `build_reveal` / `reveal_static` / `replay_spin` previews still build.

- [ ] **Step 6: Commit**

```bash
git add engine/scripts/ui/login_mystery.gd
git commit -m "refactor(ui): route mystery reveal through shared slot_reel"
```

---

### Task 4: Rewrite the Rewards screen (`explore_trade.gd`)

Drop the boxes; convert the score and reveal the spirits as reels; make `Done` skip-then-close; rename the banner. Then rewrite the screen's tests.

**Files:**
- Rewrite: `engine/scripts/scenes/explore_trade.gd`
- Test: `games/grove/tests/grove_explore_tests.gd` (rewrite `_test_screens`, `_test_trade_reward_dialog_layout`; remove `_test_trade_box_icons`)

- [ ] **Step 1: Rewrite the screen**

Replace the entire contents of `engine/scripts/scenes/explore_trade.gd` with:

```gdscript
extends Control
## Explore · Rewards — the final beat of a Rush run. The run's SCORE is converted DIRECTLY into spirits
## (Explore.trade_count → floor(score / TRADE_RATE), min 1 if any score) and they are REVEALED as
## slot-machine reels — one reel per spirit — reusing the shared ui/slot_reel.gd spin (the same feel as
## the daily mystery reveal). There is NO choice on this screen; its job is the payout. The spirits are
## granted up front via Habitat.grant_chest, so the reveal is cosmetic. Done SKIPS the reveal to the end
## on the first press, and returns to the Map on the second.

const G = preload("res://engine/scripts/core/content.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const Explore = preload("res://engine/scripts/core/explore.gd")
const Habitat = preload("res://engine/scripts/core/habitat.gd")
const Hud = preload("res://engine/scripts/ui/hud.gd")
const SceneWarm = preload("res://engine/scripts/core/scene_warm.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const SlotReel = preload("res://engine/scripts/ui/slot_reel.gd")

const INK := Color("#43352B")
const PARCH := Color("#F3E7CE")
const STRAW := Color("#D9B679")
const DIALOG_MAX_W := 540.0
const SHINE_TIER := 3                              # a spirit landing at tier ≥ this shines (the "jackpot" beat)
const SPIN_CFG := {"spin": 1.2, "stagger": 0.55, "anticipate": 0.5, "total_cap": 3.5}  # slower than the mystery reveal

var _hud_refresh := Callable()
var _root: Control = null
var _granted: Array = []                           # the {kind,tier} spirits this run (already in the hand)
var _reels: Array = []                             # the reel Controls, row order
var _caption: Label = null
var _dialog: Control = null
var _spin: Dictionary = {}                         # {finish: Callable} from SlotReel.spin_reels
var _finished := false

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#EAD9B5")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var hud := Hud.build(self, {"on_level": func() -> void: pass})
	_hud_refresh = hud.get("refresh", Callable())
	_build()

func _build() -> void:
	var Kit: GDScript = load("res://games/grove/tools/ui_workbench_kit.gd")
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_root = center

	# convert the run score straight into spirits + drop them in the hand (the reveal is cosmetic over this)
	var n := Explore.trade_count(Explore.score())
	_granted = Habitat.grant_chest(n)

	var viewport_size := _viewport_size()
	var width: float = minf(viewport_size.x * 0.92, DIALOG_MAX_W)
	var opts: Dictionary = Kit.dialog_opts_from_config(Kit.load_config(Kit.CONFIG_PATH))
	opts["banner_text"] = "Rewards"
	opts["banner_icon_id"] = "star"
	opts["banner_font"] = 30
	opts["list_max_h"] = viewport_size.y * 0.74
	opts["on_close"] = func() -> void: _on_done_pressed()
	var dialog: Control = Kit.dialog_frame(_reveal_body(Kit, width), width, opts)
	dialog.name = "TradeDialog"
	dialog.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dialog.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	center.add_child(dialog)
	FX.pop_in(dialog)
	_dialog = dialog

	if _granted.is_empty():
		_finished = true
		if _caption != null:
			_caption.text = "No spirits this run."
	else:
		_spin = SlotReel.spin_reels(self, _reels, dialog, func() -> void: _on_all_landed(), SPIN_CFG)

func _on_all_landed() -> void:
	_finished = true
	if _caption != null:
		_caption.text = "+%d spirit%s to your hand" % [_granted.size(), "" if _granted.size() == 1 else "s"]

func _viewport_size() -> Vector2:
	if is_inside_tree():
		return get_viewport_rect().size
	return Vector2(640.0, 720.0)

func _reveal_body(Kit: GDScript, width: float) -> Control:
	var col := VBoxContainer.new()
	col.name = "RewardBody"
	col.custom_minimum_size = Vector2(maxf(280.0, width - 92.0), 0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)

	var score_chip: Control = Kit.amount_chip("star", "Score  %d" % Explore.score())
	score_chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(score_chip)

	_caption = _label("Revealing your spirits…", 18)
	_caption.name = "RewardCaption"
	_caption.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_caption)

	var grid := GridContainer.new()
	grid.name = "RewardReels"
	grid.columns = clampi(_granted.size(), 1, 5)
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var cols: int = maxi(1, grid.columns)
	var cw: float = clampf((width - 72.0 - float(cols - 1) * 10.0) / float(cols), 64.0, 116.0)
	var ch: float = cw * 1.04
	var decoys := _decoy_symbols()
	var top_i := _top_tier_index(_granted)
	_reels = []
	for i in _granted.size():
		var sp: Dictionary = _granted[i]
		var reel: Control = SlotReel.build_reel(decoys, sp, cw, ch, i, _spirit_tile, int(sp.get("tier", 1)) >= SHINE_TIER)
		reel.set_meta("top", i == top_i)
		_reels.append(reel)
		grid.add_child(reel)
	col.add_child(grid)

	var done: Button = Kit.pill_button("Done", {"bg": "cream", "art": true, "font": 22})
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	done.pressed.connect(_on_done_pressed)
	col.add_child(done)
	return col

# the faces whizzing past during a spin: every unlocked kind at tier 1 (variety); the reel still lands on
# its real {kind,tier}. SlotReel falls back to [target] when this is empty (a single-kind whir).
func _decoy_symbols() -> Array:
	var g := Save.grove()
	var kinds: Array = Explore.unlocked_pool(g.get("unlocks", {}), g.get("gates", []))
	var out: Array = []
	for k in kinds:
		out.append({"kind": String(k), "tier": 1})
	return out

# the index of the highest-tier granted spirit (the reel that shines hardest); -1 if none.
func _top_tier_index(spirits: Array) -> int:
	var best := -1
	var best_t := -1
	for i in spirits.size():
		var tr := int((spirits[i] as Dictionary).get("tier", 1))
		if tr > best_t:
			best_t = tr
			best = i
	return best

# one reel tile's content: a spirit face (icon + name + tier pips). `sym` = {kind,tier}; SlotReel centres it.
func _spirit_tile(sym, w: float, _h: float) -> Control:
	var d: Dictionary = sym
	var holder := VBoxContainer.new()
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	holder.add_theme_constant_override("separation", 3)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_spirit_icon(String(d.get("kind", "")), w * 0.5))
	var nm := _label(String(d.get("kind", "")), 12, true)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	holder.add_child(nm)
	holder.add_child(_tier_pips(int(d.get("tier", 1))))
	return holder

func _tier_pips(tier: int) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for _i in maxi(1, tier):
		var dot := ColorRect.new()
		dot.color = Color(STRAW, 0.95)
		dot.custom_minimum_size = Vector2(6, 6)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(dot)
	return row

func _on_done_pressed() -> void:
	Audio.play("button_tap", -2.0)
	if not _finished:
		if _spin.has("finish"):
			(_spin["finish"] as Callable).call()
		return
	_on_done()

func _on_done() -> void:
	SceneWarm.go(get_tree(), "res://engine/scenes/Map.tscn")

# --- widgets ---------------------------------------------------------------------
# The spirit icon: real art when present, else the placeholder disc with two eyes (named SpiritEye0/1).
func _spirit_icon(kind: String, px: float) -> Control:
	var icon := Control.new()
	icon.name = "SpiritIcon"
	icon.custom_minimum_size = Vector2(px, px)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path := G.resident_art(kind)
	if path != "" and ResourceLoader.exists(path):
		var t := TextureRect.new()
		t.texture = load(path)
		t.set_anchors_preset(Control.PRESET_FULL_RECT)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.add_child(t)
	else:
		var disc := Panel.new()
		disc.set_anchors_preset(Control.PRESET_FULL_RECT)
		var ds := StyleBoxFlat.new()
		ds.bg_color = Color(STRAW, 0.95)
		ds.set_corner_radius_all(int(px / 2.0))
		disc.add_theme_stylebox_override("panel", ds)
		disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.add_child(disc)
		var eye_size := Vector2(maxf(4.0, px * 0.09), maxf(5.0, px * 0.12))
		var eye_gap := px * 0.24
		for i in 2:
			var eye := ColorRect.new()
			eye.name = "SpiritEye%d" % i
			eye.color = Color(INK, 0.82)
			eye.size = eye_size
			eye.position = Vector2(px * 0.5 + (-0.5 + float(i)) * eye_gap - eye_size.x * 0.5, px * 0.50)
			eye.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.add_child(eye)
	return icon

# kept for tests: a bare spirit face (the placeholder-eye coverage).
func _spirit_widget(kind: String, px: float) -> Control:
	return _spirit_icon(kind, px)

func _label(text: String, size: int, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", INK)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if bold:
		l.add_theme_color_override("font_outline_color", PARCH)
		l.add_theme_constant_override("outline_size", 2)
	return l
```

- [ ] **Step 2: Rewrite the screen's tests**

In `games/grove/tests/grove_explore_tests.gd`:

(a) Remove the `_test_trade_box_icons()` call from `_initialize()` (line 17) and delete the whole `_test_trade_box_icons()` function (~lines 265–284).

(b) Replace the seam block inside `_test_screens()` — from the comment `# the seam: buying a box ...` down to the `t.queue_free()` (~lines 228–263) — with:

```gdscript
	# the seam: opening the Rewards screen converts the run score DIRECTLY into hand spirits
	fresh("explore_trade_seam")
	var z := 0
	var g := Save.grove()
	var unl := {}
	for sp in G.MAPS[z].spots:
		unl[String(sp.id)] = true
	g["unlocks"] = unl
	g["gates"] = [z]
	Save.grove_write()
	Explore.begin_run({})
	Explore.add_score(400)                          # 400 / 200 = 2 spirits
	var pool: Array = Explore.unlocked_pool(unl, [z])
	var hand_before := Habitat.hand().size()
	var t = load("res://engine/scenes/ExploreTrade.tscn").instantiate()
	get_root().add_child(t)
	if t.get_child_count() == 0:
		t._ready()
	ok(Habitat.hand().size() == hand_before + 2, "opening the Rewards screen grants floor(score / RATE) spirits to the hand")
	var last: Dictionary = Habitat.hand()[Habitat.hand().size() - 1]
	ok(pool.has(String(last.kind)), "a granted spirit's kind comes from the unlocked pool")
	ok(int(last.tier) >= 1 and int(last.tier) <= 4, "a granted spirit rolls a generator tier (1–4)")
	ok(t.find_child("TradeDialog", true, false) != null, "the Rewards screen uses the shared framed dialog")
	ok(t._reels.size() == 2, "the screen builds one reel per granted spirit")
	var piglet_reveal: Control = t._spirit_widget("piglet", 72.0)
	ok(piglet_reveal.find_child("SpiritEye0", true, false) != null and piglet_reveal.find_child("SpiritEye1", true, false) != null,
		"an unarted spirit reveal shows placeholder face details instead of a blank disc")
	t.queue_free()
```

(c) Replace the body of `_test_trade_reward_dialog_layout()` (~lines 286–294) with:

```gdscript
func _test_trade_reward_dialog_layout() -> void:
	fresh("trade_reward_layout")
	var z := 0
	var g := Save.grove()
	var unl := {}
	for sp in G.MAPS[z].spots:
		unl[String(sp.id)] = true
	g["unlocks"] = unl
	g["gates"] = [z]
	Save.grove_write()
	Explore.begin_run({})
	Explore.add_score(800)                          # 800 / 200 = 4 reels
	var trade = load("res://engine/scenes/ExploreTrade.tscn").instantiate()
	get_root().add_child(trade)
	if trade.get_child_count() == 0:
		trade._ready()
	var dialog := trade.find_child("TradeDialog", true, false) as Control
	ok(dialog != null, "the Rewards screen uses the shared framed dialog instead of a loose full-page layout")
	ok(trade._reels.size() == 4, "an 800-point run reveals four reels")
	trade.queue_free()
```

- [ ] **Step 3: Run the grove suites to verify green**

Run: `make test-grove`
Expected: PASS — the seam grants 2 spirits, the layout builds 4 reels, the placeholder-eye check holds, and no `_test_trade_box_icons` remains.

- [ ] **Step 4: Commit**

```bash
git add engine/scripts/scenes/explore_trade.gd games/grove/tests/grove_explore_tests.gd
git commit -m "feat(rush): Rewards screen reveals score→spirits as a slot cascade"
```

---

### Task 5: Remove the dead box model

The boxes are gone from the screen; drop `BOXES` + `buy_box` and their stale test asserts.

**Files:**
- Modify: `engine/scripts/core/explore.gd`
- Modify: `games/grove/tests/grove_explore_tests.gd`

- [ ] **Step 1: Drop the `buy_box` asserts from `_test_run_state`**

In `games/grove/tests/grove_explore_tests.gd`, in `_test_run_state()` delete the four `buy_box` assertion lines (~211–214):

```gdscript
	ok(not Explore.buy_box(300), "a box the run can't afford is refused")
	ok(Explore.score() == 250, "a refused box leaves the score intact")
	ok(Explore.buy_box(250), "an affordable box is bought")
	ok(Explore.score() == 0, "buying a box debits its cost from the score")
```

The function ends after the `add_score` assertion (`ok(Explore.score() == 250, "add_score accrues the run score")`).

- [ ] **Step 2: Remove `BOXES` + `buy_box` from `explore.gd`**

In `engine/scripts/core/explore.gd` delete the `const BOXES := [...]` block (~lines 43–47) and the `static func buy_box(cost: int) -> bool:` function (~lines 212–216). Leave `add_score`, `score`, `begin_run`, `run`, and the new `TRADE_RATE` / `trade_count`.

- [ ] **Step 3: Verify nothing else references them**

Run: `grep -rn "\bBOXES\b\|buy_box" --include="*.gd" engine games`
Expected: no output (all references removed).

- [ ] **Step 4: Run the full sweep**

Run: `make test`
Expected: PASS — every suite (engine + grove) green, per-suite timing table printed, no FAIL/crash.

- [ ] **Step 5: Commit**

```bash
git add engine/scripts/core/explore.gd games/grove/tests/grove_explore_tests.gd
git commit -m "chore(explore): remove dead box model (BOXES, buy_box)"
```

---

## Manual verification (after Task 5)

The reveal animation, pacing, and shine can't be asserted headless — confirm by eye in the real app:

- [ ] Launch the app, run a Rush expedition to the Rewards screen (the `/run` skill, or the existing `games/grove/tools/explore_shot.gd` capture path).
- [ ] The reels cascade in left→right at the slower pacing; a tier-3+ spirit shines, the top reel pops + shakes the dialog.
- [ ] Pressing `Done` mid-cascade snaps all reels to their spirits and keeps the window open; pressing `Done` again returns to the Map.
- [ ] The hand on the Map shows the granted spirits.

---

## Self-review

**Spec coverage:** direct conversion + min-1 (Task 1) · slot reveal reusing the mystery machinery (Tasks 2–3) · spirit reels / auto-spin / banner (Task 4) · tier shine `SHINE_TIER` (Task 4) · dual-purpose Done (Task 4) · large-`n` grid wrap + `total_cap` stagger compression (Task 4 `SPIN_CFG`, SlotReel `spin_reels`) · empty-pool empty state (Task 4 `_build`) · remove boxes (Task 5) · tests incl. headless instant path (grant happens synchronously in `_build`). All spec sections map to a task.

**Placeholder scan:** no TBD/TODO; every code step shows complete code; every test step gives the exact `make` command + expected result.

**Type consistency:** `build_reel(pool, target, cw, ch, index, make_tile, shine_on_land)`, `spin_reels(host, reels, dialog, on_all_landed, cfg) -> {finish}`, `shine(reel, strong)`, `cell_stylebox()` are used identically in `slot_reel.gd`, `login_mystery.gd` (Task 3), and `explore_trade.gd` (Task 4). Reel metas (`band`, `tile_h`, `n_syms`, `reward`, `shine`, `top`, `tap`, `selected`) are written by `build_reel` and read by `spin_reels` / `_land_reel` / `login_mystery.enter_pick` / `reveal_static`. `trade_count` / `TRADE_RATE` consistent across Tasks 1, 4, 5.
