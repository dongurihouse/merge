extends SceneTree
## Headless tests for the identity provider (core/identity.gd) — the part that CAN run off iOS: it must
## degrade safely when the Game Center plugin is absent (no singleton), and honor a previously-cached id.
## The live Game Center auth/signature path is iOS-only and not exercised here.
##   godot --headless -s res://engine/tests/identity_tests.gd

const Save = preload("res://engine/scripts/core/save.gd")
const Identity = preload("res://engine/scripts/core/identity.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func fresh(name: String) -> void:
	var dir := "user://tu_identity_" + name + "/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

func _initialize() -> void:
	print("== Identity tests ==")

	fresh("degrade")
	ok(not Identity.available(), "Game Center is unavailable without the iOS plugin (no singleton)")
	ok(Identity.player_id() == "", "player_id is empty with no identity (→ broadcast)")
	ok(Identity.verification().is_empty(), "no verification signature without sign-in")

	# boot() must be a safe no-op off iOS — no crash, no id conjured.
	var host := Control.new()
	get_root().add_child(host)
	await process_frame
	Identity.boot(host)
	await process_frame
	ok(Identity.player_id() == "", "boot() is a silent no-op without the plugin")
	ok(host.get_child_count() == 0, "boot() spawns no poller when Game Center is unavailable")
	host.queue_free()

	# a previously-cached id (persisted from a prior iOS sign-in) is surfaced on relaunch.
	fresh("cached")
	var g := Save.grove()
	g["gc_player_id"] = "A:_abc123"
	Save.grove_write()
	ok(Identity.player_id() == "A:_abc123", "a cached Game Center id is returned on relaunch")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
