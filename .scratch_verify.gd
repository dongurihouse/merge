extends SceneTree
const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")
const UiFont = preload("res://engine/scripts/ui/ui_font.gd")

func _init() -> void:
	root.theme = UiFont.make()
	root.size = Vector2i(700, 760)
	# --- A) number centering: a full pill; measure dark number centroid vs its amount-slot centre ---
	var holderA := Control.new(); holderA.position = Vector2(40, 30); root.add_child(holderA)
	var pill: Control = Kit.gold_currency_pill({"icon": "gem", "count": 25, "show_plus": true}, {"gem": 25})
	holderA.add_child(pill)
	# --- B) plus_label_y nudge: three buttons (-20 / 0 / +20) + one via opts_from_config(+20) ---
	var btns: Array = []
	var labels := ["raw y=-20", "raw y=0", "raw y=+20", "cfg y=+20"]
	var ys := [-20, 0, 20]
	var y := 170.0
	for yy in ys:
		var h := Control.new(); h.position = Vector2(300, y); root.add_child(h)
		var b: Control = Kit._gold_currency_plus_button({"plus_base": 140, "plus_label_y": yy})
		h.add_child(b); btns.append(b); y += 150.0
	var hc := Control.new(); hc.position = Vector2(300, y); root.add_child(hc)
	var cfg_opts: Dictionary = Kit.gold_currency_pill_opts_from_config({"gold_currency_pill": {"plus_label_y": 20}})
	cfg_opts["plus_base"] = 140
	var bc: Control = Kit._gold_currency_plus_button(cfg_opts)
	hc.add_child(bc); btns.append(bc)
	await process_frame; await process_frame; await process_frame
	var img := root.get_texture().get_image()
	# A) number centroid (dark ink #3A1C12) vs the amount slot centre
	var slot: Control = pill.find_child("GoldCurrencyAmountSlot", true, false)
	var amt: Label = pill.find_child("GoldCurrencyAmount", true, false)
	print("amount.horizontal_alignment=", amt.horizontal_alignment, " (1==CENTER)")
	var r := slot.get_global_rect()
	var sx := 0.0; var n := 0
	for py in range(int(r.position.y), int(r.position.y + r.size.y)):
		for px in range(int(r.position.x), int(r.position.x + r.size.x)):
			var c := img.get_pixel(px, py)
			if c.r < 0.45 and c.g < 0.35 and c.b < 0.30 and c.a > 0.5:
				sx += px; n += 1
	if n > 0:
		var inkx := sx / n
		var cx := r.position.x + r.size.x * 0.5
		print("NUMBER: slot_cx=%.1f ink_cx=%.1f dx=%.2f (≈0 => centred)" % [cx, inkx, inkx - cx])
	else:
		print("NUMBER: no ink pixels found")
	# B) plus glyph centroid-y vs button centre for each
	for i in btns.size():
		var b: Control = btns[i]
		var rr := b.get_global_rect()
		var cy := rr.position.y + rr.size.y * 0.5
		var syy := 0.0; var m := 0
		for py in range(maxi(0, int(rr.position.y) - 60), mini(img.get_height(), int(rr.position.y + rr.size.y) + 60)):
			for px in range(int(rr.position.x), int(rr.position.x + rr.size.x)):
				var c := img.get_pixel(px, py)
				if c.r > 0.86 and c.g > 0.82 and c.b > 0.60 and c.b < 0.92:
					syy += py; m += 1
		if m > 0:
			print("%s: btn_cy=%.1f ink_cy=%.1f dy=%.2f" % [labels[i], cy, syy / m, syy / m - cy])
		else:
			print("%s: no cream pixels" % labels[i])
	quit()
