extends SceneTree
## Headless tests for the §14 FTUE feature-spotlight MECHANISM (T28). The overlay's
## visual feel (veil/pulse/hand-gesture) is perceptual and lives in ui/ — NOT tested
## here; the CORRECTNESS is the first-appearance gate + its persisted seen-state + the
## game's gesture/order registry, all asserted headless.
##   godot --headless --path . -s res://engine/tests/spotlight_tests.gd

const Spotlight = preload("res://engine/scripts/core/spotlight.gd")
const Features = preload("res://engine/scripts/core/features.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const G = preload("res://engine/scripts/core/content.gd")

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
	var dir := "user://tu_spot_" + name + "/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

func _initialize() -> void:
	print("== Spotlight tests ==")

	# 1. the flag exists and defaults ON (the other ftue flags do too).
	ok(Features.on("ftue_feature_spotlight"), "ftue_feature_spotlight defaults ON")

	# 2. the gate: should_spotlight() is true the FIRST time a feature appears, then FALSE
	#    once it has been marked spotlit (the once-per-feature contract — never re-announce).
	fresh("gate")
	ok(Spotlight.should_spotlight("merchant"), "first appearance of a feature → should_spotlight true")
	Spotlight.mark_spotlit("merchant")
	ok(not Spotlight.should_spotlight("merchant"), "after mark_spotlit → should_spotlight false (never re-announce)")
	ok(Spotlight.should_spotlight("bag"), "a DIFFERENT feature is still spotlight-eligible (per-feature, not global)")

	# 3. the flag gates the whole mechanism: OFF → never spotlight (even a brand-new feature).
	fresh("flag_off")
	Features.FLAGS["ftue_feature_spotlight"] = false
	ok(not Spotlight.should_spotlight("shop"), "flag OFF → should_spotlight false (mechanism disabled)")
	Features.FLAGS["ftue_feature_spotlight"] = true
	ok(Spotlight.should_spotlight("shop"), "flag back ON → should_spotlight true again")

	# 4. seen-state PERSISTS across a save→load round-trip (lives in the save blob).
	fresh("persist")
	Spotlight.mark_spotlit("merchant")
	Spotlight.mark_spotlit("shop")
	Save._loaded = false                       # force a reload from disk
	ok(not Spotlight.should_spotlight("merchant"), "seen-state persists across reload (merchant)")
	ok(not Spotlight.should_spotlight("shop"), "seen-state persists across reload (shop)")
	ok(Spotlight.should_spotlight("bag"), "an unseen feature is still eligible after the reload")

	# 5. mark_spotlit is idempotent — re-marking a seen feature is a no-op (no duplicate, still seen).
	fresh("idempotent")
	Spotlight.mark_spotlit("bag")
	Spotlight.mark_spotlit("bag")
	ok(Save.spotlights_seen().count("bag") == 1, "mark_spotlit is idempotent (one record, no duplicate)")

	# 6. the GROVE registry: gesture (tap/drag) per feature + the staged order it teaches them.
	#    The DATA lives in the game (grove_data.SPOTLIGHTS); the engine reads it game-agnostically.
	ok(Spotlight.gesture_for("merchant") == "drag", "merchant teaches a DRAG (drag a top tier to sell)")
	ok(Spotlight.gesture_for("bag") == "drag", "bag teaches a DRAG (drag a piece to stow)")
	ok(Spotlight.gesture_for("shop") == "tap", "shop teaches a TAP (tap to open the store)")
	ok(Spotlight.gesture_for("unknown_feature") == "tap", "an unknown feature falls back to a TAP gesture")

	# 7. the registry knows which features it spotlights, in the staged early-level order (§14).
	var order := Spotlight.feature_order()
	ok(order.size() >= 3, "the registry stages at least the 3 wired features (got %d)" % order.size())
	ok(order.has("merchant") and order.has("bag") and order.has("shop"), "the order includes merchant, bag, shop")
	# the merge verb is taught by the idle hint, NOT a spotlight — it must not be in the registry.
	ok(not order.has("merge"), "the merge verb is NOT spotlit here (the idle hint teaches it, §14)")
	# merchant unlocks before bag (chrome stages merchant ch1+, bag ch2+ — §14 staged-chrome).
	ok(order.find("merchant") < order.find("bag"), "merchant is staged before the bag (chrome order)")

	# 8. every registered feature is a complete entry (has a gesture the overlay can play).
	var all_valid := true
	for fid in order:
		if not ["tap", "drag"].has(Spotlight.gesture_for(fid)):
			all_valid = false
	ok(all_valid, "every registered feature declares a tap/drag gesture the overlay can mime")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
