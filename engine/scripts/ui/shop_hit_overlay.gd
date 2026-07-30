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
## IT DRAWS EVERY TAP THIS SCREEN TAKES, not only the purchases. Two things on this screen are not offers
## and were invisible here until 2026-07-30 ("what about the close button"):
##   * the ✕. It carries `Screen.CLOSE_META` (stamped in the same branch that wires its dismiss callable)
##     and is drawn in AMBER, DASHED, because it is not a purchase — with the disc the picture actually
##     draws inside it, solid. The dashed rect is bigger than that disc on purpose (the painted ✕ is under
##     the platform's fingertip floor) and the amber ring between them is tap area the art does not show.
##   * EVERYWHERE ELSE. The painting has no control of its own, so a tap that misses every region falls
##     through to the modal's veil — which dismisses the shop. That is real behaviour on this screen, so a
##     grid of points outside every region is pushed through the same picker and marked ×, and the legend
##     names what they hit. Drawing only the offers would have shown a screen that is nine-tenths inert.
##
## GATED like every other debug surface in this project: `Debug.authoring()` only (engine/scripts/ui/debug.gd
## — `Debug.force`, `TU_DEBUG=1`, or `-- debug`). It is therefore absent from a normal run, from every
## headless suite (DisplayServer is "headless") and from an ordinary quiet capture (TU_QUIET=1). The
## capture that WANTS it sets the gate deliberately: `make shot-map MODE=shophits`.

const Debug = preload("res://engine/scripts/ui/debug.gd")
const Screen = preload("res://engine/scripts/ui/shop_screen.gd")
const Overlay = preload("res://engine/scripts/ui/overlay.gd")
const FS = preload("res://engine/scripts/core/tuning.gd").FontScale

const OVERLAY_NAME := "ShopHitOverlay"
const SELF_PATH := "res://engine/scripts/ui/shop_hit_overlay.gd"

## How many points inside each region are probed through the engine's picker. Centre plus the four
## corners of a rect inset by PROBE_INSET of the region — a single centre probe would pass a region whose
## edges are stolen by a neighbour, which is exactly the failure this overlay exists to catch.
const PROBE_INSET := 0.18

## …and how many points are probed OUTSIDE every region: a grid over the whole screen, minus the points
## that land in a region. Coarse on purpose — it answers "what happens if I miss?", not "where exactly is
## the seam", which is what the per-region probes are for.
const GRID_COLS := 9
const GRID_ROWS := 16

const OK_COL := Color(0.22, 0.85, 0.35)
const BAD_COL := Color(1.0, 0.20, 0.18)
const PILL_COL := Color(0.25, 0.65, 1.0)
const CLOSE_COL := Color(1.0, 0.66, 0.12)      ## the ✕ — amber, because it dismisses rather than charges
const ELSE_COL := Color(0.97, 0.98, 1.0)
const LEGEND_BG := Color(0.05, 0.07, 0.10)
const INK := Color(0.06, 0.09, 0.12)

var _screen: Control = null
var _regions: Array = []     ## [{rect, declared, resolved, kind, good, drawn}]
var _elsewhere: Array = []   ## [{pos, hit}] — probe points inside NO region, and what the picker returned
var _probed := false

## Mount the overlay over an open storefront. A NO-OP unless the authoring gate is on, so the live game,
## the suites and ordinary captures never see it. Returns the overlay (or null when gated off).
static func mount(host: Control, screen: Control) -> Control:
	if host == null or screen == null or not Debug.authoring():
		return null
	if host.has_node(OVERLAY_NAME):
		return host.get_node(OVERLAY_NAME) as Control
	var ov: Control = load(SELF_PATH).new()
	ov.name = OVERLAY_NAME
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.z_index = Overlay.MODAL_TOP_Z + 1
	ov._screen = screen
	host.add_child(ov)
	return ov

