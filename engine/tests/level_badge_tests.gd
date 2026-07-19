extends SceneTree
## Headless guard for the Meadow level badge — one of 25 complete 256x256 variants plus a native
## level-number label. The existing Level->tier map remains banded in data/level_badges.json; tiers
## above the authored Meadow range hold on variant 25.
##   godot --headless --path . -s res://engine/tests/level_badge_tests.gd
## Proves: config parses, banded Level->tier is correct/monotonic/clamped, all 25 complete variants
## resolve at the authored size, stale part knobs cannot override them, and the shared entry point
## preserves the native level-number label.

const Look = preload("res://engine/scripts/ui/skin.gd")
const Hud = preload("res://engine/scripts/ui/hud.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Design = preload("res://engine/scripts/core/design.gd")
const LevelPopup = preload("res://engine/scripts/ui/level_popup.gd")
const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")

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
	OS.set_environment("GAME", "grove")
	print("== Meadow level badge guard ==")

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

	# --- all 25 complete variants exist at the authored 256x256 size -------------
	var missing := 0
	var wrong_size := 0
	for variant in range(1, 26):
		var path := Game.art("ui/meadow_v2/level_badge_%02d.png" % variant)
		var tex := Hud._safe_tex(path)
		if tex == null:
			missing += 1
		elif tex.get_size() != Vector2(256, 256):
			wrong_size += 1
	ok(missing == 0, "all 25 Meadow badge variants resolve (missing=%d)" % missing)
	ok(wrong_size == 0, "all 25 Meadow badge variants remain 256x256 (wrong=%d)" % wrong_size)

	# --- config resolver retains only native number controls --------------------
	var o: Dictionary = Kit.level_badge_opts_from_config({})
	ok(o.has("num_size") and o.has("num_x") and o.has("num_y") and o.has("num_burn")
		and not o.has("circle_base") and not o.has("leaf_x"),
		"level badge config exposes native number controls and retires layered-part knobs")
	var stale := Kit.level_badge_opts_from_config({"level_badge": {"circle_design": "5", "leaf_x": 999}})
	ok(not stale.has("circle_design") and not stale.has("leaf_x"),
		"stale layered-part settings cannot override a complete Meadow variant")

	# --- builder selects a clamped complete variant + native number -------------
	var opts: Dictionary = Kit.level_badge_opts_from_config({})
	var b0: Control = Kit.level_badge(opts, 0, 7, 200.0)
	var base0 := b0.find_child("lv_badge_art", true, false) as TextureRect
	var num0 := b0.find_child("lv_num", true, false) as Label
	ok(base0 != null and String(base0.texture.resource_path).ends_with("ui/meadow_v2/level_badge_01.png"),
		"tier 0 selects complete Meadow variant 01")
	ok(num0 != null and num0.text == "7", "badge preserves the native level number (7)")
	b0.free()
	var b29: Control = Kit.level_badge(opts, 29, 100, 200.0)
	var base29 := b29.find_child("lv_badge_art", true, false) as TextureRect
	ok(base29 != null and String(base29.texture.resource_path).ends_with("ui/meadow_v2/level_badge_25.png"),
		"tier 29 clamps to the final authored Meadow variant 25")
	b29.free()

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

	# --- the shared entry point (HUD chip / level dialog) delegates to the builder --
	var badge: Control = Look.make_level_badge(7, 200.0)
	var bnum := badge.find_child("lv_num", true, false) as Label
	ok(bnum != null and bnum.text == "7", "make_level_badge prints the level number")
	ok(badge.find_child("lv_badge_art", true, false) != null, "make_level_badge uses one complete Meadow base")
	badge.free()

	# --- HUD placement: the level badge occupies the configured left screen-width slot ---
	var align_host := Control.new()
	align_host.size = Vector2(1080, 1920)
	get_root().add_child(align_host)
	var hud := Hud.build(align_host, {})
	await process_frame
	await process_frame
	var lv_slot: Control = hud.get("lv_panel") as Control
	# the badge slot matches the currency pill HEIGHT — one top-band scale across the HUD
	var pill_opts := Kit.gold_currency_pill_opts_from_config(Kit.load_config(Kit.CONFIG_PATH))
	var expected_badge_w := roundf(float(pill_opts.get("pill_h", 100.0)))
	var badge_rect := lv_slot.get_global_rect() if lv_slot != null else Rect2()
	ok(lv_slot != null
		and absf(badge_rect.size.x - expected_badge_w) <= 1.0,
		"HUD level badge slot matches the currency pill height (%.1f ~= %.1f)" % [
			badge_rect.size.x, expected_badge_w])
	# the badge's PAINTED left edge honors the same edge margin the wallet uses on the right
	var layout_opts := Kit.hud_layout_opts_from_config(Kit.load_config(Kit.CONFIG_PATH))
	var expected_left := float(layout_opts.get("edge_margin_px", 18.0))
	var painted_left := badge_rect.position.x + Hud._painted_left_offset(lv_slot)
	ok(lv_slot != null and absf(painted_left - expected_left) <= 1.0,
		"HUD level badge painted left honors the edge margin (%.1f ~= %.1f)" % [
			painted_left, expected_left])
	ok(lv_slot != null and lv_slot.visible, "the level badge shows by default (the Map keeps it)")
	align_host.free()

	# --- hide_level opt: a scene (the board) can build the HUD without the level badge ---
	var hidden_host := Control.new()
	hidden_host.size = Vector2(1080, 1920)
	get_root().add_child(hidden_host)
	var hidden_hud := Hud.build(hidden_host, {"hide_level": true})
	await process_frame
	var hidden_slot: Control = hidden_hud.get("lv_panel") as Control
	ok(hidden_slot != null and not hidden_slot.visible, "hide_level hides the HUD level badge")
	hidden_host.free()

	# --- _safe_tex catches degenerate imports (exists() true but load() null) ----
	ok(Hud._safe_tex("") == null, "_safe_tex('') is null")
	ok(Hud._safe_tex("res://does/not/exist.png") == null, "_safe_tex(missing) is null")
	ok(Hud._safe_tex(Game.art("ui/meadow_v2/level_badge_02.png")) != null, "a real Meadow badge actually LOADS")

	# --- the level popup is idempotent: one overlay per host --------------------
	var host := Control.new()
	get_root().add_child(host)
	var ov1 := LevelPopup.open(host)
	var ov2 := LevelPopup.open(host)   # the duplicate emulated event, same frame
	ok(host.get_child_count() == 1, "double-fire opens ONE overlay, not two (got %d)" % host.get_child_count())
	ok(ov1 == ov2, "the second open returns the existing overlay")
	ok(ov1.z_index >= 100, "level popup overlay stays above map badges")
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
