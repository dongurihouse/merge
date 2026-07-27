extends SceneTree
## Dev tool (run via engine/tools/quiet_godot.sh): screenshot the REAL "Update Available" prompt
## (ui/update_prompt.gd::open) over the dimmed home — the App Store version-upgrade dialog. It renders
## the SHIPPED view (shared dialog_frame: parchment card · title · ✕, message, cream "Not now" + green
## "Update"), so the capture is the actual UI, not a rebuilt mock. Detection (core/update_check.gd) is
## iOS-only and not exercised here — open() is called directly with a sample version + url.
##   quiet_godot.sh --path . -s res://games/grove/tools/update_dialog_shot.gd -- <out_dir>
## Mirrors residents_dialog_shot.gd's quiet-capture header + light home seed.

const Base = preload("res://engine/tools/shot_base.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const G = preload("res://engine/scripts/core/content.gd")
const MapScene = preload("res://engine/scripts/scenes/map.gd")

func _initialize() -> void:
	var ctx := await Base.begin(self, {
		"tool": "update_dialog",
		"default_out": "/tmp/tu_update_dialog_out",
		"out_kind": "dir",
		"save_dir": "/tmp/tu_update_dialog_shot/",
	})
	if ctx.is_empty():
		return                        # refused: begin() printed why and quit(2)
	var args: Array = ctx["args"]
	var out_dir: String = ctx["out"]

	# a believable home behind the dimmed veil: the first scene fully unlocked.
	var g := Save.grove()
	g["exp"] = 60
	var unl: Dictionary = g.get("unlocks", {})
	for c in G.clusters(0):
		unl[String((c as Dictionary).id)] = true
	g["unlocks"] = unl
	Save.grove_write()
	Save.add_coins(300)

	MapScene._login_shown_launch = true
	var scn = load("res://engine/scenes/Map.tscn").instantiate()
	root.add_child(scn)
	current_scene = scn
	await create_timer(0.8).timeout

	Base.capture(self, out_dir + "home.png", args)

	# open the REAL shipped prompt with a sample newer version + store url.
	var UpdatePrompt = load("res://engine/scripts/ui/update_prompt.gd")
	UpdatePrompt.open(scn, "1.2.0", "https://apps.apple.com/app/id0000000000")
	await create_timer(0.6).timeout

	var e1 := Base.capture(self, out_dir + "update_dialog.png", args)

	print("SHOT update_dialog=%d -> %s" % [e1, out_dir])
	quit()
