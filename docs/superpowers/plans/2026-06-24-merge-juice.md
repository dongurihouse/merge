# Merge Impact + Tier 2 Juice — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the merge real weight (squash & stretch + a hitstop "thunk" + a white flash + accelerate-into-impact), add generator pop anticipation, a reserved gentle big-moment shake, and a cozy combo — and fold the duplicate `_shake` into the shared FX vocabulary.

**Architecture:** All new motion verbs are static helpers in `engine/scripts/ui/fx.gd` with their dials in `engine/scripts/core/tuning.gd` class `FX`. Each is calm-mode aware and behind a feature flag in `engine/scripts/core/features.gd`. The board wires them into `_after_merge` / `_pop_seed`. Combo cadence is a pure function in `board_logic.gd` so it unit-tests without the scene. The global-`time_scale` hitstop is hard-guarded off in headless to protect the deterministic test clock.

**Tech Stack:** Godot 4.x / GDScript. Headless SceneTree tests run via `make test-fast` (engine) and `make test` (engine + grove). Real-renderer capture via `engine/tools/quiet_godot.sh` + `override.cfg`.

**Spec:** `docs/superpowers/specs/2026-06-24-merge-juice-design.md`

**Working directory:** the worktree `/Users/xup/dh/merge-juice` (branch `juice-merge-impact`). All paths below are relative to it.

---

## Task 1: Tuning constants + feature flags (foundation)

**Files:**
- Modify: `engine/scripts/core/tuning.gd` (class `FX`, after the existing constants ~line 199, before `class Hud`)
- Modify: `engine/scripts/core/features.gd` (`FLAGS` dict, juice section ~line 21)

- [ ] **Step 1: Add the FX dials**

In `engine/scripts/core/tuning.gd`, inside `class FX`, immediately before the line `class Hud:` (i.e. at the end of the FX constants block), add:

```gdscript

	# --- squash_pop (merge result — squash & stretch, the "C" impact) ------------------
	const SQUASH_K := [Vector2(1.16, 0.84), Vector2(0.92, 1.12), Vector2(1.03, 0.98), Vector2.ONE]
	const SQUASH_T := [0.07, 0.06, 0.06]        # per-leg seconds: K0->K1, K1->K2, K2->K3
	const SQUASH_CALM := Vector2(1.08, 1.08)    # calm: a gentle uniform overshoot (no stretch)

	# --- flash (white impact pop over a merged tile) -----------------------------------
	const FLASH_PEAK := 0.55
	const FLASH_T := 0.16

	# --- hitstop (global micro-freeze at impact) ---------------------------------------
	const HITSTOP_SCALE := 0.0          # Engine.time_scale during the freeze (0 = full hold)
	const HITSTOP_MERGE := 0.05         # base freeze seconds (real time)
	const HITSTOP_TIER_BONUS := 0.006   # + per tier above 1 (a bigger merge holds a touch longer)
	const HITSTOP_BIG := 0.08           # big-moment freeze (tier >= ESCALATE_TIER)
	const HITSTOP_MAX := 0.12           # never freeze longer than this

	# --- shake (decaying positional thunk — reserved for big moments) ------------------
	const SHAKE_AMP := 7.0              # px, the gentle board nudge
	const SHAKE_BIG_AMP := 9.0          # px, login jackpot / strongest
	const SHAKE_LEG_T := 0.045
	const SHAKE_SETTLE_T := 0.05

	# --- gen_charge (generator pop anticipation: crouch -> spring -> settle) ------------
	const GEN_CHARGE_K := [Vector2(1.1, 0.9), Vector2(0.94, 1.08), Vector2.ONE]
	const GEN_CHARGE_T := [0.07, 0.11]  # per-leg seconds: K0->K1, K1->K2

	# --- combo (cozy successive-merge streak) ------------------------------------------
	const ESCALATE_TIER := 4            # tier >= this earns the reserved big-moment shake
	const COMBO_WINDOW := 2.5           # seconds; a merge within this of the last extends the streak
	const COMBO_MILESTONES := [3, 5, 8] # streak counts that shout an encouraging word
	const COMBO_PITCH_STEP := 0.04      # + audio pitch per milestone reached
	const COMBO_BURST_BONUS := 3        # + burst particles while a streak is live
```

- [ ] **Step 2: Add the flags**

In `engine/scripts/core/features.gd`, in the `# juice` section of `FLAGS` (after the `"floaters"` / `"celebrate_bursts"` lines), add:

```gdscript
		"merge_impact": true,         # squash & stretch + flash + accelerate-into-impact on a merge
		"merge_hitstop": true,        # a ~50ms global freeze at the merge impact (the "thunk"); headless-guarded
		"big_moment_shake": true,     # a gentle reserved board shake on tier>=4 merges, level-ups, map restores
		"gen_anticipation": true,     # a generator squash-charges before it pops a tile
		"merge_combo": true,          # rapid successive merges build a cozy worded streak
```

