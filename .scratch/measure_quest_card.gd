extends SceneTree
# Measure the giver card's actual box height as card_h / card_w vary, to prove where it clamps.
const GiverStand = preload("res://engine/scripts/ui/giver_stand.gd")
const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")

func _card_h(stand: Control) -> float:
	for c in stand.get_children():
		if c is TextureRect or c is Panel:   # the card art / fallback panel is the box
			return (c as Control).size.y
	return -1.0

func _build(sw: float, fh: float, card_w: int, card_h: int) -> float:
	var lay := Kit.giver_lay_from_config({"quest_card": {"card_w": card_w, "card_h": card_h}})
	var noop := func(_a: Variant, _b: Variant) -> void: pass
	var wire := func(_n: Control, _a: Callable) -> void: pass
	var made := GiverStand.make(1, {"line": 1, "tier": 3, "reward": {"stars": 5}},
		{"ask_tap": noop, "stand_tap": noop, "wire_tap": wire, "stand_w": sw, "fence_h": fh, "lay": lay})
	var stand: Control = made.chip
	get_root().add_child(stand)
	var h := _card_h(stand)
	stand.queue_free()
	return h

func _initialize() -> void:
	var artR := 369.0 / 209.0
	print("aspect (W/H) = %.3f" % artR)
	print("--- BOARD column: stand_w=252, fence_h=215 (≈1080-wide screen, 3 givers in 70%%) ---")
	for ch in [60, 86, 120, 200, 300]:
		print("  card_w=98  card_h=%3d%%  ->  box height = %.1f px" % [ch, _build(252.0, 215.0, 98, ch)])
	print("  (raise card_w so the width clamp lifts:)")
	for cw in [98, 150, 200, 300]:
		print("  card_w=%3d card_h=200%%  ->  box height = %.1f px" % [cw, _build(252.0, 215.0, cw, 200)])
	print("--- WORKBENCH preview: stand_w=480, fence_h=344 ---")
	for ch in [60, 86, 120, 200, 300]:
		print("  card_w=98  card_h=%3d%%  ->  box height = %.1f px" % [ch, _build(480.0, 344.0, 98, ch)])
	quit()
