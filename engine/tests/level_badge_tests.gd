extends SceneTree
## Headless guard for the LAYERED level badge — five cut parts (circle, leaf, flower, acorn,
## gem; ui/lvl_parts/<part>_<1..6>.png) composited per a 30-tier progression, with the level
## number centered. The Level->tier map is BANDED in data/level_badges.json. Tier ÷ 6 = group
## (0..4), tier mod 6 + 1 = stage (1..6); each group draws a fixed set of parts at that stage.
##   godot --headless --path . -s res://engine/tests/level_badge_tests.gd
## Proves: config parses, banded Level->tier is correct/monotonic/clamped, all 30 parts resolve
## as alpha-cut grove art, the tier decomposition + builder + config resolver behave, and the
## shared make_level_badge composites the right parts with the level number.

const Look = preload("res://engine/scripts/ui/skin.gd")
const Hud = preload("res://engine/scripts/ui/hud.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Design = preload("res://engine/scripts/core/design.gd")
const LevelPopup = preload("res://engine/scripts/ui/level_popup.gd")
const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")

const PARTS := ["circle", "leaf", "flower", "acorn", "gem"]

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _initialize() -> void:
	OS.set_environment("GAME", "grove")   # the parts live in grove's clothes (Game.art root)
	print("== Layered level badge guard ==")

	# --- config: 30 tiers, banded 10@1 / 10@3 / 10@6 -----------------------------
	var f := FileAccess.open("res://data/level_badges.json", FileAccess.READ)
	ok(f != null, "data/level_badges.json present")
	var cfg = JSON.parse_string(f.get_as_text()) if f != null else null
	ok(cfg is Dictionary, "config parses to a Dictionary")
	var d: Dictionary = cfg if cfg is Dictionary else {}
	var count := int(d.get("tier_count", d.get("badge_count", 0)))
	ok(count == 30, "tier_count == 30 (got %d)" % count)
	var bands: Array = d.get("bands", [])
	ok(bands.size() == 3, "3 bands (got %d)" % bands.size())
	var tier_sum := 0
	for b in bands:
		tier_sum += int((b as Dictionary).get("tiers", 0))
	ok(tier_sum == count, "band tiers sum to tier_count (%d == %d)" % [tier_sum, count])

	# --- banded tier index: 1/level (L1-10), every 3 (L11-40), every 6 (L41-100) ---
	ok(Look.level_badge_index(1) == 0,   "L1 -> tier 0")
	ok(Look.level_badge_index(10) == 9,  "L10 -> tier 9 (one per level)")
	ok(Look.level_badge_index(11) == 10, "L11 -> tier 10 (band 2 begins)")
	ok(Look.level_badge_index(13) == 10, "L13 -> tier 10 (tier of 3)")
	ok(Look.level_badge_index(14) == 11, "L14 -> tier 11 (tier flips)")
	ok(Look.level_badge_index(40) == 19, "L40 -> tier 19 (band 2 ends)")
	ok(Look.level_badge_index(41) == 20, "L41 -> tier 20 (band 3 begins)")
	ok(Look.level_badge_index(46) == 20, "L46 -> tier 20 (tier of 6)")
	ok(Look.level_badge_index(47) == 21, "L47 -> tier 21 (tier flips)")
	ok(Look.level_badge_index(100) == 29, "L100 -> tier 29 (final)")
	ok(Look.level_badge_index(101) == count - 1, "past the last band holds at the final tier")
	ok(Look.level_badge_index(1000) == count - 1, "huge level clamps to the final tier")
	ok(Look.level_badge_index(0) == 0, "L0 clamps to tier 0")
	ok(Look.level_badge_index(-5) == 0, "negative level clamps to tier 0")

	# monotonic non-decreasing, clamped, reaches EVERY tier across the design range
	var mono_ok := true
	var seen := {}
	var prev := -1
	for lvl in range(1, 200):
		var idx := Look.level_badge_index(lvl)
		if idx < prev or idx < 0 or idx >= count:
			mono_ok = false
			break
		prev = idx
		seen[idx] = true
	ok(mono_ok, "tier index is monotonic non-decreasing and in [0, count) for L in 1..199")
	ok(seen.size() == count, "every one of the %d tiers is reachable (got %d)" % [count, seen.size()])

	# --- all 30 parts exist as resolvable, alpha-cut grove art -------------------
	var missing := 0
	var opaque := 0
	for p in PARTS:
		for s in range(1, 7):
			var path := Game.art("ui/lvl_parts/%s_%d.png" % [p, s])
			if not ResourceLoader.exists(path):
				missing += 1
				continue
			var tex := Hud._safe_tex(path)
			if tex == null or not _all_corners_transparent(tex):
				opaque += 1
	ok(missing == 0, "all 30 parts resolve (missing=%d)" % missing)
	ok(opaque == 0, "all 30 parts are alpha-cut (4 transparent corners; opaque=%d)" % opaque)

	# --- tier -> (group, stage, parts) decomposition ----------------------------
	var t0: Dictionary = Kit.level_badge_tier_parts(0)
	ok(t0.get("group") == 0 and t0.get("stage") == 1 and t0.get("parts") == ["leaf"],
		"tier 0 -> group 0, stage 1, parts [leaf]")
	var t5: Dictionary = Kit.level_badge_tier_parts(5)
	ok(t5.get("group") == 0 and t5.get("stage") == 6, "tier 5 -> group 0, stage 6")
	var t6: Dictionary = Kit.level_badge_tier_parts(6)
	ok(t6.get("group") == 1 and t6.get("stage") == 1 and t6.get("parts") == ["leaf", "flower"],
		"tier 6 -> group 1, stage 1, parts [leaf, flower]")
	var t18: Dictionary = Kit.level_badge_tier_parts(18)
	ok(t18.get("group") == 3 and t18.get("parts") == ["leaf", "flower", "gem"],
		"tier 18 -> group 3, parts [leaf, flower, gem]")
	var t29: Dictionary = Kit.level_badge_tier_parts(29)
	ok(t29.get("group") == 4 and t29.get("stage") == 6 and t29.get("parts") == ["leaf", "acorn", "gem"],
		"tier 29 -> group 4, stage 6, parts [leaf, acorn, gem]")
	ok(Kit.level_badge_tier_parts(999).get("group") == 4, "tier beyond range clamps to group 4")

	# --- config resolver returns every knob with a default ----------------------
	var o: Dictionary = Kit.level_badge_opts_from_config({})
	var keys_ok := o.has("size") and o.has("num_size") and o.has("num_x") and o.has("num_y")
	for p in PARTS:
		keys_ok = keys_ok and o.has(p + "_x") and o.has(p + "_y") and o.has(p + "_scale")
	ok(keys_ok, "level_badge_opts_from_config({}) yields size/num_*/<part>_{x,y,scale} defaults")

	# --- the builder composites the tier's parts + the level number -------------
	var opts: Dictionary = Kit.level_badge_opts_from_config({})
	var b0: Control = Kit.level_badge(opts, 0, 7, 200.0)        # tier 0 = leaf only
	ok(b0.find_child("lv_leaf", true, false) != null, "tier 0 badge has lv_leaf")
	ok(b0.find_child("lv_flower", true, false) == null, "tier 0 badge has NO lv_flower")
	var num0 := b0.find_child("lv_num", true, false) as Label
	ok(num0 != null and num0.text == "7", "badge prints the level number (7)")
	b0.free()
	var b29: Control = Kit.level_badge(opts, 29, 100, 200.0)    # tier 29 = leaf+acorn+gem
	ok(b29.find_child("lv_leaf", true, false) != null
		and b29.find_child("lv_acorn", true, false) != null
		and b29.find_child("lv_gem", true, false) != null, "tier 29 badge has leaf+acorn+gem")
	ok(b29.find_child("lv_flower", true, false) == null, "tier 29 badge has NO lv_flower")
	b29.free()

	# --- circle base: a coin behind every tier (default on, toggleable) ----------
	ok(o.get("circle_base") == true, "circle_base defaults on")
	var bc: Control = Kit.level_badge(opts, 6, 7, 200.0)        # tier 6 = leaf+flower; circle is NOT in the group
	ok(bc.find_child("lv_circle", true, false) != null, "circle_base on -> the coin draws behind any tier")
	ok(bc.get_child(0).name == "lv_circle", "the circle base is the backmost layer")
	bc.free()
	var opts_off: Dictionary = opts.duplicate()
	opts_off["circle_base"] = false
	var boff: Control = Kit.level_badge(opts_off, 6, 7, 200.0)
	ok(boff.find_child("lv_circle", true, false) == null, "circle_base off -> no coin (tier 6 omits the circle)")
	boff.free()

	# --- circle design: pick a fixed coin (1-6) or 'auto' (track the tier) -------
	ok(o.get("circle_design") == "auto" and o.get("num_burn") == 0.0,
		"circle_design defaults 'auto'; num_burn defaults 0")
	var auto_c: Control = Kit.level_badge(opts, 0, 1, 200.0)     # tier 0 stage 1 -> circle_1
	ok((auto_c.find_child("lv_circle", true, false) as TextureRect).texture.resource_path.get_file().begins_with("circle_1"),
		"circle_design 'auto' tracks the tier stage (circle_1 at tier 0)")
	auto_c.free()
	var fixed: Dictionary = opts.duplicate(); fixed["circle_design"] = "5"
	var fixed_c: Control = Kit.level_badge(fixed, 0, 1, 200.0)   # tier stage 1, but pinned to design 5
	ok((fixed_c.find_child("lv_circle", true, false) as TextureRect).texture.resource_path.get_file().begins_with("circle_5"),
		"circle_design '5' pins the coin to circle_5 regardless of tier")
	fixed_c.free()

	# --- num_burn: the engraved 'burn' outline on the level number --------------
	var nob: Control = Kit.level_badge(opts, 0, 7, 200.0)        # num_burn 0 -> no outline
	ok((nob.find_child("lv_num", true, false) as Label).get_theme_constant("outline_size") == 0,
		"num_burn 0 -> the number has no outline")
	nob.free()
	var burned: Dictionary = opts.duplicate(); burned["num_burn"] = 80.0
	var bd: Control = Kit.level_badge(burned, 0, 7, 200.0)
	ok((bd.find_child("lv_num", true, false) as Label).get_theme_constant("outline_size") > 0,
		"num_burn > 0 -> the number gets a burn outline")
	bd.free()

	# --- show_all (workbench aid): every part renders so they can be positioned --
	var all_c: Control = Kit.level_badge(opts, 0, 1, 200.0, -1, true)   # tier 0 is normally leaf-only
	ok(all_c.find_child("lv_leaf", true, false) != null and all_c.find_child("lv_flower", true, false) != null
		and all_c.find_child("lv_acorn", true, false) != null and all_c.find_child("lv_gem", true, false) != null
		and all_c.find_child("lv_circle", true, false) != null, "show_all renders every part for positioning")
	all_c.free()

	# --- the shared entry point (HUD chip / level dialog) delegates to the builder --
	var badge: Control = Look.make_level_badge(7, 200.0)
	var bnum := badge.find_child("lv_num", true, false) as Label
	ok(bnum != null and bnum.text == "7", "make_level_badge prints the level number")
	ok(badge.find_child("lv_leaf", true, false) != null, "make_level_badge composites the parts")
	badge.free()

	# --- HUD placement: the level badge occupies the configured left screen-width slot ---
	var align_host := Control.new()
	align_host.size = Vector2(1080, 1920)
	get_root().add_child(align_host)
	var hud := Hud.build(align_host, {})
	await process_frame
	await process_frame
	var lv_slot: Control = hud.get("lv_panel") as Control
	var layout := Kit.hud_layout_opts_from_config(Kit.load_config(Kit.CONFIG_PATH))
	var expected_badge_w := roundf(Design.size().x * float(layout.get("level_w_frac", 0.25)))
	var badge_rect := lv_slot.get_global_rect() if lv_slot != null else Rect2()
	ok(lv_slot != null
		and absf(badge_rect.position.x) <= 1.0
		and absf(badge_rect.size.x - expected_badge_w) <= 1.0,
		"HUD level badge uses %.0f%% screen width from the left edge (%.1f ~= %.1f)" % [
			float(layout.get("level_w_frac", 0.25)) * 100.0, badge_rect.size.x, expected_badge_w])
	align_host.free()

	# --- _safe_tex catches degenerate imports (exists() true but load() null) ----
	ok(Hud._safe_tex("") == null, "_safe_tex('') is null")
	ok(Hud._safe_tex("res://does/not/exist.png") == null, "_safe_tex(missing) is null")
	ok(Hud._safe_tex(Game.art("ui/lvl_parts/leaf_2.png")) != null, "a real part actually LOADS")

	# --- the level popup is idempotent: one overlay per host --------------------
	var host := Control.new()
	get_root().add_child(host)
	var ov1 := LevelPopup.open(host)
	var ov2 := LevelPopup.open(host)   # the duplicate emulated event, same frame
	ok(host.get_child_count() == 1, "double-fire opens ONE overlay, not two (got %d)" % host.get_child_count())
	ok(ov1 == ov2, "the second open returns the existing overlay")
	host.free()

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)

func _all_corners_transparent(tex: Texture2D) -> bool:
	if tex == null:
		return false
	var img := tex.get_image()
	if img == null or img.get_width() <= 0 or img.get_height() <= 0:
		return false
	var last := Vector2i(img.get_width() - 1, img.get_height() - 1)
	for p in [Vector2i(0, 0), Vector2i(last.x, 0), Vector2i(0, last.y), last]:
		if img.get_pixelv(p).a >= 0.2:
			return false
	return true
