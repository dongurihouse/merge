# FTUE Hand Hints Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Teach a brand-new player the two core verbs with a looping hand icon — drag-to-merge first, then tap-the-generator — each shown exactly once, ever.

**Architecture:** A reusable, input-transparent `ui/` overlay (`hand_hint.gd`) draws a soft dim with rectangular cutouts around the involved cells and animates a hand texture over them. `core/save.gd` gains a seen-once `ftue_seen` ledger; `scenes/board.gd` decides which hint is eligible after each rebuild and dismisses it when the taught action actually happens. The overlay knows nothing about the board; the board knows nothing about how the hand is drawn.

**Tech Stack:** Godot 4.6, GDScript. Headless SceneTree test suites run via `python3 engine/tools/run_suites.py` (wrapped by `make test-fast` / `make test`). Screenshots via `make shot-grove` (quiet, minimized window).

**Spec:** `docs/superpowers/specs/2026-07-23-ftue-hand-hint-design.md`

## Global Constraints

- **Work in the worktree `/Users/xup/dh/wt-ftue-hand-hint` on branch `ftue-hand-hint`.** Never edit the main tree at `/Users/xup/dh/merge` — a PreToolUse hook blocks it.
- **Layering (enforced by `engine/tests/layering_tests.gd`):** files under `engine/scripts/ui/` may preload from `core/` and `ui/` only — **never** from `scenes/`. `engine/scripts/core/` may not preload from `ui/` or `scenes/`.
- **Every new FTUE/juice feature ships behind a flag** (`engine/scripts/core/features.gd` rule N4). This feature's flag is `ftue_hand_hint`, default `true`.
- **Run `make test-fast` after every change**, before anything else. Run the full `make test` before committing the final task.
- **Run test/shot commands in the FOREGROUND.** Backgrounding them and waiting for a notification hangs the run.
- Godot `Control` geometry is float32 — compare positions and sizes in tests with `is_equal_approx`, never `==`.
- Test suites are `extends SceneTree` scripts with an `_initialize()` entry point that prints `== N passed, M failed ==` and calls `quit(0 if _fail == 0 else 1)`.
- Commit after each task. End every commit message with:
  `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`

## File Structure

| File | Responsibility |
| --- | --- |
| `engine/scripts/core/features.gd` (modify) | Adds the `ftue_hand_hint` flag. |
| `engine/scripts/core/save.gd` (modify) | Adds the `ftue_seen` ledger: `ftue_seen(id)` / `mark_ftue_seen(id)`. |
| `engine/scripts/ui/hand_hint.gd` (create) | The whole presentation: dim-with-cutouts veil, hand texture + fallback, drag and tap loops. Knows nothing about the board. |
| `engine/scripts/scenes/board.gd` (modify) | Eligibility, presentation, retargeting, and the two completion hooks. |
| `engine/tests/ftue_hand_hint_tests.gd` (create) | Headless suite for the save ledger, flag gate, overlay structure, and eligibility order. |
| `Makefile` (modify) | Registers the new suite in `ENGINE_TESTS`. |
| `games/grove/assets/_new/` + `ui/kit/hand.png` (create) | The hand art, through the intake pipeline. |

---

### Task 1: The seen-once ledger and the feature flag

The state layer, with no UI. Delivers `Save.ftue_seen(id)` / `Save.mark_ftue_seen(id)` and the `ftue_hand_hint` flag.

**Files:**
- Modify: `engine/scripts/core/save.gd`
- Modify: `engine/scripts/core/features.gd:45-48` (the `# ftue` block)
- Modify: `Makefile:11` (`ENGINE_TESTS`)
- Test: `engine/tests/ftue_hand_hint_tests.gd` (create)

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `Save.ftue_seen(id: String) -> bool`
  - `Save.mark_ftue_seen(id: String) -> void`
  - `Features.on("ftue_hand_hint") -> bool`

- [ ] **Step 1: Write the failing test**

Create `engine/tests/ftue_hand_hint_tests.gd`:

