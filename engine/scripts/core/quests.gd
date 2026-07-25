extends RefCounted
## §7 fence COMPOSITION — the decisions board.gd makes about WHICH quests sit on the live
## giver fence, lifted off the scene so they are headless-testable. Pure statics: state comes
## in (the grove's unlocks/gates, the board's live generators + gen_bag, earned exp, level,
## rng) and a quests Array comes out. The quest ENGINE (gen_quest / active_giver_count) and all
## tuning live in content.gd (G); this layer only orchestrates it. board.gd keeps thin
## Save-reading wrappers (_quest_map / _refill_quests / …) over these.
## Layering: core/ never imports ui/ or scenes/ — see docs/design/merge_spec.md §15.

const G = preload("res://engine/scripts/core/content.gd")

# --- fence gating on the COIN CLOCK (coin-clock redesign, spec 2026-07-17) ----------------
# `earned` everywhere below = Save.coins_earned_lifetime() (the cumulative organic-coins clock).
# The retired per-spot exp ladder becomes the zone ladder: one zone per level (G.zone_threshold),
# so every meter/vase read keeps its shape with the source swapped. The map surface no longer drives
# the fence — the board's unlock CTA reads content.any_cluster_ready directly.

# The reward BAND the fence currently pays at (the retired "current map" axis): the band of the
# level-reached quest zone. Drives the per-band coin curve + the reseed check.
static func current_band(level: int) -> int:
	return G.zone_map(G.quest_zone_for_level(level))

# §7 fence sizing: the live fence is ALWAYS as full as the unlocked lines allow — MAX_GIVERS cards
# (refill then caps this to the current line capacity). Quests are ENDLESS: the fence never tapers
# and never stops. The old CONTENT-ARC taper + the fence_inert "endgame quiet" greying are retired
# (2026-07-23, owner call): the quest-zone roster (12 zones, all unlocked by ~L13) is far shorter
# than the real map/cluster arc (25 clusters → ~L26), so gating the fence on the zone arc greyed it
# out halfway through the game. The fence now stays full + interactive for the whole arc and past it.
static func meter_target() -> int:
	return int(G.MAX_GIVERS)

# The Purge fence card's state. One zone per level means the vase IS the level bar now: it fills
# toward the NEXT level threshold and is READY at the brim. It ALWAYS shows — levels are unbounded,
# so there is always a next threshold to advertise (the fence is endless; no endgame quiet).
# `exp` stays the displayed balance key (the card face reads it verbatim).
static func purge_state(earned: int) -> Dictionary:
	return {
		"show": true,
		"ready": purge_progress(earned) >= 1.0,
		"exp": earned,
	}

# Progress toward the NEXT level threshold on the coin clock. 0.0 at the current level's start,
# 1.0 at the next level's threshold (clamped — the level-up consumes it visually on the rebuild).
static func purge_progress(earned: int) -> float:
	var lvl := G.level_at_coins(earned)
	var base := G.coins_at_level(lvl)
	var nxt := G.coins_at_level(lvl + 1)
	if nxt <= base:
		return 1.0
	return clampf(float(earned - base) / float(nxt - base), 0.0, 1.0)

# The owned generator ids = on the board ∪ stored in the gen_bag.
static func owned_gens(board_gens: Dictionary, gen_bag: Array) -> Array:
	var out: Array = []
	for id in board_gens.values():
		out.append(String(id))
	for id in gen_bag:
		out.append(String(id))
	return out

# QUEST-DRIVEN birth-on-tap (gen redesign — the LINE_WINDOW "active lines" window is retired). The generator
# the board should birth on the next tap: the gen_1 ANCHOR self-heals FIRST (so a fresh save's very first tap
# always produces, even before any quest exists), then the first generator REQUIRED by an active quest the
# player doesn't own yet — a base quest needs its own generator, a special quest needs its two ingredient
# generators (G.gens_for_quest_line). "" if nothing is owed. Progression alone no longer grants a tool: a
# line's generator arrives only when a quest asks for it (or for a special crafted from it), which lets the
# quest stream choose what the player gets next. `owned_ids` = generators on the board ∪ the gen_bag.
static func due_gen(quests: Array, owned_ids: Array) -> String:
	# STRANDING GUARD (rescoped 2026-07-25 with the ACTIVE_LINE_WINDOW). Birth the anchor only when the
	# player owns NO line generator at all — a fresh save's very first tap, or a save that somehow lost
	# every tool. It used to fire whenever gen_1 SPECIFICALLY was missing; line 1 now leaves the fence at
	# zone 3 and is an ingredient to no special, so the old form would have resurrected a retired generator
	# on every tap forever. (Accumulator / bonus / treat gens don't count — they can't satisfy a quest.)
	if not _owns_any_line_gen(owned_ids):
		var anchor := G.anchor_gen()
		if anchor != "":
			return anchor
	for q in quests:
		var it := G.quest_item(q)
		if it.is_empty():
			continue
		for gid in G.gens_for_quest_line(int(it.line)):
			if not owned_ids.has(gid):
				return gid
	return ""

# True if `owned_ids` holds at least one BASE-LINE generator (the only kind that can satisfy a quest).
static func _owns_any_line_gen(owned_ids: Array) -> bool:
	for l in G.ZONE_BASE_LINES:
		if owned_ids.has(G.gen_for_line(int(l))):
			return true
	return false

static func _quest_line_counts(quests: Array) -> Dictionary:
	var out := {}
	for q in quests:
		var it := G.quest_item(q)
		if it.is_empty():
			continue
		var line := int(it.line)
		out[line] = int(out.get(line, 0)) + 1
	return out

