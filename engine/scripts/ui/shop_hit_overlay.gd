extends Control
## THE SHOP'S HIT-REGION OVERLAY — debug chrome that draws, over the live storefront, the region the game
## ACTUALLY hit-tests for each offer, labelled with the purchase that region resolves to.
##
## It does not re-derive where the regions ought to be. Two independent reads are drawn, and a region is
## only marked good when they agree:
##   1. the DECLARED id — the `shop_offer` meta the slot carries, set from the very same card dictionary
##      that supplied its `on_buy`, so the label and the purchase come from one source;
##   2. the RESOLVED id — what the ENGINE's own picker returns for five points inside the region. The
##      overlay pushes a real `InputEventMouseMotion` at each point and reads
##      `Viewport.gui_get_hovered_control()`, then walks that control up to the offer that owns it. That is
##      Godot's hit test, mouse_filter, z-order, rotation and all — not a rectangle intersection of ours.
## A region whose five probes do not all come back as its declared offer is drawn RED with the id it
## really resolves to, which is the whole point of looking at the picture.
##
## GATED like every other debug surface in this project: `Debug.authoring()` only (engine/scripts/ui/debug.gd
## — `Debug.force`, `TU_DEBUG=1`, or `-- debug`). It is therefore absent from a normal run, from every
## headless suite (DisplayServer is "headless") and from an ordinary quiet capture (TU_QUIET=1). The
## capture that WANTS it sets the gate deliberately: `make shot-map MODE=shophits`.

const Debug = preload("res://engine/scripts/ui/debug.gd")
const Stall = preload("res://engine/scripts/ui/market_stall.gd")
const Overlay = preload("res://engine/scripts/ui/overlay.gd")
const FS = preload("res://engine/scripts/core/tuning.gd").FontScale

const OVERLAY_NAME := "ShopHitOverlay"
const SELF_PATH := "res://engine/scripts/ui/shop_hit_overlay.gd"

## How many points inside each region are probed through the engine's picker. Centre plus the four
## corners of a rect inset by PROBE_INSET of the region — a single centre probe would pass a region whose
## edges are stolen by a neighbour, which is exactly the failure this overlay exists to catch.
const PROBE_INSET := 0.18

const OK_COL := Color(0.22, 0.85, 0.35)
const BAD_COL := Color(1.0, 0.20, 0.18)
const PILL_COL := Color(0.25, 0.65, 1.0)
const INK := Color(0.06, 0.09, 0.12)

var _stall: Control = null
var _regions: Array = []     ## [{rect, declared, resolved, kind, good}]
var _probed := false

## Mount the overlay over an open storefront. A NO-OP unless the authoring gate is on, so the live game,
## the suites and ordinary captures never see it. Returns the overlay (or null when gated off).
static func mount(host: Control, stall: Control) -> Control:
	if host == null or stall == null or not Debug.authoring():
		return null
	if host.has_node(OVERLAY_NAME):
		return host.get_node(OVERLAY_NAME) as Control
	var ov: Control = load(SELF_PATH).new()
	ov.name = OVERLAY_NAME
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.z_index = Overlay.MODAL_TOP_Z + 1
	ov._stall = stall
	host.add_child(ov)
	return ov

func _ready() -> void:
	# probe AFTER the containers have laid the stall out — a rect read in the same frame it was added is
	# the pre-layout one, and every region would be reported at the wrong place.
	_settle()

func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_probe()
	queue_redraw()

## Collect the regions, then ask the ENGINE what each one resolves to.
func _probe() -> void:
	_regions.clear()
	if _stall == null or not is_instance_valid(_stall):
		return
	var vp := get_viewport()
	for n in _stall.find_children("*", "Control", true, false):
		var c := n as Control
		if not is_instance_valid(c) or not c.is_visible_in_tree():
			continue
		var kind := ""
		if c.has_meta(Stall.SLOT_META):
			kind = "slot"
		elif c.has_meta("shop_buy"):
			kind = "price"
		else:
			continue
		if c.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			continue                       # not hit-tested at all — nothing to draw
		var rect := c.get_global_rect()
		var declared := String(c.get_meta(Stall.OFFER_META, ""))
		var resolved := _resolve(vp, rect)
		_regions.append({
			"rect": rect, "declared": declared, "resolved": resolved, "kind": kind,
			"good": resolved.size() == 1 and String(resolved[0]) == declared and declared != "",
		})
	_probed = true
	for r in _regions:
		print("SHOP HIT %-5s %-10s -> %s  rect=%s" % [
			r["kind"], r["declared"], ",".join(PackedStringArray(r["resolved"])), str(r["rect"])])

## The set of offer ids the engine's own picker returns across the sampled points of `rect`. One entry =
## every probe agreed. `gui_get_hovered_control` is Godot's live GUI pick, so mouse_filter, z-order and
## every ancestor transform are honoured exactly as they are for a real tap.
func _resolve(vp: Viewport, rect: Rect2) -> Array:
	if vp == null or not vp.has_method("gui_get_hovered_control"):
		return ["?no-picker"]              # refuse rather than silently report a re-derivation
	var inset := rect.size * PROBE_INSET
	var pts := [
		rect.get_center(),
		rect.position + inset,
		Vector2(rect.end.x - inset.x, rect.position.y + inset.y),
		Vector2(rect.position.x + inset.x, rect.end.y - inset.y),
		rect.end - inset,
	]
	var seen: Array = []
	for p in pts:
		var mm := InputEventMouseMotion.new()
		mm.position = p
		mm.global_position = p
		vp.push_input(mm, true)
		var hit: Control = vp.gui_get_hovered_control()
		var id := _offer_of(hit)
		if not seen.has(id):
			seen.append(id)
	return seen

## Walk a picked control UP to the offer that owns it. The price button carries the id itself; anything
## inside a shelf cell resolves through the cell. Nothing else in the stall stops the mouse.
func _offer_of(c: Node) -> String:
	var n := c
	while n != null:
		if n is Object and (n as Object).has_meta(Stall.OFFER_META):
			var id := String((n as Object).get_meta(Stall.OFFER_META, ""))
			if id != "":
				return id
		n = n.get_parent()
	return "—"

func _draw() -> void:
	if not _probed:
		return
	var font := get_theme_default_font()
	var fsz := int(FS.FINE * 0.8)
	for r in _regions:
		var rect: Rect2 = r["rect"]
		var local := Rect2(rect.position - global_position, rect.size)
		var slot: bool = String(r["kind"]) == "slot"
		var col: Color = (OK_COL if bool(r["good"]) else BAD_COL) if slot else \
			(PILL_COL if bool(r["good"]) else BAD_COL)
		draw_rect(local, Color(col, 0.13), true)
		draw_rect(local, col, false, 4.0 if slot else 2.0)
		var label := String(r["declared"])
		if not bool(r["good"]):
			label = "%s → %s" % [label if label != "" else "(none)", ",".join(PackedStringArray(r["resolved"]))]
		# a slot names itself inside its own top-left corner; a price button names itself just OUTSIDE its
		# bottom edge, so the label never prints over the price it is describing.
		var at := local.position + (Vector2(10.0, fsz + 8.0) if slot else Vector2(0.0, local.size.y + fsz + 3.0))
		if font != null:
			draw_string(font, at + Vector2(2, 2), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, Color(INK, 0.75))
			draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, col)

## The probed regions, for the suites: [{rect, declared, resolved, kind, good}].
func regions_for_test() -> Array:
	return _regions
