extends RefCounted
## Every cascade-guide display rule, in ONE pure place. board.gd hands over the board, the mode and
## the mode's context; this returns the ORDERED mark list the renderer draws, first mark furthest
## back. Nothing here touches a node, so the whole rule set is testable with no scene.
##
## The mode is DERIVED by the caller from state it already holds, never stored: that is what makes
## "a resting recomputation erases the running cascade's glow" unrepresentable — REST and RUN can no
## longer both be true, and there is only one field to write.
##
## Layering: core/ never imports ui/ or scenes/ — see docs/design/merge_spec.md §15.

const BoardModel = preload("res://engine/scripts/core/board_model.gd")
const BoardLogic = preload("res://engine/scripts/core/board_logic.gd")

const MODE_REST := 0
const MODE_DRAG := 1
const MODE_RUN := 2

const NO_CELL := Vector2i(-1, -1)

## Owner-facing knobs. REST_MAX and DRAG_DIM are new; the other three are today's `strength` and
## `reach` literals moved here unchanged, so this refactor re-tunes nothing.
const REST_MAX := 3                  # resting marks drawn at once, chains before runways
const DRAG_DIM := 0.35               # weight of every non-winning mark while a piece is held
const RUNWAY_WEIGHT := 0.50
const RUNWAY_REACH := 0.78
const MERGE_WEIGHT := 0.55

## One constructor, so every mark carries every key and no reader needs a default.
static func mark(role: String, run: Array, cell: Vector2i, line: int, n: int,
		weight: float, reach: float, tag: bool, tag_cell: Vector2i) -> Dictionary:
	return {
		"role": role, "run": run, "cell": cell, "line": line, "n": n,
		"weight": weight, "reach": reach, "tag": tag, "tag_cell": tag_cell,
	}

static func build(board, ctx: Dictionary) -> Array:
	if board == null:
		return []
	return _rest_marks(board, ctx)

# --- REST -------------------------------------------------------------------------------------
# Every armed chain, longest first, then every runway, truncated to REST_MAX. The cap is over the
# combined list on purpose: it is a budget for how much the resting board may say at once.
static func _rest_marks(board, ctx: Dictionary) -> Array:
	var out: Array = []
	for entry in _rest_chains(board, int(ctx.get("chain_min_n", 2))):
		var e: Dictionary = entry
		var top := Vector2i(e.get("top_cell", NO_CELL))
		out.append(mark("chain", _run_of(e), NO_CELL, int(e.get("line", 0)), int(e.get("n", 0)),
			1.0, 1.0, true, top))
	for raw in BoardLogic.runways(board, int(ctx.get("runway_min_n", 3))):
		if raw is Dictionary:
			var e: Dictionary = raw
			out.append(mark("runway", _run_of(e), NO_CELL, int(e.get("line", 0)), 0,
				RUNWAY_WEIGHT, RUNWAY_REACH, false, NO_CELL))
	return out.slice(0, REST_MAX)

## The armed chains, longest first. The comparator carries its own row-major tie-break because
## sort_custom is NOT stable in Godot — relying on ready_ladders' own ordering to survive the sort
## would make the tie-break depend on the sort's internals.
static func _rest_chains(board, min_n: int) -> Array:
	var chains: Array = []
	for raw in BoardLogic.ready_ladders(board):
		if raw is Dictionary and int((raw as Dictionary).get("n", 0)) >= min_n:
			chains.append((raw as Dictionary).duplicate(true))
	chains.sort_custom(func(a, b) -> bool:
		var na := int((a as Dictionary).get("n", 0))
		var nb := int((b as Dictionary).get("n", 0))
		if na != nb:
			return na > nb
		return BoardModel.idx(Vector2i((a as Dictionary).get("top_cell", Vector2i.ZERO))) \
			< BoardModel.idx(Vector2i((b as Dictionary).get("top_cell", Vector2i.ZERO)))
	)
	return chains

## The cells the light follows: the cascade's own run, never the same-line flood fill in `cells`.
static func _run_of(entry: Dictionary) -> Array:
	var run := Array(entry.get("run", []))
	return run.duplicate() if not run.is_empty() else Array(entry.get("cells", [])).duplicate()
