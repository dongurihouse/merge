extends SceneTree
## Micro-probe: time the shared home-button build pieces. Run:
##   godot --headless --path . -s res://engine/tests/perf_probe2.gd

const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")
const Look = preload("res://engine/scripts/ui/skin.gd")

func _ms() -> int: return Time.get_ticks_msec()

func _init() -> void:
	var opts: Dictionary = Kit.home_button_opts_from_config(Kit.load_config(Kit.CONFIG_PATH))
	print("badge polish opts = ", opts.get("badge", {}))

	# shell_texture alone, called 6× with the same args (what N buttons/build do).
	var t := _ms()
	for i in 6:
		Kit.shell_texture(String(opts.get("shell", "shared/disc_round.png")), opts.get("badge", {}))
	print("6x shell_texture           = %dms (%.0fms each)" % [_ms()-t, (_ms()-t)/6.0])

	# a full home_button, 1st vs repeats (icons cache; shell does not).
	var ids := ["gear", "shop", "map", "piggy", "gift", "faucet"]
	t = _ms()
	var b0 := Kit.home_button({"icon": "gear", "caption": "Settings"}, opts)
	print("1st home_button(gear)      = %dms" % (_ms()-t))
	t = _ms()
	for id in ids:
		Kit.home_button({"icon": id, "caption": id}, opts)
	print("6x home_button (mixed ids) = %dms (%.0fms each)" % [_ms()-t, (_ms()-t)/6.0])
	# second pass over the SAME ids — if icons are cached, only the uncached shell cost remains.
	t = _ms()
	for id in ids:
		Kit.home_button({"icon": id, "caption": id}, opts)
	print("6x home_button (2nd pass)  = %dms (%.0fms each)" % [_ms()-t, (_ms()-t)/6.0])
	quit(0)
