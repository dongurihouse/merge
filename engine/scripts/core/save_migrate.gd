extends RefCounted
## Load-time SAVE HYGIENE — the sanitizers + the above-level content purge the board runs on every
## load, lifted off the scene so they are headless-testable (this is the code most likely to silently
## eat a player's save, and it used to be reachable only by booting a whole Control).
## STATELESS statics: the raw saved data comes in (arrays, the grove dict, a BoardModel) and a verdict
## comes out. Anything mutated is mutated THROUGH an argument — never scene state, never Save itself;
## the scene reads Save, calls these, and re-persists when they report `changed`.
## Layering: core/ never imports ui/ or scenes/ — see docs/design/merge_spec.md §15.

const G = preload("res://engine/scripts/core/content.gd")
const BoardModel = preload("res://engine/scripts/core/board_model.gd")

# --- sanitizers: drop saved data the current content roster no longer knows ----------------------

# The stashed item bag, minus any code that is not a valid item today. {items, changed}.
static func sanitize_item_bag(raw: Array) -> Dictionary:
	var out: Array = []
	var changed := false
	for v in raw:
		var code := int(v)
		if code > 0 and G.is_valid_item_code(code):
			out.append(code)
		else:
			changed = true
	return {"items": out, "changed": changed}

# Every item a quest asks for still exists in the roster. Handles BOTH quest shapes: a single
# {line, tier} ask, or an `asks[]` list.
static func quest_items_are_known(q: Dictionary) -> bool:
	if q.has("line"):
		return G.is_valid_item_code(int(q.get("line", 0)) * 100 + int(q.get("tier", 0)))
	if q.has("asks"):
		for ask in Array(q.get("asks", [])):
			if not (ask is Dictionary):
				continue
			if not G.is_valid_item_code(int(ask.get("line", 0)) * 100 + int(ask.get("tier", 0))):
				return false
	return true

# The saved fence, minus non-dictionaries and quests asking for items the roster dropped. {quests, changed}.
static func sanitize_quests(raw: Array) -> Dictionary:
	var out: Array = []
	var changed := false
	for q in raw:
		if not (q is Dictionary):
			changed = true
			continue
		var qd: Dictionary = q
		if not quest_items_are_known(qd):
			changed = true
			continue
		out.append(qd)
	return {"quests": out, "changed": changed}

# The discovery set, minus non-integer keys and codes that are no longer valid items. MUTATES `g`
# in place (the grove save dict) and returns true if anything was dropped (→ the caller re-persists).
static func sanitize_seen(g: Dictionary) -> bool:
	if not g.has("seen"):
		return false
	if not (g["seen"] is Dictionary):
		g["seen"] = {}
		return true
	var seen: Dictionary = g["seen"]
	var out := {}
	var changed := false
	for key in seen.keys():
		var sk := String(key)
		if not sk.is_valid_int():
			changed = true
			continue
		var code := int(sk)
		if not G.is_valid_item_code(code):
			changed = true
			continue
		out[sk] = seen[key]
	if changed:
		g["seen"] = out
	return changed

# --- the above-level content purge ---------------------------------------------------------------

# A saved quest asks for a line the player should not have reached yet (either its single `line`, or any
# `asks[]` entry) — see G.line_gated_out. Mirrors quest_items_are_known's dual shape.
static func quest_line_gated_out(q: Dictionary, level: int) -> bool:
	if q.has("line") and G.line_gated_out(int(q.get("line", 0)), level):
		return true
	for ask in Array(q.get("asks", [])):
		if ask is Dictionary and G.line_gated_out(int((ask as Dictionary).get("line", 0)), level):
			return true
	return false

# Save migration (2026-07-23, scene-aligned zone_unlock_level cadence — now DERIVED, see content.gd's
# _build_cadence): strip every generator, item and quest for a line the player should NOT have reached
# yet at their CURRENT level, so an older save matches
# the new pacing. Silent removal, no compensation (owner call). IDEMPOTENT — a no-op on any save already
# consistent with the cadence (birth-on-tap only ever grants in-cadence content; every new save starts
# clean), so it runs on every load with no schema bump and no one-time flag. Exempt (never gated out):
# coins, treasure/treat lines and special drops (zone_of_line == -1), accumulator generators, and the gen_1
# anchor (zone 0 unlocks at L1).
# `board` is mutated in place; the filtered `bag`/`quests` come back in the result. Returns
# {changed, bag, quests} — `changed` is true if anything was removed (→ the caller re-persists).
static func purge_above_level_content(board: BoardModel, bag: Array, quests: Array, lvl: int) -> Dictionary:
	var changed := false
	# board pieces
	for r in G.ROWS:
		for c in G.COLS:
			var cell := Vector2i(r, c)
			var code := board.item_at(cell)
			if code > 0 and G.line_gated_out(BoardModel.line_of(code), lvl):
				board.take(cell)
				changed = true
	# live generators on the board (accumulators + the anchor never gate out)
	for cell in board.gens.keys():
		var gid := String(board.gens[cell])
		if not G.is_accumulator(gid) and G.line_gated_out(int(G.gen_def(G.GENERATORS, gid).get("line", 0)), lvl):
			board.remove_gen(cell)
			changed = true
	# stored generators — filter the PARALLEL bag arrays (ids ∥ tiers ∥ boost) in lockstep
	var kept_ids: Array = []
	var kept_tiers: Array = []
	var kept_boost: Array = []
	for i in board.gen_bag.size():
		var gid := String(board.gen_bag[i])
		if not G.is_accumulator(gid) and G.line_gated_out(int(G.gen_def(G.GENERATORS, gid).get("line", 0)), lvl):
			changed = true
			continue
		kept_ids.append(board.gen_bag[i])
		kept_tiers.append(board.gen_bag_tiers[i] if i < board.gen_bag_tiers.size() else 1)
		kept_boost.append(board.gen_bag_boost[i] if i < board.gen_bag_boost.size() else 0)
	board.gen_bag = kept_ids
	board.gen_bag_tiers = kept_tiers
	board.gen_bag_boost = kept_boost
	# stashed items in the item bag. `bag_kept` is the SURVIVING INDICES into the incoming bag, so a
	# caller can filter its own PARALLEL arrays (the scene's bag_seed_ranks) in lockstep without
	# re-deriving the gate rule here.
	var kept_bag: Array = []
	var bag_kept: Array = []
	for i in bag.size():
		if G.line_gated_out(BoardModel.line_of(int(bag[i])), lvl):
			changed = true
		else:
			kept_bag.append(bag[i])
			bag_kept.append(i)
	# live quests asking for a now-too-advanced line (the fence refills with valid lines after)
	var kept_quests: Array = []
	for q in quests:
		if q is Dictionary and quest_line_gated_out(q, lvl):
			changed = true
		else:
			kept_quests.append(q)
	return {"changed": changed, "bag": kept_bag, "bag_kept": bag_kept, "quests": kept_quests}
