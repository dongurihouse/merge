extends RefCounted
## §7 fence COMPOSITION — the decisions board.gd makes about WHICH quests sit on the live
## giver fence, lifted off the scene so they are headless-testable. Pure statics: state comes
## in (the grove's unlocks/gates, the board's live generators + gen_bag, banked stars, level,
## rng) and a quests Array comes out. The quest ENGINE (gen_quest / active_giver_count) and all
## tuning live in content.gd (G); this layer only orchestrates it. board.gd keeps thin
## Save-reading wrappers (_quest_map / _refill_quests / …) over these.
## Layering: core/ never imports ui/ or scenes/ — see docs/design/merge_spec.md §15.

const G = preload("res://engine/scripts/core/content.gd")

# The map currently being restored (its generators/lines are live). Clamped to a valid map.
static func current_map(unlocks: Dictionary, gates: Array) -> int:
	return clampi(G.frontier_map(unlocks, gates), 0, G.MAPS.size() - 1)

# The map id the board's Home/Purge jump targets (req 3/4): the LATEST not-fully-unlocked map (the
# frontier — current_map), falling back to the FIRST map once everything is complete (current_map clamps
# frontier_map's -1 → 0). There is always exactly one such map until the whole grove is restored.
static func home_map_id(unlocks: Dictionary, gates: Array) -> String:
	return String(G.MAPS[current_map(unlocks, gates)].id)

# Every map fully complete (spots + gate) — no frontier left.
static func map_done(unlocks: Dictionary, gates: Array) -> bool:
	return G.frontier_map(unlocks, gates) == -1

# §7 fence sizing: how many stands the fence shows, metered to the WHOLE map's remaining stars
# (not the next single spot). The fence stays full and only tapers in the map's final stretch,
# emptying once you've banked enough to finish the map. The "go restore" cue is the breathing
# Home button (gate_ready) — the fence no longer empties at each affordable spot.
static func meter_target(z: int, banked_stars: int, unlocks: Dictionary) -> int:
	return G.active_giver_count(banked_stars, G.map_stars_left(z, unlocks))

# The restore CTA: ready once the CURRENT map's cheapest spot is affordable.
static func gate_ready(z: int, banked_stars: int, unlocks: Dictionary) -> bool:
	var cost := G.map_cheapest_spot(z, unlocks)
	return cost > 0 and banked_stars >= cost

# §7 fence GREY state (req 1): the fence goes INERT — the board renders its quests GREYED + non-interactive
# instead of emptying — once the banked ★ can finish the WHOLE current map (the exact point the active
# meter used to taper to 0). False while the player still needs ★ for the map, and false on a spots-done
# map (left == 0 → that map is complete, never a frontier). The generator-carrier quest stays deliverable
# even here (board.gd keeps out[0] active), so the next map's tools still arrive — see refill().
static func fence_inert(z: int, banked_stars: int, unlocks: Dictionary) -> bool:
	var left := G.map_stars_left(z, unlocks)
	return left > 0 and banked_stars >= left

# The Purge fence card's state. It SHOWS whenever a frontier remains (the map is not done) — no longer
# only when affordable — so it always advertises the home map's current ★ balance. It is READY (full
# colour + breathing) when the banked stars can afford the cheapest remaining unlock; otherwise it greys
# out (still shown, no breathe). `stars` is the banked balance the card displays.
static func purge_state(z: int, banked_stars: int, unlocks: Dictionary, gates: Array) -> Dictionary:
	return {
		"show": not map_done(unlocks, gates),
		"ready": gate_ready(z, banked_stars, unlocks),
		"stars": banked_stars,
	}

# Stars the player still has to EARN to finish map z (its unowned spot costs, minus what is banked).
static func stars_remaining(z: int, unlocks: Dictionary, banked: int) -> int:
	return maxi(0, G.map_stars_left(z, unlocks) - banked)

