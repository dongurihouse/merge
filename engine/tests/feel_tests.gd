extends SceneTree
## Headless smoke + unit tests for engine/scripts/ui/feel.gd — the shared FEEL VERBS module.
## Phase 1 covers feel.merge: the pure helpers (colour / flash-peak / hitstop / burst-count /
## pitch / weight) are unit-tested here without a scene tree.
##   godot --headless --path . -s res://engine/tests/feel_tests.gd

const Feel = preload("res://engine/scripts/ui/feel.gd")
const Tune = preload("res://engine/scripts/core/tuning.gd").FX

var _pass := 0
var _fail := 0
func ok(cond: bool, label: String) -> void:
	if cond: _pass += 1; print("  PASS  ", label)
	else: _fail += 1; print("  FAIL  ", label)

func approx(a: float, b: float, eps := 0.0001) -> bool:
	return absf(a - b) <= eps

func _initialize() -> void:
	# the module loads + exposes its shared palette
	ok(Feel != null, "feel module loads")
	ok(Feel.LEAF is Color, "feel exposes the LEAF palette colour")
	# the haptic stub is a no-op — calling it must not error
	Feel.haptic("tick")
	ok(true, "haptic('tick') is a no-op stub that runs without error")

	# --- _merge_color: tier<4 green, 4..7 gold, >=8 hot ---
	ok(Feel._merge_color(1) == Feel.LEAF, "tier 1 burst is LEAF green")
	ok(Feel._merge_color(3) == Feel.LEAF, "tier 3 burst is LEAF green")
	ok(Feel._merge_color(4) == Feel.STRAW, "tier 4 burst is STRAW gold")
	ok(Feel._merge_color(7) == Feel.STRAW, "tier 7 burst is STRAW gold")
	ok(Feel._merge_color(Tune.MERGE_BURST_HOT_TIER) == Feel.HOT, "tier >= HOT_TIER (8) burst is HOT")
	ok(Feel._merge_color(12) == Feel.HOT, "tier 12 burst is HOT")

	# --- _merge_flash_peak: 0 at intensity 0; ramps soft->full by tier ---
	ok(approx(Feel._merge_flash_peak(4, 0.0), 0.0), "flash peak is 0 at intensity 0")
	ok(Feel._merge_flash_peak(1, 1.0) < Feel._merge_flash_peak(4, 1.0), "flash peak ramps up tier 1 -> 4")
	ok(approx(Feel._merge_flash_peak(4, 1.0), Tune.FLASH_PEAK * float(Tune.MERGE_FLASH_TIER_RAMP[3])), "tier 4 flash peak = FLASH_PEAK * ramp[3]")
	ok(approx(Feel._merge_flash_peak(9, 1.0), Tune.FLASH_PEAK * float(Tune.MERGE_FLASH_TIER_RAMP[3])), "tier beyond ramp clamps to last ramp entry")

	# --- _merge_hitstop: 0 at intensity 0; gate>combo -> 0; grows with combo; big-moment override ---
	ok(approx(Feel._merge_hitstop(4, 5, 0.0, 0), 0.0), "hitstop is 0 at intensity 0")
	ok(approx(Feel._merge_hitstop(4, 1, 1.0, 2), 0.0), "hitstop is 0 when gate > combo")
	ok(Feel._merge_hitstop(4, 5, 1.0, 2) > Feel._merge_hitstop(4, 2, 1.0, 2), "hitstop grows with combo above the gate")
	# board path: gate 0, no combo bonus contribution (combo - gate may be large, but combo bonus is feature-gated off here for the pure curve? — board adds it unconditionally to hit only via combo? no: board hit ignores combo). See note below.
	ok(approx(Feel._merge_hitstop(1, 0, 1.0, 0), Tune.HITSTOP_MERGE), "tier 1 board hitstop = HITSTOP_MERGE")
	ok(approx(Feel._merge_hitstop(4, 0, 1.0, 0), Tune.HITSTOP_MERGE + Tune.HITSTOP_TIER_BONUS * 3.0), "tier 4 board hitstop = base + tier bonus*3")
	ok(approx(Feel._merge_hitstop(Tune.ESCALATE_TIER, 0, 1.0, 0), Tune.HITSTOP_BIG), "big-moment tier hitstop = HITSTOP_BIG (override, not formula)")
	ok(Feel._merge_hitstop(4, 0, 0.5, 0) < Feel._merge_hitstop(4, 0, 1.0, 0), "hitstop scales down with intensity")
	ok(Feel._merge_hitstop(20, 0, 1.0, 0) <= Tune.HITSTOP_MAX, "hitstop never exceeds HITSTOP_MAX")

	# --- _merge_sound: tier<4 soft, tier>=4 success ---
	ok(Feel._merge_sound(3) == "merge_soft", "tier 3 picks merge_soft")
	ok(Feel._merge_sound(4) == "merge_success", "tier 4 picks merge_success")
	ok(Feel._merge_sound(9) == "merge_success", "tier 9 picks merge_success")

	# --- _merge_weight: soft/firm/heavy ladder ---
	ok(Feel._merge_weight(1) == "soft", "tier 1 haptic weight is soft")
	ok(Feel._merge_weight(4) == "firm", "tier 4 haptic weight is firm")
	ok(Feel._merge_weight(Tune.ESCALATE_TIER) == "heavy", "big-moment tier haptic weight is heavy")

	# --- _merge_pitch: base climbs with tier, combo nudges up ---
	ok(approx(Feel._merge_pitch(4, 0), clampf(0.95 + 0.03 * 4, 0.9, 1.3)), "base pitch matches board curve at combo 0")
	ok(Feel._merge_pitch(4, 8) > Feel._merge_pitch(4, 0), "combo climb raises pitch")
	ok(Feel._merge_pitch(4, 100) <= Tune.COMBO_PITCH_MAX, "combo pitch clamps to COMBO_PITCH_MAX")

	# --- _combo_milestones_passed: counts COMBO_MILESTONES reached ---
	ok(Feel._combo_milestones_passed(0) == 0, "combo 0 passes 0 milestones")
	ok(Feel._combo_milestones_passed(int(Tune.COMBO_MILESTONES[0])) == 1, "combo at first milestone passes 1")
	ok(Feel._combo_milestones_passed(100) == Tune.COMBO_MILESTONES.size(), "huge combo passes all milestones")

	# --- _merge_burst_count: base curve + bonuses, intensity-scaled ---
	# (combo + big-moment bonuses are feature-gated; with the default flags on they apply)
	ok(Feel._merge_burst_count(3, 0, 1.0) >= 10 + 3 * 3, "tier 3 burst count includes base curve")
	ok(Feel._merge_burst_count(Tune.ESCALATE_TIER, 0, 1.0) > Feel._merge_burst_count(Tune.ESCALATE_TIER - 1, 0, 1.0), "big-moment tier adds burst particles")
	ok(Feel._merge_burst_count(4, 0, 0.5) < Feel._merge_burst_count(4, 0, 1.0), "burst count scales with intensity")

	# --- feel.land ---------------------------------------------------------------
	# _land_flash_peak: FLASH_PEAK * LAND_FLASH_FACTOR * intensity; 0 at intensity 0.
	ok(approx(Feel._land_flash_peak(0.0), 0.0), "land flash peak is 0 at intensity 0")
	ok(approx(Feel._land_flash_peak(1.0), Tune.FLASH_PEAK * Tune.LAND_FLASH_FACTOR), "land flash peak at intensity 1 = FLASH_PEAK * LAND_FLASH_FACTOR")
	ok(approx(Feel._land_flash_peak(0.5), Tune.FLASH_PEAK * Tune.LAND_FLASH_FACTOR * 0.5), "land flash peak scales with intensity")
	ok(Feel._land_flash_peak(1.0) < Feel._merge_flash_peak(4, 1.0), "land flash is softer than a tier-4 merge flash")
	# _land_should_emit: the gate for sound/flash/puff/haptic. Quiet OR intensity<=0 -> no extras.
	ok(Feel._land_should_emit(1.0, false), "discrete (loud) land at intensity 1 emits flash/puff/sound/haptic")
	ok(not Feel._land_should_emit(1.0, true), "quiet land emits NO flash/puff/sound/haptic (bulk settle guard)")
	ok(not Feel._land_should_emit(0.0, false), "land at intensity 0 emits no flash/puff/sound/haptic")
	ok(not Feel._land_should_emit(0.0, true), "quiet land at intensity 0 emits nothing")
	# _land_puff_count: LAND_PUFF_N * intensity (floored to int); 0 at intensity 0.
	ok(Feel._land_puff_count(0.0) == 0, "land puff count is 0 at intensity 0")
	ok(Feel._land_puff_count(1.0) == int(Tune.LAND_PUFF_N), "land puff count at intensity 1 = LAND_PUFF_N")
	# land() must be a safe no-op on an invalid/null node. A QUIET land is squash-only, so it never
	# reaches the flash/puff/sound path — fully headless-safe even with a null host + node.
	Feel.land(null, null, Vector2.ZERO, 0.8, true)
	ok(true, "quiet land(null, null, ...) is a safe no-op (squash-only, no sound/flash/puff)")

	# --- feel.launch -------------------------------------------------------------
	# _launch_puff_count: LAUNCH_PUFF_N * intensity (floored to int); 0 at intensity 0 (no puff).
	ok(Feel._launch_puff_count(0.0) == 0, "launch puff count is 0 at intensity 0 (no muzzle puff)")
	ok(Feel._launch_puff_count(1.0) == int(Tune.LAUNCH_PUFF_N), "launch puff count at intensity 1 = LAUNCH_PUFF_N")
	ok(Feel._launch_puff_count(0.5) == int(Tune.LAUNCH_PUFF_N * 0.5), "launch puff count scales with intensity")
	# launch() must be a safe no-op on null emitter + null projectile (no parent, no recoil).
	Feel.launch(null, null, 1.0)
	ok(true, "launch(null, null, ...) is a safe no-op (no recoil, no puff parent)")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