- [ ] **Step 3: Verify everything still parses and passes**

Run: `make test-fast`
Expected: all engine suites PASS (the new constants/flags are inert until wired).

- [ ] **Step 4: Commit**

```bash
git add engine/scripts/core/tuning.gd engine/scripts/core/features.gd
git commit -m "juice: add FX tuning dials + feature flags for merge impact"
```

---

## Task 2: `combo_step` pure cadence function

**Files:**
- Modify: `engine/scripts/core/board_logic.gd` (after `rolls_coin_drop`, ~line 143)
- Test: `engine/tests/mechanics_tests.gd` (append assertions in `_initialize`)

- [ ] **Step 1: Write the failing test**

In `engine/tests/mechanics_tests.gd`, inside `_initialize()`, just before the final `print(...)`/`quit(...)` summary lines, add:

```gdscript
	# --- combo_step: cozy successive-merge streak (pure cadence) ---------------------
	ok(BoardLogic.combo_step(0, 0.0, 2.5) == 1, "combo: first merge (prev 0) starts the streak at 1")
	ok(BoardLogic.combo_step(1, 1.0, 2.5) == 2, "combo: a merge within the window bumps the streak")
	ok(BoardLogic.combo_step(3, 0.5, 2.5) == 4, "combo: streak keeps climbing while quick")
	ok(BoardLogic.combo_step(2, 2.5, 2.5) == 3, "combo: the window is inclusive at the boundary")
	ok(BoardLogic.combo_step(4, 3.0, 2.5) == 1, "combo: a gap past the window restarts at 1")
	ok(BoardLogic.combo_step(2, 2.51, 2.5) == 1, "combo: just past the window restarts at 1")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot --headless --path . -s res://engine/tests/mechanics_tests.gd`
Expected: FAIL — `Invalid call. Nonexistent function 'combo_step' in base 'GDScript'.`

- [ ] **Step 3: Implement `combo_step`**

In `engine/scripts/core/board_logic.gd`, after the `rolls_coin_drop` function (~line 143), add:

```gdscript

# A cozy successive-merge streak: a merge within `window` seconds of the previous one
# extends the streak (+1); a longer gap (or no prior streak) restarts it at 1. Pure, so the
# cadence is unit-tested without the scene. `dt` = seconds since the last merge.
static func combo_step(prev_count: int, dt: float, window: float) -> int:
	if prev_count <= 0 or dt > window:
		return 1
	return prev_count + 1
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `godot --headless --path . -s res://engine/tests/mechanics_tests.gd`
Expected: PASS (the 6 new combo assertions, plus the existing suite).

- [ ] **Step 5: Commit**

```bash
git add engine/scripts/core/board_logic.gd engine/tests/mechanics_tests.gd
git commit -m "juice: add BoardLogic.combo_step cadence + tests"
```

---

## Task 3: `FX.squash_pop`

**Files:**
- Modify: `engine/scripts/ui/fx.gd` (add static; near `pop`, ~line 48)
- Test: `engine/tests/calm_tests.gd` (append assertions)

- [ ] **Step 1: Write the failing test**

In `engine/tests/calm_tests.gd`, inside `_initialize()`, before the final `print(...)`/`quit(...)`, add:

```gdscript
	# --- squash_pop: squash & stretch (active) vs gentle overshoot (calm) ------------
	Save.set_setting("calm", false)
	var sp := Control.new(); sp.size = Vector2(80, 80); get_root().add_child(sp)
	FX.squash_pop(sp)
	ok(sp.scale.is_equal_approx(Tune.SQUASH_K[0]), "squash_pop: active path sets the squash-start pose")
	ok(sp.pivot_offset.is_equal_approx(Vector2(40, 40)), "squash_pop: scales from the node centre")

	Save.set_setting("calm", true)
	var spc := Control.new(); spc.size = Vector2(80, 80); get_root().add_child(spc)
	FX.squash_pop(spc)
	ok(not spc.scale.is_equal_approx(Tune.SQUASH_K[0]), "squash_pop: calm uses the gentle overshoot, not the squash pose")
	FX.squash_pop(null)
	ok(true, "squash_pop: tolerates a null node (no crash)")
	Save.set_setting("calm", false)
	sp.queue_free(); spc.queue_free()
```

The test references `Tune.*`, so add a `Tune` const to **`engine/tests/calm_tests.gd`** (the test file — `fx.gd` itself already preloads `Tune` at line 11, do not re-add it there). After the existing `const Features = ...` line (~line 10) in `calm_tests.gd`, add:

```gdscript
const Tune = preload("res://engine/scripts/core/tuning.gd").FX
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot --headless --path . -s res://engine/tests/calm_tests.gd`
Expected: FAIL — `Nonexistent function 'squash_pop'`.

