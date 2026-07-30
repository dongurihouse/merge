extends "res://engine/tests/test_base.gd"
## Headless guard for the HUD's paper-MEDAL level badge — which tier a Level wears, and where the
## number lands inside it.
##   godot --headless --path . -s res://engine/tests/level_badge_medal_tests.gd
##
## Two things this suite exists to hold:
##
##  1. THE TIER MAP IS THE LADDER'S OWN. The medal has three tiers; data/level_badges.json already
##     carries a 30-tier ladder banded L1-10 / L11-40 / L41+. The medal's thresholds are that
##     ladder's band starts, DERIVED, and this suite recomputes them from `bands` and checks the
##     shipped `min_level` values against them — so a retune of either half that silently pulls them
##     apart fails here instead of shipping a badge that upgrades on a different schedule from the
##     tier it is named after.
##
##  2. THE NUMBER RIDES THE DISC, NOT THE ART'S BOX. t1's ribbon tails hang below the disc, t2's
##     ribbon covers its bottom, t3's banner and star lie across it — so the art's centre is 5-9 px
##     below the disc's at the shipped slot and a number centred on the badge reads low. The offset
##     is per tier, and these checks read the offset the badge SHIPS (Look.medal_num_offset, and the
##     Label's own rect) rather than re-running the expression, so a duplicated formula cannot make
##     them pass vacuously.
##
## THE PIXEL CENTRING ITSELF IS NOT A HEADLESS CLAIM. Whether the digits' INK is optically centred is
## a measurement on the real renderer — games/grove/tools/medal_badge_shot.gd draws the tier × digit
## matrix and the centring skill's check_text_centring.py measures it. This suite holds the geometry
## that measurement was taken of.

