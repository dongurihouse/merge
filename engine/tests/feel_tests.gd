extends SceneTree
## Headless smoke + unit tests for engine/scripts/ui/feel.gd — the shared FEEL VERBS module.
## Phase 1 covers feel.merge: the pure helpers (colour / flash-peak / hitstop / burst-count /
## pitch / weight) are unit-tested here without a scene tree.
##   godot --headless --path . -s res://engine/tests/feel_tests.gd

const Feel = preload("res://engine/scripts/ui/feel.gd")
const Tune = preload("res://engine/scripts/core/tuning.gd").FX
const Save = preload("res://engine/scripts/core/save.gd")
const MergeFx = preload("res://engine/scripts/ui/merge_fx.gd")
const LandFx = preload("res://engine/scripts/ui/land_fx.gd")
const LaunchFx = preload("res://engine/scripts/ui/launch_fx.gd")
const MoveFx = preload("res://engine/scripts/ui/move_fx.gd")

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

	# --- _ladder_pitch: pure pentatonic ladder indexed by the combo degree ---
	ok(approx(Feel._ladder_pitch(1.0, 0), 1.0), "ladder degree 0 (combo 0) returns base unchanged (factor 1.0)")
	ok(approx(Feel._ladder_pitch(1.2, 0), 1.2), "ladder at combo 0 returns the base for any base")
	ok(approx(Feel._ladder_pitch(1.0, 1), pow(2.0, Tune.PENTA[1] / 12.0)), "ladder degree 1 = base * 2^(PENTA[1]/12)")
	ok(approx(Feel._ladder_pitch(1.0, 3), pow(2.0, Tune.PENTA[3] / 12.0)), "ladder degree 3 = base * 2^(PENTA[3]/12)")
	ok(Feel._ladder_pitch(1.0, 2) > Feel._ladder_pitch(1.0, 1), "ladder rises with the combo degree")
	# degree clamps at the top of PENTA — combo past the array tops out, never indexes out of bounds.
	ok(approx(Feel._ladder_pitch(1.0, Tune.PENTA.size() - 1), Feel._ladder_pitch(1.0, 999)), "ladder degree clamps at the top of PENTA")

	# --- _merge_pitch: tier base, then the pentatonic ladder when merge_combo is on ---
	ok(approx(Feel._merge_pitch(4, 0), clampf(0.95 + 0.03 * 4, 0.9, 1.3)), "base pitch matches board curve at combo 0")
	var _base4 := clampf(0.95 + 0.03 * 4, 0.9, 1.3)
	ok(approx(Feel._merge_pitch(4, 8), Feel._ladder_pitch(_base4, 8)), "merge pitch applies the ladder over the tier base")
	ok(Feel._merge_pitch(4, 8) > Feel._merge_pitch(4, 0), "a live streak climbs the ladder above the base")
	ok(approx(Feel._merge_pitch(4, 999), Feel._ladder_pitch(_base4, Tune.PENTA.size() - 1)), "a huge streak tops out at the ladder ceiling")

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
	# launch() must be a safe no-op on null emitter + null projectile (no parent, no recoil). With the
	# default OFF toss sound, this stays fully headless-safe (no Audio.play either).
	Feel.launch(null, null, 1.0)
	ok(true, "launch(null, null, ...) is a safe no-op (no recoil, no puff parent, sound off by default)")

	# --- feel.move ---------------------------------------------------------------
	# move() returns a non-null Tween that animates `position` from->to. (Headless: the
	# enhancements are hard-off, so this is the bare position tween — exactly what we want
	# the deterministic test clock to drive.)
	var holder := Control.new()
	holder.size = Vector2(96, 96)
	get_root().add_child(holder)
	var mover := Control.new()
	mover.size = Vector2(96, 96)
	holder.add_child(mover)
	var from := Vector2(0, 0)
	var to := Vector2(200, 0)
	mover.position = from
	var mtw := Feel.move(mover, from, to, "slide")
	ok(mtw is Tween, "move() returns a Tween (so callers can chain feel.land on completion)")
	ok(mtw != null and mtw.is_valid(), "move() tween is valid")
	ok(mtw != null and mtw.is_running(), "move() tween is running (animating position toward `to`)")
	# move() sets the node to `from` synchronously, then the returned tween drives it to `to`.
	# (In headless _initialize there is no idle frame loop to actually advance the tween, so we
	# assert the synchronous starting pose + a live tween; the pure timing/ease helpers below
	# cover the motion shape.)
	ok(mover.position.is_equal_approx(from), "move() seats the node at `from` before animating")
	mover.queue_free()
	holder.queue_free()

	# _move_enhance_enabled(): the shared gate for shadow/trail/lean. Headless ALWAYS disables
	# them (no felt effect off-device), so under the test runner this is false.
	ok(not Feel._move_enhance_enabled(), "move enhancements are OFF under headless (no shadow/trail/lean)")

	# _move_ease(): accelerate-INTO-impact for slide/fall (EASE_IN); arc's down-leg owns its own.
	ok(Feel._move_ease("slide") == Tween.EASE_IN, "slide eases IN (accelerate into the target)")
	ok(Feel._move_ease("fall") == Tween.EASE_IN, "fall eases IN (accelerate into the target)")

	# _move_dur(): slide is flat MOVE_SLIDE_T; fall is distance-scaled between MIN..MAX.
	ok(approx(Feel._move_dur("slide", Vector2.ZERO, Vector2(300, 0)), Tune.MOVE_SLIDE_T), "slide duration = MOVE_SLIDE_T")
	ok(Feel._move_dur("fall", Vector2.ZERO, Vector2.ZERO) >= Tune.MOVE_FALL_T_MIN - 0.0001, "a zero-distance fall is at least MOVE_FALL_T_MIN")
	ok(Feel._move_dur("fall", Vector2.ZERO, Vector2(0, 100000)) <= Tune.MOVE_FALL_T_MAX + 0.0001, "a huge fall clamps to MOVE_FALL_T_MAX")
	ok(Feel._move_dur("fall", Vector2.ZERO, Vector2(0, 50)) < Feel._move_dur("fall", Vector2.ZERO, Vector2(0, 5000)), "fall duration grows with distance")
	# an explicit dur override wins.
	ok(approx(Feel._move_dur("slide", Vector2.ZERO, Vector2.ZERO, 0.5), 0.5), "explicit dur override is honoured")

	# _move_trail_count(speed): ~0 ghosts near zero speed, up to MOVE_TRAIL_N at/above the ref speed.
	ok(Feel._move_trail_count(0.0) == 0, "trail count is 0 at zero speed")
	ok(Feel._move_trail_count(1.0) == 0, "trail count is ~0 at a crawl (a slow settle barely trails)")
	ok(Feel._move_trail_count(Tune.MOVE_TRAIL_SPEED_REF) == Tune.MOVE_TRAIL_N, "trail count reaches MOVE_TRAIL_N at the reference speed")
	ok(Feel._move_trail_count(Tune.MOVE_TRAIL_SPEED_REF * 4.0) == Tune.MOVE_TRAIL_N, "trail count clamps to MOVE_TRAIL_N above the reference speed")
	ok(Feel._move_trail_count(Tune.MOVE_TRAIL_SPEED_REF * 0.5) <= Tune.MOVE_TRAIL_N, "trail count never exceeds MOVE_TRAIL_N")
	ok(Feel._move_trail_count(Tune.MOVE_TRAIL_SPEED_REF * 0.5) < Feel._move_trail_count(Tune.MOVE_TRAIL_SPEED_REF), "trail count scales up with speed")
	# fall is the perf-critical path (a full column settles at once): it makes NO trail ghosts.
	ok(Feel._move_trail_count_for("fall", Tune.MOVE_TRAIL_SPEED_REF * 4.0) == 0, "fall makes NO trail ghosts (full-column settle perf guard)")
	ok(Feel._move_trail_count_for("arc", Tune.MOVE_TRAIL_SPEED_REF) == Tune.MOVE_TRAIL_N, "arc trails normally at the reference speed")

	# move() must be a safe no-op on a null/invalid node — returns null, never errors.
	ok(Feel.move(null, Vector2.ZERO, Vector2(10, 0), "slide") == null, "move(null, ...) is a safe no-op returning null")

	# --- feel.haptic (bundle A: tactile) -----------------------------------------
	# The haptics setting reads pull-based via Save.get_setting. Default is ON (true).
	ok(Feel._haptics_enabled() == true, "haptics setting defaults ON")
	Save.set_setting("haptics", false)
	ok(Feel._haptics_enabled() == false, "haptics setting reads OFF when the flag is cleared")
	Save.set_setting("haptics", true)
	ok(Feel._haptics_enabled() == true, "haptics setting reads ON again when re-enabled")

	# _haptic_weight_ms: weight -> ms via HAPTIC_MS, with a 14ms fallback for an unknown weight.
	ok(Feel._haptic_weight_ms("tick") == int(Tune.HAPTIC_MS["tick"]), "tick weight maps to HAPTIC_MS['tick']")
	ok(Feel._haptic_weight_ms("soft") == int(Tune.HAPTIC_MS["soft"]), "soft weight maps to HAPTIC_MS['soft']")
	ok(Feel._haptic_weight_ms("firm") == int(Tune.HAPTIC_MS["firm"]), "firm weight maps to HAPTIC_MS['firm']")
	ok(Feel._haptic_weight_ms("heavy") == int(Tune.HAPTIC_MS["heavy"]), "heavy weight maps to HAPTIC_MS['heavy']")
	ok(Feel._haptic_weight_ms("nonsense") == 14, "an unknown weight falls back to 14ms")

	# _haptic_allowed(now_ms, last_ms): the PURE throttle decision (testable without a vibrator).
	# Allowed when never fired before, or when >= HAPTIC_THROTTLE_MS since the last allowed pulse.
	ok(Feel._haptic_allowed(0, -100000), "a haptic is allowed when none has fired yet")
	ok(not Feel._haptic_allowed(1000, 1000), "a repeat at the same instant is throttled")
	ok(not Feel._haptic_allowed(1000 + Tune.HAPTIC_THROTTLE_MS - 1, 1000), "a repeat just under the throttle window is suppressed")
	ok(Feel._haptic_allowed(1000 + Tune.HAPTIC_THROTTLE_MS, 1000), "a repeat at exactly the throttle window is allowed")
	ok(Feel._haptic_allowed(1000 + Tune.HAPTIC_THROTTLE_MS + 50, 1000), "a repeat past the throttle window is allowed")

	# haptic() stays a safe no-op under headless (no real vibrator) — calling it never errors and,
	# because of the headless guard, never advances the throttle clock.
	Feel.haptic("heavy")
	ok(true, "haptic('heavy') is a safe no-op under headless")

	# --- feel.ripple (bundle B: impact propagation) -------------------------------
	# ripple tweens each given neighbour's scale away from impact_center, staggered. We assert the
	# SETUP (a live tween per valid neighbour, pivot centred, scale pushed off 1.0 in the right axis)
	# — headless has no idle loop to advance the tween to completion, so we check the decision, not the rest pose.
	var rip_parent := Control.new()
	rip_parent.size = Vector2(400, 400)
	get_root().add_child(rip_parent)
	var nb_right := Control.new()
	nb_right.size = Vector2(96, 96)
	nb_right.position = Vector2(200, 0)   # to the RIGHT of an impact at the origin
	rip_parent.add_child(nb_right)
	var nb_below := Control.new()
	nb_below.size = Vector2(96, 96)
	nb_below.position = Vector2(0, 200)   # BELOW the impact
	rip_parent.add_child(nb_below)
	Feel.ripple([nb_right, nb_below, null], Vector2.ZERO, 1.0)
	ok(nb_right.pivot_offset.is_equal_approx(nb_right.size / 2.0), "ripple centres each neighbour's pivot")
	ok(true, "ripple ran on a list of valid neighbours without error")
	# _ripple_pose: the pure direction math (headless has no idle loop to advance the scale tween,
	# so we assert the DECISION — the pose pushes off 1.0 along the axis away from the impact).
	ok(Feel._ripple_pose(Vector2(248, 0), Vector2.ZERO, 1.0).x > 1.0, "a neighbour to the RIGHT squashes along X (away from the impact)")
	ok(Feel._ripple_pose(Vector2(0, 248), Vector2.ZERO, 1.0).y > 1.0, "a neighbour BELOW squashes along Y (away from the impact)")
	ok(approx(Feel._ripple_pose(Vector2.ZERO, Vector2.ZERO, 1.0).x, 1.0), "a neighbour ON the impact gets no push (rests at 1.0)")
	ok(approx(Feel._ripple_pose(Vector2(248, 0), Vector2.ZERO, 0.5).x, 1.0 + Tune.RIPPLE_SQUASH * 0.5), "ripple pose scales with intensity")
	# ripple is null/invalid-safe: a list of null + a freed node never errors.
	var nb_freed := Control.new()
	nb_freed.size = Vector2(96, 96)
	rip_parent.add_child(nb_freed)
	nb_freed.free()
	Feel.ripple([null, nb_freed], Vector2.ZERO, 1.0)
	ok(true, "ripple([null, freed]) is a safe no-op (skips invalid neighbours)")
	Feel.ripple([], Vector2.ZERO, 1.0)
	ok(true, "ripple([]) on an empty neighbour list is a safe no-op")
	nb_right.queue_free()
	nb_below.queue_free()
	rip_parent.queue_free()

	# --- feel.board_punch (bundle B: impact propagation) --------------------------
	var board := Control.new()
	board.size = Vector2(600, 600)
	get_root().add_child(board)
	var ptw := Feel.board_punch(board, 1.0)
	ok(ptw is Tween, "board_punch returns a Tween (the scale punch)")
	ok(ptw != null and ptw.is_valid(), "board_punch tween is valid")
	ok(board.pivot_offset.is_equal_approx(board.size / 2.0), "board_punch centres the board pivot")
	# board_punch is null-safe.
	ok(Feel.board_punch(null, 1.0) == null, "board_punch(null) is a safe no-op returning null")
	board.queue_free()

	_test_fx_config()

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)

