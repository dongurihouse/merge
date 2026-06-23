extends SceneTree
## UI Workbench — headless / standalone runner.
## Loads UiWorkbench.tscn (the @tool preview scene) so ONE scene serves three uses:
##   editor live-edit:   make editor → open games/grove/tools/UiWorkbench.tscn, then drag the
##                        Inspector "Size" knobs and watch the real button update live.
##   standalone window:  make workbench
##   quiet screenshot:   make shot-workbench [OUT=/tmp/ui_workbench.png] [EL=<id>]   (born-minimized; no
##                        focus steal). EL=<id> captures JUST that one component centred (e.g. EL=mystery
##                        for the spin-reveal dialog) — a clean, repeatable single-component shot.

const UiFont = preload("res://engine/scripts/ui/ui_font.gd")
const SCENE := "res://games/grove/tools/UiWorkbench.tscn"

func _initialize() -> void:
	var quiet := FileAccess.file_exists("res://override.cfg")   # set by quiet_godot.sh
	# A WIDE desktop window so every dialog row fits without horizontal scrolling. The game's stretch
	# (canvas_items, base 1080×1920 portrait) would shrink everything to fit the window, so DISABLE
	# content scaling for the tool — it renders 1:1 and the extra window width becomes real room.
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	# Fill the screen: a WIDE window so dialog rows pair without horizontal scroll, and a TALL window so
	# the tallest dialog (the full shop) is reachable + visible without the bottom flushing against the
	# window edge. Grow the height to most of the screen (leaving room for the menu bar + dock) instead of
	# a fixed 1040 that wasted vertical space. In the quiet/screenshot path screen_get_size() is (0,0), so
	# we keep the deterministic 1760×1040 capture size.
	var screen := DisplayServer.screen_get_size()
	var win := Vector2i(1980, 1040)         # wide enough for BOTH columns (building blocks + the dialogs) side by side
	if screen.x > 0 and screen.y > 0:
		win.x = mini(1980, screen.x - 80)
		win.y = clampi(screen.y - 130, 760, 1400)
	DisplayServer.window_set_size(win)
	DisplayServer.window_set_position((screen - win) / 2)
	if quiet:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	UiFont.apply()   # the real global font + cozy styling, so text reads as it will in-game

	# args: ua[0] = OUT path (quiet path), ua[1] = optional focus element id (EL=) → render just that one.
	var ua := OS.get_cmdline_user_args()
	var focus: String = String(ua[1]) if ua.size() >= 2 else ""

	var view: Control = load(SCENE).instantiate()
	if focus != "":
		view.set("_focus_only", focus)                 # honoured in _build() — bypasses the gallery
	root.add_child(view)
	await process_frame
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)   # fill the window now that the parent size is known
	await process_frame

	if quiet:
		await create_timer(0.4).timeout                 # let layout + the nine-patch import settle
		RenderingServer.force_draw()                    # minimized windows can serve a stale frame
		var out: String = String(ua[0]) if ua.size() >= 1 else "/tmp/ui_workbench.png"
		var err := root.get_texture().get_image().save_png(out)
		print("SHOT saved=%s err=%d" % [out, err])
		quit()
	# interactive: leave the window up for you to see + press