const Look = preload("res://engine/scripts/ui/skin.gd")
const Kit = preload("res://games/grove/ui_kit.gd")
const Hud = preload("res://engine/scripts/ui/hud.gd")
const Design = preload("res://engine/scripts/core/design.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const G = preload("res://engine/scripts/core/content.gd")

const PX := 116.0          # the shipped HUD slot: ceil(pill_h × Hud.LEVEL_BADGE_SCALE)
## The bands the medal collapses, spelled as PLAIN NUMBERS (the doc's rule: a bound written in terms
## of the constant under test passes a broken constant). L1-10 · L11-40 · L41 and up.
const EXPECTED_MIN_LEVELS := [1, 11, 41]


func _initialize() -> void:
	print("== Level-badge medal guard ==")
	_check_thresholds_are_the_ladders_band_starts()
	_check_tier_selection_at_every_boundary()
	_check_offset_is_per_tier_and_lifts_the_number()
	await _check_built_badge_puts_its_number_on_the_disc()
	_check_number_is_placed_by_its_ink_not_its_advance_box()
	await _check_a_level_tick_re_places_the_number()
	_check_the_shared_num_y_key_did_not_move()
	finish()


## The medal's thresholds are DERIVED from the 30-tier ladder's banding: one medal per band, so each
## medal's first Level is the first Level of a band. Recompute the band starts from `bands` and
## compare — if the ladder is rebanded, or a min_level is retuned, exactly one of these fails and the
## other says which half moved.
func _check_thresholds_are_the_ladders_band_starts() -> void:
	var cfg: Dictionary = Look._level_badge_cfg()
	var bands: Array = cfg.get("bands", [])
	ok(bands.size() == 3, "the ladder is three bands (%d)" % bands.size())
	var starts: Array = []
	var cursor := 1
	for b in bands:
		var band: Dictionary = b
		starts.append(cursor)
		cursor += maxi(1, int(band.get("levels_per_tier", 1))) * maxi(0, int(band.get("tiers", 0)))
	ok(starts == EXPECTED_MIN_LEVELS,
		"the ladder's band starts are L%s (derived from `bands`)" % str(starts))

	var specs := Look.medal_specs()
	ok(specs.size() == 3, "the medal family has three tiers (%d)" % specs.size())
	var mins: Array = []
	for s in specs:
		mins.append(int((s as Dictionary).get("min_level", 0)))
	ok(mins == starts,
		"each medal starts where a ladder band starts (medal %s vs bands %s)" % [str(mins), str(starts)])
	ok(mins == EXPECTED_MIN_LEVELS,
		"…and those are the documented thresholds L1 / L11 / L41 (%s)" % str(mins))

	# every tier names its own art and its own disc, or two tiers would share a placement
	var arts: Array = []
	var discs: Array = []
	for s in specs:
		var d: Dictionary = s
		arts.append(String(d.get("art", "")))
		discs.append(float(d.get("circle_cy", -1.0)))
		ok(ResourceLoader.exists(Look.kit(Look.MEDAL_ART_DIR + String(d.get("art", "")))),
			"tier art exists on disk: %s" % String(d.get("art", "")))
		ok(float(d.get("circle_cy", -1.0)) > 0.30 and float(d.get("circle_cy", -1.0)) < 0.50,
			"…its disc centre is in the upper half of the canvas (%.4f)" % float(d.get("circle_cy", -1.0)))
		ok(float(d.get("painted_span", 0.0)) > 0.85 and float(d.get("painted_span", 0.0)) <= 1.0,
			"…and the painted art spans most of it (%.4f)" % float(d.get("painted_span", 0.0)))
	ok(arts.size() == 3 and arts[0] != arts[1] and arts[1] != arts[2] and arts[0] != arts[2],
		"the three tiers are three different files (%s)" % str(arts))


## Both sides of every band joint, plus the ends. A one-sided check (only the first Level of a band)
## passes a map that is off by one in the other direction.
func _check_tier_selection_at_every_boundary() -> void:
	var cases := {1: 0, 2: 0, 9: 0, 10: 0, 11: 1, 12: 1, 24: 1, 39: 1, 40: 1,
		41: 2, 42: 2, 85: 2, 100: 2, 101: 2, 999: 2}
	for lvl in cases:
		ok(Look.medal_tier_index(int(lvl)) == int(cases[lvl]),
			"Level %d wears medal tier %d (got %d)" % [lvl, int(cases[lvl]), Look.medal_tier_index(int(lvl))])
	# a level below the first band start must not fall off the bottom
	ok(Look.medal_tier_index(0) == 0 and Look.medal_tier_index(-5) == 0,
		"a Level at or below 0 clamps to the first medal")
	# the three approved mocks were labelled Lv2 / Lv24 / Lv85 — one per tier, in order
	ok(Look.medal_tier_index(2) == 0 and Look.medal_tier_index(24) == 1 and Look.medal_tier_index(85) == 2,
		"the approved mocks' own labels land on t1 / t2 / t3")


## The offset is PER TIER: it is read back from Look.medal_num_offset (the shipped accessor), and the
## three values must differ, must all be negative (the disc sits ABOVE the badge's centre because the
## tails hang below it), and must land in the band the study measured — 4 to 10 px at the 116 slot.
func _check_offset_is_per_tier_and_lifts_the_number() -> void:
	var offs: Array = []
	for lvl in [2, 24, 85]:
		offs.append(Look.medal_num_offset(Look.medal_spec(int(lvl)), PX))
	for i in offs.size():
		ok(float(offs[i]) < -3.0 and float(offs[i]) > -10.0,
			"tier %d lifts the number %.2f px off the badge centre (want 3..10 px up)" % [i + 1, -float(offs[i])])
	ok(not is_equal_approx(float(offs[0]), float(offs[1])) \
		and not is_equal_approx(float(offs[1]), float(offs[2])) \
		and not is_equal_approx(float(offs[0]), float(offs[2])),
		"the three tiers do NOT share one offset (%.2f / %.2f / %.2f)" % [offs[0], offs[1], offs[2]])
	# t1's disc sits highest inside its own art (its tails hang furthest), so it lifts the most
	ok(float(offs[0]) < float(offs[1]) and float(offs[0]) < float(offs[2]),
		"t1 lifts the most — its ribbon tails hang furthest below the disc")
	# the offset scales with the slot: it is a geometry fraction, not a pixel count (bar the one-px
	# ink bias, which is a rasterisation term and deliberately does NOT scale)
	var bias := float(Look.MEDAL_NUM_INK_BIAS_PX)
	var half := Look.medal_num_offset(Look.medal_spec(2), PX * 0.5)
	ok(is_equal_approx(half - bias, (float(offs[0]) - bias) * 0.5),
		"halving the slot halves the geometric part of the offset (%.3f vs %.3f)" % [half - bias, (float(offs[0]) - bias) * 0.5])


## The BUILT badge: the tier's art really is the texture under it, and the number Label's rect centre
## really lands on that art's disc. Both sides are read off the live nodes — the art rect on screen
## and the Label's rect — so this measures the tree, not the formula.
func _check_built_badge_puts_its_number_on_the_disc() -> void:
	var host := Control.new()
	host.size = Vector2(400, 900)
	get_root().add_child(host)
	var y := 0.0
	for lvl in [2, 24, 85]:
		var spec := Look.medal_spec(lvl)
		var badge := Look.make_star_level_badge(lvl, PX, Hud._lv_font_size(lvl, PX))
		badge.position = Vector2(20, y)
		host.add_child(badge)
		y += 200.0
	await process_frame
	await process_frame
	var i := 0
	for lvl in [2, 24, 85]:
		var spec := Look.medal_spec(lvl)
		var badge := host.get_child(i) as Control
		var art := badge.get_node_or_null("lv_badge_art") as TextureRect
		var num := badge.get_node_or_null("lv_num") as Label
		ok(art != null and art.texture != null, "tier %d badge carries its art" % (i + 1))
		if art != null and art.texture != null:
			ok(art.texture.resource_path.contains(String(spec.get("art", "@none"))) \
				or Kit.baked_path(Look.kit(Look.MEDAL_ART_DIR + String(spec.get("art", ""))), 256) == art.texture.resource_path,
				"…and it is THIS tier's file (%s ← %s)" % [String(spec.get("art", "")), art.texture.resource_path])
			# the disc, read off the art rect actually laid out, vs the Label's rect centre
			var disc_y: float = art.position.y + float(spec.get("circle_cy", 0.5)) * art.size.y
			var num_cy: float = num.position.y + num.size.y * 0.5
			ok(num != null and absf(num_cy - disc_y - Look.MEDAL_NUM_INK_BIAS_PX) < 0.05,
				"tier %d: the number's line box centres on the disc (%.2f vs %.2f + %.1f ink bias)" \
				% [i + 1, num_cy, disc_y, Look.MEDAL_NUM_INK_BIAS_PX])
			# …and that is NOT the badge's own centre — the whole point of the per-tier offset
			ok(absf(disc_y - PX * 0.5) > 3.0,
				"tier %d: the disc is %.1f px off the badge's own centre" % [i + 1, disc_y - PX * 0.5])
			ok(is_equal_approx(num.offset_left, num.offset_right),
				"tier %d: the number's horizontal offset moves both edges together" % (i + 1))
		i += 1
	host.queue_free()


## THE HORIZONTAL AXIS. This face is TABULAR — every digit carries the identical advance — but the
## digits do not carry identical INK inside it: `1` has a fat left side bearing. A Label centres the
## ADVANCE box, so a centred `1` lands 2.5 px left of a centred `8` (measured on the real render),
## and Level 1 is the first badge every player sees. The correction is therefore per STRING, not a
## constant, and it is measured from the glyphs actually being drawn.
##
## THE NON-VACUITY IS STRUCTURAL, not a duplicated formula: the two strings have the SAME advance
## width (asserted), so any implementation that centres the layout box gives them the same offset.
## Only one that measures INK can give them different ones. Delete the correction and `dx('1')`
## collapses to 0 and these fail.
func _check_number_is_placed_by_its_ink_not_its_advance_box() -> void:
	var font: Font = Kit.bold_font()
	for fs in [49, 39, 31]:
		var w1 := font.get_string_size("1", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var w8 := font.get_string_size("8", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		ok(is_equal_approx(w1, w8),
			"font %d: `1` and `8` have the SAME advance (%.1f / %.1f) — a layout-box centring cannot tell them apart" % [fs, w1, w8])
		var dx1 := Look.medal_num_ink_dx("1", font, fs)
		var dx8 := Look.medal_num_ink_dx("8", font, fs)
		ok(dx1 > 1.0, "font %d: `1` is pushed RIGHT to put its ink on the disc (%+.2f px)" % [fs, dx1])
		ok(dx1 - dx8 > 1.0,
			"font %d: …and by %.2f px MORE than `8` (%+.2f vs %+.2f) — the correction reads the glyphs" % [fs, dx1 - dx8, dx1, dx8])
	# every digit, at every shipped size, stays inside a sane band — a runaway correction would
	# shove the number off the disc, which is worse than the defect it fixes
	var worst := 0.0
	var worst_at := ""
	for fs in [49, 39, 31]:
		for d in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "11", "88", "100", "888"]:
			var dx := Look.medal_num_ink_dx(String(d), font, fs)
			if absf(dx) > worst:
				worst = absf(dx)
				worst_at = "%s@%d" % [d, fs]
	ok(worst < 4.0, "no digit's correction runs away (worst %.2f px on %s)" % [worst, worst_at])
	# an empty string and a missing font have no ink to centre — no NaN, no crash
	ok(is_equal_approx(Look.medal_num_ink_dx("", font, 49), 0.0), "an empty string needs no correction")
	ok(is_equal_approx(Look.medal_num_ink_dx("1", null, 49), 0.0), "a missing font refuses rather than guessing")


## THE DRIFT THE CORRECTION INVITES. Because the offset belongs to the STRING, a badge that keeps
## its build-time offset walks sideways the moment the level ticks — Hud.refresh changes the text
## without rebuilding the emblem inside a tier. This drives the REAL HUD across a tick from a
## two-`1` level to a `1`-free one and checks the offset followed.
func _check_a_level_tick_re_places_the_number() -> void:
	fresh("medal_tick")
	var host := Control.new()
	host.custom_minimum_size = Design.size()
	host.size = Design.size()
	get_root().add_child(host)
	Save.grove()["coins_earned"] = G.coins_at_level(11)          # Lv11 -> "11", both glyphs fat-beared
	var hud: Dictionary = Hud.build(host, {})
	await process_frame
	var num := host.find_child("lv_num", true, false) as Label
	ok(num != null and num.text == "11", "the HUD starts at Lv11 (%s)" % (num.text if num != null else "no label"))
	var at_11 := num.offset_left if num != null else 0.0
	Save.grove()["coins_earned"] = G.coins_at_level(28)          # …still tier 2, so NO rebuild: a tick
	(hud["refresh"] as Callable).call()
	await process_frame
	ok(num != null and num.text == "28", "…and ticks to Lv28 without rebuilding the emblem (%s)" % (num.text if num != null else "-"))
	var at_28 := num.offset_left if num != null else 0.0
	var want_11 := Look.medal_num_ink_dx("11", Kit.bold_font(), Hud._lv_font_size(11, PX))
	var want_28 := Look.medal_num_ink_dx("28", Kit.bold_font(), Hud._lv_font_size(28, PX))
	ok(not is_equal_approx(want_11, want_28),
		"the two strings genuinely want different offsets (%+.2f vs %+.2f)" % [want_11, want_28])
	ok(is_equal_approx(at_11, want_11), "Lv11's number was placed by ITS ink (%+.2f)" % at_11)
	ok(is_equal_approx(at_28, want_28),
		"…and the tick RE-placed it for the new string (%+.2f, not the stale %+.2f)" % [at_28, at_11])
	host.queue_free()


## THE KEY THAT MUST NOT MOVE. `level_badge.num_y` in games/grove/ui_kit_settings.json is read by
## Kit.level_badge_opts_from_config and consumed by Kit.level_badge — the MEADOW badge family
## (assets/ui/meadow_v2/level_badge_01..25.png) worn by the map/scene CELL TILES via Kit.slot_cell,
## and by the UI workbench preview. It is NOT the HUD medal's knob and it is NOT the level dialog's
## (engine/scripts/ui/level_popup.gd draws its own medallion from kit/level_plaque.png and reads no
## num_y at all). The paper-medal work deliberately gave the medal its OWN per-tier offsets instead
## of touching this shared key; this pins it, so an edit that "cleans up" num_y for the medal's sake
## fails here with the name of what it would have moved.
func _check_the_shared_num_y_key_did_not_move() -> void:
	var cfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH)
	var opts: Dictionary = Kit.level_badge_opts_from_config(cfg)
	ok(is_equal_approx(float(opts.get("num_y", -999.0)), 5.0),
		"Kit.level_badge still centres its number at num_y = 5.0%% of px (got %s)" % str(opts.get("num_y", "missing")))
	# …and the meadow badge really applies it, so the pin above is not on a dead key
	var badge := Kit.level_badge(opts, 3, 12, 100.0)
	var num := badge.get_node_or_null("lv_num") as Label
	ok(num != null and is_equal_approx(num.offset_top, 5.0),
		"…and Kit.level_badge offsets its Label by px × num_y / 100 (%.2f of 100 px)" % (num.offset_top if num != null else -999.0))
	var art := badge.get_node_or_null("lv_badge_art") as TextureRect
	ok(art != null and art.texture != null and art.texture.resource_path.contains("level_badge_"),
		"…on the MEADOW badge family, not the medal (%s)" % (art.texture.resource_path if art != null and art.texture != null else "no art"))
	badge.queue_free()