- [ ] **Step 3: Implement `squash_pop`**

In `engine/scripts/ui/fx.gd`, immediately after the `pop` function (ends ~line 48), add:

```gdscript

## The merge result's IMPACT: squash & stretch (the chosen "C" feel). Calm falls back to a
## gentle uniform overshoot. `pop()` stays for taps/confirms — this is for produced tiles.
static func squash_pop(node: Control) -> void:
	if not (node and is_instance_valid(node)):
		return
	node.pivot_offset = _center_pivot(node)
	if calm():
		var c := node.create_tween()
		c.tween_property(node, "scale", Tune.SQUASH_CALM, Tune.POP_T_OUT).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		c.tween_property(node, "scale", Vector2.ONE, Tune.POP_T_SETTLE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		return
	node.scale = Tune.SQUASH_K[0]
	var t := node.create_tween()
	for i in range(1, Tune.SQUASH_K.size()):
		t.tween_property(node, "scale", Tune.SQUASH_K[i], Tune.SQUASH_T[i - 1]).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `godot --headless --path . -s res://engine/tests/calm_tests.gd`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add engine/scripts/ui/fx.gd engine/tests/calm_tests.gd
git commit -m "juice: FX.squash_pop (squash & stretch, calm-aware) + tests"
```

---

## Task 4: `FX.flash`

**Files:**
- Modify: `engine/scripts/ui/fx.gd` (add static after `squash_pop`)
- Test: `engine/tests/calm_tests.gd` (append assertions)

- [ ] **Step 1: Write the failing test**

In `engine/tests/calm_tests.gd`, before the final summary, add:

```gdscript
	# --- flash: a brief white overlay (gated on merge_impact, off under calm) --------
	Features.FLAGS["merge_impact"] = true
	Save.set_setting("calm", false)
	var fh := Control.new(); fh.size = Vector2(200, 200); get_root().add_child(fh)
	FX.flash(fh, Vector2(100, 100), 64.0)
	ok(fh.get_child_count() == 1, "flash: active path adds a white overlay child")

	Save.set_setting("calm", true)
	var fh2 := Control.new(); fh2.size = Vector2(200, 200); get_root().add_child(fh2)
	FX.flash(fh2, Vector2(100, 100), 64.0)
	ok(fh2.get_child_count() == 0, "flash: calm adds nothing")

	Save.set_setting("calm", false)
	Features.FLAGS["merge_impact"] = false
	var fh3 := Control.new(); fh3.size = Vector2(200, 200); get_root().add_child(fh3)
	FX.flash(fh3, Vector2(100, 100), 64.0)
	ok(fh3.get_child_count() == 0, "flash: flag OFF adds nothing")
	Features.FLAGS["merge_impact"] = true
	fh.queue_free(); fh2.queue_free(); fh3.queue_free()
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot --headless --path . -s res://engine/tests/calm_tests.gd`
Expected: FAIL — `Nonexistent function 'flash'`.

- [ ] **Step 3: Implement `flash`**

In `engine/scripts/ui/fx.gd`, after `squash_pop`, add:

```gdscript

## A brief white impact pop over a merged tile (modelled on login_mystery's reel flash).
## `gpos`/`size` are host-local — a `size`×`size` square centred on `gpos`. Gated on
## merge_impact, off under calm. Frees itself.
static func flash(host: Node, gpos: Vector2, size: float, peak := Tune.FLASH_PEAK) -> void:
	if not Features.on("merge_impact") or calm():
		return
	if not (host and is_instance_valid(host)):
		return
	var fl := ColorRect.new()
	fl.color = Color(1, 1, 1, peak)
	fl.size = Vector2(size, size)
	fl.position = gpos - Vector2(size, size) * 0.5
	fl.z_index = Tune.BURST_Z + 1
	fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(fl)
	var t := fl.create_tween()
	t.tween_property(fl, "modulate:a", 0.0, Tune.FLASH_T).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_callback(fl.queue_free)
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `godot --headless --path . -s res://engine/tests/calm_tests.gd`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add engine/scripts/ui/fx.gd engine/tests/calm_tests.gd
git commit -m "juice: FX.flash (white impact overlay) + tests"
```

---

## Task 5: `FX.shake` (promote the duplicate)

**Files:**
- Modify: `engine/scripts/ui/fx.gd` (add static after `flash`)
- Modify: `engine/scripts/ui/login_mystery.gd` (call `FX.shake`; delete private `_shake`)
- Test: `engine/tests/calm_tests.gd` (append assertions)

- [ ] **Step 1: Write the failing test**

In `engine/tests/calm_tests.gd`, before the final summary, add:

```gdscript
	# --- shake: a decaying positional thunk (active) / no-op under calm -------------
	Save.set_setting("calm", false)
	var sk := Control.new(); sk.size = Vector2(60, 60); get_root().add_child(sk)
	FX.shake(sk)
	ok(sk.get_tree() != null and is_instance_valid(sk), "shake: active path runs on a real in-tree node (no crash)")
	Save.set_setting("calm", true)
	var skc := Control.new(); skc.size = Vector2(60, 60); skc.position = Vector2(5, 5); get_root().add_child(skc)
	FX.shake(skc)
	ok(skc.position.is_equal_approx(Vector2(5, 5)), "shake: calm leaves the position untouched (no shake)")
	FX.shake(null)
	ok(true, "shake: tolerates a null node")
	Save.set_setting("calm", false)
	sk.queue_free(); skc.queue_free()
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot --headless --path . -s res://engine/tests/calm_tests.gd`
Expected: FAIL — `Nonexistent function 'shake'`.

