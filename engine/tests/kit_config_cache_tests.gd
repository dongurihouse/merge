extends SceneTree
## Headless tests for Kit.load_config caching — the parsed config is read+JSON-parsed ONCE per path,
## not re-parsed for every widget a scene build creates. Cleared on demand (the workbench's Save hook).
##   godot --headless -s res://engine/tests/kit_config_cache_tests.gd

const Kit = preload("res://games/grove/ui_kit.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _write(path: String, body: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(body)
	f.close()

func _initialize() -> void:
	print("== Kit config-cache tests ==")
	var path := "user://tu_kit_cfg_test.json"
	Kit.clear_config_cache()

	# 1. first load parses the file.
	_write(path, '{"button": {"font": 22}}')
	var a := Kit.load_config(path)
	ok(a is Dictionary and int((a.get("button", {}) as Dictionary).get("font", 0)) == 22, "first load parses the file")

	# 2. the file changes on disk, but a cached load returns the ORIGINAL (proves it isn't re-parsing).
	_write(path, '{"button": {"font": 40}}')
	var b := Kit.load_config(path)
	ok(int((b.get("button", {}) as Dictionary).get("font", 0)) == 22, "second load is cached (no re-parse)")

	# 3. clearing the cache re-reads the new contents.
	Kit.clear_config_cache(path)
	var c := Kit.load_config(path)
	ok(int((c.get("button", {}) as Dictionary).get("font", 0)) == 40, "clear_config_cache() forces a re-read")

	# 4. a missing path returns {} and is harmless to cache/clear.
	Kit.clear_config_cache()
	ok(Kit.load_config("res://nope/missing.json") == {}, "missing path returns empty dict")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_test_fx_and_kit_share_one_cache()
	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)


## REGRESSION: FX and the kit read the SAME settings file. They used to hold two independent caches
## that each invalidated only themselves, so a save through either side left the other serving
## pre-save values for the rest of the session (and the FX gallery then re-persisted the stale read).
## Both directions must now go through the one cache with the one invalidation point.
func _test_fx_and_kit_share_one_cache() -> void:
	var path := "user://tu_fx_shared_cfg_test.json"
	Kit.clear_config_cache()
	FX.configure_reward_fx_config_for_test(path)

	# Seed the file with kit-owned content and warm the kit cache, exactly as a scene build would.
	_write(path, '{"button": {"font": 33}}')
	Kit.clear_config_cache(path)
	ok(int((Kit.load_config(path).get("button", {}) as Dictionary).get("font", 0)) == 33, "kit cache warmed from the shared file")

	# 5. FX writes the file → a kit-side read must see it (was stale: only FX's own cache dropped).
	FX.set_reward_fx_enabled("coin_pickup", false)
	var after_fx_write := Kit.load_config(path)
	var fx_block: Dictionary = after_fx_write.get("fx", {})
	var enabled: Dictionary = fx_block.get("enabled", {})
	ok(not bool(enabled.get("coin_pickup", true)), "FX write is visible to a kit-side load_config")
	ok(int((after_fx_write.get("button", {}) as Dictionary).get("font", 0)) == 33, "FX write preserved the kit-owned keys")

	# 6. The kit's Save hook (write + clear_config_cache) → an FX read must see it
	#    (was stale: FX's private cache survived Kit.clear_config_cache).
	ok(is_equal_approx(FX.reward_fx_icon_size(), FX.REWARD_FX_DEFAULT_ICON_SIZE), "FX read is warm before the kit-side save")
	_write(path, '{"button": {"font": 33}, "fx": {"icon_size": 61.0}}')
	Kit.clear_config_cache(path)
	ok(is_equal_approx(FX.reward_fx_icon_size(), 61.0), "kit-side save is visible to an FX read")

	# The handed-out config is a COPY — mutating it must not reach the shared cache.
	var copy := FX.reward_fx_config()
	copy["icon_size"] = 24.0
	(copy["enabled"] as Dictionary)["coin_pickup"] = true
	ok(is_equal_approx(FX.reward_fx_icon_size(), 61.0), "mutating reward_fx_config() does not corrupt the cache")
	ok(int((Kit.load_config(path).get("button", {}) as Dictionary).get("font", 0)) == 33, "the kit's cached dict survived the FX round-trip")

	# A path swap must never serve the previous path's data.
	var other := "user://tu_fx_shared_cfg_test_b.json"
	_write(other, '{"fx": {"icon_size": 30.0}}')
	FX.configure_reward_fx_config_for_test(other)
	ok(is_equal_approx(FX.reward_fx_icon_size(), 30.0), "test path swap reads the new path, not the old cache")

	FX.configure_reward_fx_config_for_test("")
	Kit.clear_config_cache()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(other))
