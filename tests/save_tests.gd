extends SceneTree
## Headless tests for the Save persistence layer.
##   godot --headless -s res://tests/save_tests.gd

const Save = preload("res://engine/scripts/save.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

# Point Save at a clean temp dir (never touches the real save or progress.cfg).
func fresh(name: String) -> void:
	var dir := "user://tu_test_" + name + "/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

func _initialize() -> void:
	print("== Save tests ==")

	# 1. fresh load → defaults
	fresh("fresh")
	ok(Save.coins() == 0, "fresh load: coins default 0")

	# 2. persistence across an explicit reload
	fresh("persist")
	Save.add_coins(120)
	Save._loaded = false              # force a reload from disk
	ok(Save.coins() == 120, "coins persist across reload")

	# 3. corruption of the live file recovers from .bak
	fresh("corrupt")
	Save.add_coins(200)               # 1st write: creates save.json (no .bak yet)
	Save.add_coins(0)                 # 2nd write: rotates save.json -> save.bak
	var bad := FileAccess.open(Save.path, FileAccess.WRITE)
	bad.store_string("{ this is not json")
	bad.close()
	Save._loaded = false
	ok(Save.coins() == 200, "corrupt primary recovers from .bak")

	# 4. spend
	fresh("spend")
	Save.add_coins(100)
	ok(Save.spend(30) and Save.coins() == 70, "spend deducts when affordable")
	ok(not Save.spend(1000) and Save.coins() == 70, "spend refused when too poor")

	# 5. board-clear counter
	fresh("clears")
	Save.record_board_clear()
	Save.record_board_clear()
	ok(Save.boards_cleared() == 2, "record_board_clear increments")

	# 6. per-job best record
	fresh("jobs")
	Save.record_job("bedroom_01", 2, 5)
	Save.record_job("bedroom_01", 3, 4)     # better run
	Save.record_job("bedroom_01", 1, 9)     # worse run must not regress best
	var j := Save.job("bedroom_01")
	ok(int(j["best_stars"]) == 3 and int(j["best_drags"]) == 4 and int(j["plays"]) == 3, \
		"record_job keeps best stars/drags + play count")

	# 7. migrate a legacy progress.cfg, exactly once
	fresh("migrate")
	var c := ConfigFile.new()
	c.set_value("progress", "cleared", 5)
	c.save(Save.legacy)                      # temp legacy file (NOT the real one)
	Save._loaded = false
	Save.load_now()
	ok(Save.boards_cleared() == 5, "migration carries over boards_cleared")
	ok(Save.coins() == 5 * Save.COINS_PER_CLEAR_SEED, "migration seeds coins from past clears")
	ok(bool(Save.data["migrated_v2"]), "migration sets the once-guard")
	var after := Save.coins()
	Save._loaded = false
	Save.load_now()                          # reloading must NOT re-grant
	ok(Save.coins() == after, "migration does not double-grant on reload")

	# 11. first-clear flag (full pay once, trickle after)
	fresh("paid")
	ok(not Save.clear_paid("lvl_x"), "unrecorded job is unpaid")
	Save.record_job("lvl_x", 2, 5)
	ok(Save.clear_paid("lvl_x"), "record_job marks the job paid")

	# 12. room decor: buy is atomic, idempotent, and persists
	fresh("decor")
	ok(Save.decor_count("bedroom") == 0, "fresh room owns no decor")
	ok(not Save.buy_decor("bedroom", "rug", 120), "buy_decor refused when broke")
	ok(Save.coins() == 0, "refused buy takes no coins")
	Save.add_coins(300)
	ok(Save.buy_decor("bedroom", "rug", 120), "buy_decor succeeds when affordable")
	ok(Save.coins() == 180, "buy_decor deducts the cost")
	ok(Save.decor_owned("bedroom", "rug"), "bought slot is owned")
	ok(not Save.buy_decor("bedroom", "rug", 120), "double-buy refused")
	ok(Save.coins() == 180, "double-buy takes no coins")
	Save._loaded = false                     # force a reload from disk
	ok(Save.decor_owned("bedroom", "rug") and Save.decor_count("bedroom") == 1, \
		"decor persists across reload")

	# 13b. settings: defaults true, set persists across reload
	fresh("settings")
	ok(Save.get_setting("music") and Save.get_setting("sfx"), "settings default to ON")
	Save.set_setting("music", false)
	Save._loaded = false
	ok(not Save.get_setting("music") and Save.get_setting("sfx"), "setting persists across reload")

	# 13. old saves (no rooms key) gain it via the additive merge
	fresh("decor_migrate")
	Save.add_coins(1)                        # writes a save file
	Save.data.erase("rooms")                 # simulate a v2 save written before rooms existed
	Save.save_now()
	Save._loaded = false
	ok(Save.decor_count("bedroom") == 0, "pre-rooms save loads with an empty rooms dict")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