# --- the four tunable feel appliers read their config (the workbench-saved toggles + knobs) -------
# Proves a saved config TAKES EFFECT: from_config resolves the toggles/knobs the appliers read, and a
# cue toggled OFF in the config does not fire (probed via the scene-tree side effect — FX.burst /
# FX.flash add a child to the host only when their toggle is on).
func _test_fx_config() -> void:
	# --- from_config: a saved toggle + knob override resolves over the defaults ---
	var m := MergeFx.from_config({"merge_fx": {"flash": false, "hitstop_ms": 0}})
	ok(MergeFx.on(m, "flash") == false, "MergeFx.from_config honours a saved 'flash:false' toggle")
	ok(MergeFx.knob(m, "hitstop_ms") == 0, "MergeFx.from_config honours a saved 'hitstop_ms:0' knob")
	ok(MergeFx.on(m, "burst") == true, "MergeFx.from_config leaves un-overridden toggles at their default (on)")
	var m_default := MergeFx.from_config({})
	ok(MergeFx.knob(m_default, "burst_count") == MergeFx.KNOBS["burst_count"], "MergeFx.from_config falls back to the default knob when unset")
	var l := LandFx.from_config({"land_fx": {"sound": false, "puff_count": 3}})
	ok(LandFx.on(l, "sound") == false and LandFx.knob(l, "puff_count") == 3, "LandFx.from_config honours saved toggle + knob")
	var la := LaunchFx.from_config({"launch_fx": {"recoil": false}})
	ok(LaunchFx.on(la, "recoil") == false, "LaunchFx.from_config honours a saved toggle")
	var mv := MoveFx.from_config({"move_fx": {"duration_ms": 99}})
	ok(MoveFx.knob(mv, "duration_ms") == 99, "MoveFx.from_config honours a saved knob")

	# --- the master switch gates every cue ---
	var off := MergeFx.from_config({"merge_fx": {"enabled": false}})
	ok(MergeFx.on(off, "burst") == false, "the merge master switch (enabled:false) turns every cue off")

	# --- T63: an INTENSIFIED (§6.G recipe-line) merge feels like a pinnacle merge at any tier ---
	# escalation_tier lifts the tier the colour/sound/weight read off to the big-moment band when intensified,
	# but never drops a real high-tier merge.
	ok(MergeFx.escalation_tier(1, false) == 1, "escalation_tier leaves an ordinary merge's tier untouched")
	ok(MergeFx.escalation_tier(1, true) >= Tune.ESCALATE_TIER, "escalation_tier lifts a low-tier intensified merge to the big-moment band")
	ok(MergeFx.escalation_tier(12, true) == 12, "escalation_tier never lowers a real high-tier merge")
	# the lift composes to the TOP band (hot burst colour, success chime tier, heavy haptic) at tier 1...
	ok(MergeFx._color(MergeFx.escalation_tier(1, true)) == MergeFx.HOT, "a t1 recipe merge bursts HOT (not LEAF)")
	ok(MergeFx._weight(MergeFx.escalation_tier(1, true)) == "heavy", "a t1 recipe merge thumps heavy")
	ok(MergeFx.escalation_tier(1, true) >= 4, "a t1 recipe merge crosses the success-chime threshold (>=4)")
	# ...while an ordinary t1 merge stays cozy (green burst, soft thump, soft chime)
	ok(MergeFx._color(MergeFx.escalation_tier(1, false)) == MergeFx.LEAF, "an ordinary t1 merge stays LEAF green")
	ok(MergeFx._weight(MergeFx.escalation_tier(1, false)) == "soft", "an ordinary t1 merge stays soft")
	# the reserved big-moment cues (shake + board punch, default OFF) are FORCED on for an intensified merge,
	# but still respect the master enable.
	var dflt := MergeFx.from_config({})
	ok(not MergeFx.on(dflt, "shake") and not MergeFx.on(dflt, "board_punch"), "shake + board punch default OFF (cozy)")
	ok(MergeFx.big_cue_forced(dflt, true), "an intensified merge forces the reserved shake + board punch on")
	ok(not MergeFx.big_cue_forced(dflt, false), "an ordinary merge does NOT force the reserved cues")
	ok(not MergeFx.big_cue_forced(off, true), "even an intensified merge stays silent when the merge master is off")

	# --- apply: a cue toggled OFF does not fire (burst adds no GPUParticles2D child) ---
	var host_on := Control.new()
	host_on.size = Vector2(200, 200)
	get_root().add_child(host_on)
	var tile_on := Control.new()
	tile_on.size = Vector2(96, 96)
	host_on.add_child(tile_on)
	# burst ON (default) → a particle child is added to the host
	MergeFx.apply(host_on, tile_on, Vector2(50, 50), 3, 0, [], host_on, MergeFx.from_config({}), 1.0, 0)
	ok(_count_particles(host_on) >= 1, "MergeFx.apply with burst ON fires a particle burst (a child is added)")
	# burst OFF → no particle child is added
	var host_off := Control.new()
	host_off.size = Vector2(200, 200)
	get_root().add_child(host_off)
	var tile_off := Control.new()
	tile_off.size = Vector2(96, 96)
	host_off.add_child(tile_off)
	# both particle cues OFF (burst + the world_puff petals) → no GPUParticles2D child at all
	MergeFx.apply(host_off, tile_off, Vector2(50, 50), 3, 0, [], host_off, MergeFx.from_config({"merge_fx": {"burst": false, "world_puff": false}}), 1.0, 0)
	ok(_count_particles(host_off) == 0, "MergeFx.apply with burst + world_puff OFF fires NO particles (no child added)")

	# --- the three new world-reaction cues: defaults + apply behaviour ---
	var d3 := MergeFx.from_config({})
	ok(MergeFx.on(d3, "world_puff") and MergeFx.on(d3, "combo_words") and MergeFx.on(d3, "combo_bloom"), \
		"world_puff / combo_words / combo_bloom all default ON")
	ok(MergeFx.knob(d3, "puff_count") == 8 and MergeFx.knob(d3, "puff_size_pct") == 120 \
		and MergeFx.knob(d3, "words_size") == 30 and MergeFx.knob(d3, "bloom_pct") == 100, \
		"the new knobs default to puff_count 8 / puff_size_pct 120 / words_size 30 / bloom_pct 100")
	var c3 := MergeFx.from_config({"merge_fx": {"world_puff": false, "combo_words": false, "combo_bloom": false, "puff_count": 3, "bloom_pct": 50}})
	ok(not MergeFx.on(c3, "world_puff") and not MergeFx.on(c3, "combo_words") and not MergeFx.on(c3, "combo_bloom"), \
		"from_config honours the three new toggles set false")
	ok(MergeFx.knob(c3, "puff_count") == 3 and MergeFx.knob(c3, "bloom_pct") == 50, "from_config honours the new knobs")

	# world_puff ON (burst OFF) → exactly the petal puff GPUParticles2D appears
	var host_wp := Control.new()
	host_wp.size = Vector2(200, 200)
	get_root().add_child(host_wp)
	var tile_wp := Control.new()
	tile_wp.size = Vector2(96, 96)
	host_wp.add_child(tile_wp)
	MergeFx.apply(host_wp, tile_wp, Vector2(50, 50), 3, 0, [], host_wp, MergeFx.from_config({"merge_fx": {"burst": false, "world_puff": true}}), 1.0, 0)
	ok(_count_particles(host_wp) >= 1, "MergeFx.apply with world_puff ON adds a petal GPUParticles2D")
	# world_puff OFF (burst OFF) → no particle child
	var host_wo := Control.new()
	host_wo.size = Vector2(200, 200)
	get_root().add_child(host_wo)
	var tile_wo := Control.new()
	tile_wo.size = Vector2(96, 96)
	host_wo.add_child(tile_wo)
	MergeFx.apply(host_wo, tile_wo, Vector2(50, 50), 3, 0, [], host_wo, MergeFx.from_config({"merge_fx": {"burst": false, "world_puff": false}}), 1.0, 0)
	ok(_count_particles(host_wo) == 0, "MergeFx.apply with world_puff OFF adds no petal particles")

	# combo_words fires a floating Label ONLY at a milestone combo (3/5/8), not at a non-milestone
	var host_w0 := Control.new()
	host_w0.size = Vector2(200, 200)
	get_root().add_child(host_w0)
	var tile_w0 := Control.new()
	tile_w0.size = Vector2(96, 96)
	host_w0.add_child(tile_w0)
	# combo 2 (not a milestone) → no word
	MergeFx.apply(host_w0, tile_w0, Vector2(50, 50), 3, 2, [], host_w0, MergeFx.from_config({"merge_fx": {"burst": false, "world_puff": false}}), 1.0, 0)
	ok(_count_labels(host_w0) == 0, "combo_words fires NO word at a non-milestone combo (2)")
	# combo 3 (a milestone) → one word
	MergeFx.apply(host_w0, tile_w0, Vector2(50, 50), 3, 3, [], host_w0, MergeFx.from_config({"merge_fx": {"burst": false, "world_puff": false}}), 1.0, 0)
	ok(_count_labels(host_w0) >= 1, "combo_words fires a floating word at a milestone combo (3)")

	# --- LandFx.apply: a QUIET land fires the puff but NOT the flash/sound (mirrors feel.land) ---
	var host_q := Control.new()
	host_q.size = Vector2(200, 200)
	get_root().add_child(host_q)
	var tile_q := Control.new()
	tile_q.size = Vector2(96, 96)
	host_q.add_child(tile_q)
	LandFx.apply(host_q, tile_q, Vector2(50, 50), LandFx.from_config({}), 1.0, true)
	ok(_count_particles(host_q) >= 1, "LandFx.apply quiet still fires the dust puff (the touchdown visual)")
	ok(_count_flashes(host_q) == 0, "LandFx.apply quiet suppresses the flash (the per-tile dedupe)")

	# --- LandFx ripple: the new neighbour BUMP on a plain drop (mirrors the merge ripple, driven by the
	# new trailing `neighbors` arg). Default ON; gated by `not quiet` so a bulk settle never N-bumps. ---
	var l_def := LandFx.from_config({})
	ok(LandFx.on(l_def, "ripple"), "LandFx ripple defaults ON")
	ok(LandFx.knob(l_def, "ripple_pct") == LandFx.KNOBS["ripple_pct"], "LandFx ripple_pct defaults to the registry knob")
	var l_rip := LandFx.from_config({"land_fx": {"ripple": false, "ripple_pct": 30}})
	ok(LandFx.on(l_rip, "ripple") == false and LandFx.knob(l_rip, "ripple_pct") == 30, "LandFx.from_config honours the ripple toggle + knob")
	var host_r := Control.new(); host_r.size = Vector2(300, 300); get_root().add_child(host_r)
	var tile_r := Control.new(); tile_r.size = Vector2(96, 96); host_r.add_child(tile_r)
	# loud land + ripple ON → the neighbour's pivot gets centred (the Feel.ripple side effect we can read headless).
	var nb := Control.new(); nb.size = Vector2(96, 96); nb.position = Vector2(120, 0); host_r.add_child(nb)
	LandFx.apply(host_r, tile_r, Vector2(20, 20), LandFx.from_config({}), 1.0, false, [nb])
	ok(nb.pivot_offset.is_equal_approx(nb.size / 2.0), "LandFx.apply with a neighbour + ripple on bumps the neighbour (pivot centred)")
	# a QUIET land must NOT ripple (a gravity/bulk settle can't fire N neighbour bumps).
	var nb_q := Control.new(); nb_q.size = Vector2(96, 96); nb_q.position = Vector2(120, 0); host_r.add_child(nb_q)
	LandFx.apply(host_r, tile_r, Vector2(20, 20), LandFx.from_config({}), 1.0, true, [nb_q])
	ok(nb_q.pivot_offset == Vector2.ZERO, "a QUIET LandFx.apply does NOT ripple the neighbours")
	# ripple toggled OFF → no neighbour bump even on a loud land.
	var nb_off := Control.new(); nb_off.size = Vector2(96, 96); nb_off.position = Vector2(120, 0); host_r.add_child(nb_off)
	LandFx.apply(host_r, tile_r, Vector2(20, 20), LandFx.from_config({"land_fx": {"ripple": false}}), 1.0, false, [nb_off])
	ok(nb_off.pivot_offset == Vector2.ZERO, "LandFx.apply with ripple OFF does not bump neighbours")
	host_r.queue_free()

	host_on.queue_free(); host_off.queue_free(); host_q.queue_free()

# Count the GPUParticles2D children of a host (the FX.burst side effect).
func _count_particles(host: Node) -> int:
	var n := 0
	for ch in host.get_children():
		if ch is GPUParticles2D:
			n += 1
	return n

# Count the FX.flash ColorRect children of a host (white impact squares; the tile child is a plain Control).
func _count_flashes(host: Node) -> int:
	var n := 0
	for ch in host.get_children():
		if ch is ColorRect:
			n += 1
	return n

# Count the FX.floating_text Label children of a host (the combo milestone word floater).
func _count_labels(host: Node) -> int:
	var n := 0
	for ch in host.get_children():
		if ch is Label:
			n += 1
	return n