func _ready() -> void:
	# probe AFTER the containers have laid the screen out — a rect read in the same frame it was added is
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
	_elsewhere.clear()
	if _screen == null or not is_instance_valid(_screen):
		return
	var vp := get_viewport()
	for n in _screen.find_children("*", "Control", true, false):
		var c := n as Control
		if not is_instance_valid(c) or not c.is_visible_in_tree():
			continue
		# WHAT IS THIS REGION FOR? Read off the metas the screen stamped beside the callable it wired, so a
		# label and a behaviour cannot disagree. Anything hit-testable that carries NONE of them is still
		# collected below, as `?`, rather than dropped — an unlabelled tap target is the failure this
		# overlay exists to show, not something to hide by filtering.
		var kind := ""
		var declared := ""
		if c.has_meta(Screen.CLOSE_META):
			kind = "close"
			declared = Screen.CLOSE_ID
		elif c.has_meta(Screen.SLOT_META):
			kind = "slot"
			declared = String(c.get_meta(Screen.OFFER_META, ""))
		elif c.has_meta("shop_buy"):
			kind = "price"
			declared = String(c.get_meta(Screen.OFFER_META, ""))
		else:
			kind = "?"
		if c.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			continue                       # not hit-tested at all — nothing to draw
		var rect := c.get_global_rect()
		var resolved := _resolve(vp, rect)
		# the disc the picture draws, when the region is bigger than it (the ✕). Anchored to the button's
		# OWN probed rect by the offset the screen stamped, so it cannot drift off it.
		var drawn := Rect2()
		if c.has_meta(Screen.CLOSE_DRAWN_META):
			var d: Rect2 = c.get_meta(Screen.CLOSE_DRAWN_META)
			if d.size.x > 0.0 and d.size.y > 0.0:
				drawn = Rect2(rect.position + (d.position - c.position), d.size)
		_regions.append({
			"rect": rect, "declared": declared, "resolved": resolved, "kind": kind, "drawn": drawn,
			"good": resolved.size() == 1 and String(resolved[0]) == declared and declared != "",
		})
	_probe_elsewhere(vp)
	_probed = true
	for r in _regions:
		print("SHOP HIT %-5s %-10s -> %s  rect=%s" % [
			r["kind"], r["declared"], ",".join(PackedStringArray(r["resolved"])), str(r["rect"])])
	print("SHOP HIT elsewhere %d probes -> %s" % [_elsewhere.size(), ",".join(PackedStringArray(_elsewhere_answers()))])

## What a tap that MISSES every region does. The painting itself stops nothing (its TextureRect and the
## screen root are both MOUSE_FILTER_IGNORE), so this is not a formality: whatever is under the picture
## takes those taps, and on the live shop that is the modal's dismiss veil.
func _probe_elsewhere(vp: Viewport) -> void:
	if vp == null or _screen == null or not vp.has_method("gui_get_hovered_control"):
		return
	var box := _screen.get_global_rect()
	for iy in GRID_ROWS:
		for ix in GRID_COLS:
			var p := box.position + Vector2(
				box.size.x * (float(ix) + 0.5) / float(GRID_COLS),
				box.size.y * (float(iy) + 0.5) / float(GRID_ROWS))
			var inside := false
			for r in _regions:
				if (r["rect"] as Rect2).has_point(p):
					inside = true
					break
			if inside:
				continue
			var mm := InputEventMouseMotion.new()
			mm.position = p
			mm.global_position = p
			vp.push_input(mm, true)
			_elsewhere.append({"pos": p, "hit": _pick_label(vp.gui_get_hovered_control())})

## The distinct answers the off-region probes came back with.
func _elsewhere_answers() -> Array:
	var out: Array = []
	for e in _elsewhere:
		if not out.has(String(e["hit"])):
			out.append(String(e["hit"]))
	return out

## Name a picked control WITHOUT claiming anything it has not been asked. The modal's veil is recognised
## by identity (it is the ColorRect beside this overlay under the same modal), and whether a tap there
## dismisses is read off the veil's own `gui_input` connection — the exact switch Overlay.scaffold flips
## for `dismissable`. Anything else is reported as the class and name it is.
func _pick_label(c: Control) -> String:
	if c == null:
		return "nothing"
	var veil := _host_veil()
	if veil != null and c == veil:
		return "veil · dismisses" if not veil.get_signal_connection_list("gui_input").is_empty() \
			else "veil · blocks"
	var offer := _offer_of(c)
	if offer != "—":
		return offer
	return "%s '%s'" % [c.get_class(), c.name]

## The veil of the modal this overlay is mounted in, if any (the capture tool and the workbench mount the
## storefront with no modal at all, and then there is simply none).
func _host_veil() -> Control:
	var p := get_parent()
	if p == null:
		return null
	for ch in p.get_children():
		if ch is ColorRect:
			return ch as Control
	return null

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

## Walk a picked control UP to what owns it: the offer it buys, or the ✕ it dismisses through. The price
## button carries the id itself; anything inside a shelf cell resolves through the cell. Nothing else over
## the painting stops the mouse.
func _offer_of(c: Node) -> String:
	var n := c
	while n != null:
		if n is Object and (n as Object).has_meta(Screen.CLOSE_META):
			return Screen.CLOSE_ID
		if n is Object and (n as Object).has_meta(Screen.OFFER_META):
			var id := String((n as Object).get_meta(Screen.OFFER_META, ""))
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
		if String(r["kind"]) == "close":
			_draw_close(r, font, fsz)
			continue
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
	_draw_elsewhere()
	_draw_legend(font, fsz)

