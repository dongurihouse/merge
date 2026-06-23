extends RefCounted
## Shared modal-overlay guard. Every dialog mounts ONE full-rect Control onto its host as the
## scrim+content root. Two of these stacking is the "open twice, close twice" bug (emulate_touch_from_mouse
## delivers a tap as BOTH a mouse AND a touch event, so one trigger can fire open() twice in a frame; the
## scrim also doesn't block a second trigger while one is open). Naming the overlay + this guard make
## opening idempotent — add_child is synchronous, so a duplicate event finds the first overlay here.

## True when a live (not mid-deletion) overlay named `name` is already mounted on `host`. A dialog's
## open() calls this first and bails when true.
static func is_open(host: Control, name: String) -> bool:
	if host == null:
		return false
	var live := host.get_node_or_null(NodePath(name))
	return live is Control and not (live as Node).is_queued_for_deletion()
