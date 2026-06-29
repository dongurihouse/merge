extends RefCounted
## §7 fence COMPOSITION — the decisions board.gd makes about WHICH quests sit on the live
## giver fence, lifted off the scene so they are headless-testable. Pure statics: state comes
## in (the grove's unlocks/gates, the board's live generators + gen_bag, earned exp, level,
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

# §7 fence sizing: how many stands the fence shows, metered to the WHOLE map's remaining exp
# (not the next single spot). The fence stays full and only tapers in the map's final stretch,
# emptying once you've banked enough to finish the map. The "go restore" cue is the breathing
# Home button (gate_ready) — the fence no longer empties at each affordable spot.
static func meter_target(z: int, exp: int, unlocks: Dictionary) -> int:
	return G.active_giver_count(exp, G.map_finish_exp(z, unlocks))

# The restore CTA: ready once total exp has reached the NEXT unclaimed spot's threshold.
static func gate_ready(z: int, exp: int, unlocks: Dictionary) -> bool:
	var nxt := int(G.map_next_unlock(z, unlocks).exp)
	return nxt >= 0 and exp >= nxt

# §7 fence GREY state (req 1): the fence goes INERT — the board renders its quests GREYED + non-interactive
# instead of emptying — once earned exp can finish the WHOLE current map (the exact point the active
# meter used to taper to 0). False while the player still needs exp for the map, and false on a spots-done
# map (left == 0 → that map is complete, never a frontier). The generator-carrier quest stays deliverable
# even here (board.gd keeps out[0] active), so the next map's tools still arrive — see refill().
static func fence_inert(z: int, exp: int, unlocks: Dictionary) -> bool:
	var fin := G.map_finish_exp(z, unlocks)
	return fin >= 0 and exp >= fin

# The Purge fence card's state. It SHOWS whenever a frontier remains (the map is not done) — no longer
# only when affordable — so it always advertises the home map's current exp total. It is READY (full
# colour + breathing) when earned exp reaches the cheapest remaining unlock; otherwise it greys
# out (still shown, no breathe). `exp` is the balance the card displays.
static func purge_state(z: int, exp: int, unlocks: Dictionary, gates: Array) -> Dictionary:
	return {
		"show": not map_done(unlocks, gates),
		"ready": gate_ready(z, exp, unlocks),
		"exp": exp,
	}

# Progress toward the NEXT unclaimed restore spot on the current frontier map.
# 0.0 = the previous claimed spot threshold (or a fresh map at 0 exp), 1.0 = the
# next unclaimed spot's threshold. Exp is cumulative, so extra exp beyond the
# next threshold stays clamped full until the player claims that spot on the map.
static func purge_progress(z: int, exp: int, unlocks: Dictionary) -> float:
	if z < 0 or z >= G.MAPS.size():
		return 0.0
	var nxt := G.map_next_unlock(z, unlocks)
	if int(nxt.k) < 0:
		return 1.0
	var previous := 0
	for k in G.MAPS[z].spots.size():
		if unlocks.has(String(G.MAPS[z].spots[k].id)):
			previous = maxi(previous, G.spot_unlock_exp(z, k))
	var target := int(nxt.exp)
	if target <= previous:
		return 1.0
	return clampf(float(exp - previous) / float(target - previous), 0.0, 1.0)

# Exp the player still has to EARN to make the WHOLE of map z claimable (the highest unclaimed
# threshold minus current exp, floored at 0).
static func exp_remaining(z: int, unlocks: Dictionary, exp: int) -> int:
	var fin := G.map_finish_exp(z, unlocks)
	return 0 if fin < 0 else maxi(0, fin - exp)

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
# then gen_quest is drawn once per appended stand, in order. Generators are NO LONGER delivered by a
# carrier quest — they arrive when a generator tap produces a DUE tool (G.due_generators / board.gd), so
# refill is purely the §7 ask stream now. Returns the new quests array.
static func refill(quests: Array, z: int, unlocks: Dictionary, gates: Array, board_gens: Dictionary, gen_bag: Array, exp: int, level: int, rng: RandomNumberGenerator, recent_items: Array = []) -> Array:
	if map_done(unlocks, gates):
		return []
	var out: Array = quests.filter(func(q): return not q.has("grant") and not bool(q.get("gate", false)))
	# Ask only from the current map's live lines (`level` gates a not-yet-grown generator's lines
	# out, so the fence never asks for what nothing on the board can produce yet).
	# #14/#16: ask the live base lines PLUS any craftable SPECIAL (merge) line, then trim to the QUEST_GEN_CAP
	# generator footprint (a special folds into its 2 ingredient generators — usually already paid for).
	var base_lines := G.askable_lines(G.GENERATORS, z, level)
	var lines := G.cap_quest_lines(base_lines + G.active_special_lines(base_lines, unlocks.size()))
	# req 1: when the bank can already finish the whole map the active meter is 0 — instead of letting the
	# fence empty, fill it to a FULL set the board renders GREYED + inert (so it never goes blank under the
	# lit Purge card).
	var target := int(G.MAX_GIVERS) if fence_inert(z, exp, unlocks) else meter_target(z, exp, unlocks)
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
		out.append(G.gen_quest(level, lines, rng, avoid, z))   # z = current map → per-map coin band
	while out.size() > target:
		out.pop_back()
	return out

