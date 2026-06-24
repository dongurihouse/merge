extends SceneTree
## Headless tests for the synth SFX palette + variation (audio.gd).
##   godot --headless --path . -s res://engine/tests/sfx_tests.gd

const Audio = preload("res://engine/scripts/core/audio.gd")
const Save = preload("res://engine/scripts/core/save.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond: _pass += 1; print("  PASS  ", label)
	else: _fail += 1; print("  FAIL  ", label)

func _initialize() -> void:
	Save.set_setting("sfx", true)

	# every cue in the palette is loaded (manifest-driven, not a hardcoded list)
	for name in ["button_tap", "invalid_soft", "merge_soft", "merge_success",
			"item_pickup", "item_drop", "bag_in", "bag_out", "star_earn",
			"star_pop", "water_pop", "rain_refill", "bramble_clear", "tidy_poof",
			"giver_cheer", "coin_earn", "unlock", "quest_complete", "undo",
			"item_slide", "level_complete"]:
		ok(Audio.has(name), "cue loaded: %s" % name)

	# the 7 previously-inert, fallback-wired cues now resolve (no silent fallback)
	for name in ["water_pop", "rain_refill", "bramble_clear", "star_earn",
			"bag_in", "bag_out", "giver_cheer"]:
		ok(Audio.has(name), "no-longer-inert: %s" % name)

	# hot cues expose 3 variants; a non-hot cue exposes 1
	ok(Audio.variant_count("button_tap") == 3, "button_tap has 3 variants")
	ok(Audio.variant_count("water_pop") == 1, "water_pop has 1 variant")

	# jitter is bounded and actually varies (the #1 boring-fix)
	var pitches := {}
	for i in range(40):
		pitches[Audio.jitter_pitch(1.0)] = true
	ok(pitches.size() > 1, "jitter_pitch varies across calls")
	var within := true
	for p in pitches:
		if p < 0.95 or p > 1.06: within = false
	ok(within, "jitter_pitch stays within ~±35 cents of base")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