- [ ] **Step 3: Implement `shake` in fx.gd**

In `engine/scripts/ui/fx.gd`, after `flash`, add:

```gdscript

## A short decaying positional shake (the "thunk"). Promoted from login_mystery's private
## copy so the board's big-moment escalation and the slot jackpot share one verb. `amp` px;
## settles back to the rest position. No-op under calm (motion accessibility). Callers gate
## on their own flag (e.g. big_moment_shake).
static func shake(node: Control, amp := Tune.SHAKE_AMP) -> void:
	if not (node and is_instance_valid(node)) or not node.is_inside_tree():
		return
	if calm():
		return
	var rest := node.position
	var t := node.create_tween()
	var offs := [Vector2(amp, -amp * 0.5), Vector2(-amp * 0.8, amp * 0.4), Vector2(amp * 0.5, amp * 0.3), Vector2(-amp * 0.3, -amp * 0.2)]
	for o in offs:
		t.tween_property(node, "position", rest + o, Tune.SHAKE_LEG_T).set_trans(Tween.TRANS_SINE)
	t.tween_property(node, "position", rest, Tune.SHAKE_SETTLE_T).set_trans(Tween.TRANS_SINE)
```

- [ ] **Step 4: Route login_mystery through the shared verb**

In `engine/scripts/ui/login_mystery.gd`:

(a) Ensure FX is preloaded. Near the top of the file with the other `const ... = preload(...)` lines, add (if not already present):

```gdscript
const FX = preload("res://engine/scripts/ui/fx.gd")
```

(b) Replace the jackpot shake call (~line 379) — change:

```gdscript
		_shake(dialog, 9.0)
```

to:

```gdscript
		FX.shake(dialog, FX.Tune.SHAKE_BIG_AMP)
```

(c) Delete the now-dead private helper (~lines 397-406): the comment `# A short decaying positional shake (the jackpot "thunk")...` and the entire `static func _shake(node: Control, amp: float) -> void:` body.

- [ ] **Step 5: Run the tests**

Run: `godot --headless --path . -s res://engine/tests/calm_tests.gd && godot --headless --path . -s res://engine/tests/login_tests.gd`
Expected: both PASS (login still green after the swap).

- [ ] **Step 6: Commit**

```bash
git add engine/scripts/ui/fx.gd engine/scripts/ui/login_mystery.gd engine/tests/calm_tests.gd
git commit -m "juice: promote _shake into shared FX.shake; route login jackpot through it"
```

---

## Task 6: `FX.hitstop` (+ headless guard)

**Files:**
- Modify: `engine/scripts/ui/fx.gd` (add statics + a module static var after `shake`)
- Test: `engine/tests/calm_tests.gd` (append assertions)

- [ ] **Step 1: Write the failing test**

In `engine/tests/calm_tests.gd`, before the final summary, add:

```gdscript
	# --- hitstop: wanted-gate is testable; the full gate + effect are off in headless --
	Features.FLAGS["merge_hitstop"] = true
	Save.set_setting("calm", false)
	ok(FX.hitstop_wanted(), "hitstop: flag ON + calm OFF → wanted")
	Save.set_setting("calm", true)
	ok(not FX.hitstop_wanted(), "hitstop: calm ON → not wanted")
	Save.set_setting("calm", false)
	Features.FLAGS["merge_hitstop"] = false
	ok(not FX.hitstop_wanted(), "hitstop: flag OFF → not wanted")
	Features.FLAGS["merge_hitstop"] = true
	# the load-bearing safety property: never enabled in headless, whatever the gates say
	ok(not FX.hitstop_enabled(), "hitstop: NEVER enabled in headless (protects the test clock)")
	var before := Engine.time_scale
	FX.hitstop(0.05)
	ok(Engine.time_scale == before, "hitstop: a call in headless does not touch Engine.time_scale")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot --headless --path . -s res://engine/tests/calm_tests.gd`
Expected: FAIL — `Nonexistent function 'hitstop_wanted'`.

