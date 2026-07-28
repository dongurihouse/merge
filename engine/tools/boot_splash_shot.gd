extends SceneTree
## Dev tool (REAL renderer; run via engine/tools/quiet_godot.sh): render the cold-boot splash
## to a PNG for visual review. Builds boot.gd in capture mode (no prewarm/handoff), sets a
## representative mid-load bar, and captures the design-resolution frame.
##   engine/tools/quiet_godot.sh --path . -s res://engine/tools/boot_splash_shot.gd -- /tmp/out.png
##
## Positionals: <out.png> [WxH] [noload]. `WxH` (e.g. an App Store size) is parsed by shot_base
## wherever it sits; `noload` hides the bar/label for a clean key-art capture.

const Base = preload("res://engine/tools/shot_base.gd")
const BootScript = preload("res://engine/scripts/scenes/boot.gd")

func _initialize() -> void:
	# The splash reads no save state, so it takes no temp save dir (save: false). The window size
	# defaults to shot_base's SHOT_SIZE — the same Design.size() owner this tool used to re-read —
	# and any `WxH` positional overrides it.
	var ctx := await Base.begin(self, {"tool": "boot_splash", "save": false,
		"default_out": "/tmp/tu_boot_splash.png"})
	if ctx.is_empty():
		return                        # refused: begin() printed why and quit(2)
	var args: Array = ctx["args"]
	var out: String = ctx["out"]

	BootScript.capture = true
	var b: Control = BootScript.new()
	b.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(b)                 # capture mode → _ready paints the splash only
	await process_frame
	b.set_process(false)              # belt-and-suspenders: freeze the frame for a deterministic shot
	await process_frame

	# a representative mid-load frame (the live bar is exercised by the running game).
	# `noload` hides the bar/label for a clean key-art capture (e.g. a store screenshot).
	var noload := "noload" in args
	if b._bar != null:
		b._bar.value = 0.62
		b._bar.visible = not noload
	if b._label != null:
		b._label.text = "Loading…  62%"
		b._label.visible = not noload

	await create_timer(0.3).timeout
	RenderingServer.force_draw()      # warm-up draw: a hidden window's FIRST read can be stale
	await create_timer(0.1).timeout
	var err := Base.capture(self, out, args)
	print("BOOT SPLASH saved=%s err=%d size=%s" % [out, err, str(DisplayServer.window_get_size())])
	quit()
