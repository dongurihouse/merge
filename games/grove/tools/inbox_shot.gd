extends SceneTree
## Dev tool (run via engine/tools/quiet_godot.sh): screenshot the Mailbox modal over the Map.
##   quiet_godot.sh --path . -s res://games/grove/tools/inbox_shot.gd -- <out.png>
## Seeds a couple of inbox messages (incl. an unclaimed gift), opens InboxUI over the home
## map, waits a beat, and saves a PNG. Mirrors map_shot.gd's quiet-capture header (REFUSES
## unless override.cfg exists — the born-minimized window must come from quiet_godot.sh, not
## in-script flags, which are too late and flash/steal focus). Parallel-safe (own temp save).

const Save = preload("res://engine/scripts/core/save.gd")
const Inbox = preload("res://engine/scripts/core/inbox.gd")
const InboxUI = preload("res://engine/scripts/ui/inbox.gd")
const G = preload("res://engine/scripts/core/content.gd")

func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: real-renderer tools must run via engine/tools/quiet_godot.sh (born-minimized")
		print("window; in-script flags are too late and flash/steal focus). See ~/.claude/CLAUDE.md")
		quit(2)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() >= 1 else "/tmp/inbox.png"

	var dir := "/tmp/tu_inboxshot/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

	# past the cold FTUE (one hub spot owned), then seed a news note + an unclaimed gift on top of
	# the starters.
	var g := Save.grove()
	g["unlocks"] = {String(G.MAPS[G.hub_map()].spots[0].id): true}
	g["exp"] = 6
	Save.grove_write()
	Inbox.messages()                       # trigger the one-time seed (welcome + starter gift)
	Inbox.add({
		"id": "news_update",
		"title": "Spring is here",
		"body": "New seeds have come to the grove. Tend them well!",
		"icon": "star",
		"reward": {},
	})
	Inbox.add({
		"id": "comp_gift",
		"title": "A gift from us",
		"body": "Thanks for playing — please enjoy these on the house.",
		"icon": "gem",
		"reward": {"coins": 250, "gems": 10, "water": 20},
	})

	var scn = load("res://engine/scenes/Map.tscn").instantiate()
	root.add_child(scn)
	current_scene = scn
	await create_timer(0.6).timeout
	InboxUI.open(scn)
	await create_timer(0.6).timeout

	# minimized windows occasionally serve a STALE frame — force a fresh draw first
	RenderingServer.force_draw()
	var img := root.get_texture().get_image()
	var err := img.save_png(out)
	print("SHOT saved=%s err=%d unread=%d unclaimed=%s" % [out, err, Inbox.unread_count(), str(Inbox.has_unclaimed())])
	quit()
