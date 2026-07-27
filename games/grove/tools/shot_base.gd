extends RefCounted
## The SHARED prologue + epilogue for every real-renderer screenshot tool.
##
## Every `*_shot.gd` used to carry a byte-identical ~28-line header (refusal guard, window flags,
## arg parse, WxH resize, temp-save wipe) and a copy of the capture tail. That copy-paste is what
## let four tools drift without the refusal guard, and what let the window-size race go unnoticed.
## A tool now keeps ONLY its own fixture body:
##
##   const Base = preload("res://games/grove/tools/shot_base.gd")
##   func _initialize() -> void:
##       var ctx := await Base.begin(self, {"tool": "grove", "default_mode": "hud",
##                                          "default_out": "/tmp/grove_%s.png",
##                                          "save_dir": "/tmp/tu_groveshot_%s/"})
##       if ctx.is_empty():
##           return                      # refused — begin() already printed + quit(2)
##       ... build the fixture ...
##       Base.capture(self, ctx.out, ctx.args)
##       quit()
##
## WHY THE REFUSAL GUARD MATTERS: the born-minimized/no-focus window flags must be applied AT
## WINDOW CREATION, which only engine/tools/quiet_godot.sh's temporary override.cfg can do.
## Setting them from _initialize() is TOO LATE — the window has already flashed and stolen the
## owner's focus mid-session. So a tool with no override.cfg REFUSES to run. Living here, that
## guard is structural instead of copy-pasted.
##
## WHY AN UNKNOWN MODE REFUSES TOO: a `match mode:` that finds no branch falls through in silence,
## so a misspelled or RETIRED mode used to save a plausible-looking PNG of the default fixture and
## exit 0. A capture tool is the project's visual-verification instrument — a shot that quietly
## ignores what was asked is worse than a crash, because it gets believed. A tool that declares
## `modes` refuses instead. Opt-in: tools that don't declare it behave exactly as before.
##
## DETERMINISM. `begin` makes a capture reproducible instead of merely likely-similar:
##  * WINDOW SIZE — the window is born at either the project size or a screen-clamped one (macOS
##    clamps a 1080x1920 window to the usable height of a 1440-tall display → 1378), a RACE at
##    window creation that flipped the saved PNG's height between runs. begin() forces the size
##    and waits until it sticks.
##  * WEATHER — Weather Hours rolls clear/breeze/rain/snow/star off the wall-clock HOUR, and particle-heavy states are
##    animated particle systems. Captures pin it to "clear" unless the caller passes `weather=<x>`
##    (or `weather=auto` for the live hourly roll).
##  * GLOBAL RNG — begin() calls seed(RNG_SEED). Scene code reaches for the bare @GlobalScope randi()
##    in places (board.gd picks its cut-paper BACKDROP from four scenes that way — day meadow vs
##    sunset clouds, which repaints every sky pixel), and none of that answers to a scene-local RNG.
##  * BOARD RNG — see board.gd's `forced_rng_seed`; a tool that stands up Board.tscn sets it BEFORE
##    add_child, because _load_state randomizes its own RNG on a fresh save.
##
## Every tool keeps its OWN temp save dir (/tmp/tu_<name>shot/) so parallel work on different
## tools never shares a save. (Quiet runs themselves are serial by law — they own override.cfg.)

const Save = preload("res://engine/scripts/core/save.gd")
const Ambient = preload("res://engine/scripts/ui/ambient.gd")
const Design = preload("res://engine/scripts/core/design.gd")

## The project's viewport size — the canonical capture resolution, read from THE design owner
## (Design → project.godot display/window/size), so a canvas change moves every capture with it.
static var SHOT_SIZE := Vector2i(Design.size())

## How many force-and-check rounds `_apply_size` will spend making the window take our size.
const SIZE_TRIES := 6
const SIZE_SETTLE := 0.2      # seconds between a set_size and the re-read

## The fixed global-RNG seed every capture runs under (cfg `seed` overrides). Board tools pass the
## same value to board.gd's forced_rng_seed so both streams are pinned to one number.
const RNG_SEED := 7