# --- §7 stand PORTRAIT (the giver face) ---------------------------------------------------------------
# Each quest carries a stable `giver` index (0..pool-1): the character portrait drawn on its stand. The
# rule the board needs ("no same quest giver on screen") is on-screen UNIQUENESS — no two LIVE quests share
# a face. pick_giver enforces that as a HARD exclusion (`used` = faces already on the fence) and treats the
# rolling recency window (`recent` = the last ≤GIVER_RECENT assigned) as a SOFT preference, relaxed BEFORE
# uniqueness when the pool is too small to honour both. Pure: pool size + rng in, an index out.
const GIVER_RECENT := 5

# Faces in [0,pool) that are in neither `used` (on a live quest) nor `recent` (recently shown).
static func _free_faces(pool: int, used: Array, recent: Array) -> Array:
	var out: Array = []
	for g in range(pool):
		if not used.has(g) and not recent.has(g):
			out.append(g)
	return out

# Pick a face for a NEW stand: never one already on a live quest (hard), and not a recently-shown one when
# the pool allows (soft). Layered fallback always returns a valid index — drop recency first, then (only if
# every face is in use) allow an unavoidable repeat.
static func pick_giver(used: Array, recent: Array, pool: int, rng: RandomNumberGenerator) -> int:
	var avail := _free_faces(pool, used, recent)
	if avail.is_empty():
		avail = _free_faces(pool, used, [])      # pool too tight → drop the soft recency rule, KEEP uniqueness
	if avail.is_empty():
		return rng.randi() % pool                # every face is live (≥pool stands) → a repeat is unavoidable
	return avail[rng.randi() % avail.size()]

# The faces on every LIVE quest EXCEPT the stand at `skip` (the one being assigned) — its hard avoid-set.
static func _live_givers(quests: Array, skip: int) -> Array:
	var out: Array = []
	for i in range(quests.size()):
		if i != skip and (quests[i] as Dictionary).has("giver"):
			out.append(int(quests[i]["giver"]))
	return out

# Give every quest that lacks a face one, AND reassign any whose face collides with an EARLIER live quest
# (a save written before on-screen-uniqueness existed could carry duplicates) — so no two live quests share
# a face. An already-distinct fence is left untouched (faces stay stable across refills). Each fresh pick is
# pushed into the board's rolling `recent` window (capped). Mutates `quests` + `recent` in place.
static func assign_givers(quests: Array, recent: Array, pool: int, rng: RandomNumberGenerator) -> void:
	for i in range(quests.size()):
		var q: Dictionary = quests[i]
		var collides := false
		if q.has("giver"):
			for j in range(i):
				if (quests[j] as Dictionary).has("giver") and int(quests[j]["giver"]) == int(q["giver"]):
					collides = true
					break
		if (not q.has("giver")) or collides:
			var pick := pick_giver(_live_givers(quests, i), recent, pool, rng)
			q["giver"] = pick
			recent.append(pick)
			while recent.size() > GIVER_RECENT:
				recent.pop_front()

# The discovery ladder for a line: one row per tier, code = line*100+tier, with `seen` flagged
# from the save's `seen` set (keyed by the string code, as written on merge).
static func ladder_entries(seen: Dictionary, line: int) -> Array:
	var out: Array = []
	var top := G.merge_top(line * 100 + 1)
	for t in range(1, top + 1):
		var code := line * 100 + t
		out.append({"tier": t, "code": code, "seen": seen.has(str(code))})
	return out

# Reward readers — the {reward:{exp,coins,gems}} shape, falling back to the flat legacy key.
static func exp(q: Dictionary) -> int:
	return int(q.reward.get("exp", 0)) if q.has("reward") else int(q.get("exp", 0))

static func coins(q: Dictionary) -> int:
	return int(q.reward.get("coins", 0)) if q.has("reward") else 0

# Reward reader for optional premium in data-authored quests; current generated quests return 0.
static func gems(q: Dictionary) -> int:
	return int(q.reward.get("gems", 0)) if q.has("reward") else 0
