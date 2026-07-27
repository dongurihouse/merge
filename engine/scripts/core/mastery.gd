extends RefCounted
## Generator mastery: a save-backed, per-base-line meter that changes generator
## pop tier windows. Pure helpers only; scenes and sims call these at the two
## credit sites and pass live quests into window().

const G = preload("res://engine/scripts/core/content.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const Features = preload("res://engine/scripts/core/features.gd")

static func _enabled() -> bool:
	return Features.on("mastery")

static func _is_mastery_line(line: int) -> bool:
	return G.ZONE_BASE_LINES.has(int(line))

static func _store() -> Dictionary:
	var g := Save.grove()
	if not g.has("mastery") or not (g.get("mastery", {}) is Dictionary):
		g["mastery"] = {}
	return g["mastery"]

static func _seen_store() -> Dictionary:
	var g := Save.grove()
	if not g.has("mastery_seen") or not (g.get("mastery_seen", {}) is Dictionary):
		g["mastery_seen"] = {}
	return g["mastery_seen"]

static func meter(line: int) -> int:
	if not _enabled() or not _is_mastery_line(line):
		return 0
	return maxi(0, int(_store().get(str(int(line)), 0)))

static func rank(line: int) -> int:
	return rank_for_meter(meter(line))

static func rank_for_meter(amount: int) -> int:
	var r := 0
	for threshold in G.MASTERY_THRESHOLDS:
		if int(amount) >= int(threshold):
			r += 1
	return clampi(r, 0, G.MASTERY_THRESHOLDS.size())

static func tier_window_for_rank(r: int) -> Vector2i:
	var rr := clampi(r, 0, G.MASTERY_THRESHOLDS.size())
	var lo := 1 + int(rr / 2)
	var hi := 4 + int((rr + 1) / 2)
	return Vector2i(lo, mini(8, hi))

static func ask_band(line: int, quests: Array) -> int:
	var band := 0
	for q in quests:
		if not (q is Dictionary):
			continue
		var it := G.quest_item(q)
		if it.is_empty():
			continue
		if int(it.line) == int(line):
			band = maxi(band, int(it.tier))
	return band

static func window(line: int, quests: Array) -> Vector2i:
	if not _enabled() or not _is_mastery_line(line):
		return tier_window_for_rank(0)
	var w := tier_window_for_rank(rank(line))
	var band := ask_band(line, quests)
	if band <= 0:
		return w
	var floor_for_band := maxi(1, band - 3)
	var slide := maxi(0, w.x - floor_for_band)
	return Vector2i(maxi(1, w.x - slide), maxi(1, w.y - slide))

static func next_threshold(line: int) -> int:
	var r := rank(line)
	if r >= G.MASTERY_THRESHOLDS.size():
		return int(G.MASTERY_THRESHOLDS[G.MASTERY_THRESHOLDS.size() - 1])
	return int(G.MASTERY_THRESHOLDS[r])

static func rank_progress(line: int) -> float:
	var r := rank(line)
	if r >= G.MASTERY_THRESHOLDS.size():
		return 1.0
	var prev := 0 if r <= 0 else int(G.MASTERY_THRESHOLDS[r - 1])
	var nxt := int(G.MASTERY_THRESHOLDS[r])
	return clampf(float(meter(line) - prev) / float(maxi(1, nxt - prev)), 0.0, 1.0)

static func seen_rank(line: int) -> int:
	if not _enabled() or not _is_mastery_line(line):
		return 0
	return clampi(int(_seen_store().get(str(int(line)), 0)), 0, G.MASTERY_THRESHOLDS.size())

static func mark_seen_rank(line: int, r: int) -> void:
	if not _enabled() or not _is_mastery_line(line):
		return
	var seen := _seen_store()
	var key := str(int(line))
	var next := clampi(int(r), 0, G.MASTERY_THRESHOLDS.size())
	if next <= int(seen.get(key, 0)):
		return
	seen[key] = next
	Save.grove_write()

static func any_rank_at_least(r: int) -> bool:
	if not _enabled():
		return false
	for line in G.ZONE_BASE_LINES:
		if rank(int(line)) >= int(r):
			return true
	return false

static func credit_delivery(code: int) -> Dictionary:
	var line := int(code / 100.0)
	var tier := code % 100
	if tier <= 0 or not _is_mastery_line(line):
		return {}
	return _credit_many({line: G.tier_clicks(tier)})

static func credit_craft(a_code: int, b_code: int) -> Dictionary:
	var at := a_code % 100
	var bt := b_code % 100
	if at <= 0 or at != bt:
		return {}
	var credits := {}
	for code in [a_code, b_code]:
		var line := int(int(code) / 100.0)
		if _is_mastery_line(line):
			credits[line] = int(credits.get(line, 0)) + G.tier_clicks(at)
	return _credit_many(credits)

static func _credit_many(credits: Dictionary) -> Dictionary:
	if not _enabled() or credits.is_empty():
		return {}
	var s := _store()
	var gained := {}
	var touched := false
	for raw_line in credits.keys():
		var line := int(raw_line)
		var amount := maxi(0, int(credits[raw_line]))
		if amount <= 0 or not _is_mastery_line(line):
			continue
		var before := maxi(0, int(s.get(str(line), 0)))
		var before_rank := rank_for_meter(before)
		var after := before + amount
		s[str(line)] = after
		var delta := rank_for_meter(after) - before_rank
		if delta > 0:
			gained[line] = delta
		touched = true
	if touched:
		Save.grove_write()
	return gained