## Guard + flags + arg parse + window size + temp save dir. AWAIT it.
##
## cfg keys (all optional except `tool`):
##   tool          String  — names the default temp save dir (/tmp/tu_<tool>shot/)
##   default_mode  String  — present ⇒ args[0] is the MODE and args[1] the output; absent ⇒ args[0]
##                           is the output (widget/inbox-style tools)
##   modes         Array   — every valid mode name; declaring it makes an unknown MODE REFUSE the
##                           run instead of silently capturing the default fixture (see the header)
##   retired       Dict    — mode name → a one-line hint naming its replacement, printed verbatim
##                           when the rejected mode is one we used to have
##   default_out   String  — fallback output path; a "%s" is filled with the mode
##   out_arg       int     — index of the positional carrying the output path [default 1 with a
##                           mode, else 0]; a tool with extra positionals passes its own
##   out_kind      String  — "file" (default) or "dir" (normalised to a trailing "/" + created)
##   save_dir      String  — temp save dir template; a "%s" is filled with the mode
##   save          bool    — false skips the temp save entirely (pure-widget tools) [default true]
##   size          Vector2i— window size to force [default SHOT_SIZE]; any `WxH` user arg overrides
##   weather       String  — the pinned weather when no `weather=` arg is passed [default "clear"]
##
## Returns {} when the run is REFUSED (the caller must just `return`; quit(2) is already issued),
## else {args: Array, mode: String, out: String, dir: String}.
static func begin(tree: SceneTree, cfg: Dictionary) -> Dictionary:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: real-renderer tools must run via engine/tools/quiet_godot.sh (born-minimized")
		print("window; in-script flags are too late and flash/steal focus). See ~/.claude/CLAUDE.md")
		tree.quit(2)
		return {}
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	seed(int(cfg.get("seed", RNG_SEED)))   # pin the GLOBAL stream before any scene code can draw from it

	var args := OS.get_cmdline_user_args()
	var tool_name := String(cfg.get("tool", "shot"))
	var has_mode: bool = cfg.has("default_mode")
	var mode := ""
	if has_mode:
		mode = String(args[0]) if args.size() >= 1 and String(args[0]) != "" else String(cfg["default_mode"])
	if cfg.has("modes") and not (mode in cfg["modes"]):
		var retired: Dictionary = cfg.get("retired", {})
		print("REFUSED: %s_shot has no MODE '%s' — it would have fallen through and saved the" % [tool_name, mode])
		print("DEFAULT fixture, so the PNG would look fine and show the wrong thing.")
		if retired.has(mode):
			print("  RETIRED: %s" % String(retired[mode]))
		print("  valid modes: %s" % ", ".join(PackedStringArray(cfg["modes"])))
		tree.quit(2)
		return {}
	# which positional carries the output path (a tool with extra positionals passes its own index)
	var out_at := int(cfg.get("out_arg", 1 if has_mode else 0))
	var default_out := String(cfg.get("default_out", "/tmp/%s.png" % tool_name))
	var out: String = String(args[out_at]) if args.size() > out_at else _fill(default_out, mode)
	if String(cfg.get("out_kind", "file")) == "dir":
		out = out.trim_suffix("/") + "/"
		DirAccess.make_dir_recursive_absolute(out)

	await _apply_size(tree, _size_from(args, cfg.get("size", SHOT_SIZE)))
	_apply_weather(args, String(cfg.get("weather", "clear")))

	var dir := ""
	if bool(cfg.get("save", true)):
		dir = _fill(String(cfg.get("save_dir", "/tmp/tu_%sshot/" % tool_name)), mode)
		wipe_dir(dir)
		Save.configure_for_test(dir)
	return {"args": args, "mode": mode, "out": out, "dir": dir}

## force_draw → read the framebuffer → optional region → optional `crop=` zoom → save_png.
## Returns the save_png error code (OK == 0). `region` (in framebuffer pixels) frames the shot to
## its content; it is clamped to the image, so a short window yields a short crop, never a crash.
static func capture(tree: SceneTree, out: String, args: Array = [], region := Rect2i()) -> int:
	var img := frame(tree)
	if img == null:
		return FAILED
	if region.size.x > 0 and region.size.y > 0:
		img = img.get_region(region.intersection(Rect2i(Vector2i.ZERO, img.get_size())))
	img = crop(img, args)
	return img.save_png(out)

## One fresh framebuffer read. A MINIMIZED window occasionally serves a STALE frame (the capture
## then shows the PREVIOUS screen), so every read forces a draw first. null under --headless.
static func frame(tree: SceneTree) -> Image:
	RenderingServer.force_draw()
	var img := tree.root.get_texture().get_image()
	if img == null:
		push_error("shot_base: no image — real-renderer run required (get_image() is null under --headless)")
	return img

## `crop=x,y,w,h` saves a ZOOMED (3x, nearest) cutout of one element, so the exact pixels of a
## small widget can be LOOKED at before calling a change done.
static func crop(img: Image, args: Array) -> Image:
	for a in args:
		if String(a).begins_with("crop="):
			var r := String(a).substr(5).split(",")
			var cut := img.get_region(Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])))
			cut.resize(int(r[2]) * 3, int(r[3]) * 3, Image.INTERPOLATE_NEAREST)
			return cut
	return img

## Empty (or create) a temp directory — a stale save from a previous run must never leak into a capture.
static func wipe_dir(dir: String) -> void:
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)

## The value of a `key=value` user arg, or `def` when absent.
static func opt(args: Array, key: String, def: String = "") -> String:
	for a in args:
		if String(a).begins_with(key + "="):
			return String(a).substr(key.length() + 1)
	return def

## True when a bare flag arg (`midfall=1`, `noftue=1`) is set.
static func flag(args: Array, key: String) -> bool:
	return opt(args, key, "0") == "1"

# --- internals ---------------------------------------------------------------------

static func _fill(template: String, mode: String) -> String:
	return (template % mode) if "%s" in template else template

# A `WxH` user arg (e.g. `393x852`) overrides the configured capture size.
static func _size_from(args: Array, base) -> Vector2i:
	var want: Vector2i = base
	var re := RegEx.create_from_string("^([0-9]+)x([0-9]+)$")
	for a in args:
		var m := re.search(String(a))
		if m != null:
			want = Vector2i(int(m.get_string(1)), int(m.get_string(2)))
	return want

# The window is born at either the project size or a screen-clamped one (a macOS race — see the
# header). Force ours and wait until BOTH the window and the root viewport report it, so the saved
# PNG's dimensions are a property of the tool, not of how the window manager felt that second.
static func _apply_size(tree: SceneTree, size: Vector2i) -> void:
	for _try in SIZE_TRIES:
		DisplayServer.window_set_size(size)
		await tree.create_timer(SIZE_SETTLE).timeout
		if DisplayServer.window_get_size() == size and tree.root.size == size:
			return
	push_warning("shot_base: window stuck at %s, wanted %s — the capture will be off-size" % \
		[str(DisplayServer.window_get_size()), str(size)])

# Weather is an hourly wall-clock roll and some states are animated particles, so a capture pins it.
# `weather=<state>` picks one explicitly; `weather=auto` restores the live roll.
static func _apply_weather(args: Array, pinned: String) -> void:
	var want := opt(args, "weather", pinned)
	Ambient.forced_weather = "" if want == "auto" else want
