extends RefCounted
## Shared modal-overlay guard. Every dialog mounts ONE full-rect Control onto its host as the
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

const MODAL_Z := 100      ## the modal layer — above all world/HUD/FX chrome
const MODAL_TOP_Z := 110  ## one notch up: a layer that must sit above an open modal

## Create a full-rect modal overlay named `name`, stamped at the canonical modal z, mounted on `host`, and
## return it. Callers run their own `is_open` guard first (they have setup to skip on a re-open).
static func mount(host: Control, name: String, z: int = MODAL_Z) -> Control:
	var overlay := Control.new()
	overlay.name = name
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = z
	host.add_child(overlay)
	return overlay

## True when a live (not mid-deletion) overlay named `name` is already mounted on `host`. A dialog's
## open() calls this first and bails when true.
static func is_open(host: Control, name: String) -> bool:
	if host == null:
		return false
	var live := host.get_node_or_null(NodePath(name))
	return live is Control and not (live as Node).is_queued_for_deletion()