```gdscript
extends SceneTree
## Headless tests for the FTUE hand hints (spec: docs/superpowers/specs/2026-07-23-ftue-hand-hint-design.md).
##   godot --headless --path . -s res://engine/tests/ftue_hand_hint_tests.gd

const Save = preload("res://engine/scripts/core/save.gd")
const Feat = preload("res://engine/scripts/core/features.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

# Point Save at a clean temp dir (never touches the real save).
func fresh(name: String) -> void:
	var dir := "user://tu_ftue_" + name + "/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

func _initialize() -> void:
	print("== FTUE hand hint tests ==")

	# --- the seen-once ledger ---
	fresh("ledger")
	ok(not Save.ftue_seen("merge"), "fresh save: merge is unseen")
	ok(not Save.ftue_seen("gen_tap"), "fresh save: gen_tap is unseen")
	ok(not Save.ftue_seen("nonsense"), "an unknown id reads as unseen (never crashes)")

	Save.mark_ftue_seen("merge")
	ok(Save.ftue_seen("merge"), "marking merge makes it seen")
	ok(not Save.ftue_seen("gen_tap"), "marking merge leaves gen_tap alone")

	Save.mark_ftue_seen("merge")
	ok(Save.ftue_seen("merge"), "marking twice is idempotent")

	Save.load_now()   # round-trip through the JSON file
	ok(Save.ftue_seen("merge"), "seen state survives a reload")
	ok(not Save.ftue_seen("gen_tap"), "unseen state survives a reload")

	# An old save with no ftue_seen key at all deep-merges over the defaults.
	fresh("oldsave")
	Save.data.erase("ftue_seen")
	ok(not Save.ftue_seen("merge"), "a save missing the ftue_seen key reads as unseen (no migration)")

	# --- the flag ---
	ok(Feat.FLAGS.has("ftue_hand_hint"), "the ftue_hand_hint flag exists")
	ok(Feat.on("ftue_hand_hint"), "the ftue_hand_hint flag defaults ON")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd /Users/xup/dh/wt-ftue-hand-hint && godot --headless --path . -s res://engine/tests/ftue_hand_hint_tests.gd
```

Expected: FAIL — the run errors on `Save.ftue_seen`, an invalid call to a nonexistent function.

- [ ] **Step 3: Add the ledger to `save.gd`**

In `engine/scripts/core/save.gd`, add `"ftue_seen": {}` to the `_default()` dictionary (around line 34):

```gdscript
static func _default() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"currencies": {"coins": 0, "diamonds": NEW_SAVE_GEMS},
		"settings": {},
		"ftue_seen": {},
	}
```

Then add the accessors next to the other small ledgers (after `set_setting`, around line 280):

```gdscript
# --- FTUE seen-once ledger -------------------------------------------------
# Which one-time hand hints the player has already been shown-and-completed, keyed by hint id
# ("merge", "gen_tap"). Deep-merged over the defaults like the rest of the blob, so a save written
# before this key existed simply reads every id as unseen — no migration.

static func ftue_seen(id: String) -> bool:
	_ensure_loaded()
	var seen: Dictionary = data.get("ftue_seen", {})
	return bool(seen.get(id, false))

static func mark_ftue_seen(id: String) -> void:
	_ensure_loaded()
	if not data.has("ftue_seen"):
		data["ftue_seen"] = {}
	if bool(data["ftue_seen"].get(id, false)):
		return                       # idempotent — never re-write an already-seen id
	data["ftue_seen"][id] = true
	save_now()
```

- [ ] **Step 4: Add the flag to `features.gd`**

In `engine/scripts/core/features.gd`, replace the `# ftue` block's trailing comment lines with the new flag, keeping the historical note:

```gdscript
	# ftue
	"ftue_free_pops": false,      # retired: water now costs from the first pop (no 10-pop free intro)
	"ftue_hand_hint": true,       # the two one-time hand teaches: drag-to-merge, then tap-the-generator (spec 2026-07-23)
	# (ftue_feature_spotlight flag removed 2026-06-23 with the dormant spotlight subsystem — the
	#  merge+bag spotlight redesign is superseded for merge by ftue_hand_hint; the bag teach stays parked)
```

- [ ] **Step 5: Register the suite in the Makefile**

In `Makefile:11`, append ` engine/tests/ftue_hand_hint_tests` to the end of the `ENGINE_TESTS` list.

- [ ] **Step 6: Run the test to verify it passes**

```bash
cd /Users/xup/dh/wt-ftue-hand-hint && godot --headless --path . -s res://engine/tests/ftue_hand_hint_tests.gd
```

Expected: `== 11 passed, 0 failed ==`, exit code 0.

- [ ] **Step 7: Run the fast sweep**

```bash
cd /Users/xup/dh/wt-ftue-hand-hint && make test-fast
```

Expected: every suite PASS, including `ftue_hand_hint_tests`.

- [ ] **Step 8: Commit**

