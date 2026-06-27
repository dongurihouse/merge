# Unified Feel Verbs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the whole game one juice vocabulary — four shared verbs (`merge`, `land`, `launch`, `move`) every scene calls, plus tactile/impact/combo screen-juice bundles — so merges, landings, launches, and movement feel consistently great everywhere.

**Architecture:** A new `engine/scripts/ui/feel.gd` static library composes the existing `fx.gd` primitives (`squash_pop`, `flash`, `hitstop`, `burst`, `shake`, `gen_charge`, `Audio.play`) into the four verbs, each taking an `intensity` (0–1) so a surface shares the vocabulary while dialing strength. `fx.gd` stays the primitive library; scenes stop hand-assembling primitives and call `feel.*`. Board merge is refactored behavior-preserving first, then Rush and the map adopt the verbs, then the bundles layer on.

**Tech Stack:** Godot 4.6 (Mobile renderer), GDScript. Tests are headless SceneTree suites run via `make test-fast` (engine) and `make test-grove` / `make test` (full).

**Source of truth:** `docs/superpowers/specs/2026-06-27-unified-feel-verbs-design.md`. Read it before starting. For any exact value not pinned here, read the cited real code line and the spec, and preserve existing feel.

**Working rules:**
- Worktree is `/Users/xup/dh/feel-verbs` on branch `feel-verbs` (already created). Do all work here.
- TDD: write the failing test, see it fail, implement minimally, see it pass, commit.
- Run `make test-fast` after every engine change; `make test` before handoff. The runner never trusts a zero exit alone — read its per-suite table.
- Headless cannot freeze `time_scale` or vibrate; assert *intent* (the `*_wanted()`/requested calls), not the global side effect, in headless suites — follow the existing `fx_juice_tests.gd` / `rush_fx_tests.gd` patterns.
- Match surrounding code style: `extends RefCounted`, `const FX = preload(...)`, static funcs, snake_case.

---

## File Structure

- **Create** `engine/scripts/ui/feel.gd` — the four verbs + `haptic` + `ripple` + `board_punch`, composing `fx.gd` primitives. One responsibility: the shared juice grammar.
- **Create** `engine/tests/feel_tests.gd` — unit suite for the verbs/bundles (intent-level, calm/headless aware).
- **Modify** `engine/scripts/core/tuning.gd` (class `FX`) — add the new constants.
- **Modify** `engine/scripts/ui/fx.gd` — generalize `gen_charge` for reuse if needed; no primitive behavior changes.
- **Modify** `engine/scripts/scenes/board.gd` — route merge/land/launch/move through `feel`; add telegraph + drag-lean.
- **Modify** `engine/scripts/scenes/explore_rush.gd` — route merge/land/launch/move through `feel`.
- **Modify** `engine/scripts/scenes/map.gd` — route the spirit merge through `feel.merge` at low intensity.
- **Modify** `engine/scripts/ui/rush_fx.gd` — thin out the merge effects now owned by `feel.merge`; keep score tick / pulse / combo heat / timer / treefall.
- **Modify** `engine/scripts/ui/ambient.gd` — accept an outward puff impulse for reactive motes.
- **Modify** `engine/tests/rush_fx_tests.gd` — update for the rerouting.
- **Modify** `engine/tools/run_suites.py` (or the suite registry it reads) — register `feel_tests`.

---

## Phase 0 — Scaffolding: tuning constants + empty module + registered suite

### Task 0.1: Add tuning constants

**Files:**
- Modify: `engine/scripts/core/tuning.gd` (class `FX`)

- [ ] **Step 1: Read the existing FX tuning block** (`tuning.gd`, the `class FX` region, ~lines 114–239) to match style and find `SQUASH_K/T`, `FLASH_PEAK/T`, `HITSTOP_*`, `BURST_*`, `SHAKE_*`, `GEN_CHARGE_K/T`, `ESCALATE_TIER`, `COMBO_WINDOW`, `COMBO_MILESTONES`.

- [ ] **Step 2: Add the new constants** (suggested starting values; tune later). Append inside `class FX`:

```gdscript
# --- feel.land ---
const LAND_SQUASH_K := [Vector2(1.14, 0.86), Vector2.ONE]   # 2-key land impact (Rush's current values)
const LAND_SQUASH_T := [0.05, 0.10]
const LAND_FLASH_FACTOR := 0.45        # land flash peak = FLASH_PEAK * this * intensity
const LAND_FLASH_T := 0.10             # shorter than a merge flash
const LAND_TOUCH_DB := -4.0
const LAND_PUFF_N := 4
# --- feel.launch ---
const LAUNCH_TOSS_DB := -5.0
const LAUNCH_PUFF_N := 4
# --- feel.merge extras ---
const MERGE_FLASH_TIER_RAMP := [0.5, 0.65, 0.8, 1.0]   # peak factor for tier 1,2,3,>=4
const MERGE_HITSTOP_COMBO_BONUS := 0.004               # secs per combo over the gate
const MERGE_BURST_HOT_TIER := 8
# --- feel.move ---
const MOVE_SLIDE_T := 0.12
const MOVE_ARC_T_UP := 0.16
const MOVE_ARC_T_DOWN := 0.18
const MOVE_FALL_T_MIN := 0.10
const MOVE_FALL_T_MAX := 0.36
const MOVE_LEAN_DEG := 6.0
const MOVE_SHADOW_ALPHA := 0.22
const MOVE_SHADOW_OFFSET := Vector2(3, 6)
const MOVE_SHADOW_SCALE := 0.9
const MOVE_TRAIL_N := 3
const MOVE_TRAIL_T := 0.12
const MOVE_TRAIL_SPEED_REF := 1400.0   # px/s at which the trail reaches full density
# --- bundle A: tactile ---
const HAPTIC_MS := {"tick": 8, "soft": 14, "firm": 22, "heavy": 32}
const HAPTIC_THROTTLE_MS := 40
const DRAG_LEAN_DEG := 8.0
const DRAG_LEAN_LAG := 0.12
const TELEGRAPH_GLOW := Color(1.15, 1.15, 1.05, 1.0)
const TELEGRAPH_MAGNET := 0.10         # fraction of a cell the pair leans together
# --- bundle B: impact propagation ---
const RIPPLE_SQUASH := 0.06            # neighbor nudge as a fraction off rest scale
const RIPPLE_STAGGER_MS := 18
const PUNCH := 0.03                    # board scale delta at intensity 1
const PUNCH_T := 0.09
# --- bundle D: combo / world ---
const PENTA := [0, 2, 4, 7, 9, 12, 14, 16, 19, 21]   # major-pentatonic semitone ladder
const COMBO_BLOOM_MAX := 0.28
const COMBO_BLOOM_RISE := 0.12
const COMBO_BLOOM_DECAY := 0.5
const MOTE_PUFF_IMPULSE := 220.0
```

- [ ] **Step 3: Run the engine suite to confirm nothing broke** — `make test-fast` — Expected: all green (constants are inert).

- [ ] **Step 4: Commit** — `git add engine/scripts/core/tuning.gd && git commit -m "feat(feel): add tuning constants for unified feel verbs + juice bundles"`

### Task 0.2: Create the empty `feel.gd` module and a registered test suite

**Files:**
- Create: `engine/scripts/ui/feel.gd`
- Create: `engine/tests/feel_tests.gd`
- Modify: `engine/tools/run_suites.py` (the engine suite list)

- [ ] **Step 1: Read `engine/scripts/ui/rush_fx.gd` and `engine/tests/rush_fx_tests.gd`** for the module + test patterns (static funcs, how a headless suite instantiates and asserts, the colour consts `LEAF/STRAW/HOT`).

- [ ] **Step 2: Read `engine/tools/run_suites.py`** to find the engine suite list and how suites are named/added.

- [ ] **Step 3: Create `feel.gd` with the verb signatures as stubs:**

```gdscript
extends RefCounted
## The four shared FEEL VERBS — merge / land / launch / move — plus the screen-juice
## helpers (haptic, ripple, board_punch). Each composes the fx.gd primitives and takes an
## `intensity` (0..1) so a surface shares the vocabulary while dialing the strength.
## fx.gd stays the primitive library; scenes call these instead of hand-assembling primitives.

const FX = preload("res://engine/scripts/ui/fx.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")
const Tune = preload("res://engine/scripts/core/tuning.gd").FX

const LEAF := Color("#7FB069")
const STRAW := Color("#E3B23C")
const HOT := Color("#E0592B")

# implemented in later tasks
static func merge(host: Node, node: Control, center: Vector2, tier: int, combo: int, intensity := 1.0, hitstop_gate := 0) -> void:
	pass
static func land(host: Node, node: Control, center: Vector2, intensity := 1.0) -> void:
	pass
static func launch(emitter: Control, projectile: Control, intensity := 1.0) -> void:
	pass
static func move(node: Control, from: Vector2, to: Vector2, kind := "slide", dur := -1.0) -> Tween:
	return null
static func haptic(weight := "soft") -> void:
	pass
static func ripple(neighbors: Array, impact_center: Vector2, intensity := 1.0) -> void:
	pass
static func board_punch(board: Control, intensity := 1.0) -> void:
	pass
```

- [ ] **Step 4: Create `feel_tests.gd`** mirroring `rush_fx_tests.gd`'s harness with one smoke test:

```gdscript
extends SceneTree
const Feel = preload("res://engine/scripts/ui/feel.gd")

func _initialize() -> void:
	var ok := true
	ok = _t_module_loads() and ok
	# more tests appended in later tasks
	print("feel_tests: ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)

func _t_module_loads() -> bool:
	# the verbs exist and are callable as no-ops at this stage
	Feel.haptic("tick")
	return true
```

(Match the actual base/harness used by the engine suites — if they extend a shared base or use a different print/assert convention, follow it instead of the sketch above.)

- [ ] **Step 5: Register the suite** in `run_suites.py` engine list so `make test-fast` runs `feel_tests`.

- [ ] **Step 6: Run** `make test-fast` — Expected: `feel_tests` appears in the table and PASSes.