# The owned generator ids = on the board ∪ stored in the gen_bag.
static func owned_gens(board_gens: Dictionary, gen_bag: Array) -> Array:
	var out: Array = []
	for id in board_gens.values():
		out.append(String(id))
	for id in gen_bag:
		out.append(String(id))
	return out

# Top up / trim the live fence to the metered count with freshly generated quests (§7). Deterministic
# via `rng` — RNG CALL ORDER IS LOAD-BEARING (the rng is seeded + persisted): the filter takes no rng,
# then gen_quest is drawn once per appended stand, in order. Near the END of the map, ONE quest also
# carries `reward.generators` — the NEXT map's unowned generator(s) (the simplest replacement for the
# gate's old "grant the next tool" role); delivering it appends those ids to the gen_bag. Idempotent:
# a quest already carrying the reward is left alone, so a later refill never duplicates it onto a
# second quest. Returns the new quests array.
static func refill(quests: Array, z: int, unlocks: Dictionary, gates: Array, board_gens: Dictionary, gen_bag: Array, banked_stars: int, level: int, rng: RandomNumberGenerator, recent_items: Array = []) -> Array:
	if map_done(unlocks, gates):
		return []
	var out: Array = quests.filter(func(q): return not q.has("grant") and not bool(q.get("gate", false)))
	# Ask only from the current map's live lines (`level` gates a not-yet-grown generator's lines
	# out, so the fence never asks for what nothing on the board can produce yet).
	var lines := G.askable_lines(G.GENERATORS, z, level)
	# req 1: when the bank can already finish the whole map the active meter is 0 — instead of letting the
	# fence empty, fill it to a FULL set the board renders GREYED + inert (so it never goes blank under the
	# lit Purge card). The generator-carrier below still rides out[0] and stays deliverable.
	var target := int(G.MAX_GIVERS) if fence_inert(z, banked_stars, unlocks) else meter_target(z, banked_stars, unlocks)
	while out.size() < target:
		# §7 anti-monotony: steer the new stand off the recent-items window (the last ≤5 item codes just
		# asked) AND the items already on the fence (so the concurrent single-ask stands stay distinct),
		# so a NEW quest never repeats an item from the previous few — a different TIER of the same line
		# still counts as variety. The avoid set is PRIORITY-ORDERED — recent items (oldest→newest) first,
		# then the concurrent fence items LAST, so when the pool is too small to honour the whole window
		# gen_quest relaxes the oldest first and the fence stands stay distinct longest (see gen_quest).
		var avoid: Array = recent_items.duplicate()
		for q in out:
			var it := G.quest_item(q)
			if not it.is_empty():
				avoid.append(int(it.line) * 100 + int(it.tier))
		out.append(G.gen_quest(level, lines, rng, avoid))
	while out.size() > target:
		out.pop_back()
	# near the end of the map, ONE quest also rewards the next generator(s) — idempotent: skip if a
	# quest already carries it (so a later refill never duplicates the reward onto a second quest)
	var already := false
	for q in out:
		if q.has("reward") and q.reward.has("generators"):
			already = true
			break
	var grant := G.gens_to_grant(G.GENERATORS, z, owned_gens(board_gens, gen_bag))
	# INVARIANT: GEN_GRANT_REMAINING_STARS must stay BELOW the cheapest "final remaining spot"
	# cost on every non-final map — otherwise a player could afford that last spot and auto-unlock
	# the next map before this generator-carrier quest ever surfaces, skipping the generator
	# delivery entirely. Today's roster: costliest final spots are 5 > 4 stars, so the grant
	# window (currently 4) always opens first. Any future roster pass must preserve this margin.
	if not already and not grant.is_empty() and stars_remaining(z, unlocks, banked_stars) <= G.GEN_GRANT_REMAINING_STARS and not out.is_empty():
		var q0: Dictionary = out[0].duplicate(true)
		var rw: Dictionary = (q0.get("reward", {}) as Dictionary).duplicate(true)
		rw["generators"] = grant
		q0["reward"] = rw
		out[0] = q0
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
