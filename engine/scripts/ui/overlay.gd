extends RefCounted
## Shared modal-overlay guard + scaffold. Every dialog mounts ONE full-rect Control onto its host as the
## scrim+content root. Two of these stacking is the "open twice, close twice" bug (emulate_touch_from_mouse
## delivers a tap as BOTH a mouse AND a touch event, so one trigger can fire open() twice in a frame; the
## scrim also doesn't block a second trigger while one is open). Naming the overlay + this guard make
## opening idempotent — add_child is synchronous, so a duplicate event finds the first overlay here.
##
## Layering is ONE source of truth here. The whole game renders on a single canvas (no CanvasLayers), so
## "on top" is purely z_index. Every modal must sit ABOVE the highest world/HUD/FX z (wallet 40, FX 60) —
## so `mount()` always stamps MODAL_Z. A layer that must stack above ANOTHER modal (a confirm sheet over an
## open shop, the mystery reel over the daily calendar, the wallet kept readable above the shop backdrop)
## uses MODAL_TOP_Z. Dialogs call `mount()` instead of hand-rolling z — that is what keeps the shop (which
## once forgot its z and slid under the HUD) and every future dialog reliably on top.
##
## The SCAFFOLD every one of those dialogs then builds is identical — a full-rect veil ColorRect, an
## optional tap-to-dismiss on it, and a full-rect MOUSE_FILTER_IGNORE CenterContainer for the card. That
## was hand-rolled at 20 sites and had already drifted (four different veil alphas, five different spellings
## of the same "was this tap a press?" lambda). `modal()` owns it now: one veil darkness, one dismiss seam.
## Layout is unchanged — veil is child 0, the content root is child 1, both unnamed, exactly as before.

const Game = preload("res://engine/scripts/core/game.gd")

## The ONE veil darkness. The hand-rolled sites ran 0.5 / 0.55 / 0.56 / 0.6 with no stated reason;
## 0.55 was the plurality (9 of 20) and the median, so it is the default every dialog now gets.
## A site with a NAMED, documented reason to differ (the storefront's Tune.VEIL_ALPHA, which doubles
## as the flat fallback under its frosted backdrop shader) passes `alpha` and says why at the call site.
const VEIL_ALPHA := 0.55

# Home's painter-sorted cut-paper props and build badges use their authored canvas y
# (up to 1510) as z-index. Keep the shared modal band above that world range as well
# as the ordinary HUD/FX range, so no plot label or prop can pierce a dialog veil.
const MODAL_Z := 2048      ## the modal layer — above all world/HUD/FX chrome
const MODAL_TOP_Z := 2110  ## one notch up: a layer that must sit above an open modal

## Create a full-rect modal overlay named `name`, stamped at the canonical modal z, mounted on `host`, and
## return it. Callers run their own `is_open` guard first (they have setup to skip on a re-open).
static func mount(host: Control, name: String, z: int = MODAL_Z) -> Control:
	var overlay := Control.new()
	overlay.name = name
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = z
	host.add_child(overlay)
	return overlay

## Mount a modal overlay on `host` AND build the shared scaffold into it. THE call every dialog makes.
## Returns {"overlay","veil","center","dismiss"} — see `scaffold()` for the parts and the opts.
static func modal(host: Control, name: String, opts := {}) -> Dictionary:
	return scaffold(mount(host, name, int(opts.get("z", MODAL_Z))), opts)

## Build the shared modal scaffold into an ALREADY-mounted `overlay`: the full-rect veil, its optional
## tap-to-dismiss, and the full-rect CenterContainer the dialog card goes in. Split out of `modal()` for
## the one dialog that REBUILDS in place (ui/ladder.gd re-renders into its live overlay rather than
## stacking a second one), so that path shares the scaffold instead of hand-rolling it.
##
## opts (all optional):
##   z           int       — the modal layer; MODAL_TOP_Z for a sheet over an open modal (`modal()` only)
##   ink         Color     — the veil's hue. Default Pal.INK; the board-side dialogs pass their own
##                           (Pal.GROUND_EDGE / the map's DOCK_INK) — a deliberate per-surface tone, not drift.
##   alpha       float     — the veil's darkness. Default VEIL_ALPHA; pass only with a stated reason.
##   material    Material  — a shader on the veil (the shop's blurred + warm-tinted frosted backdrop).
##   dismissable bool      — default true. FALSE for a sheet that must not be tapped away (a spinning
##                           reel, a blocking purchase wait, an unclaimed reward): no gui_input is
##                           connected, and the veil still swallows the tap (Control's default STOP).
##                           Getting this backwards makes a blocking dialog dismissable — it is the one
##                           opt worth double-checking at every call site.
##   on_dismiss  Callable  — extra work on the way out (fire an on_close, mark a version dismissed,
##                           record a decline). Runs BEFORE the overlay is freed.
##
## The returned `dismiss` is THE single close seam: guard → on_dismiss → queue_free. The veil tap runs
## it, and callers hand the same Callable to the frame's ✕ and to any in-card "close" action, so every
## exit path is literally the same code.
static func scaffold(overlay: Control, opts := {}) -> Dictionary:
	var ink: Color = opts.get("ink", Game.PALETTE.INK)
	var veil := ColorRect.new()
	veil.color = Color(ink, float(opts.get("alpha", VEIL_ALPHA)))
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat: Material = opts.get("material", null)
	if mat != null:
		veil.material = mat
	overlay.add_child(veil)

	var on_dismiss: Callable = opts.get("on_dismiss", Callable())
	var dismiss := func() -> void:
		if not is_instance_valid(overlay) or overlay.is_queued_for_deletion():
			return
		if on_dismiss.is_valid():
			on_dismiss.call()
		if is_instance_valid(overlay):
			overlay.queue_free()

	# emulate_touch_from_mouse delivers one tap as BOTH a mouse button AND a screen touch, so both
	# have to count as a press — this is the test every hand-rolled veil was spelling out for itself.
	if bool(opts.get("dismissable", true)):
		veil.gui_input.connect(func(ev: InputEvent) -> void:
			if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
				dismiss.call())

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE   # taps fall through the empty area to the veil
	overlay.add_child(center)
	return {"overlay": overlay, "veil": veil, "center": center, "dismiss": dismiss}

## True when a live (not mid-deletion) overlay named `name` is already mounted on `host`. A dialog's
## open() calls this first and bails when true.
static func is_open(host: Control, name: String) -> bool:
	if host == null:
		return false
	var live := host.get_node_or_null(NodePath(name))
	return live is Control and not (live as Node).is_queued_for_deletion()