- [ ] **Step 7: Commit** — `git add engine/scripts/ui/feel.gd engine/tests/feel_tests.gd engine/tools/run_suites.py && git commit -m "feat(feel): scaffold feel.gd verb stubs + registered test suite"`

---

## Phase 1 — `feel.merge` + behavior-preserving board refactor

### Task 1.1: Implement `feel.merge`

**Files:**
- Modify: `engine/scripts/ui/feel.gd`
- Test: `engine/tests/feel_tests.gd`

- [ ] **Step 1: Read** `board.gd:2531-2612` (`_after_merge`) and `fx.gd` `flash`/`hitstop`/`burst`/`squash_pop`/`shake` signatures, plus the pitch math at `board.gd:2551-2563`. The verb must reproduce the board's behaviour at `intensity=1.0, gate=0`.

- [ ] **Step 2: Write failing tests** in `feel_tests.gd`: at intensity 0 no flash/hitstop/burst fire; tier<4 picks green burst + `merge_soft`, tier>=4 picks gold + `merge_success`; tier>=`MERGE_BURST_HOT_TIER` picks `HOT`; `hitstop_gate` above `combo` yields zero freeze request. Use the headless-safe intent checks (e.g. `FX.hitstop_wanted()`, the colour the verb computes — extract the colour/count/peak math into small pure helpers so they're unit-testable without a tree):

```gdscript
static func _merge_color(tier: int) -> Color:
	if tier >= Tune.MERGE_BURST_HOT_TIER: return HOT
	return STRAW if tier >= 4 else LEAF
static func _merge_flash_peak(tier: int, intensity: float) -> float:
	var ramp: Array = Tune.MERGE_FLASH_TIER_RAMP
	return Tune.FLASH_PEAK * float(ramp[clampi(tier - 1, 0, ramp.size() - 1)]) * intensity
static func _merge_hitstop(tier: int, combo: int, intensity: float, gate: int) -> float:
	if combo < gate: return 0.0
	var base := Tune.HITSTOP_MERGE + Tune.HITSTOP_TIER_BONUS * maxi(0, tier - 1)
	base += Tune.MERGE_HITSTOP_COMBO_BONUS * maxi(0, combo - gate)
	return clampf(base, 0.0, Tune.HITSTOP_MAX) * intensity
```

- [ ] **Step 3: Run** the new tests — Expected: FAIL (helpers/verb not implemented).

- [ ] **Step 4: Implement `feel.merge`** composing the primitives with those helpers:

```gdscript
static func merge(host: Node, node: Control, center: Vector2, tier: int, combo: int, intensity := 1.0, hitstop_gate := 0) -> void:
	FX.squash_pop(node)
	var size := node.size.x if node else 96.0
	FX.flash(host, center, size, _merge_flash_peak(tier, intensity))
	if tier >= Tune.ESCALATE_TIER:
		FX.shake(host)
	var n := FX.amount_for(int((10 + tier * 3) * intensity))
	FX.burst(host, center, _merge_color(tier), n)
	var hs := _merge_hitstop(tier, combo, intensity, hitstop_gate)
	if hs > 0.0:
		FX.hitstop(minf(hs, Tune.HITSTOP_MAX))
	var snd := "merge_success" if tier >= 4 else "merge_soft"
	var pitch := clampf(0.95 + 0.03 * tier, 0.9, 1.3)
	Audio.play(snd, -1.0, pitch)
	haptic(_merge_weight(tier))
```

Add `_merge_weight(tier)` → `"heavy" if tier >= ESCALATE_TIER else "firm" if tier >= 4 else "soft"`. (The pentatonic ladder replaces the linear pitch in Phase 8 — keep linear here.)

- [ ] **Step 5: Run** the tests — Expected: PASS. Then `make test-fast` — Expected: all green.

- [ ] **Step 6: Commit** — `git add -A && git commit -m "feat(feel): implement feel.merge composing primitives with intensity + hitstop gate"`

### Task 1.2: Route board `_after_merge` through `feel.merge` (behavior-preserving)

**Files:**
- Modify: `engine/scripts/scenes/board.gd:2531-2582`
- Test: existing board suites (`make test-grove`)

- [ ] **Step 1: Read** `board.gd:2531-2582` fully and note what stays board-local: the combo-milestone callout (`_combo_celebrate`), coin/special drops, `_refresh_locked_cells`, score logic.

- [ ] **Step 2: Replace** the inline squash/flash/shake/hitstop/burst/sound block with a single call, keeping the board-local pieces around it:

```gdscript
Feel.merge(board_area, n, center, tier, combo, 1.0, 0)
```

Add `const Feel = preload("res://engine/scripts/ui/feel.gd")` at the top of `board.gd` if not present. Preserve the `merge_impact` feature flag by leaving `FX.flash`/`FX.hitstop`'s own internal gates (they already self-gate on `merge_impact`/`merge_hitstop` + calm), so behaviour is unchanged when flags are off.

- [ ] **Step 3: Run** `make test-grove` — Expected: green. If a board test asserted specific inline FX, update it to assert the `Feel.merge` path.

- [ ] **Step 4: Manual parity note** — leave a TODO-free comment that this is the unified path; verify side-by-side feel at review time (cannot be unit-verified).

- [ ] **Step 5: Commit** — `git add -A && git commit -m "refactor(board): route merge juice through feel.merge (behavior-preserving)"`

---

## Phase 2 — `feel.merge` into Rush + Spirit; thin `rush_fx`

### Task 2.1: Rush merge through `feel.merge`

**Files:**
- Modify: `engine/scripts/scenes/explore_rush.gd:560-602`
- Modify: `engine/scripts/ui/rush_fx.gd`
- Test: `engine/tests/rush_fx_tests.gd`

- [ ] **Step 1: Read** `explore_rush.gd:560-602` and `rush_fx.gd`. Identify what stays RushFx: `score_tick`, `score_pulse`, `mult_pop`, `combo_heat`, `timer_low`, `treefall_crack`. What moves to `feel.merge`: `merge_burst`, the tier>=4 `flash`+`hitstop`, and the `button_tap` sound.

- [ ] **Step 2: Replace** the merge FX in `_merge`:
  - Remove `Audio.play("button_tap", -3.0)`, the tier>=4 `FX.flash`/`FX.hitstop`, and the `RushFx.merge_burst` call.
  - Add `Feel.merge(self, node, ctr, int(win.tier), _combo, 1.0, 2)` (gate=2 keeps isolated low-combo merges snappy).
  - Keep `FX.floating_text("+pts")`, the score/mult cell pops, `combo_heat`, and the tier>=4 `"BUILD!"` celebrate callout (a Rush-specific milestone, not the verb).
  - Add `const Feel = preload(...)` if missing.

- [ ] **Step 3: Thin `rush_fx.gd`** — keep `merge_burst` defined (used by the workbench preview) but remove its call from the game `_merge`; leave a comment that the live merge burst now comes from `feel.merge`. Do not delete the `merge_burst`/EFFECTS row (the workbench still references it) unless the workbench is updated in the same task.

- [ ] **Step 4: Update `rush_fx_tests.gd`** for the rerouting (the merge-burst/flash/hitstop are no longer asserted off `_merge`; assert the workbench wrapper still works).

- [ ] **Step 5: Run** `make test-grove` and `make test-fast` — Expected: green.

- [ ] **Step 6: Commit** — `git add -A && git commit -m "feat(rush): route merge through feel.merge (real merge sound, every-merge flash, combo-gated thunk)"`

### Task 2.2: Spirit merge through `feel.merge` at intensity 0.4

**Files:**
- Modify: `engine/scripts/scenes/map.gd:1897-1899`
- Test: existing map/grove suite

- [ ] **Step 1: Read** `map.gd:1863-1899` (`_merge_fx` and the placement context) to get the merge node + center.

- [ ] **Step 2: Replace** `_merge_fx` body so it calls the verb gently and keeps the "Merged!" text, with a sentinel gate so no freeze ever fires:

```gdscript
func _merge_fx(node: Control, at: Vector2) -> void:
	Feel.merge(self, node, at, int(node_tier), 0, 0.4, 9999)  # 9999 gate => never freezes
	FX.celebrate_at(self, at, "Merged!", STRAW)
```

(Use the real tier source available at that call site; if tier isn't handy, pass a low constant — the spirit merge is not tier-escalated.) Add `const Feel = preload(...)` if missing.

- [ ] **Step 3: Run** `make test-grove` — Expected: green (the map suite instantiates scenes).

- [ ] **Step 4: Commit** — `git add -A && git commit -m "feat(map): give spirit merge real squash+bloom+burst via feel.merge at low intensity"`

---

## Phase 3 — `feel.land`

### Task 3.1: Implement `feel.land`

**Files:**
- Modify: `engine/scripts/ui/feel.gd`
- Test: `engine/tests/feel_tests.gd`

- [ ] **Step 1: Write failing tests** — at intensity 0 no flash/puff; land flash peak == `FLASH_PEAK * LAND_FLASH_FACTOR * intensity`; a touch sound is requested.

- [ ] **Step 2: Run** — Expected: FAIL.

- [ ] **Step 3: Implement:**

```gdscript
static func land(host: Node, node: Control, center: Vector2, intensity := 1.0) -> void:
	if node and is_instance_valid(node):
		node.pivot_offset = node.size / 2.0
		node.scale = Tune.LAND_SQUASH_K[0]
		var t := node.create_tween()
		for i in range(1, Tune.LAND_SQUASH_K.size()):
			t.tween_property(node, "scale", Tune.LAND_SQUASH_K[i], Tune.LAND_SQUASH_T[i - 1]).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var size := node.size.x if node else 96.0
	FX.flash(host, center, size, Tune.FLASH_PEAK * Tune.LAND_FLASH_FACTOR * intensity)
	if intensity > 0.0:
		FX.burst(host, center, LEAF, FX.amount_for(int(Tune.LAND_PUFF_N * intensity)))
		Audio.play("tidy_poof", Tune.LAND_TOUCH_DB, 1.0)
	haptic("soft")
```

(Land squash should respect `FX.calm()` like `squash_pop` does — gate the scale tween on `not FX.calm()` or reuse `FX.squash_pop(node, ...)` with the 2-key path if a calm fallback exists. Verify the calm path against `fx.gd`.)

- [ ] **Step 4: Run** tests + `make test-fast` — Expected: green.

- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(feel): implement feel.land (impact squash + small flash + touch sound + puff)"`

### Task 3.2: Wire `feel.land` into Rush arrivals + board drops

**Files:**
- Modify: `engine/scripts/scenes/explore_rush.gd` (`_spawn` :517, `_settle` :657, fling-land in `_fly_to` :674)
- Modify: `engine/scripts/scenes/board.gd` (`_drop_coin_near` :2656, `_drop_special_near` :2704)

- [ ] **Step 1: Read** each site's current landing tween; replace the inline `1.14/0.86` squash with a `Feel.land(self, node, center, 0.8)` call on arrival (chain it on the move/fall tween's completion). For Rush settle, call once per settled tile but rely on `haptic`'s throttle (Phase 6) — until then, suppress per-tile haptic by calling land with a flag or only haptic on the merge. Simplest: for bulk settle, call a land *visual* without haptic; expose `land(..., do_haptic := true)` and pass `false` in `_settle`.
  - Add the param to `feel.land`: `static func land(host, node, center, intensity := 1.0, do_haptic := true)`.
- [ ] **Step 2: Board drops** — at the end of the existing grow-in flight tween in `_drop_coin_near`/`_drop_special_near`, chain `Feel.land(self, node, cell_center, 0.8)`. Keep the existing `tidy_poof` or let `feel.land` own the touch sound — pick one (prefer `feel.land`'s, remove the duplicate). **Do NOT touch the generator spawn grow-in** (`_pop_seed`/`_on_pop`) — it keeps its own signature.
- [ ] **Step 3: Run** `make test-grove` + `make test-fast` — Expected: green.
- [ ] **Step 4: Commit** — `git add -A && git commit -m "feat(land): unify Rush arrivals + board drops through feel.land"`

---

## Phase 4 — `feel.launch`

### Task 4.1: Implement `feel.launch` + wire generator & fling

**Files:**
- Modify: `engine/scripts/ui/feel.gd`, `engine/scripts/ui/fx.gd` (reuse `gen_charge`)
- Modify: `engine/scripts/scenes/board.gd` (`_pop_seed`/`_on_pop` ~2385/2437), `engine/scripts/scenes/explore_rush.gd` (`_fling` :604)
- Test: `engine/tests/feel_tests.gd`

- [ ] **Step 1: Read** `fx.gd` `gen_charge` (~277). `feel.launch` should reuse it for the emitter recoil.

- [ ] **Step 2: Write failing test** — `feel.launch` requests the toss sound and a muzzle puff at intensity>0; no-op at intensity 0.

- [ ] **Step 3: Implement:**

```gdscript
static func launch(emitter: Control, projectile: Control, intensity := 1.0) -> void:
	if emitter and is_instance_valid(emitter):
		FX.gen_charge(emitter)
	if intensity > 0.0 and projectile and is_instance_valid(projectile):
		FX.burst(projectile.get_parent(), projectile.position + projectile.size / 2.0, LEAF, FX.amount_for(int(Tune.LAUNCH_PUFF_N * intensity)))
	Audio.play("item_drop", Tune.LAUNCH_TOSS_DB, 1.1)
	haptic("tick")
```

- [ ] **Step 4: Wire generator** — in the generator emit path, replace the bespoke `gen_charge` + spawn sound with `Feel.launch(gnode, item, 1.0)`; **keep** the projectile grow-in `0.3 → 1.0` flight (generator-specific). 
- [ ] **Step 5: Wire fling** — in `_fling`, replace `Audio.play("button_tap", -5.0, 1.2)` with `Feel.launch(<fling-origin-node>, node, 0.9)`; keep the arc + spin (that's `feel.move`'s arc in Phase 5). If no discrete emitter node exists for the fling, pass the tile itself as emitter for the recoil or pass `null` and let recoil no-op.
- [ ] **Step 6: Run** `make test-grove` + `make test-fast` — green.
- [ ] **Step 7: Commit** — `git add -A && git commit -m "feat(launch): unify generator + fling emit through feel.launch"`

---

## Phase 5 — `feel.move` (shadow + trail + accelerate-into-impact)

### Task 5.1: Implement `feel.move`

**Files:**
- Modify: `engine/scripts/ui/feel.gd`
- Test: `engine/tests/feel_tests.gd`

- [ ] **Step 1: Write failing tests** — `move("slide")` returns a Tween animating `position` from→to with `EASE_IN`; under `calm()` no shadow/trail nodes are added; trail count scales with speed (a near-zero distance yields ~0 ghosts, a fast one yields up to `MOVE_TRAIL_N`).

- [ ] **Step 2: Implement** the three kinds with accelerate-into-impact easing, a cast-shadow (a darkened duplicate of `node`'s texture parented under it, freed on finish), a speed-scaled afterimage trail (N faded `node` duplicates dropped along the path, each self-freeing over `MOVE_TRAIL_T`), and a `MOVE_LEAN_DEG` tilt that rights on arrival. Gate shadow/trail/lean on `not FX.calm()` and `DisplayServer.get_name() != "headless"`. Return the primary tween so callers chain `feel.land`.

```gdscript
static func move(node: Control, from: Vector2, to: Vector2, kind := "slide", dur := -1.0) -> Tween:
	# slide: QUAD EASE_IN, dur=MOVE_SLIDE_T; fall: QUAD EASE_IN, distance-scaled; arc: up+down legs.
	# add _spawn_shadow(node) + _spawn_trail(node, from, to, speed) when not calm/headless.
	...
```

(Implement `_spawn_shadow` and `_spawn_trail` as private helpers. Keep them cheap: short-lived, self-freeing, density capped.)

- [ ] **Step 3: Run** tests + `make test-fast` — green.
- [ ] **Step 4: Commit** — `git add -A && git commit -m "feat(feel): implement feel.move with shadow, motion trail, accelerate-into-impact"`

### Task 5.2: Adopt `feel.move` at the travel sites + chain `feel.land`

**Files:**
- Modify: `engine/scripts/scenes/board.gd` (`_commit_merge` slide :2522), `engine/scripts/scenes/explore_rush.gd` (`_fly_to` :674 arc, `_fall_to` :714 fall)

- [ ] **Step 1: Board merge slide** — replace the inline 0.12s position tween in `_commit_merge` with `Feel.move(node, a_pos, b_pos, "slide")` and keep `_after_merge` as the completion callback. Preserve the `merge_impact` ease choice (the verb's EASE_IN already matches the accelerate-into-impact intent).
- [ ] **Step 2: Rush fall** — replace `_fall_to`'s body with `Feel.move(node, node.position, rest, "fall")` then chain `Feel.land(self, node, center, 0.8, false)` on finish (no per-tile haptic).
- [ ] **Step 3: Rush fling arc** — replace `_fly_to`'s hand-rolled arc with `Feel.move(node, start, dest, "arc")`, keep the ±22° spin (either inside the arc kind or as a parallel tween), chain `Feel.land(self, node, center, 0.8)` on finish.
- [ ] **Step 4: Run** `make test-grove` + `make test-fast` — green. **Perf check:** instrument or eyeball a full Rush settle (many tiles) to confirm shadow/trail node churn is acceptable; if heavy, lower `MOVE_TRAIL_N` or skip trail on `fall`.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(move): unify board slide + rush arc/fall through feel.move, chain feel.land"`

---

## Phase 6 — Bundle A: haptics + telegraph + drag lean

### Task 6.1: Implement `feel.haptic` with setting + throttle

**Files:**
- Modify: `engine/scripts/ui/feel.gd`
- Test: `engine/tests/feel_tests.gd`
- Modify: settings store (find where user settings like `calm` live — likely `features.gd` or a settings singleton; read first)

- [ ] **Step 1: Find** the settings layer that holds `calm`/accessibility toggles; add a `haptics` bool (default true). Read how `calm()` is exposed in `fx.gd` and mirror it.
- [ ] **Step 2: Write failing tests** — `haptic` maps weights to `HAPTIC_MS`; returns early when the `haptics` setting is off; a second call within `HAPTIC_THROTTLE_MS` is suppressed. Make the throttle testable by injecting a clock or exposing `_last_haptic_ms` (headless has no real vibrator; assert the *decision*, e.g. a pure `_haptic_allowed(now_ms)` helper).
- [ ] **Step 3: Implement:**

```gdscript
static var _last_haptic := -1000
static func haptic(weight := "soft") -> void:
	if not _haptics_enabled() or DisplayServer.get_name() == "headless":
		return
	var now := Time.get_ticks_msec()
	if now - _last_haptic < Tune.HAPTIC_THROTTLE_MS:
		return
	_last_haptic = now
	Input.vibrate_handheld(int(Tune.HAPTIC_MS.get(weight, 14)))
```

- [ ] **Step 4: Run** tests + `make test-fast` — green (the verb haptic calls from earlier phases now resolve to real behaviour on device, no-op headless).
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(juice): haptics across the feel verbs with setting + throttle"`

### Task 6.2: Merge-target telegraph (board drag)

**Files:**
- Modify: `engine/scripts/scenes/board.gd` (drag-follow + hover logic around :2245–2363, `can_merge` at :2303)
- Test: a board UI test (`grove_ui_tests` or the suite that drives board input)

- [ ] **Step 1: Read** the drag-follow/hover code and `can_merge`. Find where the hovered target cell is computed each drag frame.
- [ ] **Step 2: Write a failing UI test** — while dragging over a cell where `can_merge` is true, the target node shows the telegraph (a breathe + `TELEGRAPH_GLOW` modulate); moving to a non-mergeable cell clears it.
- [ ] **Step 3: Implement** — on hover-enter of a valid target: `FX.breathe_once(target)` (or `FX.breathe`) + `target.modulate = Tune.TELEGRAPH_GLOW`, and lean the held tile + target toward each other by `TELEGRAPH_MAGNET * _cell`. On hover-exit/invalid: restore modulate + positions. Reuse the Bag-highlight pattern at `board.gd:1022`.
- [ ] **Step 4: Run** the UI suite + `make test-fast` — green.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(juice): merge-target telegraph (glow + breathe + magnetism) on board drag"`

### Task 6.3: Drag lean/lag

**Files:**
- Modify: `engine/scripts/scenes/board.gd` (drag-follow update)
- Test: board UI test

- [ ] **Step 1: Write a failing test** — during drag, the held node's `rotation` tilts toward pointer velocity, clamped to `DRAG_LEAN_DEG`, and returns toward 0 when the pointer is still.
- [ ] **Step 2: Implement** — track pointer delta per frame; set `rotation = clampf(deg_to_rad(DRAG_LEAN_DEG) * sign_of_velocity * speed_factor, ...)` lerped by `DRAG_LEAN_LAG`; ease to 0 when delta ~0. Skip under `calm()`.
- [ ] **Step 3: Run** + `make test-fast` — green.
- [ ] **Step 4: Commit** — `git add -A && git commit -m "feat(juice): drag lean/lag on held board tile"`

---

## Phase 7 — Bundle B: neighbor ripple + board punch

### Task 7.1: Implement `feel.ripple` + `feel.board_punch`

**Files:**
- Modify: `engine/scripts/ui/feel.gd`
- Test: `engine/tests/feel_tests.gd`

- [ ] **Step 1: Write failing tests** — `ripple` tweens each neighbor's scale by ~`RIPPLE_SQUASH` away from `impact_center`, staggered; no-op under calm. `board_punch` returns a scale tween `1 → 1+PUNCH*intensity → 1`; no-op under calm.
- [ ] **Step 2: Implement:**

```gdscript
static func ripple(neighbors: Array, impact_center: Vector2, intensity := 1.0) -> void:
	if FX.calm(): return
	var i := 0
	for nb in neighbors:
		if nb == null or not is_instance_valid(nb): continue
		var dir := (nb.global_position + nb.size / 2.0 - impact_center).normalized()
		var pose := Vector2.ONE + dir.abs() * (Tune.RIPPLE_SQUASH * intensity)  # nudge wider along the push axis
		var t := nb.create_tween()
		t.tween_interval(i * Tune.RIPPLE_STAGGER_MS / 1000.0)
		t.tween_property(nb, "scale", pose, 0.05).set_trans(Tween.TRANS_SINE)
		t.tween_property(nb, "scale", Vector2.ONE, 0.08).set_trans(Tween.TRANS_SINE)
		i += 1

static func board_punch(board: Control, intensity := 1.0) -> void:
	if FX.calm() or board == null or not is_instance_valid(board): return
	board.pivot_offset = board.size / 2.0
	var t := board.create_tween()
	t.tween_property(board, "scale", Vector2.ONE * (1.0 + Tune.PUNCH * intensity), Tune.PUNCH_T * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(board, "scale", Vector2.ONE, Tune.PUNCH_T * 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
```

- [ ] **Step 3: Run** tests + `make test-fast` — green.
- [ ] **Step 4: Commit** — `git add -A && git commit -m "feat(juice): feel.ripple + feel.board_punch"`

### Task 7.2: Wire ripple into merge/land; board-punch into big merges

**Files:**
- Modify: `engine/scripts/scenes/board.gd`, `engine/scripts/scenes/explore_rush.gd`

- [ ] **Step 1:** At each merge and land site, gather the up-to-4 orthogonal neighbor nodes from the grid and call `Feel.ripple(neighbors, center, intensity)`. Add an optional `neighbors` param to `feel.merge`/`feel.land`, OR call `Feel.ripple` from the scene right after the verb (simpler; the scene owns the grid). Prefer the scene-side call.
- [ ] **Step 2:** For merges with `tier >= ESCALATE_TIER`, call `Feel.board_punch(board_area, 1.0)` (board) / `Feel.board_punch(_board, 1.0)` (rush). This complements the reserved `FX.shake` already inside `feel.merge`; if double-feel is too much, drop the in-verb shake for mid-tier and let punch carry it (decide at review).
- [ ] **Step 3:** Run `make test-grove` + `make test-fast` — green.
- [ ] **Step 4: Commit** — `git add -A && git commit -m "feat(juice): neighbor ripple on merge/land + board punch on big merges"`

---

## Phase 8 — Bundle D: musical ladder + combo bloom + ambient motes

### Task 8.1: Musical merge ladder

**Files:**
- Modify: `engine/scripts/ui/feel.gd` (merge sound step)
- Test: `engine/tests/feel_tests.gd`

- [ ] **Step 1: Write failing tests** — consecutive merges step the pitch through `PENTA` degrees: `_ladder_pitch(base, degree)` == `base * pow(2, PENTA[degree]/12.0)`; `degree` clamps at the top of `PENTA`; a reset returns to degree 0.
- [ ] **Step 2: Implement** a small ladder state on `feel`: a `static var _ladder_degree` and `_ladder_last_ms`, advanced per merge and reset when `now - _ladder_last_ms > COMBO_WINDOW*1000`. Replace the linear pitch in `feel.merge` with `_ladder_pitch(base, _ladder_degree)`, still passed through `Audio.jitter_pitch` if the board did. Keep the tier offset as the `base`.

```gdscript
static func _ladder_pitch(base: float, degree: int) -> float:
	var p: Array = Tune.PENTA
	return base * pow(2.0, float(p[clampi(degree, 0, p.size() - 1)]) / 12.0)
```

- [ ] **Step 3: Run** tests + `make test-fast` — green. Verify the board/rush merge still sounds (manual at review).
- [ ] **Step 4: Commit** — `git add -A && git commit -m "feat(juice): musical pentatonic merge ladder with combo-window reset"`

### Task 8.2: Combo screen bloom overlay

**Files:**
- Create: `engine/scripts/ui/combo_bloom.gd` (a small scene-owned overlay) OR a helper in `feel.gd`
- Modify: `engine/scripts/scenes/board.gd`, `engine/scripts/scenes/explore_rush.gd` (own the overlay + drive decay)
- Test: `engine/tests/feel_tests.gd`

- [ ] **Step 1: Write failing test** — feeding a rising combo raises bloom strength toward `COMBO_BLOOM_MAX`; with no merges its strength decays by `COMBO_BLOOM_DECAY`/sec; strength never exceeds `COMBO_BLOOM_MAX`.
- [ ] **Step 2: Implement** a `ComboBloom` node: a `CanvasLayer` + a full-rect vignette `ColorRect` (warm, additive) whose alpha = `strength`. API: `bump(combo)` raises target by `COMBO_BLOOM_RISE` (scaled by combo), `_process(delta)` eases strength toward target and decays target. Allowed under calm at reduced strength (multiply by e.g. 0.5 when `FX.calm()`).
- [ ] **Step 3: Wire** — board/rush create one `ComboBloom` child at startup, free it with the scene; `feel.merge` pokes it via a passed reference or the scene calls `bloom.bump(combo)` right after `Feel.merge`. Prefer the scene calling `bloom.bump` (keeps `feel.merge` parameter-light).
- [ ] **Step 4: Run** `make test-grove` + `make test-fast` — green.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(juice): combo screen bloom overlay (swell on streak, decay on lapse)"`

### Task 8.3: Reactive ambient motes

**Files:**
- Modify: `engine/scripts/ui/ambient.gd`
- Modify: `engine/scripts/scenes/board.gd` (merge hook)
- Test: existing ambient/grove suite

- [ ] **Step 1: Read** `ambient.gd` mote/weather emission (~129, ~194). Add a public `puff(center: Vector2, impulse := Tune.MOTE_PUFF_IMPULSE)` that pushes nearby motes outward from `center` for a moment.
- [ ] **Step 2: Wire** — after a board merge, if an ambient layer is present, call `ambient.puff(center)`. Graceful no-op when absent (Rush / weather off).
- [ ] **Step 3: Run** `make test-grove` + `make test-fast` — green.
- [ ] **Step 4: Commit** — `git add -A && git commit -m "feat(juice): ambient motes puff outward from a merge"`

---

## Phase 9 — Full sweep + handoff

- [ ] **Step 1:** Run the full suite — `make test` — read the per-suite table, confirm all green.
- [ ] **Step 2:** Re-read the spec; confirm every section maps to a shipped task (verbs, intensity table, generator grow-in kept separate, Rush thunk combo-gated, spirit freeze-free, land flash, move shadow/trail/accel, bundles A/B/D, accessibility, tests). Note any gap.
- [ ] **Step 3:** Confirm no behavior regressions on the board merge by side-by-side feel (manual).
- [ ] **Step 4: Commit** any cleanup — `git commit -m "chore(feel): full-suite green + spec coverage sweep"`.

---

## Self-Review notes (author)

- **Spec coverage:** verbs (P1–P5), intensity scaling (per-call args throughout), generator grow-in kept (P3.2/P4 explicit "do not touch"), Rush combo-gated thunk (P2.1 gate=2), spirit freeze-free (P2.2 gate=9999), land flash (P3.1), move shadow/trail/accel (P5.1), bundle A (P6), B (P7), D (P8), accessibility/headless (gated in each verb + haptic/bloom rules), tests (each task). Bundle C correctly absent (parked).
- **Type consistency:** `feel.merge(host, node, center, tier, combo, intensity, hitstop_gate)`, `feel.land(host, node, center, intensity, do_haptic)`, `feel.move(...)->Tween`, `haptic(weight)`, `ripple(neighbors, center, intensity)`, `board_punch(board, intensity)` — used consistently across phases.
- **Open verifications for the executor (not placeholders — real-code checks):** exact `FX.amount_for`/`calm`/`gen_charge` signatures; the settings layer that holds `calm` (for the `haptics` toggle); the board UI test harness used for telegraph/drag-lean; whether `Audio.jitter_pitch` is applied at the board merge call site (preserve it).
