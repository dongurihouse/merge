extends SceneTree
## Dev tool (run via engine/tools/quiet_godot.sh): screenshot the Mailbox modal over the Map.
##   quiet_godot.sh --path . -s res://games/grove/tools/inbox_shot.gd -- <out.png>
## Seeds a couple of inbox messages (incl. an unclaimed gift), opens InboxUI over the home
## map, waits a beat, and saves a PNG. Mirrors map_shot.gd's quiet-capture header (REFUSES
## unless override.cfg exists — the born-minimized window must come from quiet_godot.sh, not
## in-script flags, which are too late and flash/steal focus). Parallel-safe (own temp save).

const Base = preload("res://games/grove/tools/shot_base.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const Inbox = preload("res://engine/scripts/core/inbox.gd")
const InboxUI = preload("res://engine/scripts/ui/inbox.gd")
const G = preload("res://engine/scripts/core/content.gd")

func _initialize() -> void:
	var ctx := await Base.begin(self, {"tool": "inbox", "default_out": "/tmp/inbox.png"})
	if ctx.is_empty():
		return                        # refused: begin() printed why and quit(2)
	var args: Array = ctx["args"]
	var out: String = ctx["out"]

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

	var err := Base.capture(self, out, args)
	print("SHOT saved=%s err=%d unread=%d unclaimed=%s" % [out, err, Inbox.unread_count(), str(Inbox.has_unclaimed())])
	quit()