```bash
cd /Users/xup/dh/wt-ftue-hand-hint && git add engine/scripts/core/save.gd engine/scripts/core/features.gd engine/tests/ftue_hand_hint_tests.gd Makefile && git commit -m "FTUE: seen-once ledger + ftue_hand_hint flag

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: The hand-hint overlay

The whole presentation, standalone and testable without a board: a non-blocking dim with rectangular cutouts, plus a looping hand.

**Files:**
- Create: `engine/scripts/ui/hand_hint.gd`
- Modify: `engine/tests/ftue_hand_hint_tests.gd` (add an overlay section)

**Interfaces:**
- Consumes: `Save.ftue_seen` / `Features.on` from Task 1 (only the flag, via `Features.on("ftue_hand_hint")`).
- Produces:
  - `HandHint.present(host: Control, gesture: String, source_rect: Rect2, target_rect: Rect2) -> Control` — static; returns the overlay node (already added as a child of `host`), or `null` when the flag is off.
  - `overlay.retarget(source_rect: Rect2, target_rect: Rect2) -> void`
  - `overlay.dismiss() -> void`
  - `overlay.gesture -> String` (`"drag"` or `"tap"`)
  - `overlay.cutouts() -> Array[Rect2]` — the bright rects, for tests.
  - `const GESTURE_DRAG := "drag"`, `const GESTURE_TAP := "tap"`

- [ ] **Step 1: Write the failing test**

Append to `engine/tests/ftue_hand_hint_tests.gd`, immediately before the final `print("== %d passed…` line:

```gdscript
	# --- the overlay ---
	var host := Control.new()
	host.size = Vector2(800, 1200)
	root.add_child(host)

	var src := Rect2(100, 200, 60, 60)
	var dst := Rect2(300, 200, 60, 60)

	var drag: Control = HandHint.present(host, HandHint.GESTURE_DRAG, src, dst)
	ok(drag != null, "drag: present returns an overlay")
	ok(drag.get_parent() == host, "drag: the overlay is parented to the host")
	ok(drag.gesture == HandHint.GESTURE_DRAG, "drag: the gesture is recorded")
	var cuts: Array = drag.cutouts()
	ok(cuts.size() == 2, "drag: two cutouts (source + target)")
	ok((cuts[0] as Rect2).get_center().is_equal_approx(src.get_center()), "drag: cutout 0 is centred on the source")
	ok((cuts[1] as Rect2).get_center().is_equal_approx(dst.get_center()), "drag: cutout 1 is centred on the target")
	ok(_all_ignore_mouse(drag), "drag: every node in the overlay ignores mouse input (never blocks play)")

	drag.retarget(Rect2(0, 0, 60, 60), Rect2(200, 0, 60, 60))
	var moved: Array = drag.cutouts()
	ok((moved[0] as Rect2).get_center().is_equal_approx(Vector2(30, 30)), "retarget: cutout 0 follows the new source")
	ok((moved[1] as Rect2).get_center().is_equal_approx(Vector2(230, 30)), "retarget: cutout 1 follows the new target")
	ok(drag.get_parent() == host, "retarget: the overlay stays live (no re-present)")

	drag.dismiss()
	ok(drag.dismissed, "dismiss: the overlay is marked dismissed immediately (the fade then frees it)")

	var tap: Control = HandHint.present(host, HandHint.GESTURE_TAP, Rect2(), dst)
	ok(tap != null, "tap: present returns an overlay")
	ok(tap.cutouts().size() == 1, "tap: one cutout (the target only)")
	ok(_all_ignore_mouse(tap), "tap: every node ignores mouse input")
	tap.dismiss()

	# A FRESH host, so the dismissed-but-still-fading overlays above can't be miscounted here.
	var host2 := Control.new()
	host2.size = Vector2(800, 1200)
	root.add_child(host2)
	Feat.FLAGS["ftue_hand_hint"] = false
	ok(HandHint.present(host2, HandHint.GESTURE_TAP, Rect2(), dst) == null, "flag off: present returns null")
	ok(host2.get_child_count() == 0, "flag off: nothing is added to the host")
	Feat.FLAGS["ftue_hand_hint"] = true
```

Add the preload at the top of the file, next to the others:

```gdscript
const HandHint = preload("res://engine/scripts/ui/hand_hint.gd")
```

And add this helper next to `ok()`:

```gdscript
# The overlay must never eat a touch — the player performs the real gesture through it.
func _all_ignore_mouse(n: Node) -> bool:
	if n is Control and (n as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return false
	for c in n.get_children():
		if not _all_ignore_mouse(c):
			return false
	return true
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd /Users/xup/dh/wt-ftue-hand-hint && godot --headless --path . -s res://engine/tests/ftue_hand_hint_tests.gd
```

Expected: FAIL — the script fails to load, `res://engine/scripts/ui/hand_hint.gd` does not exist.

- [ ] **Step 3: Write the overlay**

Create `engine/scripts/ui/hand_hint.gd`:

```gdscript
extends Control
## The FTUE hand hint — one reusable, INPUT-TRANSPARENT teach overlay.
## Spec: docs/superpowers/specs/2026-07-23-ftue-hand-hint-design.md
##
## Two gestures: "drag" (hand glides source → target, two bright cutouts) and "tap" (hand bobs on
## the target, one cutout). A soft dim covers everything EXCEPT the cutouts, built by rectangle
## SUBTRACTION — screen minus each cutout — as plain ColorRect bands. No shader.
##
## The overlay never blocks play: every node sets MOUSE_FILTER_IGNORE, so the player performs the
## real gesture straight through the veil. It also never self-dismisses — it loops until the owner
## calls dismiss() because the taught action actually happened. The owner (board.gd) decides WHEN;
## this file only decides HOW it looks.
##
## ui/ layer: imports core/ and ui/ only, never scenes/.

const Features = preload("res://engine/scripts/core/features.gd")
const Look = preload("res://engine/scripts/ui/skin.gd")

const GESTURE_DRAG := "drag"
const GESTURE_TAP := "tap"

const DIM_ALPHA := 0.35          # the soft dim over everything but the cutouts
const CUTOUT_PAD := 6.0          # a little breathing room around the taught cell
const HAND_PX := 96.0            # the hand's on-screen size
const HAND_OFFSET := Vector2(18.0, 14.0)   # the fingertip sits up-left of the texture's centre
const DRAG_GLIDE_S := 0.9        # source → target travel
const DRAG_PAUSE_S := 0.4        # the beat between loops
const TAP_CYCLE_S := 0.35        # one down/up bob
const PRESS_SCALE := 0.86        # the hand's scale while "pressing"
const TAP_BOB_PX := 14.0         # how far the hand dips on the tap's down beat

var gesture := GESTURE_DRAG
var dismissed := false           # set the instant dismiss() is called, before the fade-out finishes
var _src := Rect2()
var _dst := Rect2()
var _veil: Control
var _hand: Control
var _tween: Tween

## Build and start a hint over `host`. Returns null (and adds nothing) when the flag is off.
## Rects are in `host`'s coordinate space.
static func present(host: Control, gesture_id: String, source_rect: Rect2, target_rect: Rect2) -> Control:
	if not Features.on("ftue_hand_hint"):
		return null
	if host == null or not is_instance_valid(host):
		return null
	var o := new()
	o.gesture = gesture_id
	o._src = source_rect
	o._dst = target_rect
	host.add_child(o)
	return o

func _ready() -> void:
	name = "HandHint"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 4000                       # above the board, below nothing that matters
	_veil = Control.new()
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_veil)
	_hand = _make_hand()
	add_child(_hand)
	_rebuild_veil()
	_start_loop()

## The bright rects this hint punches through the dim: [source, target] for a drag, [target] for a tap.
func cutouts() -> Array:
	if gesture == GESTURE_DRAG:
		return [_src.grow(CUTOUT_PAD), _dst.grow(CUTOUT_PAD)]
	return [_dst.grow(CUTOUT_PAD)]

## Move the hint to new rects WITHOUT restarting it — the board rebuilt under us.
func retarget(source_rect: Rect2, target_rect: Rect2) -> void:
	_src = source_rect
	_dst = target_rect
	_rebuild_veil()
	_start_loop()

func dismiss() -> void:
	if dismissed:
		return
	dismissed = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.18)
	t.tween_callback(queue_free)

# --- the veil ---------------------------------------------------------------
# Screen minus N cutouts, as axis-aligned bands. For one cutout that is the classic four-band
# frame (above / below / left / right). For two, the second is subtracted from each band the
# first produced — so the result is always a set of disjoint rects covering everything but the
# cutouts, however they are arranged.

func _rebuild_veil() -> void:
	for c in _veil.get_children():
		c.queue_free()
	var screen := Rect2(Vector2.ZERO, size if size != Vector2.ZERO else get_viewport_rect().size)
	var bands: Array = [screen]
	for hole in cutouts():
		var next: Array = []
		for band in bands:
			next.append_array(_subtract(band, hole))
		bands = next
	for band in bands:
		var r := ColorRect.new()
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.color = Color(0.0, 0.0, 0.0, DIM_ALPHA)
		r.position = (band as Rect2).position
		r.size = (band as Rect2).size
		_veil.add_child(r)

# `band` minus `hole` as up to four axis-aligned rects. No intersection → the band, unchanged.
func _subtract(band: Rect2, hole: Rect2) -> Array:
	var cut := band.intersection(hole)
	if cut.size.x <= 0.0 or cut.size.y <= 0.0:
		return [band]
	var out: Array = []
	if cut.position.y > band.position.y:                                   # above
		out.append(Rect2(band.position, Vector2(band.size.x, cut.position.y - band.position.y)))
	if cut.end.y < band.end.y:                                             # below
		out.append(Rect2(Vector2(band.position.x, cut.end.y), Vector2(band.size.x, band.end.y - cut.end.y)))
	if cut.position.x > band.position.x:                                   # left, between the two
		out.append(Rect2(Vector2(band.position.x, cut.position.y), Vector2(cut.position.x - band.position.x, cut.size.y)))
	if cut.end.x < band.end.x:                                             # right, between the two
		out.append(Rect2(Vector2(cut.end.x, cut.position.y), Vector2(band.end.x - cut.end.x, cut.size.y)))
	return out

# --- the hand ---------------------------------------------------------------
# Ships twice (Look kit rule): the generated cursor when ui/kit/hand.png exists, a small
# code-drawn hand otherwise, at the SAME metrics so the motion is identical either way.

func _make_hand() -> Control:
	var tex: Texture2D = null
	var p := Look.kit("kit/hand.png")
	if ResourceLoader.exists(p):
		tex = load(p) as Texture2D
	if tex != null:
		var tr := TextureRect.new()
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE      # BEFORE size — a later set silently clamps up
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		tr.texture = tex
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.size = Vector2(HAND_PX, HAND_PX)
		tr.pivot_offset = Vector2(HAND_PX, HAND_PX) * 0.5
		return tr
	var fb := _HandDraw.new()
	fb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fb.size = Vector2(HAND_PX, HAND_PX)
	fb.pivot_offset = Vector2(HAND_PX, HAND_PX) * 0.5
	return fb

# The code-drawn fallback: a pale rounded finger with a cuff. Same box as the texture.
class _HandDraw extends Control:
	func _draw() -> void:
		var w := size.x
		var cream := Color(0.98, 0.94, 0.86, 0.98)
		var edge := Color(0.36, 0.28, 0.22, 0.85)
		var palm := Rect2(w * 0.28, w * 0.42, w * 0.44, w * 0.44)
		draw_circle(Vector2(w * 0.5, w * 0.30), w * 0.13, cream)          # fingertip
		draw_rect(palm, cream, true)
		draw_circle(Vector2(w * 0.5, w * 0.30), w * 0.13, edge, false, 2.0)
		draw_rect(palm, edge, false, 2.0)

func _hand_pos_for(r: Rect2) -> Vector2:
	return r.get_center() - _hand.size * 0.5 + HAND_OFFSET

func _start_loop() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if gesture == GESTURE_DRAG:
		_loop_drag()
	else:
		_loop_tap()

func _loop_drag() -> void:
	_hand.position = _hand_pos_for(_src)
	_hand.scale = Vector2.ONE
	_tween = create_tween().set_loops()
	_tween.tween_property(_hand, "scale", Vector2(PRESS_SCALE, PRESS_SCALE), 0.14)   # press
	_tween.tween_property(_hand, "position", _hand_pos_for(_dst), DRAG_GLIDE_S) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)                     # glide
	_tween.tween_property(_hand, "scale", Vector2.ONE, 0.14)                         # release
	_tween.tween_interval(DRAG_PAUSE_S)
	_tween.tween_property(_hand, "modulate:a", 0.0, 0.18)
	_tween.tween_callback(func() -> void: _hand.position = _hand_pos_for(_src))
	_tween.tween_property(_hand, "modulate:a", 1.0, 0.18)

func _loop_tap() -> void:
	var up := _hand_pos_for(_dst)
	_hand.position = up
	_hand.scale = Vector2.ONE
	_tween = create_tween().set_loops()
	_tween.set_parallel(false)
	_tween.tween_property(_hand, "position", up + Vector2(0.0, TAP_BOB_PX), TAP_CYCLE_S * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(_hand, "scale", Vector2(PRESS_SCALE, PRESS_SCALE), TAP_CYCLE_S * 0.5)
	_tween.tween_property(_hand, "position", up, TAP_CYCLE_S * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_hand, "scale", Vector2.ONE, TAP_CYCLE_S * 0.5)
	_tween.tween_interval(DRAG_PAUSE_S)
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
cd /Users/xup/dh/wt-ftue-hand-hint && godot --headless --path . -s res://engine/tests/ftue_hand_hint_tests.gd
```

Expected: `== 27 passed, 0 failed ==`, exit code 0. Note the dismiss assertion reads the `dismissed` flag, not the parent: the fade-out tween does not advance inside a headless `SceneTree` script, so the node is still parented at that moment by design.

- [ ] **Step 5: Verify the layering rule still holds**

```bash
cd /Users/xup/dh/wt-ftue-hand-hint && godot --headless --path . -s res://engine/tests/layering_tests.gd
```

Expected: PASS — `hand_hint.gd` preloads only from `core/` and `ui/`.

- [ ] **Step 6: Run the fast sweep**

```bash
cd /Users/xup/dh/wt-ftue-hand-hint && make test-fast
```

Expected: every suite PASS.

- [ ] **Step 7: Commit**

```bash
cd /Users/xup/dh/wt-ftue-hand-hint && git add engine/scripts/ui/hand_hint.gd engine/tests/ftue_hand_hint_tests.gd && git commit -m "FTUE: the reusable hand-hint overlay (soft dim + looping hand)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Board triggers, completion hooks, and idle-hint coordination

Wires the overlay into play: which hint is eligible, when it retargets, and what ends it.

**Files:**
- Modify: `engine/scripts/scenes/board.gd` — the members block (~line 154), `_rebuild_all` (line 1524), `_hint_pair` (line 422), `_after_merge` (line 2939), `_release_gen`'s still-tap branch (line 2668).
- Modify: `engine/tests/ftue_hand_hint_tests.gd` (add an eligibility section)

**Interfaces:**
- Consumes: `Save.ftue_seen` / `Save.mark_ftue_seen` (Task 1); `HandHint.present` / `retarget` / `dismiss` / `GESTURE_DRAG` / `GESTURE_TAP` (Task 2).
- Produces:
  - `board.gd` members `_hand_hint: Control`, `_hand_hint_id: String`
  - `board.gd` methods `_maybe_hand_hint() -> void`, `_hand_hint_eligible() -> String`, `_end_hand_hint(id: String) -> void`
  - A pure static seam for tests: `HandHint.next_hint_id(merge_seen: bool, gen_tap_seen: bool, has_pair: bool, has_gen: bool) -> String` — returns `"merge"`, `"gen_tap"`, or `""`.

- [ ] **Step 1: Write the failing test for the eligibility seam**

Append to `engine/tests/ftue_hand_hint_tests.gd`, before the final print:

```gdscript
	# --- eligibility order (pure seam — no scene needed) ---
	# merge first; gen_tap only once merge is seen; nothing once both are seen.
	ok(HandHint.next_hint_id(false, false, true, true) == "merge", "fresh board: merge is the eligible hint")
	ok(HandHint.next_hint_id(true, false, true, true) == "gen_tap", "merge seen: gen_tap follows")
	ok(HandHint.next_hint_id(true, true, true, true) == "", "both seen: nothing is eligible")
	ok(HandHint.next_hint_id(false, false, false, true) == "", "no mergeable pair: the merge hint waits (does not skip ahead)")
	ok(HandHint.next_hint_id(true, false, true, false) == "", "no generator node: gen_tap waits")
	# skip-if-already-done: the player popped the generator during the merge hint.
	ok(HandHint.next_hint_id(false, true, true, true) == "merge", "gen_tap already done: merge still shows")
	ok(HandHint.next_hint_id(true, true, true, true) == "", "gen_tap already done: it never shows afterwards")
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd /Users/xup/dh/wt-ftue-hand-hint && godot --headless --path . -s res://engine/tests/ftue_hand_hint_tests.gd
```

Expected: FAIL — invalid call, `next_hint_id` is not declared.

- [ ] **Step 3: Add the seam to `hand_hint.gd`**

Append to `engine/scripts/ui/hand_hint.gd`:

```gdscript
# --- eligibility (pure seam) ------------------------------------------------
# WHICH hint should be live right now, given the ledger and what the board can offer. Kept here,
# free of scene state, so the teach ORDER is asserted headlessly. "" = show nothing.
# Order is merge → gen_tap: a hint never skips ahead of an earlier unseen one, so a player who
# happens to lack a mergeable pair simply waits rather than being taught out of order.
static func next_hint_id(merge_seen: bool, gen_tap_seen: bool, has_pair: bool, has_gen: bool) -> String:
	if not merge_seen:
		return "merge" if has_pair else ""
	if not gen_tap_seen:
		return "gen_tap" if has_gen else ""
	return ""
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
cd /Users/xup/dh/wt-ftue-hand-hint && godot --headless --path . -s res://engine/tests/ftue_hand_hint_tests.gd
```

Expected: `== 34 passed, 0 failed ==`.

- [ ] **Step 5: Add the members and the preload to `board.gd`**

At the top of `engine/scripts/scenes/board.gd`, alongside the other `ui/` preloads, add:

```gdscript
const HandHint = preload("res://engine/scripts/ui/hand_hint.gd")
```

Next to the other node-tracking members (near `var gen_nodes := {}`, line 154), add:

```gdscript
var _hand_hint: Control = null      # FTUE: the live hand teach overlay (at most one), or null
var _hand_hint_id := ""             # which teach it is ("merge" / "gen_tap")
```

- [ ] **Step 6: Add the trigger to `board.gd`**

Add these three functions near `_hint_pair` (after line 431):

```gdscript
# --- FTUE hand hints -------------------------------------------------------------------
# Two one-time teaches, in order: drag-to-merge, then tap-the-generator. Spec:
# docs/superpowers/specs/2026-07-23-ftue-hand-hint-design.md. Called at the end of every
# _rebuild_all so the hint follows the board; a live hint RETARGETS rather than restarting.

func _maybe_hand_hint() -> void:
	if not Features.on("ftue_hand_hint"):
		return
	await get_tree().process_frame          # let the rebuild's layout settle before reading rects
	if not is_inside_tree():
		return
	var want := _hand_hint_eligible()
	if want == "":
		_dismiss_hand_hint()
		return
	var rects := _hand_hint_rects(want)
	if rects.is_empty():
		_dismiss_hand_hint()
		return
	if _hand_hint != null and is_instance_valid(_hand_hint) and _hand_hint_id == want:
		_hand_hint.retarget(rects[0], rects[1])   # same teach, moved board — keep the loop running
		return
	_dismiss_hand_hint()
	var gesture: String = HandHint.GESTURE_DRAG if want == "merge" else HandHint.GESTURE_TAP
	_hand_hint = HandHint.present(self, gesture, rects[0], rects[1])
	_hand_hint_id = want if _hand_hint != null else ""

# Which teach the ledger + the current board allow. "" = none.
func _hand_hint_eligible() -> String:
	var has_pair := not BoardLogic.find_mergeable_pair(board).is_empty()
	var has_gen := not _hand_hint_gen_cell().is_empty()
	return HandHint.next_hint_id(Save.ftue_seen("merge"), Save.ftue_seen("gen_tap"), has_pair, has_gen)

# The generator the tap teach points at: the first live, tappable (non-accumulator, non-treat)
# generator on the board. [] when there is none. Returned as an Array so "no cell" is expressible.
func _hand_hint_gen_cell() -> Array:
	for cell in gen_nodes.keys():
		if not board.is_gen(cell):
			continue
		var gid := board.gen_id_at(cell)
		if G.is_accumulator(gid) or G.is_treat_gen(gid):
			continue
		var n: Control = gen_nodes.get(cell)
		if n != null and is_instance_valid(n):
			return [cell]
	return []

# [source_rect, target_rect] in THIS control's space, or [] when a node is missing.
func _hand_hint_rects(id: String) -> Array:
	if id == "merge":
		var pair := BoardLogic.find_mergeable_pair(board)
		if pair.size() < 2:
			return []
		var a: Control = piece_nodes.get(pair[0])
		var b: Control = piece_nodes.get(pair[1])
		if a == null or not is_instance_valid(a) or b == null or not is_instance_valid(b):
			return []
		return [_local_rect(a), _local_rect(b)]
	var gc := _hand_hint_gen_cell()
	if gc.is_empty():
		return []
	var gn: Control = gen_nodes.get(gc[0])
	if gn == null or not is_instance_valid(gn):
		return []
	return [Rect2(), _local_rect(gn)]

func _local_rect(n: Control) -> Rect2:
	var gr := n.get_global_rect()
	return Rect2(gr.position - get_global_rect().position, gr.size)

func _dismiss_hand_hint() -> void:
	if _hand_hint != null and is_instance_valid(_hand_hint):
		_hand_hint.dismiss()
	_hand_hint = null
	_hand_hint_id = ""

# The taught action HAPPENED — bank it and hand off to the next teach.
func _end_hand_hint(id: String) -> void:
	if not Features.on("ftue_hand_hint"):
		return
	if Save.ftue_seen(id):
		return
	Save.mark_ftue_seen(id)
	if _hand_hint_id == id:
		_dismiss_hand_hint()
	_maybe_hand_hint()
```

- [ ] **Step 7: Call the trigger and the two completion hooks**

At the very end of `_rebuild_all` (line 1524's function), append:

```gdscript
	_maybe_hand_hint()                        # FTUE: the merge / generator-tap teach follows the board
```

In `_after_merge` (line 2939), immediately after `_mark_seen(produced)`, add:

```gdscript
	_end_hand_hint("merge")       # FTUE: the player just merged — the merge teach is done, forever
```

In `_release_gen`'s still-tap branch (line 2668), in the `else:` arm, immediately after `_pop_seed(from)`, add:

```gdscript
			_end_hand_hint("gen_tap")   # FTUE: a real generator tap ends (or pre-empts) the tap teach
```

- [ ] **Step 8: Suppress the idle hint while a hand hint is live or the merge teach is pending**

Replace the guard at the top of `_hint_pair` (line 422-424) with:

```gdscript
func _hint_pair() -> Array:
	if not Features.on("idle_hint"):
		return []
	# FTUE: the hand is the FIRST merge teach. Don't rock pieces under a live hint, and don't
	# rock them at all until the merge hand has been seen — after that the idle hint resumes as
	# the ongoing re-nudge.
	if _hand_hint != null and is_instance_valid(_hand_hint):
		return []
	if Features.on("ftue_hand_hint") and not Save.ftue_seen("merge"):
		return []
```

- [ ] **Step 9: Parse-check the scene**

```bash
cd /Users/xup/dh/wt-ftue-hand-hint && godot --headless --path . --check-only --script res://engine/scripts/scenes/board.gd && echo PARSE-OK
```

Expected: `PARSE-OK`, no errors. (A full `godot -s` run of board.gd is not how this file is exercised — the grove suites instantiate the scene.)

- [ ] **Step 10: Run the full sweep**

```bash
cd /Users/xup/dh/wt-ftue-hand-hint && make test
```

Expected: every suite PASS, including the grove suites that build the board scene. If `grove_ui_tests` or `grove_placement_tests` now fail because a hand hint appears over a test board, fix it by having those suites mark both ids seen in `games/grove/tests/grove_test_base.gd` setup:

```gdscript
	Save.mark_ftue_seen("merge")
	Save.mark_ftue_seen("gen_tap")
```

- [ ] **Step 11: Commit**

```bash
cd /Users/xup/dh/wt-ftue-hand-hint && git add -A && git commit -m "FTUE: board triggers for the merge and generator-tap hand hints

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: The hand art, and seeing the result

The overlay ships with a code-drawn fallback, so this task swaps in the real cursor and — the actual gate — looks at both hints rendered through the real path.

**Files:**
- Read first: `docs/design/art-style-guide.md`
- Create: `games/grove/assets/_new/<raw>.png`, `games/grove/assets/_new/hand.plan.json`
- Produces: `games/grove/assets/ui/kit/hand.png`, archived raw under `_originals/ui/`
- Modify: `games/grove/tools/grove_shot.gd` (a `ftue` capture mode)

**Interfaces:**
- Consumes: `Look.kit("kit/hand.png")` resolves to `games/grove/assets/ui/kit/hand.png` — the path `hand_hint.gd` already probes.
- Produces: no code interface; an art file plus two screenshots.

- [ ] **Step 1: Read the art guide before generating anything**

Read `docs/design/art-style-guide.md` in full — palette, canvas contract, prompt scaffolds, keying, and the intake workflow. Do not hand-roll a keyer or a prompt.

- [ ] **Step 2: Generate the raw hand**

Use the `generating-images-with-codex` skill. The subject: a simple pointing-hand cursor — index finger extended upward-left, other fingers curled, a short cuff — in the game's cut-paper style, cream fill with a warm dark outline, on a fully transparent background, generous padding, no shadow. Save the raw PNG into `games/grove/assets/_new/`.

- [ ] **Step 3: Author the intake plan**

Create `games/grove/assets/_new/hand.plan.json` following the guide's schema — `category: icon`, `params.size: 512`, output `ui/kit/hand.png`, archive under `_originals/ui/`. All judgment (classification, naming, params) lives in this plan; the scripts stay deterministic.

- [ ] **Step 4: Run intake**

```bash
cd /Users/xup/dh/wt-ftue-hand-hint && make intake
```

Expected: the plan is consumed, `games/grove/assets/ui/kit/hand.png` is written, the raw is archived (never deleted), and the importer runs.

- [ ] **Step 5: Verify the alpha**

Open `games/grove/assets/ui/kit/hand.png` and check it over a contrasting background per the guide's review checklist. If it has halos or a dirty edge, re-roll the raw and repeat from Step 2.

- [ ] **Step 6: Add a capture mode to the shot tool**

In `games/grove/tools/grove_shot.gd`, add a `ftue` mode that clears the ledger before the board builds, so a capture shows the merge hand on a fresh board:

```gdscript
	if mode == "ftue":
		Save.data["ftue_seen"] = {}          # a brand-new player: the merge hand is live
```

and a `ftuegen` mode that shows the second teach:

```gdscript
	if mode == "ftuegen":
		Save.data["ftue_seen"] = {"merge": true}   # merge taught — the generator tap hand is live
```

Place both alongside the existing mode branches, before the board is built.

- [ ] **Step 7: Capture both hints**

```bash
cd /Users/xup/dh/wt-ftue-hand-hint && make shot-grove MODE=ftue OUT=/tmp/ftue_merge.png && make shot-grove MODE=ftuegen OUT=/tmp/ftue_gen.png
```

Expected: two PNGs at the project's full resolution, no focus stolen.

- [ ] **Step 8: Look at both screenshots**

Read `/tmp/ftue_merge.png` and `/tmp/ftue_gen.png` and confirm, explicitly:
- the dim is soft, not a blackout, and covers everything except the cutouts;
- the merge shot has **two** bright cells, the generator shot has **one**;
- the hand reads as a hand at this size and sits over the right cell;
- the board underneath is still legible.

If any of these fail, fix and re-capture. Do not claim this task done from the test results alone — the gate is having seen the rendered result.

- [ ] **Step 9: Run the full sweep**

```bash
cd /Users/xup/dh/wt-ftue-hand-hint && make test
```

Expected: every suite PASS.

- [ ] **Step 10: Commit and deliver the screenshots**

```bash
cd /Users/xup/dh/wt-ftue-hand-hint && git add -A && git commit -m "FTUE: hand cursor art + ftue capture modes

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

Then send `/tmp/ftue_merge.png` and `/tmp/ftue_gen.png` to the user before declaring the feature done.

---

## Done criteria

- `make test` green.
- Both screenshots captured, looked at, and delivered.
- A fresh save shows the merge hand immediately; performing a merge swaps it for the generator hand; tapping the generator ends it; neither returns on the next launch.
- Setting `ftue_hand_hint` to `false` removes both hints entirely with no other behaviour change.