static func _cap_quests_per_line(quests: Array) -> Array:
	var out: Array = []
	var counts := {}
	for q in quests:
		var it := G.quest_item(q)
		if it.is_empty():
			out.append(q)
			continue
		var line := int(it.line)
		if int(counts.get(line, 0)) >= int(G.MAX_QUESTS_PER_LINE):
			continue
		counts[line] = int(counts.get(line, 0)) + 1
		out.append(q)
	return out

static func _line_capacity(lines: Array) -> int:
	var seen := {}
	for line in lines:
		seen[int(line)] = true
	return seen.size() * int(G.MAX_QUESTS_PER_LINE)

static func _lines_with_room(lines: Array, quests: Array) -> Array:
	var counts := _quest_line_counts(quests)
	var seen := {}
	var out: Array = []
	for line in lines:
		var li := int(line)
		if seen.has(li):
			continue
		seen[li] = true
		if int(counts.get(li, 0)) < int(G.MAX_QUESTS_PER_LINE):
			out.append(li)
	return out

# Top up / trim the live fence to the metered count with freshly generated quests (§7). Deterministic
# via `rng` — RNG CALL ORDER IS LOAD-BEARING (the rng is seeded + persisted): the filter takes no rng,
# then gen_quest is drawn once per appended stand, in order. Generators are NO LONGER delivered by a
# carrier quest — they arrive when a generator tap produces a DUE tool (Quests.due_gen / board.gd), so
# refill is purely the §7 ask stream now. Returns the new quests array.
static func refill(quests: Array, band: int, board_gens: Dictionary, gen_bag: Array, _earned: int, level: int, rng: RandomNumberGenerator, recent_items: Array = []) -> Array:
	var out: Array = _cap_quests_per_line(quests.filter(func(q): return not q.has("grant") and not bool(q.get("gate", false))))
	# Ask from the level-reached line window (the coin clock drives level): a player keeps seeing
	# new quest lines by earning coins even if they delay building newly affordable structures.
	# §7 the ACTIVE-LINE WINDOW (2026-07-25): ACTIVE_LINE_WINDOW lines at a time, base or crafted-special
	# alike — the arc's sliding zone window, then a fresh deterministic draw per level-up past the last zone.
	# Still trimmed to the QUEST_GEN_CAP generator footprint (a special folds into its 2 ingredient gens,
	# which arrive by birth-on-tap). NOTE: a re-roll never drops a quest already on the fence — `out` keeps
	# every live stand, so items the player has already built stay deliverable.
	var lines := G.cap_quest_lines(G.active_lines(level))
	# The fence is always full (endless quests): MAX_GIVERS, then capped to the unlocked line capacity.
	var target := mini(meter_target(), _line_capacity(lines))
	while out.size() < target:
		var eligible_lines := _lines_with_room(lines, out)
		if eligible_lines.is_empty():
			break
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
		out.append(G.gen_quest(level, eligible_lines, rng, avoid, band))   # band → the per-band coin curve
	while out.size() > target:
		out.pop_back()
	return out

# Fence ORDER: float every DELIVERABLE quest to the FRONT of the row so a player can find and hand in a
# completed ask at a glance. A STABLE partition — `ready[i]` flags `items[i]` as payable; the ready ones
# come first in their existing order, then the rest in theirs. Pure: it reorders the index/entry list the
# board renders, NOT the persisted `quests` array (whose order is load-bearing for refill RNG, due_gen,
# and giver assignment). A missing flag (ready shorter than items) reads as not-ready.
static func ready_first(items: Array, ready: Array) -> Array:
	var head: Array = []
	var tail: Array = []
	for i in range(items.size()):
		if i < ready.size() and bool(ready[i]):
			head.append(items[i])
		else:
			tail.append(items[i])
	return head + tail

# --- §7 stand PORTRAIT (the giver face) ---------------------------------------------------------------
# Each quest carries a stable `giver` index (0..pool-1): the character portrait drawn on its stand. The
# rule the board prefers is on-screen variety: do not reuse a face already on the fence while the scene pool
# still has an unused portrait. pick_giver treats `used` as hard until every face is live, and treats the
# rolling recency window (`recent` = the last ≤GIVER_RECENT assigned) as a SOFT preference, relaxed BEFORE
# an unavoidable repeat. Pure: pool size + rng in, an index out.
const GIVER_RECENT := 5

# Faces in [0,pool) that are in neither `used` (on a live quest) nor `recent` (recently shown).
static func _free_faces(pool: int, used: Array, recent: Array) -> Array:
	var out: Array = []
	for g in range(pool):
		if not used.has(g) and not recent.has(g):
			out.append(g)
	return out

# Pick a face for a NEW stand: avoid one already on a live quest while the pool allows, and avoid a recently
# shown one when there is still room. Layered fallback always returns a valid index — drop recency first,
# then allow an unavoidable repeat only if every face is already in use.
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
# when another face is available. Once every face is already live, repeats are allowed so a full fence still
# renders. An already-distinct fence is left untouched (faces stay stable across refills). Each fresh pick is
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

# Reward reader — the {reward:{coins,gems}} shape (COINS ONLY since the coin-clock redesign;
# the exp reader is retired with the exp economy).
static func coins(q: Dictionary) -> int:
	return int(q.reward.get("coins", 0)) if q.has("reward") else 0

# Reward reader for optional premium in data-authored quests; current generated quests return 0.
static func gems(q: Dictionary) -> int:
	return int(q.reward.get("gems", 0)) if q.has("reward") else 0
