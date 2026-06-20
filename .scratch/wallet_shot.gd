extends SceneTree
## Quiet capture: prove the currency bar updates after an inbox claim. Snaps the Map wallet BEFORE,
## then claims a 500-coin gift in the mailbox, closes it, and snaps the wallet AFTER.
##   make shot TOOL=.scratch/wallet_shot ARGS=/tmp/wallet

const Save = preload("res://engine/scripts/core/save.gd")
const Inbox = preload("res://engine/scripts/core/inbox.gd")
const InboxUI = preload("res://engine/scripts/ui/inbox.gd")
const G = preload("res://engine/scripts/core/content.gd")
const MapScript = preload("res://engine/scripts/scenes/map.gd")

func _find_claim(n: Node) -> Button:
	if n is Button and (n as Button).text.to_lower().contains("claim"):
		return n
	for c in n.get_children():
		var r := _find_claim(c)
		if r != null:
			return r
	return null

func _snap(out: String) -> void:
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(out)

func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: run via make shot")
		quit(2)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var args := OS.get_cmdline_user_args()
	var stem: String = args[0] if args.size() >= 1 else "/tmp/wallet"

	var dir := "/tmp/tu_walletshot/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

	var g := Save.grove()
	g["unlocks"] = {String(G.MAPS[G.hub_map()].spots[0].id): true}
	g["stars_earned"] = 6
	Save.grove_write()
	Save.mark_spotlight_seen("shop")
	Inbox.messages()
	Inbox.add({"id": "comp_big", "title": "A gift from us", "body": "Enjoy these coins!",
		"icon": "gift", "reward": {"coins": 500}})

	MapScript._login_shown_launch = true      # suppress the daily-login auto-popup so the wallet is visible
	var scn = load("res://engine/scenes/Map.tscn").instantiate()
	root.add_child(scn)
	current_scene = scn
	await create_timer(0.6).timeout
	var before := Save.coins()
	_snap(stem + "_before.png")

	InboxUI.open(scn)
	await create_timer(0.4).timeout
	var overlay: Control = null
	for c in scn.get_children():
		if c is Control and (c as Control).z_index == 100:
			overlay = c
	var claim := _find_claim(overlay if overlay != null else scn)
	if claim != null:
		claim.pressed.emit()
	await create_timer(0.4).timeout
	if overlay != null and is_instance_valid(overlay):
		overlay.queue_free()                 # close the modal so the wallet is visible again
	await create_timer(0.5).timeout
	var after := Save.coins()
	_snap(stem + "_after.png")

	print("WALLET before=%d after=%d delta=%d (claimed 500)" % [before, after, after - before])
	quit()