## THE ✕, drawn as what it is: an ENLARGED tap target over a small painted disc.
##   * the dashed amber rect is what the engine hit-tests (dashed and amber so it never reads as one of
##     the solid purchase regions — this one dismisses, it does not charge);
##   * the solid ring inside it is the disc the PICTURE draws, handed over by the screen;
##   * the amber between them is the difference, which is the whole reason the region was opened up.
func _draw_close(r: Dictionary, font: Font, fsz: int) -> void:
	var rect: Rect2 = r["rect"]
	var local := Rect2(rect.position - global_position, rect.size)
	var col: Color = CLOSE_COL if bool(r["good"]) else BAD_COL
	draw_rect(local, Color(col, 0.12), true)
	_dashed_rect(local, col, 3.0, 13.0)
	var label := String(r["declared"])
	var drawn: Rect2 = r.get("drawn", Rect2())
	if drawn.size.x > 0.0 and drawn.size.y > 0.0:
		var dl := Rect2(drawn.position - global_position, drawn.size)
		var c := dl.get_center()
		var rad: float = minf(dl.size.x, dl.size.y) * 0.5
		draw_circle(c, rad, Color(col, 0.14))
		draw_arc(c, rad, 0.0, TAU, 64, col, 2.0, true)
		label = "%s ✕  tap %.0f · drawn %.0f" % [label, local.size.x, dl.size.x]
	if not bool(r["good"]):
		label = "%s → %s" % [label, ",".join(PackedStringArray(r["resolved"]))]
	# the ✕ sits in the top-right corner, so its label goes UNDER it and right-aligned to its own edge:
	# clear of the ✕ it describes, clear of the screen edge, and on the picture's plain ground rather than
	# over the signboard's dark plank (where amber-on-wood was measurably hard to read).
	if font == null:
		return
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
	var at := Vector2(clampf(local.end.x - w, 6.0, maxf(size.x - w - 6.0, 6.0)), local.end.y + fsz + 8.0)
	draw_string(font, at + Vector2(2, 2), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, Color(INK, 0.75))
	draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, col)

## Every probe that landed in NO region, marked where it was taken. Small and faint: it is the ground the
## regions sit on, and the legend carries what it resolved to.
func _draw_elsewhere() -> void:
	for e in _elsewhere:
		var p: Vector2 = (e["pos"] as Vector2) - global_position
		var a := 7.0
		draw_line(p - Vector2(a, a), p + Vector2(a, a), Color(ELSE_COL, 0.5), 2.0)
		draw_line(p - Vector2(a, -a), p + Vector2(a, -a), Color(ELSE_COL, 0.5), 2.0)

func _dashed_rect(r: Rect2, col: Color, width: float, dash: float) -> void:
	var tl := r.position
	var tr := Vector2(r.end.x, r.position.y)
	var br := r.end
	var bl := Vector2(r.position.x, r.end.y)
	for pair in [[tl, tr], [tr, br], [br, bl], [bl, tl]]:
		draw_dashed_line(pair[0], pair[1], col, width, dash)

## The key. It names the three kinds of region AND what the rest of the screen does, because "the rest of
## the screen" is the majority of it: the painting stops no taps of its own.
func _draw_legend(font: Font, fsz: int) -> void:
	if font == null:
		return
	var lines: Array = [
		[OK_COL, "fill", "shelf cell → the offer named inside it"],
		[PILL_COL, "fill", "price plate → the same offer, on top"],
		[CLOSE_COL, "dash", "close ✕ → dismisses (dashed = tap area, ring = the drawn disc)"],
		[ELSE_COL, "x", "× %d probes hit no region → %s" % [
			_elsewhere.size(), ",".join(PackedStringArray(_elsewhere_answers())) if not _elsewhere.is_empty() else "—"]],
	]
	var pad := 12.0
	var step := float(fsz) + 10.0
	var w := 0.0
	for ln in lines:
		w = maxf(w, font.get_string_size(String(ln[2]), HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x)
	var box := Rect2(14.0, 14.0, w + pad * 2.0 + 26.0, step * lines.size() + pad * 2.0)
	draw_rect(box, Color(LEGEND_BG, 0.82), true)
	draw_rect(box, Color(ELSE_COL, 0.30), false, 2.0)
	var y := box.position.y + pad + float(fsz)
	for ln in lines:
		var col: Color = ln[0]
		var swatch := Rect2(box.position.x + pad, y - float(fsz) * 0.8, 16.0, 12.0)
		match String(ln[1]):
			"fill":
				draw_rect(swatch, Color(col, 0.35), true)
				draw_rect(swatch, col, false, 2.0)
			"dash":
				_dashed_rect(swatch, col, 2.0, 5.0)
			_:
				var c := swatch.get_center()
				draw_line(c - Vector2(6, 6), c + Vector2(6, 6), Color(col, 0.8), 2.0)
				draw_line(c - Vector2(6, -6), c + Vector2(6, -6), Color(col, 0.8), 2.0)
		draw_string(font, Vector2(box.position.x + pad + 26.0, y), String(ln[2]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, Color(ELSE_COL, 0.95))
		y += step

## The probed regions, for the suites: [{rect, declared, resolved, kind, good, drawn}].
func regions_for_test() -> Array:
	return _regions

## …and the probes that landed in no region at all: [{pos, hit}]. The suites assert this screen's misses
## are accounted for rather than merely unlabelled.
func elsewhere_for_test() -> Array:
	return _elsewhere
