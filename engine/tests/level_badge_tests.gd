extends SceneTree
## Headless guard for the evolving level-chip badge (the HUD level frame that upgrades
## with Level, sliced from assets/board/lvls.png into ui/lvl/ and mapped by
## data/level_badges.json).
##   godot --headless --path . -s res://engine/tests/level_badge_tests.gd
## Proves: the config parses, the even-tier Level->badge index is correct & clamped, and
## all 16 sliced frames resolve as grove art (so a level-up actually has a frame to swap).

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
		if not ResourceLoader.exists(Game.art("ui/lvl/badge_%02d.png" % i)):
			missing += 1
	ok(missing == 0, "all %d badge frames resolve (missing=%d)" % [count, missing])

	# --- path resolution: distinct tiers -> distinct, existing frames -----------
	var p1 := Look.level_badge_path(1)
	var p_crown := Look.level_badge_path(46)
	ok(p1.ends_with("badge_00.png") and ResourceLoader.exists(p1), "L1 resolves to badge_00 art")
	ok(p_crown.ends_with("badge_15.png") and ResourceLoader.exists(p_crown), "L46 resolves to badge_15 art")
	ok(p1 != p_crown, "the frame changes between low and high level")

	# --- _safe_tex catches degenerate imports (exists() true but load() null) ---------
	# A committed .import can make exists() true while load() returns null (art not yet
	# reimported in this checkout) — _safe_tex must catch that and return null.
	ok(Hud._safe_tex("") == null, "_safe_tex('') is null")
	ok(Hud._safe_tex("res://does/not/exist.png") == null, "_safe_tex(missing) is null")
	ok(Hud._safe_tex(Look.level_badge_path(2)) != null, "badge_00 actually LOADS (not just exists)")
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
