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
	match int(ctx.get("mode", MODE_REST)):
		MODE_DRAG:
			return _drag_marks(board, ctx)
		_:
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

# --- DRAG -------------------------------------------------------------------------------------
# ONE place for the eye. Of everything the held piece could do, the LONGEST chain it would form is
# the answer, so that target alone is loud and carries the ×n; every other chain, runway and merge
# target is dimmed to DRAG_DIM. A held piece that forms no chain at all draws no chain light —
# only its plain merge targets and the staging pads.
#
# These marks depend on the HELD PIECE, never on the pointer, so board.gd builds them once at
# pickup. Nothing here re-runs inside the gesture.
static func _drag_marks(board, ctx: Dictionary) -> Array:
	var from := Vector2i(ctx.get("from", NO_CELL))
	var code := int(ctx.get("code", 0))
	if from.x < 0 or code <= 0:
		return []
	var min_n := int(ctx.get("chain_min_n", 2))
	var line := BoardModel.line_of(code)
	var targets := _merge_targets(board, from, Array(ctx.get("targets", [])))
	var win := _winner_index(targets, min_n)
	var out: Array = []
	if win < 0:
		for raw in targets:
			var t: Dictionary = raw
			out.append(mark("target", [], Vector2i(t.get("cell", NO_CELL)), line,
				int(t.get("n", 1)), MERGE_WEIGHT, 1.0, false, NO_CELL))
		out.append_array(_stage_marks(board, ctx, from, code, _occupied_of(targets)))
		return out
	var winner: Dictionary = targets[win]
	var win_cell := Vector2i(winner.get("cell", NO_CELL))
	var win_run: Array = [win_cell]
	for raw in Array(winner.get("path", [])):
		win_run.append(Vector2i(raw))
	# background first: the resting marks this drag is NOT about
	for raw in _rest_marks(board, ctx):
		var m: Dictionary = (raw as Dictionary).duplicate(true)
		if _same_cells(Array(m.get("run", [])), win_run):
			continue
		m["weight"] = DRAG_DIM
		m["tag"] = false
		m["tag_cell"] = NO_CELL
		out.append(m)
	out.append(mark("chain", win_run, NO_CELL, line, int(winner.get("n", min_n)), 1.0, 1.0, false, NO_CELL))
	for i in targets.size():
		if i == win:
			continue
		var t: Dictionary = targets[i]
		out.append(mark("target", [], Vector2i(t.get("cell", NO_CELL)), line,
			int(t.get("n", 1)), DRAG_DIM, 1.0, false, NO_CELL))
	out.append(mark("target", [], win_cell, line, int(winner.get("n", min_n)), 1.0, 1.0, true, win_cell))
	return out

## Every occupied cell the held piece can merge onto, row-major, with the chain length that merge
## would run. `candidates` is the caller's list because it comes from the rendered pieces.
static func _merge_targets(board, from: Vector2i, candidates: Array) -> Array:
	var out: Array = []
	for raw in candidates:
		var t := Vector2i(raw)
		if t == from or not board.can_merge(from, t):
			continue
		var path := BoardLogic.chain_path(board, from, t)
		out.append({"cell": t, "n": 1 + path.size(), "path": path})
	out.sort_custom(func(a, b) -> bool:
		return BoardModel.idx(Vector2i((a as Dictionary).get("cell", Vector2i.ZERO))) \
			< BoardModel.idx(Vector2i((b as Dictionary).get("cell", Vector2i.ZERO)))
	)
	return out

## The longest chain, ties going to the row-major first — `>` and a row-major-sorted input, so the
## tie-break is the input's order and not the comparison's.
static func _winner_index(targets: Array, min_n: int) -> int:
	var win := -1
	for i in targets.size():
		var n := int((targets[i] as Dictionary).get("n", 0))
		if n < min_n:
			continue
		if win < 0 or n > int((targets[win] as Dictionary).get("n", 0)):
			win = i
	return win

static func _occupied_of(targets: Array) -> Dictionary:
	var out := {}
	for raw in targets:
		out[Vector2i((raw as Dictionary).get("cell", NO_CELL))] = true
	return out

