extends SceneTree
## Headless guard for the engine layering invariant.
##   godot --headless --path . -s res://engine/tests/layering_tests.gd
## Imports may only flow scenes/ -> ui/ -> core/. This proves the direction holds:
## core/ never reaches up into ui/ or scenes/, and ui/ never reaches into scenes/.
## See docs/design/merge_spec.md §15 (the layering invariant).

const CORE := "res://engine/scripts/core/"
const UI := "res://engine/scripts/ui/"
const SCENES := "res://engine/scripts/scenes/"

const Overlay := preload("res://engine/scripts/ui/overlay.gd")
const Hud := preload("res://engine/scripts/ui/hud.gd")
const TuneFX := preload("res://engine/scripts/core/tuning.gd").FX   # the FX juice dials (FLY_Z / FLOAT_Z)

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _gd_files(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir + f)
	return out

# True if `path` mentions `needle` anywhere (preload/load both look like a path string).
func _reads(path: String, needle: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var t := f.get_as_text()
	f.close()
	return t.find(needle) != -1

func _initialize() -> void:
	print("== Engine layering guard ==")
	var core := _gd_files(CORE)
	var ui := _gd_files(UI)
	ok(core.size() >= 1, "core/ has scripts (%d found)" % core.size())
	ok(ui.size() >= 1, "ui/ has scripts (%d found)" % ui.size())
	# core/ is the bottom layer — it must not import ui/ or scenes/.
	for p in core:
		var base := p.get_file()
		ok(not _reads(p, UI), "core/%s does not import ui/" % base)
		ok(not _reads(p, SCENES), "core/%s does not import scenes/" % base)
	# ui/ is the middle layer — it must not import scenes/ (the top).
	for p in ui:
		ok(not _reads(p, SCENES), "ui/%s does not import scenes/" % p.get_file())
	_check_modal_z()
	await _check_level_badge_layout()
	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)

# The modal-overlay z invariant. The game renders on ONE canvas (no CanvasLayers), so "dialogs stay on top
# of the background" is purely z_index: every dialog mounts via Overlay.mount, which MUST stamp a z above
# ALL world/HUD/FX chrome. This is the guard the shop lacked when it forgot its z and slid under the HUD;
# MODAL_TOP_Z stacks one notch higher for a sheet that must sit above an already-open modal.
func _check_modal_z() -> void:
	var host := Control.new()
	var ov: Control = Overlay.mount(host, "ProbeOverlay")
	ok(ov != null and ov.name == "ProbeOverlay", "Overlay.mount returns the named overlay")
	ok(ov != null and ov.z_index == Overlay.MODAL_Z, "Overlay.mount stamps the canonical MODAL_Z")
	ok(host.get_node_or_null("ProbeOverlay") == ov, "Overlay.mount parents the overlay onto its host")
	var chrome_top: int = maxi(Hud.HUD_WALLET_Z, maxi(TuneFX.FLY_Z, TuneFX.FLOAT_Z))
	ok(Overlay.MODAL_Z > chrome_top, \
		"MODAL_Z (%d) sits above the highest HUD/FX chrome (%d) — dialogs cover the world" % [Overlay.MODAL_Z, chrome_top])
	ok(Overlay.MODAL_TOP_Z > Overlay.MODAL_Z, "MODAL_TOP_Z sits above MODAL_Z — a sheet can stack over an open modal")
	host.free()

func _check_level_badge_layout() -> void:
	var host := Control.new()
	host.custom_minimum_size = Vector2(1080, 1920)
	host.size = Vector2(1080, 1920)
	get_root().add_child(host)
	var hud: Dictionary = Hud.build(host, {})
	await process_frame
	await process_frame
	var water_pill := hud.get("water_pill") as Control
	var lv_panel := hud.get("lv_panel") as Control
	var badge := lv_panel.find_child("LevelBadge", true, false) as Control if lv_panel != null else null
	var num := badge.get_node_or_null("lv_num") as Label if badge != null else null
	var water_h := water_pill.get_global_rect().size.y if water_pill != null else 0.0
	var badge_h := badge.get_global_rect().size.y if badge != null else 0.0
	ok(badge != null and water_h > 0.0 and badge_h >= water_h * 1.19 and badge_h <= water_h * 1.21,
		"level badge is about 20%% larger than the wallet pill (badge=%.1f pill=%.1f)" % [badge_h, water_h])
	var badge_center := badge.get_global_rect().get_center() if badge != null else Vector2.ZERO
	var num_center := num.get_global_rect().get_center() if num != null else Vector2(INF, INF)
	ok(num != null and badge_center.distance_to(num_center) <= 1.0,
		"level badge number rect is dead-centered (delta=%.1f, %.1f)" % [num_center.x - badge_center.x, num_center.y - badge_center.y])
	host.queue_free()
	await process_frame
