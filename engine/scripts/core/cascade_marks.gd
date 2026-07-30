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

## THE ONE RULE, and there is no other: a chain is marked if and only if its run is GUIDE_MIN_N cells
## or longer. It holds in every mode — a ×2 gets no resting telegraph, is not a drag's chain winner,
## and lights nothing while it runs. Brightness used to encode "will this fire", which read as
## "how important" and made a 3-cell hint look weaker than a 2-cell one; now there is one strength.
##
## This is DISPLAY ONLY. board.gd's CHAIN_MIN_N still governs whether a cascade actually fires, and a
## ×2 still cascades — it is simply not advertised beforehand.
const GUIDE_MIN_N := 3

## Owner-facing knobs. DRAG_DIM and MERGE_WEIGHT are today's display weights. A drag keeps the
## previous three-entry budget for unrelated already-armed ladders; REST itself is uncapped.
const DRAG_BACKGROUND_MAX := 3
const DRAG_DIM := 0.35               # weight of every non-winning mark while a piece is held
const MERGE_WEIGHT := 0.55

## One constructor, so every mark carries every key and no reader needs a default.
static func mark(role: String, run: Array, cell: Vector2i, line: int, n: int,
		weight: float, reach: float, tag: bool, tag_cell: Vector2i) -> Dictionary:
	return {
		"role": role, "run": run, "cell": cell, "line": line, "n": n,
		"weight": weight, "reach": reach, "tag": tag, "tag_cell": tag_cell,
	}

## THE CHAIN EFFECT STACK, and there is only one. A chain is the contour glow over its whole run,
## the target bloom on run[0], and the ×n chip on that same cell — in that order, so the bloom sits
## over the contour. Every mode builds its chains through here, so "how loud" is the ONLY thing a
## mode may vary: pass a lower `weight` and the same effect is turned down, never swapped for
## another one. That is the bug this replaces — only a DRAG used to emit the bloom, so the resting
## and mid-run chains were a second, far fainter effect nobody chose.
##
## run[0] is the same semantic everywhere: the cell the tipping merge lands on. `BoardLogic._run_cells`
## returns `[to] + path`, RUN's own cells are `[head] + remaining`, and a drag winner's run is
## `[winner cell] + chain_path` — so this asks nothing new of any caller.
##
## GUIDE_MIN_N is enforced HERE as well as at the two places a chain is selected, so a chain shorter
## than the floor cannot be constructed by any mode, present or future — the rule is a property of
## the effect stack, not a filter each caller has to remember to apply.
static func chain_stack(run: Array, line: int, n: int, weight: float, tag: bool) -> Array:
	if run.is_empty() or n < GUIDE_MIN_N:
		return []
	var head := Vector2i(run[0])
	return [
		mark("chain", run, NO_CELL, line, n, weight, 1.0, false, NO_CELL),
		mark("target", [], head, line, n, weight, 1.0, tag, head if tag else NO_CELL),
	]

static func build(board, ctx: Dictionary) -> Array:
	if board == null:
		return []
	match int(ctx.get("mode", MODE_REST)):
		MODE_RUN:
			return _run_marks(board, ctx)
		MODE_DRAG:
			return _drag_marks(board, ctx)
		_:
			return _rest_marks(board, ctx)

# --- REST -------------------------------------------------------------------------------------
# Every actionable chain at or above GUIDE_MIN_N, longest first.
static func _rest_marks(board, ctx: Dictionary) -> Array:
	var out: Array = []
	for raw in _rest_entries(board):
		out.append_array(_rest_entry_marks(raw as Dictionary, 1.0, true))
	return out

## What the resting board has to say: every legal piece-to-piece merge whose resulting run meets the
## guide floor. DRAG already answers that question for one held piece through `_merge_targets`; REST
## asks it for every occupied source. Equivalent sources can describe the same target and contour,
## so those visual duplicates collapse before the deterministic longest-first sort.
static func _rest_entries(board) -> Array:
	var occupied: Array = []
	for i in board.items.size():
		if int(board.items[i]) > 0:
			occupied.append(BoardModel.cell_of(i))
	var chains: Array = []
	for raw_from in occupied:
		var from := Vector2i(raw_from)
		var line := BoardModel.line_of(board.item_at(from))
		for raw_target in _merge_targets(board, from, occupied):
			var target: Dictionary = raw_target
			var n := int(target.get("n", 0))
			if n < GUIDE_MIN_N:
				continue
			var cell := Vector2i(target.get("cell", NO_CELL))
			var run: Array = [cell]
			for raw_cell in Array(target.get("path", [])):
				run.append(Vector2i(raw_cell))
			var duplicate := false
			for raw_existing in chains:
				var existing: Dictionary = raw_existing
				if Vector2i(existing.get("cell", NO_CELL)) == cell \
						and _same_cells(Array(existing.get("run", [])), run):
					duplicate = true
					break
			if duplicate:
				continue
			chains.append({
				"from": from,
				"cell": cell,
				"path": Array(target.get("path", [])).duplicate(),
				"run": run,
				"line": line,
				"n": n,
			})
	chains.sort_custom(func(a, b) -> bool:
		var na := int((a as Dictionary).get("n", 0))
		var nb := int((b as Dictionary).get("n", 0))
		if na != nb:
			return na > nb
		var ac := BoardModel.idx(Vector2i((a as Dictionary).get("cell", Vector2i.ZERO)))
		var bc := BoardModel.idx(Vector2i((b as Dictionary).get("cell", Vector2i.ZERO)))
		if ac != bc:
			return ac < bc
		return BoardModel.idx(Vector2i((a as Dictionary).get("from", Vector2i.ZERO))) \
			< BoardModel.idx(Vector2i((b as Dictionary).get("from", Vector2i.ZERO)))
	)
	return chains

