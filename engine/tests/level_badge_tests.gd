extends SceneTree
## Headless guard for the evolving level-chip badge (the HUD level frame that upgrades
## with Level, sliced from assets/board/lvls.png into kit/badges/ and mapped by
## data/level_badges.json).
##   godot --headless --path . -s res://engine/tests/level_badge_tests.gd
## Proves: the config parses, the even-tier Level->badge index is correct & clamped, and
## all 16 sliced frames resolve as grove art (so a level-up actually has a frame to swap).

const Look = preload("res://engine/scripts/ui/skin.gd")
const Hud = preload("res://engine/scripts/ui/hud.gd")

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
	var per := maxi(1, int(d.get("levels_per_tier", 1)))
	ok(count == 16, "badge_count == 16 (got %d)" % count)
	ok(int(d.get("levels_per_tier", 0)) == 3, "levels_per_tier == 3 (crown at L46)")

	# --- even-tier index: idx = clamp(floor((level-1)/per), 0, count-1) ----------
	ok(Look.level_badge_index(1) == 0, "L1 -> badge 0")
	ok(Look.level_badge_index(3) == 0, "L3 -> badge 0 (tier of 3)")
	ok(Look.level_badge_index(4) == 1, "L4 -> badge 1 (tier flips)")
	ok(Look.level_badge_index(45) == 14, "L45 -> badge 14")
	ok(Look.level_badge_index(46) == 15, "L46 -> badge 15 (crown)")
	ok(Look.level_badge_index(1000) == count - 1, "huge level clamps to crown")
	ok(Look.level_badge_index(0) == 0, "L0 clamps to badge 0")
	ok(Look.level_badge_index(-5) == 0, "negative level clamps to badge 0")

	# formula holds across the whole designed-and-then-some range (also proves monotonic)
	var formula_ok := true
	for lvl in range(1, 200):
		var want := clampi(int(floor((maxf(1.0, float(lvl)) - 1.0) / float(per))), 0, count - 1)
		if Look.level_badge_index(lvl) != want:
			formula_ok = false
			break
	ok(formula_ok, "index matches floor((L-1)/per) clamped for L in 1..199")

	# --- all 16 frames exist as resolvable art ----------------------------------
	var missing := 0
	for i in count:
		if not ResourceLoader.exists(Look.kit("badges/badge_%02d.png" % i)):
			missing += 1
	ok(missing == 0, "all %d badge frames resolve (missing=%d)" % [count, missing])

	# --- path resolution: distinct tiers -> distinct, existing frames -----------
	var p1 := Look.level_badge_path(1)
	var p_crown := Look.level_badge_path(46)
	ok(p1.ends_with("badge_00.png") and ResourceLoader.exists(p1), "L1 resolves to badge_00 art")
	ok(p_crown.ends_with("badge_15.png") and ResourceLoader.exists(p_crown), "L46 resolves to badge_15 art")
	ok(p1 != p_crown, "the frame changes between low and high level")

	# --- the chip never renders a BLANK frame (regression: trusting exists() over load()) ---
	# A committed .import can make exists() true while load() returns null (art not yet
	# reimported in this checkout) — the frame must fall back to a VISIBLE ring, never null.
	ok(Hud._safe_tex("") == null, "_safe_tex('') is null")
	ok(Hud._safe_tex("res://does/not/exist.png") == null, "_safe_tex(missing) is null")
	ok(Hud._safe_tex(Look.level_badge_path(2)) != null, "badge_00 actually LOADS (not just exists)")
	ok(Hud._frame_tex(2) != null, "L2 frame texture is non-null (a ring is shown)")
	ok(_has_transparent_corner(Hud._frame_tex(2)), "HUD level frame has transparent corners (no square backing)")
	# simulate the user's case: badges unavailable -> still a visible ring (rope-ring fallback)
	Look._badge_cfg = {"badge_count": 16, "levels_per_tier": 3, "dir": "no_such_dir", "prefix": "x_"}
	ok(Look.level_badge_path(2) == "", "missing badge art -> empty path")
	ok(Hud._frame_tex(2) != null, "badges absent -> frame falls back to a visible ring (NOT blank)")

	print("== level_badge: %d passed, %d failed ==" % [_pass, _fail])
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