- [ ] **Step 3: Implement hitstop in fx.gd**

In `engine/scripts/ui/fx.gd`, after `shake`, add:

```gdscript

# --- hitstop: a global micro-freeze at the moment of impact -------------------------
static var _hitstop_active := false

# "do we want a freeze" — flag ON and not calm. Testable off-headless.
static func hitstop_wanted() -> bool:
	return Features.on("merge_hitstop") and not calm()

# the full gate: wanted AND not headless. A global time_scale change would starve the
# deterministic headless test clock (the grove base pins time_scale=1.0), and a freeze
# is a purely-felt effect with no logic consequence — so it is hard-off in headless.
static func hitstop_enabled() -> bool:
	return hitstop_wanted() and DisplayServer.get_name() != "headless"

## Freeze the whole game for `secs` real-time, then restore. Tweens obey time_scale, so a
## squash_pop started at impact holds its compressed pose during the freeze and plays on
## release; audio ignores time_scale, so the merge sound punches through. The restore timer
## ignores time_scale, so it always fires. Re-entrancy-guarded so rapid merges don't stack.
static func hitstop(secs: float) -> void:
	if not hitstop_enabled() or _hitstop_active or secs <= 0.0:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	_hitstop_active = true
	Engine.time_scale = Tune.HITSTOP_SCALE
	var timer := tree.create_timer(secs, true, false, true)   # process_always, ignore_time_scale
	timer.timeout.connect(func() -> void:
		Engine.time_scale = 1.0
		_hitstop_active = false)
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `godot --headless --path . -s res://engine/tests/calm_tests.gd`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add engine/scripts/ui/fx.gd engine/tests/calm_tests.gd
git commit -m "juice: FX.hitstop with headless guard + re-entrancy guard + tests"
```

---

## Task 7: `FX.gen_charge`

**Files:**
- Modify: `engine/scripts/ui/fx.gd` (add static after the hitstop block)
- Test: `engine/tests/calm_tests.gd` (append assertions)

- [ ] **Step 1: Write the failing test**

In `engine/tests/calm_tests.gd`, before the final summary, add:

```gdscript
	# --- gen_charge: anticipation pose (flag on) vs plain pop fallback (flag off) -----
	Features.FLAGS["gen_anticipation"] = true
	Save.set_setting("calm", false)
	var gc := Control.new(); gc.size = Vector2(90, 90); get_root().add_child(gc)
	FX.gen_charge(gc)
	ok(gc.scale.is_equal_approx(Tune.GEN_CHARGE_K[0]), "gen_charge: active path sets the crouch pose")
	Features.FLAGS["gen_anticipation"] = false
	var gc2 := Control.new(); gc2.size = Vector2(90, 90); get_root().add_child(gc2)
	FX.gen_charge(gc2)
	ok(not gc2.scale.is_equal_approx(Tune.GEN_CHARGE_K[0]), "gen_charge: flag OFF falls back to plain pop (no crouch pose)")
	FX.gen_charge(null)
	ok(true, "gen_charge: tolerates a null node")
	Features.FLAGS["gen_anticipation"] = true
	gc.queue_free(); gc2.queue_free()
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot --headless --path . -s res://engine/tests/calm_tests.gd`
Expected: FAIL — `Nonexistent function 'gen_charge'`.

- [ ] **Step 3: Implement `gen_charge`**

In `engine/scripts/ui/fx.gd`, after the hitstop block, add:

```gdscript

## Generator pop anticipation: a quick crouch -> spring -> settle squash as the generator
## spits a tile. Flag-off / calm fall back to the existing `pop()` so a tap still feels
## responsive.
static func gen_charge(node: Control) -> void:
	if not (node and is_instance_valid(node)):
		return
	if not Features.on("gen_anticipation") or calm():
		pop(node)
		return
	node.pivot_offset = _center_pivot(node)
	node.scale = Tune.GEN_CHARGE_K[0]
	var t := node.create_tween()
	for i in range(1, Tune.GEN_CHARGE_K.size()):
		t.tween_property(node, "scale", Tune.GEN_CHARGE_K[i], Tune.GEN_CHARGE_T[i - 1]).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `godot --headless --path . -s res://engine/tests/calm_tests.gd`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add engine/scripts/ui/fx.gd engine/tests/calm_tests.gd