## One resting entry, at the loudness the caller is drawing it. REST and the background of a DRAG
## both come through here, so a dimmed chain is this same stack at DRAG_DIM.
static func _rest_entry_marks(entry: Dictionary, weight: float, tag: bool) -> Array:
	return chain_stack(_run_of(entry), int(entry.get("line", 0)), int(entry.get("n", 0)), weight, tag)

## The armed chains, longest first. The comparator carries its own row-major tie-break because
## sort_custom is NOT stable in Godot — relying on ready_ladders' own ordering to survive the sort
## would make the tie-break depend on the sort's internals.
##
## `min_n` stays a PARAMETER even though the guide has one rule: the staging-pad component list
## (`_extension_pads`) is a different consumer with a different floor — board.gd's CHAIN_MIN_N — and
## the owner kept those pads exactly as they are. The mark path passes GUIDE_MIN_N; the pad path
## passes the caller's. Hard-coding the floor here would move the pads.
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

static func _drag_background_entries(board) -> Array:
	return _rest_chains(board, GUIDE_MIN_N).slice(0, DRAG_BACKGROUND_MAX)

## The cells the light follows: the cascade's own run, never the same-line flood fill in `cells`.
static func _run_of(entry: Dictionary) -> Array:
	var run := Array(entry.get("run", []))
	return run.duplicate() if not run.is_empty() else Array(entry.get("cells", [])).duplicate()

# --- RUN --------------------------------------------------------------------------------------
# While a cascade is walking, the run OWNS the display: one mark, the head plus everything still to
# come, for the whole run. It reads only the caller's context — never ready_ladders — because a
# mid-chain board has no armed ladder of its own, and consulting it is exactly what used to erase
# this glow one beat after the first automatic step.
static func _run_marks(board, ctx: Dictionary) -> Array:
	var head := Vector2i(ctx.get("head", NO_CELL))
	var remaining := Array(ctx.get("run", []))
	# The head ALONE is still a mark. On the run's last step there is nothing left to walk, and the
	# light belongs on the cell the merge is landing in until the run itself ends — the mark is
	# republished at every step until _finish_chain, so the only thing that ends it is the run ending.
	if head.x < 0:
		return []
	var cells: Array = [head]
	for raw in remaining:
		cells.append(Vector2i(raw))
	var n := int(ctx.get("n", cells.size()))
	# cells[0] IS the head, so the stack's bloom and chip land on the cell this step's merge is
	# landing in — the same place a drag puts them, because it is the same cell.
	return chain_stack(cells, BoardModel.line_of(board.item_at(head)), n, 1.0, true)

# --- DRAG -------------------------------------------------------------------------------------
# ONE place for the eye. Of everything the held piece could do, the LONGEST chain it would form is
# the answer, so that target alone is loud and carries the ×n; every other chain and merge target is
# dimmed to DRAG_DIM. A held piece that forms no chain THE ONE RULE ADMITS draws no chain light —
# a ×2 drop is an ordinary merge target here, at MERGE_WEIGHT and with no ×n — only its plain merge
# targets and the staging pads.
#
# These marks depend on the HELD PIECE, never on the pointer, so board.gd builds them once at
# pickup. Nothing here re-runs inside the gesture.
static func _drag_marks(board, ctx: Dictionary) -> Array:
	var from := Vector2i(ctx.get("from", NO_CELL))
	var code := int(ctx.get("code", 0))
	if from.x < 0 or code <= 0:
		return []
	var line := BoardModel.line_of(code)
	var targets := _merge_targets(board, from, Array(ctx.get("targets", [])))
	# The winner is decided by the GUIDE's floor, never the caller's arming floor: a ×2 drop is not
	# the drag's answer, so it falls through to the plain merge target below and the staging pads stay.
	var win := _winner_index(targets, GUIDE_MIN_N)
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
	# Background first: the resting marks this drag is NOT about, each turned DOWN rather than turned
	# into something else — a dimmed chain keeps its bloom, so it stays the same effect at DRAG_DIM.
	# The skip is per ENTRY, not per mark: the winner's own resting stack goes entirely, or its bloom
	# would be stamped twice on the winning cell.
	for raw in _drag_background_entries(board):
		var entry: Dictionary = raw
		if _same_cells(_run_of(entry), win_run):
			continue
		out.append_array(_rest_entry_marks(entry, DRAG_DIM, false))
	# The winner's own stack, split around the losing targets so its bloom is emitted LAST and draws
	# on top of them. Same two marks as everywhere else, in the same order.
	var stack := chain_stack(win_run, line, int(winner.get("n", GUIDE_MIN_N)), 1.0, true)
	out.append(stack[0])
	for i in targets.size():
		if i == win:
			continue
		var t: Dictionary = targets[i]
		out.append(mark("target", [], Vector2i(t.get("cell", NO_CELL)), line,
			int(t.get("n", 1)), DRAG_DIM, 1.0, false, NO_CELL))
	out.append(stack[1])
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
