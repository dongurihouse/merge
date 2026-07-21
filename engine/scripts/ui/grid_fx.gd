extends RefCounted
## GridFx — THE single owner of grid-cell FEEL: the merge celebration and the slide-and-land, wired to
## the workbench-tuned MergeFx / MoveFx / LandFx appliers. Every grid surface (the live board, the
## Residents habitat/hand, any future board) plays merge/move through here, so the feel can't drift or be
## re-implemented per surface. It owns ORCHESTRATION only — the drop RULES (what a merge/move means) stay
## with each surface, because those are different games, not duplication.
##
## Layering: ui/ never imports scenes/. GridFx takes plain nodes + positions, so a scene (board.gd) and a
## dialog (residents.gd) both drive it without either importing the other.

const MergeFx = preload("res://engine/scripts/ui/merge_fx.gd")
const MoveFx = preload("res://engine/scripts/ui/move_fx.gd")
const LandFx = preload("res://engine/scripts/ui/land_fx.gd")

# Resolve the three feel-opt bundles once from a workbench config dict (mirrors board.gd's _ready).
# Callers hold the returned dict and pass it back to play_merge / slide_and_land.
static func opts_from_config(cfg: Dictionary) -> Dictionary:
	return {
		"merge": MergeFx.from_config(cfg),
		"move": MoveFx.from_config(cfg),
		"land": LandFx.from_config(cfg),
	}

# The board-scale cues that only make sense on the full-screen grid — screen shake, the board punch, the
# grove-scale world puff, and the floating milestone word. A dialog grid mutes these and keeps the
# piece-local celebration (squash / burst / flash / hitstop / sound).
const _DIALOG_MUTED := ["board_punch", "shake", "world_puff", "combo_words"]

static func merge_opts_for(opts: Dictionary, dialog: bool) -> Dictionary:
	var m: Dictionary = opts.get("merge", {})
	if not dialog:
		return m
	var trimmed: Dictionary = m.duplicate(true)
	for k in _DIALOG_MUTED:
		trimmed[k] = false
	return trimmed

## The merge IMPACT on a produced tile centred in its cell: squash / flash / hitstop / burst / sound
## (+ neighbour ripple + board punch on the full board). `host` parents the effects and is the shake/
## punch target; `neighbors` is the orthogonal-neighbour node list (`[]` on a flex grid). `dialog` mutes
## the board-scale cues. `intensified` forces the pinnacle feel (special/recipe lines).
static func play_merge(host: Control, node: Control, center: Vector2, tier: int, combo: int,
		neighbors: Array, opts: Dictionary, dialog := false, intensified := false) -> void:
	MergeFx.apply(host, node, center, tier, combo, neighbors, host,
		merge_opts_for(opts, dialog), 1.0, 0, intensified)

## Slide `node` from its current position to `to_pos`, then land it (squash + dust + flash + land sound +
## neighbour ripple). Returns the tween. Used when a grid has real cell coordinates to move between.
static func slide_and_land(host: Control, node: Control, to_pos: Vector2, land_ctr: Vector2,
		neighbors: Array, opts: Dictionary, slide_ms := 120) -> Tween:
	if node == null or not is_instance_valid(node):
		return null
	var t := node.create_tween()
	t.tween_property(node, "position", to_pos, float(slide_ms) / 1000.0) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_callback(LandFx.apply.bind(host, node, land_ctr, opts.get("land", {}), 1.0, false, neighbors))
	return t
