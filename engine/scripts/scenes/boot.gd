extends Control
## BOOT SPLASH: the app's cold-launch loading screen (the new main_scene). It paints the
## brand (logo on the cream chrome) + a progress bar immediately, kicks the heavy Map scene
## load onto a worker thread (SceneWarm), animates the bar from real load progress while the
## thread works, then hands off to the home map through the existing SceneFade+SceneWarm path.
##
## It also opens the boot trace (BootTrace.start): every cold-boot phase here AND inside
## map.gd's _ready is timed and printed as a table to the log — the "what's taking long"
## record we watch during development. The bar reflects the threaded LOAD live; the per-phase
## BUILD detail lands in that log table (the build runs synchronously, so the screen can't
## repaint mid-build — see docs/superpowers/specs/2026-06-20-boot-loading-screen-design.md).

const Game = preload("res://engine/scripts/core/game.gd")
const Design = preload("res://engine/scripts/core/design.gd")
const UiFont = preload("res://engine/scripts/ui/ui_font.gd")
const SceneWarm = preload("res://engine/scripts/core/scene_warm.gd")
const SceneFade = preload("res://engine/scripts/ui/scene_fade.gd")
const BootTrace = preload("res://engine/scripts/core/boot_trace.gd")
const Pal = Game.PALETTE

const MAP_PATH := "res://engine/scenes/Map.tscn"
const LOGO_PATH := "res://games/grove/assets/ui/boot/logo_tidyup.png"
const MIN_DURATION := 1.0     # min seconds the splash shows, so a fast load never just flashes

var _bar: ProgressBar
var _label: Label
var _elapsed := 0.0
var _done := false
var _load_ended := false

## Screenshot hook: the dev capture tool (engine/tools/boot_splash_shot.gd) sets this true so
## _ready only paints the splash — no window fit, no prewarm, no auto-handoff to the map.
static var capture := false

func _ready() -> void:
	if capture:
		_build_splash()
		return
	BootTrace.start()
	BootTrace.begin("boot.window")
	Design.fit_desktop_window()          # desktop: open at the design portrait aspect (same as map.gd)
	UiFont.apply()                        # install the UI theme/fonts once, early
	BootTrace.end("boot.window")
	BootTrace.begin("boot.ui")
	_build_splash()
	BootTrace.end("boot.ui")
	BootTrace.begin("boot.prewarm")
	SceneWarm.prewarm(MAP_PATH)           # load + compile the home map on a worker thread
	BootTrace.end("boot.prewarm")
	BootTrace.begin("scene.load")         # worker-thread load; closed in _process when it reports warm
	if get_tree() == null:                # headless harnesses run _ready out of tree — no splash loop
		return
	set_process(true)

## Build the splash tree. Public so the screenshot tool (boot_splash_shot.gd) can render a
## frozen splash without running the auto-handoff in _process.
func _build_splash() -> void:
	var vp := get_viewport_rect().size    # design space (1080 x 1920) under canvas_items stretch

	var bg := ColorRect.new()
	bg.color = Pal.SCREEN_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var logo := TextureRect.new()
	if ResourceLoader.exists(LOGO_PATH):
		logo.texture = load(LOGO_PATH)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var logo_w := vp.x * 0.62
	var logo_h := logo_w * 0.75           # 512x384 source ratio (KEEP_ASPECT_CENTERED letterboxes anyway)
	logo.size = Vector2(logo_w, logo_h)
	logo.position = Vector2((vp.x - logo_w) * 0.5, vp.y * 0.28)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(logo)

	var bar_w := vp.x * 0.56
	var bar_h := 24.0
	var bar_y := vp.y * 0.66
	_bar = ProgressBar.new()
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.step = 0.0
	_bar.value = 0.0
	_bar.show_percentage = false
	_bar.size = Vector2(bar_w, bar_h)
	_bar.position = Vector2((vp.x - bar_w) * 0.5, bar_y)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_theme_stylebox_override("background", _bar_box(Pal.PILL_EDGE, bar_h))   # track
	_bar.add_theme_stylebox_override("fill", _bar_box(Pal.STRAW, bar_h))             # fill
	add_child(_bar)

	_label = Label.new()
	_label.text = "Loading…"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_color", Pal.INK_MUTED)
	_label.size = Vector2(bar_w, 40)
	_label.position = Vector2((vp.x - bar_w) * 0.5, bar_y + bar_h + 18)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)

func _bar_box(col: Color, h: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(h * 0.5))
	return sb

func _process(delta: float) -> void:
	if _done:
		return
	_elapsed += delta
	var p := [0.0]
	var st := ResourceLoader.load_threaded_get_status(MAP_PATH, p)
	var warm := st == ResourceLoader.THREAD_LOAD_LOADED or SceneWarm.is_warm(MAP_PATH)
	var load_frac := 1.0 if warm else float(p[0])
	if warm and not _load_ended:
		BootTrace.end("scene.load")        # close the load span the moment the worker reports done
		_load_ended = true
	if _bar != null:
		_bar.value = boot_bar(_elapsed, MIN_DURATION, load_frac, warm)
	if _label != null:
		_label.text = "Ready" if warm else "Loading…  %d%%" % int(round(load_frac * 100.0))
	if boot_ready(_elapsed, MIN_DURATION, warm):
		_done = true
		set_process(false)
		SceneFade.to(self, get_tree(), MAP_PATH)   # cover -> warm packed swap -> map's own fade_in
		# map.gd closes the trace (BootTrace.done) after its build spans — the fade between is
		# deliberate, so no span covers it.

# --- pure progress math (unit-tested in engine/tests/boot_trace_tests.gd) ----------------

## The bar position: real load progress, paced by a minimum duration, held honestly at ≤0.9
## until the scene is actually warm (so a slow load is visible, never faked to 100%).
static func boot_bar(elapsed: float, min_dur: float, load_frac: float, warm: bool) -> float:
	var time_ease := clampf(elapsed / min_dur, 0.0, 1.0) if min_dur > 0.0 else 1.0
	var load_cap := 1.0 if warm else minf(0.9, 0.1 + 0.8 * clampf(load_frac, 0.0, 1.0))
	return minf(time_ease, load_cap)

## Hand off to the map only once the scene is warm AND the minimum splash time has elapsed.
static func boot_ready(elapsed: float, min_dur: float, warm: bool) -> bool:
	return warm and elapsed >= min_dur
