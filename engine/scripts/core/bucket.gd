extends RefCounted
## The Save-backed adapter over the PURE resident bucket (resident_bucket.gd) — the ONLY game-facing
## resident API. Real time + RNG live here; every rule lives in the module. State persists under
## Save.grove()["bucket"]; cells are DERIVED from fully-restored maps (BUCKET_CELL_GRANTS) on every
## access; collected lines credit currencies here (coins/water/diamonds + the board's boost stockpile).
## Spec: docs/superpowers/specs/2026-07-16-global-resident-bucket-design.md

const Save = preload("res://engine/scripts/core/save.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Content = preload("res://engine/scripts/core/content.gd")
const RB = preload("res://engine/scripts/core/resident_bucket.gd")
const D = Game.DATA

const MAX_TIER := RB.MAX_TIER
const SELL_PER_TIER := RB.SELL_PER_TIER
const LINES := RB.LINES

static func now() -> float:
	return Time.get_unix_time_from_system()

## Line -> the resident family whose ladder art it wears (items/resident_<kind>/...).
static func line_kind(line: String) -> String:
	return String(D.RESIDENT_LINE_KINDS.get(line, ""))

static func kind_line(kind: String) -> String:
	return String(D.RESIDENT_KIND_LINES.get(kind, ""))

## Cells granted so far — the sum of BUCKET_CELL_GRANTS over FULLY-restored maps. The only capacity source.
static func cells_total() -> int:
	var unlocks: Dictionary = Save.grove().get("unlocks", {})
	var total := 0
	for z in Content.MAPS.size():
		if z >= D.BUCKET_CELL_GRANTS.size():
			break
		if Content.map_spots_restored(z, unlocks) >= G_spots(z):
			total += int(D.BUCKET_CELL_GRANTS[z])
	return total

static func G_spots(z: int) -> int:
	return Content.MAPS[z].spots.size()

## The live bucket state (module shape). Created by migration on first access; cells re-synced every time.
static func state() -> Dictionary:
	var g := Save.grove()
	if not g.has("bucket"):
		g["bucket"] = _migrated_state(g)
		Save.grove_write()
	var st: Dictionary = g["bucket"]
	st["cells"] = cells_total()
	return st

# --- migration (legacy per-map habitat -> the bucket) --------------------------------------------
## Non-destructive: every legacy spirit (hand + all per-map placed) lands in the NEW hand at its tier,
## kinds mapped to lines (RESIDENT_KIND_LINES). The last-settled banked accrual credits floor(acc) in
## the old map's currency (live un-settled accrual since then is forfeited — accepted, small).
static func _migrated_state(g: Dictionary) -> Dictionary:
	var st := RB.make_state(now())
	for inst in g.get("hand", []):
		_migrate_spirit(st, inst)
	var hab: Dictionary = g.get("habitat", {})
	for mid in hab:
		for inst in hab[mid]:
			_migrate_spirit(st, inst)
	var old_cur := {"farmhouse": "coin", "barn": "water", "pond": "boost", "orchard": "diamond"}
	var prod: Dictionary = g.get("hab_prod", {})
	for mid in prod:
		var whole := int(floor(float(prod[mid].get("acc", 0.0))))
		if whole > 0 and old_cur.has(mid):
			_credit_line(String(old_cur[mid]), whole)
	for key in ["hand", "habitat", "hab_prod", "hab_cap"]:
		g.erase(key)
	return st

static func _migrate_spirit(st: Dictionary, inst: Dictionary) -> void:
	var line := kind_line(String(inst.get("kind", "")))
	if line != "":
		RB.hand_add(st, line, int(inst.get("tier", 1)))

# --- hand + cells (thin persistence wrappers over the module ops) --------------------------------
static func hand() -> Array:
	return state().hand

static func placed() -> Array:
	return state().placed

static func hand_add(line: String, tier: int = 1) -> int:
	var n := RB.hand_add(state(), line, tier)
	Save.grove_write()
	return n

## Module semantics: keeps index i (climbs it a tier), removes index j — pass the DROP TARGET first.
static func hand_merge(i: int, j: int) -> bool:
	var did := RB.hand_merge(state(), i, j)
	if did:
		Save.grove_write()
	return did

static func place(hand_index: int) -> bool:
	var did := RB.place(state(), hand_index, now())
	if did:
		Save.grove_write()
	return did

static func place_merge(hand_index: int, placed_index: int) -> bool:
	var did := RB.place_merge(state(), hand_index, placed_index, now())
	if did:
		Save.grove_write()
	return did

static func unplace(placed_index: int) -> bool:
	var did := RB.unplace(state(), placed_index, now())
	if did:
		Save.grove_write()
	return did

static func is_full() -> bool:
	var st := state()
	return st.placed.size() >= int(st.cells)

## Selling credits the coins HERE (the UI never touches Save for it). Returns the coins paid (0 on a bad index).
static func sell_hand(i: int) -> int:
	var got := RB.sell_hand(state(), i)
	if got > 0:
		Save.add_coins(got)
		Save.grove_write()
	return got

static func sell_placed(i: int) -> int:
	var got := RB.sell_placed(state(), i, now())
	if got > 0:
		Save.add_coins(got)
		Save.grove_write()
	return got

# --- production + collect ------------------------------------------------------------------------
static func pending_line(line: String) -> float:
	return RB.pending(state(), line, now())

static func line_stier(line: String) -> int:
	return RB.line_stier(state(), line)

## One line's dock report: placed Σtier, matured pending, its bank cap, what a collect would grant
## NOW (day-ceiling aware), and whether the bank has plateaued (production stopped until a collect).
static func line_report(line: String) -> Dictionary:
	var st := state()
	var n := now()
	var p := RB.pending(st, line, n)
	var cap := RB.bank_cap(st, line)
	return {"stier": RB.line_stier(st, line), "pending": p, "cap": cap,
		"ready": RB.collectable(st, line, n), "full": p >= cap - 0.0001}

## Collect every line's matured whole units and credit them (day ceilings enforced by the module).
## Returns the granted {line: amount} for FX.
static func collect() -> Dictionary:
	var got := RB.collect(state(), now())
	for line in got:
		_credit_line(String(line), int(got[line]))
	Save.grove_write()
	return got

static func _credit_line(line: String, amount: int) -> void:
	match line:
		"coin":
			Save.add_coins(amount)
		"water":
			Save.add_water(amount)               # clamps the TOTAL to WATER_CAP
		"diamond":
			Save.add_diamonds(amount)
		"boost":
			Save.grove()["boost_charges"] = boost_charges() + amount

# --- generator-boost charges (the board's free-boost stockpile; save key kept verbatim) ----------
static func boost_charges() -> int:
	return int(Save.grove().get("boost_charges", 0))

static func spend_boost_charge() -> bool:
	if boost_charges() <= 0:
		return false
	Save.grove()["boost_charges"] = boost_charges() - 1
	Save.grove_write()
	return true

# --- expedition boxes ----------------------------------------------------------------------------
# A shared loot rng — NOT the board's seeded+persisted rng (box loot is never replayed).
static var _loot_rng: RandomNumberGenerator = null

static func _rng() -> RandomNumberGenerator:
	if _loot_rng == null:
		_loot_rng = RandomNumberGenerator.new()
		_loot_rng.randomize()
	return _loot_rng

## Roll `count` spirits into the hand (line by rarity weight, t1-heavy tier — module DEFAULTS).
## Returns [{line, kind, tier}] — `kind` is the art family for the reveal.
static func grant_box(count: int) -> Array:
	var granted := RB.grant_box(state(), count, _rng())
	Save.grove_write()
	var out: Array = []
	for inst in granted:
		out.append({"line": String(inst.line), "kind": line_kind(String(inst.line)), "tier": int(inst.tier)})
	return out
