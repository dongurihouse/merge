extends SceneTree
const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")
func _init() -> void:
	var o := Kit.gold_currency_pill_opts_from_config({"gold_currency_pill": {"plus_label_y": 20}})
	print("opts.plus_label_y=", o.get("plus_label_y", "MISSING"))
	var b: Control = Kit._gold_currency_plus_button(o)
	var lab: Label = b.find_child("GoldCurrencyPlusLabel", true, false)
	print("label offset_top=", lab.offset_top, " anchor_top=", lab.anchor_top, " grow_v=", lab.grow_vertical)
	quit()