static func _same_cells(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	var seen := {}
	for raw in a:
		seen[Vector2i(raw)] = true
	for raw in b:
		if not seen.has(Vector2i(raw)):
			return false
	return true

# --- the staging pads -------------------------------------------------------------------------
# The empty-cell staging marks: "put it here and the ladder grows". Three generators, exactly as
# they behaved before this refactor — the placements the held code improves, the pads that extend
# an existing component, and the seeds beside a lone one-tier-off neighbour. They are emitted ONLY
# when no chain target won, which is today's `if not fires` rule.
static func _stage_marks(board, ctx: Dictionary, from: Vector2i, code: int, occupied: Dictionary) -> Array:
	var out: Array = []
	var line := BoardModel.line_of(code)
	var seen := occupied.duplicate()
	var min_n := int(ctx.get("chain_min_n", 2))
	for raw in BoardLogic.chain_placements(board, from, code):
		if not (raw is Dictionary):
			continue
		# today's board.gd filter: a staging pad below the threshold advertises nothing
		if int((raw as Dictionary).get("n", 0)) < min_n:
			continue
		var cell := Vector2i((raw as Dictionary).get("cell", NO_CELL))
		if cell.x < 0 or seen.has(cell):
			continue
		seen[cell] = true
		out.append(mark("stage", [], cell, line, 0, 1.0, 1.0, false, NO_CELL))
	for raw in _extension_pads(board, from, code, seen, min_n, int(ctx.get("runway_min_n", 3))):
		var cell := Vector2i((raw as Dictionary).get("cell", NO_CELL))
		if cell.x < 0 or seen.has(cell):
			continue
		seen[cell] = true
		out.append(mark("stage", [], cell, line, 0, 1.0, 1.0, false, NO_CELL))
	return out

## Moved verbatim from board.gd's `_cascade_extension_pads`: the empty cells that would extend an
## armed ladder or a runway of the held line, plus the lone-neighbour seeds, deduped and row-major.
## `chain_min_n` / `runway_min_n` arrive from the caller because the thresholds live in board.gd.
static func _extension_pads(board, from: Vector2i, code: int, occupied: Dictionary,
		chain_min_n: int, runway_min_n: int) -> Array:
	var out: Array = []
	var line := BoardModel.line_of(code)
	var components: Array = []
	for raw in _rest_chains(board, chain_min_n):
		if raw is Dictionary and int((raw as Dictionary).get("line", 0)) == line:
			components.append({"cells": _run_of(raw as Dictionary), "line": line})
	for raw in BoardLogic.runways(board, runway_min_n):
		if raw is Dictionary and int((raw as Dictionary).get("line", 0)) == line:
			components.append({"cells": _run_of(raw as Dictionary), "line": line})
	var seen := {}
	for comp in components:
		for entry in _extension_pads_for_component(board, from, code, Array((comp as Dictionary).get("cells", [])), occupied):
			var cell := Vector2i((entry as Dictionary).get("cell", NO_CELL))
			if cell.x < 0 or seen.has(cell):
				continue
			seen[cell] = true
			out.append(entry)
	for entry in _single_neighbor_seed_pads(board, from, code, occupied):
		var cell := Vector2i((entry as Dictionary).get("cell", NO_CELL))
		if cell.x < 0 or seen.has(cell):
			continue
		seen[cell] = true
		out.append(entry)
	out.sort_custom(func(a, b): return BoardModel.idx(Vector2i((a as Dictionary).get("cell", Vector2i.ZERO))) < BoardModel.idx(Vector2i((b as Dictionary).get("cell", Vector2i.ZERO))))
	return out

static func _single_neighbor_seed_pads(board, from: Vector2i, code: int, occupied: Dictionary) -> Array:
	var out: Array = []
	if board == null or code <= 0:
		return out
	var line := BoardModel.line_of(code)
	var held_tier := BoardModel.tier_of(code)
	for i in board.items.size():
		var base := BoardModel.cell_of(i)
		if base == from:
			continue
		var item := int(board.items[i])
		if item <= 0 or BoardModel.line_of(item) != line:
			continue
		var tier := BoardModel.tier_of(item)
		if tier != held_tier - 1 and tier != held_tier + 1:
			continue
		for raw_d in BoardLogic.ORTHO_DIRS:
			var cell := base + Vector2i(raw_d)
			if not _can_show_extension_pad(board, cell, from, occupied):
				continue
			out.append({"cell": cell, "line": line, "kind": "stage"})
	return out

static func _extension_pads_for_component(board, from: Vector2i, code: int, cells: Array, occupied: Dictionary) -> Array:
	var out: Array = []
	if cells.is_empty():
		return out
	var held_tier := BoardModel.tier_of(code)
	var min_tier := 9999
	var max_tier := -1
	for raw in cells:
		var tier := BoardModel.tier_of(board.item_at(Vector2i(raw)))
		min_tier = mini(min_tier, tier)
		max_tier = maxi(max_tier, tier)
	var edge_tier := -1
	if held_tier == min_tier - 1:
		edge_tier = min_tier
	elif held_tier == max_tier + 1:
		edge_tier = max_tier
	else:
		return out
	for raw in cells:
		var base := Vector2i(raw)
		if BoardModel.tier_of(board.item_at(base)) != edge_tier:
			continue
		for raw_d in BoardLogic.ORTHO_DIRS:
			var cell := base + Vector2i(raw_d)
			if not _can_show_extension_pad(board, cell, from, occupied):
				continue
			out.append({"cell": cell, "line": BoardModel.line_of(code), "kind": "stage"})
	return out

static func _can_show_extension_pad(board, cell: Vector2i, from: Vector2i, occupied: Dictionary) -> bool:
	if cell == from or occupied.has(cell) or board == null or not board.in_bounds(cell):
		return false
	if not board.is_empty_ground(cell):
		return false
	return not board.gens.has(cell)
