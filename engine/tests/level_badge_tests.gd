extends SceneTree
## Headless guard for the evolving level-chip badge (the HUD level frame that upgrades
## with Level, sliced from assets/_originals/ui/lvls2.png into ui/lvl/ and mapped by
## data/level_badges.json).
##   godot --headless --path . -s res://engine/tests/level_badge_tests.gd
## Proves: the config parses, the BANDED Level->badge index is correct, monotonic & clamped,
## and all 36 sliced frames resolve as grove art (so a level-up actually has a frame to swap).

const Look = preload("res://engine/scripts/ui/skin.gd")
const Hud = preload("res://engine/scripts/ui/hud.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const LevelPopup = preload("res://engine/scripts/ui/level_popup.gd")

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
	OS.set_environment("GAME", "grove")   # the badges live in grove's clothes (Game.art root)
	print("== Level badge guard ==")

	# --- config -----------------------------------------------------------------
	var f := FileAccess.open("res://data/level_badges.json", FileAccess.READ)
	ok(f != null, "data/level_badges.json present")
	var cfg = JSON.parse_string(f.get_as_text()) if f != null else null
	ok(cfg is Dictionary, "config parses to a Dictionary")
	var d: Dictionary = cfg if cfg is Dictionary else {}
	var count := int(d.get("badge_count", 0))
	ok(count == 36, "badge_count == 36 (got %d)" % count)
	var bands: Array = d.get("bands", [])
	ok(bands.size() == 3, "3 bands (got %d)" % bands.size())
	var tier_sum := 0
	for b in bands:
		tier_sum += int((b as Dictionary).get("tiers", 0))
	ok(tier_sum == count, "band tiers sum to badge_count (%d == %d)" % [tier_sum, count])

	# --- banded index: 12 badges/level (L1-12), then every 3 (L13-48), then every 6 (L49-120) ---
	ok(Look.level_badge_index(1) == 0,   "L1 -> badge 0")
	ok(Look.level_badge_index(12) == 11, "L12 -> badge 11 (one per level)")
	ok(Look.level_badge_index(13) == 12, "L13 -> badge 12 (band 2 begins)")
	ok(Look.level_badge_index(15) == 12, "L15 -> badge 12 (tier of 3)")
	ok(Look.level_badge_index(16) == 13, "L16 -> badge 13 (tier flips)")
	ok(Look.level_badge_index(48) == 23, "L48 -> badge 23 (band 2 ends)")
	ok(Look.level_badge_index(49) == 24, "L49 -> badge 24 (band 3 begins)")
	ok(Look.level_badge_index(54) == 24, "L54 -> badge 24 (tier of 6)")
	ok(Look.level_badge_index(55) == 25, "L55 -> badge 25 (tier flips)")
	ok(Look.level_badge_index(120) == 35, "L120 -> badge 35 (grand crown)")
	ok(Look.level_badge_index(121) == count - 1, "past the last band holds at the crown")
	ok(Look.level_badge_index(1000) == count - 1, "huge level clamps to crown")
	ok(Look.level_badge_index(0) == 0, "L0 clamps to badge 0")
	ok(Look.level_badge_index(-5) == 0, "negative level clamps to badge 0")

	# index is monotonic non-decreasing, clamped, and reaches EVERY badge across the design range
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
	ok(mono_ok, "index is monotonic non-decreasing and in [0, count) for L in 1..199")
	ok(seen.size() == count, "every one of the %d badges is reachable (got %d)" % [count, seen.size()])

	# --- all 36 frames exist as resolvable art ----------------------------------
	var missing := 0
	for i in count:
		if not ResourceLoader.exists(Game.art("ui/lvl/badge_%02d.png" % i)):
			missing += 1
	ok(missing == 0, "all %d badge frames resolve (missing=%d)" % [count, missing])

	# --- path resolution: distinct tiers -> distinct, existing frames -----------
	var p1 := Look.level_badge_path(1)
	var p_crown := Look.level_badge_path(120)
	ok(p1.ends_with("badge_00.png") and ResourceLoader.exists(p1), "L1 resolves to badge_00 art")
	ok(p_crown.ends_with("badge_35.png") and ResourceLoader.exists(p_crown), "L120 resolves to badge_35 art")
	ok(p1 != p_crown, "the frame changes between low and high level")

	# --- _safe_tex catches degenerate imports (exists() true but load() null) ---------
	# A committed .import can make exists() true while load() returns null (art not yet
	# reimported in this checkout) — _safe_tex must catch that and return null.
	ok(Hud._safe_tex("") == null, "_safe_tex('') is null")
	ok(Hud._safe_tex("res://does/not/exist.png") == null, "_safe_tex(missing) is null")
	ok(Hud._safe_tex(Look.level_badge_path(2)) != null, "a real badge actually LOADS (not just exists)")
	ok(Hud._frame_tex(2) != null, "L2 frame texture loads (the evolving badge)")

	# --- no ring fallback: every shipped badge MUST be alpha-cut --------------------------
	# The HUD draws the badge directly now, so an opaque (checker/white-backed) slice would
	# render a square backing in the compact chip. Enforce transparent corners at build time.
	var opaque := 0
	for i in count:
		var tex := Hud._safe_tex(Game.art("ui/lvl/badge_%02d.png" % i))
		if tex == null or not _has_transparent_corner(tex):
			opaque += 1
	ok(opaque == 0, "all %d badges are alpha-cut (transparent corners, no square backing)" % count)

	# --- the level popup is idempotent: one overlay per host -------------------------
	# emulate_touch_from_mouse (project.godot) makes a single tap deliver BOTH a mouse and a
	# touch event, so the HUD badge's gui_input fires on_level TWICE in one frame. Two stacked,
	# identical overlays look like the dialog "won't close" — you must dismiss it twice. open()
	# must guard against that and keep exactly one overlay alive per host.
	var host := Control.new()
	get_root().add_child(host)
	var ov1 := LevelPopup.open(host)
	var ov2 := LevelPopup.open(host)   # the duplicate emulated event, same frame
	ok(host.get_child_count() == 1, "double-fire opens ONE overlay, not two (got %d)" % host.get_child_count())
	ok(ov1 == ov2, "the second open returns the existing overlay")
	host.free()

	# Badges absent -> the frame is null and the HUD shows the honey-token coin; no ring.
	Look._badge_cfg = {"badge_count": 16, "levels_per_tier": 3, "dir": "no_such_dir", "prefix": "x_"}
	ok(Look.level_badge_path(2) == "", "missing badge art -> empty path")
	ok(Hud._frame_tex(2) == null, "badges absent -> frame is null (honey-token coin, no ring fallback)")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)

func _has_transparent_corner(tex: Texture2D) -> bool:
	if tex == null:
		return false
	var img := tex.get_image()
	if img == null or img.get_width() <= 0 or img.get_height() <= 0:
		return false
	var last := Vector2i(img.get_width() - 1, img.get_height() - 1)
	for p in [Vector2i(0, 0), Vector2i(last.x, 0), Vector2i(0, last.y), last]:
		if img.get_pixelv(p).a < 0.2:
			return true
	return false
