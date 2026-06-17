extends RefCounted
## §7 fence COMPOSITION — the decisions board.gd makes about WHICH quests sit on the live
## giver fence, lifted off the scene so they are headless-testable. Pure statics: state comes
## in (the grove's unlocks/gates, the board's live generators, banked stars, level, rng) and a
## quests Array comes out. The quest ENGINE (gen_quest / gate_quest / active_giver_count) and
## all tuning live in content.gd (G); this layer only orchestrates it. board.gd keeps thin
## Save-reading wrappers (_quest_map / _refill_quests / _gate_pending / …) over these.
## Layering: core/ never imports ui/ or scenes/ — see docs/design/merge_spec.md §15.

const G = preload("res://engine/scripts/core/content.gd")

# The map currently being restored (its generators/lines are live). Clamped to a valid map.
static func current_map(unlocks: Dictionary, gates: Array) -> int:
	return clampi(G.frontier_map(unlocks, gates), 0, G.MAPS.size() - 1)

# Every map fully complete (spots + gate) — no frontier left.
static func map_done(unlocks: Dictionary, gates: Array) -> bool:
	return G.frontier_map(unlocks, gates) == -1

# Current map fully spot-restored but its great-spirit GATE not yet delivered? Then the gate
# quest is the lone fence stand (§7) — delivering it unlocks the next map.
static func gate_pending(z: int, unlocks: Dictionary, gates: Array) -> bool:
	return G.map_spots_done(z, unlocks) and not gates.has(z)

# The soft gate (§7): how many stands the fence shows, metered to the current map's next spot.
static func meter_target(z: int, banked_stars: int, unlocks: Dictionary, level: int) -> int:
	return G.active_giver_count(banked_stars, G.map_cheapest_spot(z, unlocks, level))

# The restore CTA: ready once the CURRENT map's cheapest level-affordable spot is affordable.
static func gate_ready(z: int, banked_stars: int, unlocks: Dictionary, level: int) -> bool:
	var cost := G.map_cheapest_spot(z, unlocks, level)
	return cost > 0 and banked_stars >= cost

# §6: the current map's generator-grant hand-ins not yet claimed — each asks for a previous-map
# generator (still on the board) and rewards a new line. The map opens with these before its
# regular stream; once handed in, the new generators are live and regular quests resume.
static func pending_grant_quests(z: int, board_gens: Dictionary) -> Array:
	var out: Array = []
	for q in G.grant_quests_for_map(G.GENERATORS, z):
		var gid := String(q.grant.grants)
		if not board_gens.values().has(gid) and G.gen_can_grant(board_gens, G.GENERATORS, gid):
			out.append(q)
	return out

# Top up / trim the live fence to the metered count with freshly generated quests (§7); once the
# map is fully restored, the fence becomes the lone authored GATE quest. Deterministic via `rng` —
# RNG CALL ORDER IS LOAD-BEARING (the rng is seeded + persisted): the filter takes no rng, then
# gen_quest is drawn once per appended stand, in order. Returns the new quests array.
static func refill(quests: Array, z: int, unlocks: Dictionary, gates: Array, board_gens: Dictionary, banked_stars: int, level: int, rng: RandomNumberGenerator) -> Array:
	if map_done(unlocks, gates):
		return []
	if gate_pending(z, unlocks, gates):
		if quests.size() != 1 or not bool(quests[0].get("gate", false)):
			return [G.gate_quest(G.GENERATORS, z, rng)]
		return quests
	var out: Array = quests.filter(func(q): return not bool(q.get("gate", false)) and not q.has("grant"))
	# §6 anchor exemption: ask from the current map's lines ∪ the anchor's lines (its generator
	# never retires, so its lines stay askable past their debut map) — NOT the bare map roster.
	# `level` also gates a not-yet-grown generator's lines out (a delayed second generator's lines
	# stay un-askable until it appears, so the fence never asks for what nothing can produce).
	var lines := G.askable_lines(G.GENERATORS, z, level)
	var target := meter_target(z, banked_stars, unlocks, level)
	# §6/§7: a new map opens with a generator-grant hand-in, and extra grants surface ONE AT A
	# TIME (spread through the map, not all upfront) — the regular generated stream fills the slots
	# between. The lead grant always shows while pending (it is how the new line arrives — it leads
	# the fence and reserves one slot, never metered away by the soft gate). With no grants pending
	# (every map ≤ the shipped grove) this is byte-identical to the plain metered fill.
	var pend := pending_grant_quests(z, board_gens)
	var regular_target := maxi(0, target - 1) if not pend.is_empty() else target
	while out.size() < regular_target:
		out.append(G.gen_quest(level, lines, rng))
	while out.size() > regular_target:
		out.pop_back()
	if not pend.is_empty():
		return [pend[0]] + out                # the hand-in leads; the generated stream fills the rest
	return out

# The discovery ladder for a line: one row per tier, code = line*100+tier, with `seen` flagged
# from the save's `seen` set (keyed by the string code, as written on merge).
static func ladder_entries(seen: Dictionary, line: int) -> Array:
	var out: Array = []
	for t in range(1, G.TOP_TIER + 1):
		var code := line * 100 + t
		out.append({"tier": t, "code": code, "seen": seen.has(str(code))})
	return out

# Reward readers — the new {reward:{stars,coins,gems}} shape, falling back to the flat legacy key.
static func stars(q: Dictionary) -> int:
	return int(q.reward.stars) if q.has("reward") else int(q.get("stars", 0))

static func coins(q: Dictionary) -> int:
	return int(q.reward.coins) if q.has("reward") else 0

# §7 featured premium: the occasional 💎 bonus on a featured quest (0 on a normal one).
static func gems(q: Dictionary) -> int:
	return int(q.reward.get("gems", 0)) if q.has("reward") else 0
