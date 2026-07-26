extends "res://engine/tests/test_base.gd"
## Guard: a BLOCKING dialog must not be tappable away.
##   godot --headless --path . -s res://engine/tests/modal_dismiss_tests.gd
##
## Overlay.modal()'s `dismissable` opt defaults to TRUE, so a sheet that must survive a
## background tap only does so because its call site says `"dismissable": false`. That is one
## word, in one dict, per dialog — and dropping it fails silently: the dialog still renders,
## still looks right in a screenshot, and simply closes when it must not. A purchase spinner
## dismissed mid-flight leaves the player staring at the board while a charge is in progress.
##
## So this pins BOTH halves:
##   1. the Overlay contract  — dismissable:false wires no veil handler, and the veil still
##                              SWALLOWS the tap (MOUSE_FILTER_STOP) rather than letting it
##                              reach the board underneath;
##   2. the real call sites   — built through each dialog's own public entry point, not a
##                              mock, so deleting the flag in purchase_wait.gd or level_popup.gd
##                              fails here.
## The dismissable cases are asserted alongside so the blocking assertions cannot pass vacuously
## (a matcher that finds nothing everywhere would report every dialog as blocking).

const Overlay = preload("res://engine/scripts/ui/overlay.gd")
const PurchaseWait = preload("res://engine/scripts/ui/purchase_wait.gd")
const LevelPopup = preload("res://engine/scripts/ui/level_popup.gd")

func _host() -> Control:
	var host := Control.new()
	host.custom_minimum_size = Vector2(1080, 1920)
	host.size = Vector2(1080, 1920)
	root.add_child(host)
	return host

# The veil is the modal's child 0 (pinned by the scaffold contract).
func _veil(overlay: Control) -> ColorRect:
	for c in overlay.get_children():
		if c is ColorRect:
			return c
	return null

# How many handlers are wired to the veil's tap. 0 == nothing can dismiss it.
func _tap_handlers(veil: ColorRect) -> int:
	return 0 if veil == null else veil.gui_input.get_connections().size()

# Press the veil the way a real background tap arrives, then report whether the dialog died.
func _tap_dismisses(overlay: Control, veil: ColorRect) -> bool:
	if veil == null:
		return false
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = veil.size * 0.5
	ev.global_position = veil.global_position + veil.size * 0.5
	veil.gui_input.emit(ev)
	return not is_instance_valid(overlay) or overlay.is_queued_for_deletion()

func _initialize() -> void:
	var host := _host()

	# --- 1. the Overlay contract, directly -------------------------------------------------
	var blocking := Overlay.modal(host, "GuardBlocking", {"dismissable": false})
	var bv: ColorRect = blocking.veil
	ok(_tap_handlers(bv) == 0, "dismissable:false wires NO veil tap handler")
	ok(bv != null and bv.mouse_filter == Control.MOUSE_FILTER_STOP, \
		"a blocking veil still SWALLOWS the tap (does not fall through to the board)")
	ok(not _tap_dismisses(blocking.overlay, bv), "dismissable:false survives a background tap")
	if is_instance_valid(blocking.overlay):
		blocking.overlay.queue_free()

	var open := Overlay.modal(host, "GuardOpen", {})
	var ov: ColorRect = open.veil
	ok(_tap_handlers(ov) == 1, "the DEFAULT wires exactly one veil tap handler")
	ok(_tap_dismisses(open.overlay, ov), "the default dismisses on a background tap")

	# --- 2. the real blocking call sites ---------------------------------------------------
	# purchase_wait: a charge is in flight; tapping it away strands the player mid-purchase.
	var pw := PurchaseWait.show(host, "Working", "Contacting the store…")
	var pwv := _veil(pw)
	ok(_tap_handlers(pwv) == 0, "purchase_wait: no veil tap handler (a charge is in flight)")
	ok(not _tap_dismisses(pw, pwv), "purchase_wait survives a background tap")
	if is_instance_valid(pw):
		pw.queue_free()

	# level-up: the ceremony must be acknowledged, not swiped past.
	var lu := LevelPopup.open_levelup(host, 1)
	var luv := _veil(lu)
	ok(_tap_handlers(luv) == 0, "level_popup LEVELUP: no veil tap handler")
	ok(not _tap_dismisses(lu, luv), "level_popup LEVELUP survives a background tap")
	if is_instance_valid(lu):
		lu.queue_free()

	# ...and the INFO mode of the SAME dialog still dismisses, so the two assertions above
	# are proven to be discriminating rather than matching nothing.
	var info := LevelPopup.open(host)
	var iv := _veil(info)
	ok(_tap_handlers(iv) == 1, "level_popup INFO still wires its veil tap (control case)")
	ok(_tap_dismisses(info, iv), "level_popup INFO still dismisses on a background tap")

	finish()