git commit -m "juice: FX.gen_charge (generator pop anticipation) + tests"
```

---

## Task 8: Wire the merge impact into the board

**Files:**
- Modify: `engine/scripts/scenes/board.gd` — `_commit_merge` (~2108), `_after_merge` (~2116)

This task is integration: the effect is visual, so the "test" is the existing merge regression suites staying green (critically, the hitstop must NOT disturb them — it is headless-guarded).

- [ ] **Step 1: Accelerate the absorbed tile into the impact**

In `engine/scripts/scenes/board.gd`, `_commit_merge` (~line 2112-2113), replace:

```gdscript
	var t := node.create_tween()
	t.tween_property(node, "position", _cell_pos(b), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
```

with:

```gdscript
	var t := node.create_tween()
	var slide_ease := Tween.EASE_IN if Features.on("merge_impact") else Tween.EASE_OUT   # accelerate INTO the hit
	t.tween_property(node, "position", _cell_pos(b), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(slide_ease)
```

- [ ] **Step 2: Replace the flat pop with the impact sequence**

In `_after_merge` (~lines 2128-2131), replace:

```gdscript
	FX.pop(n)
	var tier := BoardModel.tier_of(produced)
	FX.burst(board_area, _cell_pos(b) + Vector2(csz, csz) / 2.0, STRAW if tier >= 4 else Color("#7FA65A"), 10 + tier * 3)
	Audio.play("merge_success" if tier >= 4 else "merge_soft", -1.0, clampf(0.95 + 0.03 * tier, 0.9, 1.3))
```

with:

```gdscript
	var tier := BoardModel.tier_of(produced)
	var center := _cell_pos(b) + Vector2(csz, csz) / 2.0
	# the merge IMPACT (the chosen "C" feel): squash & stretch on the result + a white flash
	if Features.on("merge_impact"):
		FX.squash_pop(n)
		FX.flash(board_area, center, csz)
	else:
		FX.pop(n)
	var combo := _bump_combo()
	var hit := FX.Tune.HITSTOP_MERGE + FX.Tune.HITSTOP_TIER_BONUS * maxf(0.0, tier - 1)
	var burst_n := 10 + tier * 3
	var pitch := clampf(0.95 + 0.03 * tier, 0.9, 1.3)
	# big-moment escalation: a rare high-tier merge earns a gentle board shake + a longer hold + a fuller burst
	if Features.on("big_moment_shake") and tier >= FX.Tune.ESCALATE_TIER:
		FX.shake(board_area)
		hit = FX.Tune.HITSTOP_BIG
		burst_n += 6
	# cozy combo: a live streak nudges the pitch up and the burst out a touch
	if combo > 0 and Features.on("merge_combo"):
		burst_n += FX.Tune.COMBO_BURST_BONUS
		pitch = clampf(pitch + FX.Tune.COMBO_PITCH_STEP * _combo_milestones_passed(combo), 0.9, 1.6)
	FX.hitstop(minf(hit, FX.Tune.HITSTOP_MAX))     # the "thunk" — no-op in headless / calm
	FX.burst(board_area, center, STRAW if tier >= 4 else Color("#7FA65A"), burst_n)
	Audio.play("merge_success" if tier >= 4 else "merge_soft", -1.0, pitch)
	_combo_celebrate(combo, center)
```

> Note: `_bump_combo`, `_combo_milestones_passed`, and `_combo_celebrate` are added in Task 11. Until then they are undefined — so commit this task's slide-ease change and the squash/flash/hitstop/escalation lines TOGETHER WITH Task 11, OR temporarily stub the three helpers. To keep tasks independently green, implement Task 11's helpers BEFORE running this task's verification. **Execution order: do Step 1 here, then jump to Task 11 Steps 1-3 (add the helpers + state + strings), then return and finish this task's Step 2 and verification.**

- [ ] **Step 3: Verify the full merge path is green**

Run: `make test`
Expected: every suite PASS — in particular the grove merge→log and bramble-clear asserts (the hitstop is headless-guarded, so `Engine.time_scale` stays 1.0 during tests).

- [ ] **Step 4: Commit**

```bash
git add engine/scripts/scenes/board.gd
git commit -m "juice: wire merge impact (squash+flash+hitstop+anticipation+escalation) into _after_merge"
```

---

## Task 9: Big-moment shake on level-up and map restore

**Files:**
- Modify: `engine/scripts/scenes/map.gd` — level-up (~1025), map restore (~1057)

- [ ] **Step 1: Add the reserved shake to the level-up celebration**

In `engine/scripts/scenes/map.gd`, just after the level-up burst/sound (~lines 1025-1026: `FX.burst(self, at, STRAW, 18)` / `Audio.play("level_complete", -6.0, 1.2)`), add:

```gdscript
	if Features.on("big_moment_shake"):
		FX.shake(self)
```

- [ ] **Step 2: Add the reserved shake to the map restore**

In `map.gd`, just after the restore's `FX.shatter_veil(...)` call (~line 1057), add:

```gdscript
	if Features.on("big_moment_shake"):
		FX.shake(self)
```

(If `Features` is not already preloaded in `map.gd`, add `const Features = preload("res://engine/scripts/core/features.gd")` with the other preloads at the top.)

- [ ] **Step 3: Verify the map FX suite is green**

Run: `godot --headless --path . -s res://engine/tests/mapfx_tests.gd && make test-fast`
Expected: PASS (shake is a no-op in headless only via calm? No — shake runs in headless but only moves/restores `self.position` within one tween; it does not touch global state. Confirm `mapfx_tests` still green; if a test asserts an exact root position, gate the shake or restore position in teardown.)

- [ ] **Step 4: Commit**

```bash
git add engine/scripts/scenes/map.gd
git commit -m "juice: reserved gentle shake on level-up + map restore"
```

---

## Task 10: Generator pop anticipation

**Files:**
- Modify: `engine/scripts/scenes/board.gd` — `_pop_seed` (~2046)

- [ ] **Step 1: Swap the generator's plain pop for the charge**

In `engine/scripts/scenes/board.gd`, `_pop_seed` (~line 2046), replace:

```gdscript
	FX.pop(gnode)
```

with:

```gdscript
	FX.gen_charge(gnode)
```

- [ ] **Step 2: Verify spawn/pop suites are green**

Run: `make test`
Expected: PASS (gen_charge falls back to `pop()` when the flag is off/calm; under the default flag it sets a tween — no logic change to spawning).

- [ ] **Step 3: Commit**

```bash
git add engine/scripts/scenes/board.gd
git commit -m "juice: generator pop anticipation (FX.gen_charge on _pop_seed)"
```

---

## Task 11: Cozy combo wiring

**Files:**
- Modify: `engine/scripts/scenes/board.gd` — state vars (near the const block ~line 56) + three helpers
- Modify: `games/grove/strings.json` — three encouraging words under `board.feedback`

> Do this task's Steps 1-3 BEFORE finishing Task 8's verification (Task 8 Step 2 calls these helpers).

- [ ] **Step 1: Add the combo state vars**

In `engine/scripts/scenes/board.gd`, find the first `var` member declarations after the `const` block (the existing pattern is consts ~lines 48-66, then members). Add with the other members:

```gdscript
var _combo_count := 0                 # cozy successive-merge streak length (see _bump_combo)
var _last_merge_ms := -100000         # ticks at the last merge; a big initial gap → first merge starts at 1
```

- [ ] **Step 2: Add the three combo helpers**

In `board.gd`, near `_after_merge` (e.g. right after it, ~line 2144), add:

```gdscript

# Extend or restart the cozy merge streak. A merge within COMBO_WINDOW of the previous one
# bumps the count; a longer gap restarts at 1. Returns the new streak length. Cadence is
# BoardLogic.combo_step (pure, unit-tested).
func _bump_combo() -> int:
	var now := Time.get_ticks_msec()
	var dt := float(now - _last_merge_ms) / 1000.0
	_last_merge_ms = now
	_combo_count = BoardLogic.combo_step(_combo_count, dt, FX.Tune.COMBO_WINDOW)
	return _combo_count

# How many milestone thresholds the current streak has reached (drives the pitch nudge).
func _combo_milestones_passed(count: int) -> int:
	var k := 0
	for m in FX.Tune.COMBO_MILESTONES:
		if count >= int(m):
			k += 1
	return k

# At an EXACT milestone, shout a cozy word over the merge (never a "COMBO xN" tag).
func _combo_celebrate(count: int, center: Vector2) -> void:
	if not Features.on("merge_combo"):
		return
	var idx := FX.Tune.COMBO_MILESTONES.find(count)
	if idx < 0:
		return
	var words := ["combo_nice", "combo_lovely", "combo_wonderful"]
	var key: String = words[mini(idx, words.size() - 1)]
	var gpos := board_area.get_global_transform() * center - Vector2(20, 50)
	FX.floating_text(self, gpos, Strings.t("board.feedback." + key), STRAW, 30)
```

- [ ] **Step 3: Add the strings**

In `games/grove/strings.json`, in the `board.feedback` block (after `"cleared": "Cleared!",`), add:

```json
			"combo_nice": "Nice!",
			"combo_lovely": "Lovely!",
			"combo_wonderful": "Wonderful!",
```

- [ ] **Step 4: Verify strings + board load**

Run: `godot --headless --path . -s res://engine/tests/strings_tests.gd && make test`
Expected: PASS (the new keys resolve; `make test` exercises a real merge that now calls the combo helpers — with `merge_combo` on, milestones at 3/5/8 shout a worded floater).

- [ ] **Step 5: Commit**

```bash
git add engine/scripts/scenes/board.gd games/grove/strings.json
git commit -m "juice: cozy merge combo (worded milestone floaters) + strings"
```

---

## Task 12: Full sweep + real-renderer verification capture

**Files:**
- Create: `games/grove/tools/merge_juice_shot.gd` (capture harness, modelled on `grove_shot.gd`)

This produces a before/after frame strip of a merge for the OWNER to judge the feel — per the spec, juice is verified by capture, not eyeballed by the agent.

- [ ] **Step 1: Full test sweep**

Run: `make test`
Expected: every suite PASS with the per-suite timing table (no FAIL/crash).

- [ ] **Step 2: Write the capture harness**

Create `games/grove/tools/merge_juice_shot.gd`:

```gdscript
extends SceneTree
## Dev tool (real renderer; run via engine/tools/quiet_godot.sh): capture a STRIP of frames
## across a single merge so the owner can judge the impact feel. Flags come from the live
## features.gd, so run it once as-is (juice ON) and once after flipping the merge_* flags off
## to get a before/after.
##   quiet_godot.sh --path . -s res://games/grove/tools/merge_juice_shot.gd -- <out_dir>

const Save = preload("res://engine/scripts/core/save.gd")

func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: real-renderer tools must run via engine/tools/quiet_godot.sh")
		quit(2)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() >= 1 else "/tmp/merge_juice/"
	if not out_dir.ends_with("/"):
		out_dir += "/"
	if DirAccess.dir_exists_absolute(out_dir):
		for fn in DirAccess.get_files_at(out_dir):
			DirAccess.remove_absolute(out_dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(out_dir)

	var test_dir := "/tmp/tu_mergejuice_save/"
	DirAccess.make_dir_recursive_absolute(test_dir)
	Save.configure_for_test(test_dir)

	var scn = load("res://engine/scenes/Board.tscn").instantiate()
	root.add_child(scn)
	current_scene = scn
	await create_timer(0.5).timeout
	scn.rng.seed = 7

	# start the merge: the two starter flowers at (3,2) and (3,4)
	var half: Vector2 = Vector2(scn.csz, scn.csz) / 2.0
	scn._on_press(scn._cell_pos(Vector2i(3, 2)) + half)
	scn._on_release(scn._cell_pos(Vector2i(3, 4)) + half)

	# sample ~18 frames at 35ms of WALL-CLOCK each (ignore_time_scale, so a hitstop freeze
	# is sampled too instead of stalling the capture loop)
	for i in 18:
		RenderingServer.force_draw()
		var img := root.get_texture().get_image()
		img.save_png(out_dir + "f%02d.png" % i)
		await create_timer(0.035, true, false, true).timeout
	print("STRIP saved to %s (18 frames)" % out_dir)
	quit()
```

- [ ] **Step 3: Capture the AFTER strip (juice on)**

Run: `engine/tools/quiet_godot.sh --path . -s res://games/grove/tools/merge_juice_shot.gd -- .scratch/juice_after/`
Expected: 18 PNGs in `.scratch/juice_after/`.

- [ ] **Step 4: Capture the BEFORE strip (juice off)**

Temporarily flip the five new flags to `false` in `engine/scripts/core/features.gd`, re-run into a different dir, then revert the flags:

```bash
# flip merge_impact/merge_hitstop/big_moment_shake/gen_anticipation/merge_combo to false, then:
engine/tools/quiet_godot.sh --path . -s res://games/grove/tools/merge_juice_shot.gd -- .scratch/juice_before/
# revert the flags back to true
```

- [ ] **Step 5: Composite both strips and deliver to the owner**

Build a side-by-side contact sheet (e.g. with the project's image tooling or `montage`) of `juice_before` over `juice_after`, save to `.scratch/merge_juice_compare.png`, and send it to the owner with `SendUserFile` for a feel judgment. Do NOT assert the feel is good from a thumbnail — let the owner decide and tune the `tuning.gd` dials from there.

- [ ] **Step 6: Commit the harness**

```bash
git add games/grove/tools/merge_juice_shot.gd
git commit -m "juice: merge-impact capture harness for before/after verification"
```

---

## Self-review notes (coverage map)

- Spec §1 hitstop → Task 6 (+ headless guard test). squash_pop → Task 3. flash → Task 4. shake (promotion) → Task 5. gen_charge → Task 7.
- Spec §2 merge wiring (anticipation ease + sequence) → Task 8.
- Spec §3 big-moment escalation: tier≥4 merge → Task 8; level-up + map restore → Task 9.
- Spec §4 generator anticipation → Task 10.
- Spec §5 combo (pure `combo_step` + wiring + strings) → Task 2 + Task 11.
- Spec §6 flags → Task 1. §7 tuning dials → Task 1.
- Spec Testing → unit tests in Tasks 2-7; regression sweeps in Tasks 8-11; capture in Task 12.
- Cross-task type consistency: `FX.Tune.*` constants (Task 1) referenced in Tasks 3-11; `combo_step(prev,dt,window)` signature identical in Task 2 (def) and Task 11 (`_bump_combo`); `_bump_combo`/`_combo_milestones_passed`/`_combo_celebrate` defined in Task 11 and called in Task 8 (note flags the ordering dependency).
