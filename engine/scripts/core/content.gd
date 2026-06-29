extends RefCounted
## Content ENGINE (theme-agnostic). The DATA lives in the active game
## (games/<name>/*_data.gd, reached via Game.DATA); this file is the generic
## logic that operates on it — bramble field, quest generation, progression,
## economy formulas — plus a re-export of the data so callers keep using G.X.
## (Was grove_content.gd; the grove tables moved to games/grove/grove_data.gd.)

const Game = preload("res://engine/scripts/core/game.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const Vault = preload("res://engine/scripts/core/vault.gd")   # T44 SKIM-SITE — the piggy bank skims earned premium here

# --- the ACTIVE game's DATA (compile-time const), re-exported as consts so every
# --- existing G.<CONST> reader keeps working and := type inference still resolves.
const D = Game.DATA
const COLS = D.COLS
const ROWS = D.ROWS
const TOP_TIER = D.TOP_TIER
const PREMIUM_TIER = D.PREMIUM_TIER
const LINES = D.LINES
const GENERATORS = D.GENERATORS
const APPEAR_ALL := 1 << 30        # sentinel level: "include every generator regardless of appear_level"
const GEN_CELL = D.GEN_CELL
static var MIN_LEVEL: Array = D.MIN_LEVEL   # OWNER DIAL — live-overridable by economy_tuning.json (apply_tuning)
const TIER_ODDS = D.TIER_ODDS
const ASK_WEIGHT = D.ASK_WEIGHT
const POP_LINE_CAP = D.POP_LINE_CAP         # §6 max distinct lines popped at once (zone 2+)
const POP_LINE_CAP_Z1 = D.POP_LINE_CAP_Z1   # §6 the tighter zone-1 (Farmhouse) cap — the tiny FTUE board
const LINE_WINDOW = D.LINE_WINDOW           # §6 rolling map-window width for the askable lines
const ZONE_BASE_LINES = D.ZONE_BASE_LINES   # §6 the new per-line zone model (gen redesign 2026-06-28)
const ZONE_SPECIAL_LINES = D.ZONE_SPECIAL_LINES
const ZONE_COUNT = D.ZONE_COUNT
const GEN_TOP_TIER = D.GEN_TOP_TIER
const QUEST_GEN_CAP = D.QUEST_GEN_CAP
const GEN_SELF_DUP_RATE = D.GEN_SELF_DUP_RATE
const GEN_TIER_BURST_ODDS = D.GEN_TIER_BURST_ODDS
const ASK_TIER_WEIGHT = D.ASK_TIER_WEIGHT   # §6 spawn TIER-bias strength (0 = off; owner pacing dial)
static var QUEST_CLICKS_PER_EXP: int = D.QUEST_CLICKS_PER_EXP   # OWNER DIAL — live-overridable (apply_tuning)
const QUEST_CLICKS_PER_COIN = D.QUEST_CLICKS_PER_COIN
const QUEST_COIN_DEPTH = D.QUEST_COIN_DEPTH
const COINS_PER_ACORN = D.COINS_PER_ACORN
const QUEST_TIER_BASE = D.QUEST_TIER_BASE
const QUEST_LEVELS_PER_TIER = D.QUEST_LEVELS_PER_TIER
const QUEST_NEWEST_BIAS = D.QUEST_NEWEST_BIAS
const QUEST_FEATURED_RATE = D.QUEST_FEATURED_RATE
const QUEST_FEATURED_COIN_BONUS = D.QUEST_FEATURED_COIN_BONUS
const MAX_GIVERS = D.MAX_GIVERS
const EXP_PER_QUEST_EST = D.STARS_PER_QUEST_EST
const BURST_ODDS = D.BURST_ODDS
const BURST_ODDS_BOOST = D.BURST_ODDS_BOOST
const BURST_MAX = D.BURST_MAX
const BOOST_BONUS = D.BOOST_BONUS
const BOOST_TAPS = D.BOOST_TAPS
const BOOST_COST = D.BOOST_COST
const RESIDENT_MAX_TIER = D.RESIDENT_MAX_TIER
const RESIDENT_SLOTS_MAX = D.RESIDENT_SLOTS_MAX
const RESIDENT_LINES = D.RESIDENT_LINES
const RESIDENT_ART = D.RESIDENT_ART
const RESIDENT_BASE_COST = D.RESIDENT_BASE_COST
const RESIDENT_PREMIUM_COST = D.RESIDENT_PREMIUM_COST
const STARTER_ITEMS = D.STARTER_ITEMS
const SELL_MAP_BAND = D.SELL_MAP_BAND
const BUY_MARKUP = D.BUY_MARKUP
const LEVEL_DIAMONDS = D.LEVEL_DIAMONDS
const LEVEL_DIAMOND_EVERY = D.LEVEL_DIAMOND_EVERY
const MAP_DIAMONDS = D.MAP_DIAMONDS
const REFILL_DIAMOND_COST = D.REFILL_DIAMOND_COST
const COLLECT_2X_COIN_RATE = D.COLLECT_2X_COIN_RATE
const BAG_START_SLOTS = D.BAG_START_SLOTS
const BAG_MAX_SLOTS = D.BAG_MAX_SLOTS
const BAG_SLOT_PRICES = D.BAG_SLOT_PRICES
const WATER_CAP = D.WATER_CAP
const REGEN_SECS = D.REGEN_SECS
const POP_COST = D.POP_COST
const FREE_REFILLS = D.FREE_REFILLS
const WINBACK_HOURS = D.WINBACK_HOURS
const WATER_REWARD_MAX_RATIO = D.WATER_REWARD_MAX_RATIO
const COIN_LINE = D.COIN_LINE
const COIN_TOP = D.COIN_TOP
const COIN_VALUES = D.COIN_VALUES
const COIN_DROP_RATE = D.COIN_DROP_RATE
const SPECIAL_TOP = D.SPECIAL_TOP
const SPECIAL_ITEMS = D.SPECIAL_ITEMS
const SPECIAL_DROP_RATE = D.SPECIAL_DROP_RATE
const SPECIAL_DROP_WEIGHTS = D.SPECIAL_DROP_WEIGHTS
const SPECIAL_COLLECT = D.SPECIAL_COLLECT
const CHEST_OPEN_COINS = D.CHEST_OPEN_COINS
const CHEST_OPEN_ACORNS = D.CHEST_OPEN_ACORNS
const KEY_TIER_MULT = D.KEY_TIER_MULT
const ACCUMULATORS = D.ACCUMULATORS
const BONUS_SPAWN_CHANCE = D.BONUS_SPAWN_CHANCE
const BONUS_CLICKS = D.BONUS_CLICKS
const TREAT_SPAWN_CHANCE = D.TREAT_SPAWN_CHANCE
const TREAT_CLICKS = D.TREAT_CLICKS
const TREAT_LINES = D.TREAT_LINES
const MAP_TREAT_LINE = D.MAP_TREAT_LINE
const TREAT_POP_TIER = D.TREAT_POP_TIER
const TREAT_DROP_RATE = D.TREAT_DROP_RATE
const TREAT_SELL_BAND = D.TREAT_SELL_BAND
const TREAT_GEN_TEX = D.TREAT_GEN_TEX
static var MAPS: Array = D.MAPS   # var, not const: grove_data builds MAPS at load (merges the placer's JSON layout)
static var LEVEL_BASE_EXP: int = D.LEVEL_BASE_EXP   # OWNER DIAL — the level curve, live-overridable (apply_tuning)
static var LEVEL_STEP_EXP: int = D.LEVEL_STEP_EXP   # OWNER DIAL — live-overridable (apply_tuning)
static var ENDGAME_CLICKS: int = D.ENDGAME_CLICKS   # OWNER DIAL — whole-arc click budget (anchor; economy_tuning.json)
const LEVEL_WATER_GIFT = D.LEVEL_WATER_GIFT

# --- OWNER ECONOMY TUNING (docs/economy_tuning.html writes the JSON; the game picks it up here) -----
# The HTML tool is the editor; this is the reader. At class load we read the ACTIVE game's
# economy_tuning.json and override the curve/board DIALS above (LEVEL_BASE_EXP / LEVEL_STEP_EXP /
# QUEST_CLICKS_PER_EXP / ENDGAME_CLICKS / MIN_LEVEL). An absent or invalid file is a clean no-op —
# the grove_data defaults stand — so the dials only move when the owner deliberately saves a file.
# Only the named keys override; every other dial is untouched.
const TUNING_PATH := "res://games/%s/economy_tuning.json"

static func _static_init() -> void:
	apply_tuning()

# Read the tuning JSON (default: the active game's file) and apply any present, valid keys. Exposed
# (with a path arg) so a test can drive it off a temp file. Returns the keys actually applied.
static func apply_tuning(path: String = "") -> PackedStringArray:
	if path == "":
		path = TUNING_PATH % Game.active()
	var applied := PackedStringArray()
	if not FileAccess.file_exists(path):
		return applied
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return applied
	var t: Dictionary = parsed
	if t.has("level_base_exp"):
		LEVEL_BASE_EXP = maxi(1, int(t["level_base_exp"]));   applied.append("level_base_exp")
	if t.has("level_step_exp"):
		LEVEL_STEP_EXP = maxi(0, int(t["level_step_exp"]));   applied.append("level_step_exp")
	if t.has("quest_clicks_per_exp"):
		QUEST_CLICKS_PER_EXP = maxi(1, int(t["quest_clicks_per_exp"]));  applied.append("quest_clicks_per_exp")
	if t.has("endgame_clicks"):
		ENDGAME_CLICKS = maxi(1, int(t["endgame_clicks"]));   applied.append("endgame_clicks")
	if t.has("min_level") and t["min_level"] is Array:
		var grid := _coerce_grid(t["min_level"])
		if not grid.is_empty():
			MIN_LEVEL = grid;   applied.append("min_level")
	return applied

# Validate a ROWS×COLS non-negative int grid; [] (→ ignored) on any shape mismatch.
static func _coerce_grid(raw: Array) -> Array:
	if raw.size() != int(D.ROWS):
		return []
	var grid: Array = []
	for r in raw:
		if not (r is Array) or (r as Array).size() != int(D.COLS):
			return []
		var row: Array = []
		for v in r:
			row.append(maxi(0, int(v)))
		grid.append(row)
	return grid

# --- the bag (§5) ----------------------------------------------------------------
# The 💎 price of the NEXT expansion when `owned` slots are held (BAG_START_SLOTS..BAG_MAX_SLOTS).
# Indexes BAG_SLOT_PRICES by how many expansions are already bought (owned - START). Returns 0
# at/above the cap (nothing left to buy) — the caller treats 0 as "maxed".
static func next_bag_slot_price(owned: int) -> int:
	var bought := owned - BAG_START_SLOTS
	if bought < 0 or bought >= BAG_SLOT_PRICES.size():
		return 0
	return int(BAG_SLOT_PRICES[bought])

# --- generators ------------------------------------------------------------------
# --- per-map generator roster (§6) -----------------------------------------------
# A roster is an Array of {id, map, lines:[a,b], cell}. Each generator persists at its
# own authored cell; the next map's generator is granted by a near-end quest (its
# `reward.generators`) into the gen_bag, never handed in. (`grant_from` is now inert
# legacy data, retained on the defs for the deferred roster re-author.) Generators never
# merge to evolve (that mechanic is retired). Pure derivation — the live code passes
# GENERATORS; tests pass a fixture. Replaces appears_at accumulation.
# `level` gates generators that GROW IN later (a def's `appear_level`, default 0 = live at
# start): a generator whose appear_level exceeds the player's Level is not yet on the map, so
# it is excluded from placement (live_gen_state) AND from the askable lines (askable_lines) —
# the two must agree or the fence would ask for a line nothing on the board can produce. The
# default APPEAR_ALL includes every generator (the many callers that don't care about staging).
static func generators_for_map(roster: Array, map: int, level: int = APPEAR_ALL) -> Array:
	var out: Array = []
	for g in roster:
		if int(g.map) == map and int(g.get("appear_level", 0)) <= level:
			out.append(g)
	return out

## The lines LIVE while the player is in `map` — its generators' lines only (older maps'
## lines have retired, §6). The current map's quests draw only from these.
static func lines_for_map(roster: Array, map: int, level: int = APPEAR_ALL) -> Array:
	var out: Array = []
	for g in generators_for_map(roster, map, level):
		var l := int(g.line)   # gen redesign: ONE line per generator (the `lines` array is retired)
		if not out.has(l):
			out.append(l)
	return out

## The lines a regular quest may ASK while the player is in `map`: a ROLLING WINDOW of the last
## LINE_WINDOW maps — the current map's live lines PLUS the previous LINE_WINDOW-1 maps' (maps
## [map-LINE_WINDOW+1 .. map], clamped). Older lines RETIRE off the fence (→ the Collection), so the
## live set stays small as the lifetime roster grows (NOT cumulative — the old "nothing retires" set is
## retired). `level` still gates a not-yet-grown generator's lines out (the staging invariant).
static func askable_lines(roster: Array, map: int, level: int = APPEAR_ALL) -> Array:
	var out: Array = []
	for z in range(maxi(0, map - LINE_WINDOW + 1), map + 1):   # the rolling window: current + previous (LINE_WINDOW-1) maps
		for l in lines_for_map(roster, z, level):
			if not out.has(int(l)):
				out.append(int(l))
	out.sort()
	return out

## The max distinct lines the single generator pops at once — STAGED by map: a tighter cap on the tiny
## zone-1 (Farmhouse) board, the full cap from zone 2 on (the §6 rolling window is POP_LINE_CAP maps wide).
static func pop_line_cap(map: int) -> int:
	return POP_LINE_CAP_Z1 if map <= 0 else POP_LINE_CAP

## Lines that have RETIRED by the time you reach `map` — the maps that have fallen OUT of the rolling
## window (every map z < map-LINE_WINDOW+1). A retired line is never popped or asked again (it archives
## to the Collection — that hook is a separate task; here it simply drops out of the live set).
static func retired_lines(roster: Array, map: int) -> Array:
	var out: Array = []
	for z in maxi(0, map - LINE_WINDOW + 1):     # maps 0 .. (window start - 1) — everything before the window
		for l in lines_for_map(roster, z):
			if not out.has(int(l)):
				out.append(int(l))
	return out

## The generator the player is OWED but doesn't have. Birth-on-tap per line: restored-zone count
## (`unlocks.size()`) selects the active base-line window, then the newest active line lacking a generator
## is due. Fresh saves self-heal `gen_1`; after the first restored zone, `gen_2` becomes due if unowned.
## `gates` is kept for the call-site signature.
static func due_generators(unlocks: Dictionary, gates: Array, owned_ids: Array) -> Array:
	# gen redesign: birth-on-tap per line. current_zone = spots restored; the newest active base line lacking
	# a generator is due (Core §6.B). At start (zone 0) gen_1 is due if unowned — the FTUE anchor self-heals.
	var gid := due_line_gen(unlocks.size(), owned_ids)
	return [gid] if gid != "" else []

# --- §6 ZONE PROGRESSION (gen redesign 2026-06-28) — the new per-line model -----------------------------
# The world is a run of ZONES (each = a restoration spot). Rhythm base · base · special: zone z (0-based)
# with z%3 in {0,1} introduces a BASE line (its own generator); z%3==2 is a SPECIAL line crafted by merging
# the two preceding base lines (no generator). Built ADDITIVELY — the board still runs the legacy roster
# until the wiring flips. Pure derivation off ZONE_BASE_LINES / ZONE_SPECIAL_LINES.
static func zone_is_special(z: int) -> bool:
	return z >= 0 and z % 3 == 2

# The line a zone introduces (a base line, or a special line on every 3rd zone). 0 if out of range.
static func zone_line(z: int) -> int:
	if z < 0 or z >= ZONE_COUNT:
		return 0
	if zone_is_special(z):
		var si := z / 3
		return int(ZONE_SPECIAL_LINES[si]) if si < ZONE_SPECIAL_LINES.size() else 0
	var bi := z - (z / 3)   # base lines skip the every-3rd special zones
	return int(ZONE_BASE_LINES[bi]) if bi < ZONE_BASE_LINES.size() else 0

# The two base lines a special zone is crafted from (its two preceding base zones); [] for a base zone.
static func zone_recipe(z: int) -> Array:
	if not zone_is_special(z):
		return []
	return [zone_line(z - 2), zone_line(z - 1)]

# The SPECIAL line crafted by merging two base lines at the same tier (Core §6.G). Order-independent; 0 if
# the pair isn't a recipe. (Derived: the special zone whose two preceding base lines are this pair.)
static func special_for_pair(line_a: int, line_b: int) -> int:
	for z in ZONE_COUNT:
		if not zone_is_special(z):
			continue
		var r := zone_recipe(z)
		if r.size() == 2 and ((int(r[0]) == int(line_a) and int(r[1]) == int(line_b)) or (int(r[0]) == int(line_b) and int(r[1]) == int(line_a))):
			var s := zone_line(z)
			return s if LINES.has(s) else 0   # 76-77 unauthored (no LINES def) → no craft (would make an unrenderable item)
	return 0

# --- §7 quest-side generator cap (gen redesign #16, RE-SCOPED) -----------------------------------------
# The generator(s) a quest for `line` REQUIRES: a base line → its own generator; a crafted SPECIAL line →
# its 2 ingredient base-line generators (the special has no generator of its own).
static func _gens_for_quest_line(line: int) -> Array:
	var gid := gen_for_line(int(line))
	if gid != "":
		return [gid]
	var z := zone_of_line(int(line))
	var out: Array = []
	for il in (zone_recipe(z) if z >= 0 else []):
		var ig := gen_for_line(int(il))
		if ig != "" and not out.has(ig):
			out.append(ig)
	return out

# Trim the askable quest-line pool so the active quests can never DEMAND more than QUEST_GEN_CAP distinct
# generators (a base ask = 1, a merge/special ask = its 2 ingredients). Stops merge-quests forcing the player
# into a huge generator count; the player's BOARD itself stays uncapped (births/dups place freely).
static func cap_quest_lines(lines: Array, cap: int = QUEST_GEN_CAP) -> Array:
	var out: Array = []
	var used := {}
	for line in lines:
		var union := used.duplicate()
		for g in _gens_for_quest_line(int(line)):
			union[g] = true
		if union.size() > cap:
			continue                              # this line would push the generator footprint past the cap
		used = union
		out.append(int(line))
	return out

# A base line → its generator id ("gen_<line>"); "" if the line is a special (no generator).
static func gen_for_line(line: int) -> String:
	return "gen_%d" % int(line) if ZONE_BASE_LINES.has(int(line)) else ""

# zone → which of the 5 maps it sits in. Zone = restoration spot, so a zone's map IS its spot's map:
# derived live from the MAPS spot counts (map_for_spots), never a hardcoded distribution — so it can't
# drift from the vine-region layout the way the old ZONE_MAP_SPOTS const did.
static func zone_map(z: int) -> int:
	return map_for_spots(z)

# The zone a line is introduced at (inverse of zone_line); -1 if the line is not in the zone roster.
static func zone_of_line(line: int) -> int:
	for z in ZONE_COUNT:
		if zone_line(z) == int(line):
			return z
	return -1

# The per-line generator def for a base line: {id, line, zone, map}. {} for a special line (no generator).
static func base_generator(line: int) -> Dictionary:
	if not ZONE_BASE_LINES.has(int(line)):
		return {}
	var z := zone_of_line(int(line))
	return {"id": gen_for_line(int(line)), "line": int(line), "zone": z, "map": zone_map(z)}

# All 16 base-line generators, in zone order — the new per-line roster (replaces the 5 multi-line GENERATORS
# when the board flips). Special lines have no generator and are absent here.
static func base_generators() -> Array:
	var out: Array = []
	for line in ZONE_BASE_LINES:
		out.append(base_generator(int(line)))
	return out

# The base lines ACTIVE at a given progress (current_zone = spots restored so far): a rolling window of the
# last LINE_WINDOW base zones reached (specials aren't window slots — they're crafted from active base lines).
static func active_base_lines(current_zone: int) -> Array:
	var out: Array = []
	var z := mini(current_zone, ZONE_COUNT - 1)
	while z >= 0 and out.size() < LINE_WINDOW:
		if not zone_is_special(z):
			out.append(zone_line(z))
		z -= 1
	out.reverse()
	return out

# The SPECIAL (merge) lines the player can be ASKED for right now (gen redesign #14/#16): a special whose
# zone has been REACHED (current_zone = spots restored) AND whose two ingredient base lines are BOTH still in
# `base_lines` — so it is craftable NOW (pop both ingredients, merge them, Core §6.G). Gating on the live
# ingredients keeps every special quest PRODUCIBLE (no-strand) and lets cap_quest_lines fold its shared
# generators into the footprint cap (a special adds no generator the base asks didn't already need).
static func active_special_lines(base_lines: Array, current_zone: int) -> Array:
	var out: Array = []
	for z in range(ZONE_COUNT):
		if not zone_is_special(z):
			continue
		if z > current_zone:
			break                                  # zones are reached in order — nothing past current_zone yet
		var r := zone_recipe(z)
		# LINES.has gate: specials 76-77 have no art/def yet (ZONE_SPECIAL_LINES lists them; LINES doesn't) —
		# keep them DORMANT (never asked) until authored, so a quest card always has a piece to render.
		if r.size() == 2 and base_lines.has(int(r[0])) and base_lines.has(int(r[1])) and LINES.has(zone_line(z)):
			out.append(zone_line(z))
	return out

# gen redesign (#12, simplified): the BASE lines a quest may ask — a rolling window of the last QUEST_GEN_CAP
# base lines REACHED (current_zone = spots restored). The SINGLE quest window: the old map-wide askable_lines
# pulled in whole maps (and cap_quest_lines then kept the OLDEST 6); this slides with the player and matches the
# born generators. Specials are crafted FROM these (active_special_lines), never a window slot of their own.
static func quest_base_lines(current_zone: int) -> Array:
	var out: Array = []
	var z := mini(current_zone, ZONE_COUNT - 1)
	while z >= 0 and out.size() < QUEST_GEN_CAP:
		if not zone_is_special(z):
			out.append(zone_line(z))
		z -= 1
	out.reverse()
	return out

# The generator the player is OWED but lacks (birth-on-tap, Core §6.B): the newest active base line whose
# generator isn't owned. "" if none due. (current_zone = spots restored; owned_ids = gens on board + bag.)
static func due_line_gen(current_zone: int, owned_ids: Array) -> String:
	var lines := active_base_lines(current_zone)
	lines.reverse()   # newest first
	for line in lines:
		var gid := gen_for_line(int(line))
		if gid != "" and not owned_ids.has(gid):
			return gid
	return ""

# --- §6.D generator merge ladder (gen redesign 2026-06-28) ---------------------------------------------
# A generator's burst odds at its tier (1..GEN_TOP_TIER); higher tier pops more multiples.
static func gen_burst_odds(tier: int) -> Array:
	return GEN_TIER_BURST_ODDS[clampi(tier, 1, GEN_TOP_TIER) - 1]

# Two same-line generators merge 2:1 into the next tier (capped at GEN_TOP_TIER).
static func gen_merge_tier(tier: int) -> int:
	return mini(tier + 1, GEN_TOP_TIER)

# A below-top generator self-produces a duplicate at GEN_SELF_DUP_RATE per tap (the merge fuel).
static func rolls_gen_self_dup(rng: RandomNumberGenerator) -> bool:
	return rng.randf() < GEN_SELF_DUP_RATE

# A generator's burst count at its tier (1..N items), rolled over its tier odds.
static func gen_burst_count(tier: int, rng: RandomNumberGenerator) -> int:
	var odds := gen_burst_odds(tier)
	var n := 1
	var roll := rng.randf()
	var acc := 0.0
	for i in odds.size():
		acc += float(odds[i])
		if roll <= acc:
			n = i + 1
			break
	return clampi(n, 1, odds.size())

static func gen_def(roster: Array, id: String) -> Dictionary:
	for g in roster:
		if String(g.id) == id:
			return g
	return {}

## The map a LINE belongs to — its emitting generator's `map` (0-indexed). Pure derivation
## off the GENERATORS roster (line → the generator whose `lines` lists it → that gen's map).
## Drives the §6/§9 per-map sell band. Returns 0 if the line has no generator (defensive: an
## unrostered/coin line falls to the map-1 band 1.0 rather than crashing the sell path).
static func map_for_line(line: int) -> int:
	for g in GENERATORS:
		if int(g.get("line", 0)) == int(line):
			return int(g.map)
	# gen redesign: a special line has no generator — map it via its zone (its recipe's region).
	var z := zone_of_line(int(line))
	return zone_map(z) if z >= 0 else 0

## The map an ITEM (code = line*100 + tier) belongs to — derive its line, then its map.
## The sell band reads this so later-map harvests sell for more coins (§6).
static func map_for_code(code: int) -> int:
	return map_for_line(int(code / 100.0))

## The lines currently LIVE = the union of the lines of every generator on the board.
## `gen_state` maps cell (Vector2i) -> generator id. Sorted, deduped.
static func gen_live_lines(gen_state: Dictionary, roster: Array) -> Array:
	var out: Array = []
	for cell in gen_state:
		var l := int(gen_def(roster, String(gen_state[cell])).get("line", 0))   # gen redesign: one line per gen
		if l > 0 and not out.has(l):
			out.append(l)
	out.sort()
	return out

## The cell a generator occupies — its own authored `cell`. Generators persist (no hand-in
## lineage), so each def carries the cell it lives on.
static func gen_cell_of(roster: Array, id: String) -> Vector2i:
	return gen_def(roster, id).get("cell", Vector2i(-1, -1))

## The live generator set for a map: {cell -> id} for each of the map's generators at their
## own authored cells. Seeds the board's generators (seed_gens) and backs the sim/shot tools.
static func live_gen_state(roster: Array, map: int, level: int = APPEAR_ALL) -> Dictionary:
	var out: Dictionary = {}
	for g in generators_for_map(roster, map, level):
		out[gen_cell_of(roster, String(g.id))] = String(g.id)
	return out

# --- the obstacle field (§4): every non-center cell is sealed until the player's Level reaches
# --- its min_level, then opens on the next adjacent merge. `terrain` is a plain sealed flag
# --- (0 = open, >0 = sealed); the gate is the STATIC MIN_LEVEL table, never the stored value —
# --- so legacy saves (old tier-encoded terrain) still read as "sealed" and need no migration.
## The Level a cell unseals at (§4). 0 = open at start (the center 3×3 + the generator). The
## grove authors a hand-tuned diamond (L2/L3 frontier → L12 corners) in MIN_LEVEL; we read it.
static func cell_min_level(cell: Vector2i) -> int:
	return int(MIN_LEVEL[cell.x][cell.y])

static func open_at_start(cell: Vector2i) -> bool:
	return cell_min_level(cell) == 0

static func bramble_terrain(cell: Vector2i) -> int:        # sealed marker = the min_level (inspectable)
	return cell_min_level(cell)

## A freshly-opened cell's reward item — a low-tier seed of a positional anchor line. The gate is
## level-based now, so contents no longer carry a gate line; derive deterministically (lines 1-2).
static func bramble_contents(cell: Vector2i) -> int:
	var line := 1 + (cell.x + cell.y) % 2
	var tier := 1 + (cell.x * 3 + cell.y) % 2     # t1 or t2
	return line * 100 + tier

static func quest_item(q: Dictionary) -> Dictionary:
	if q.has("line"):
		return {"line": int(q.line), "tier": int(q.tier)}
	if q.has("asks") and not q.asks.is_empty():   # tolerate a stale pre-change save
		return {"line": int(q.asks[0].line), "tier": int(q.asks[0].tier)}
	return {}

## Clicks (generator pops / water / merge-cost) to BUILD one tier-`t` item: merge is 2:1 and
## generators pop tier-1, so a tier-N item costs 2^(N-1) clicks. The fundamental effort unit.
static func tier_clicks(t: int) -> int:
	return int(pow(2, maxi(1, t) - 1))

## EFFORT-BASED quest reward, keyed on the asked TIER and the MAP (§7). The whole economy is priced
## in clicks (= the effort to build the asked item):
##   exp   = round(clicks / QUEST_CLICKS_PER_EXP)                       — flat across maps (progression clock)
##   coins = round(clicks / QUEST_CLICKS_PER_COIN[map] × depth^(tier-base)) — later maps + deeper merges pay more
##   acorns= NONE (acorns are milestone/IAP only — Option A). `map` is 0-indexed; defaults to map 1.
## All numbers OWNER/SIM tunables (grove_data); validated against the 100K-click budget (docs/economy_model.html).
static func quest_reward(tier: int, map: int = 0) -> Dictionary:
	var c := float(tier_clicks(tier))
	var cpc_arr: Array = QUEST_CLICKS_PER_COIN
	var cpc: float = float(cpc_arr[clampi(map, 0, cpc_arr.size() - 1)]) if not cpc_arr.is_empty() else 8.0
	var depth: float = pow(QUEST_COIN_DEPTH, maxi(0, tier - QUEST_TIER_BASE))
	return {
		"exp": maxi(1, int(round(c / float(QUEST_CLICKS_PER_EXP)))),
		"coins": maxi(0, int(round(c / cpc * depth))),
	}

## The diamond-priced quest-reward 2× DOUBLER (§10). Pure economy helpers — the board UI reads
## these to decide whether to offer the card and what it costs. The doubler grants `got` extra
## coins (doubling the reward to 2×); it costs floor(got / COLLECT_2X_COIN_RATE) 💎, and is ONLY
## offered when got is big enough to afford 1 💎 — which guarantees coins-per-💎 (got / cost) is
## at least COLLECT_2X_COIN_RATE, strictly better than the shop coin pouch (a test guards this).

## Whether the 2× doubler is worth offering for a `got`-coin reward (the deal beats the shop).
static func collect_2x_offered(got: int) -> bool:
	return got >= COLLECT_2X_COIN_RATE

## The 💎 price to double a `got`-coin reward. floor(got / rate) — always >= 1 when offered, and
## scaled so the effective rate (got / cost) stays >= COLLECT_2X_COIN_RATE for any reward size.
static func collect_2x_cost(got: int) -> int:
	return maxi(1, got / COLLECT_2X_COIN_RATE)

## Weighted random index into the parallel `weights` array (all ≥ 0). Returns -1 when every weight
## is 0. The `weights[i] > 0.0` guard plus the backward-scan fallback make it impossible to return a
## zero-weight entry, so a HARD-excluded candidate is never picked by a float-rounding slip.
static func _weighted_index(weights: Array, rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for w in weights:
		total += float(w)
	if total <= 0.0:
		return -1
	var r := rng.randf() * total
	var acc := 0.0
	for i in weights.size():
		acc += float(weights[i])
		if float(weights[i]) > 0.0 and r <= acc:
			return i
	for i in range(weights.size() - 1, -1, -1):
		if float(weights[i]) > 0.0:
			return i
	return -1

## True when EVERY candidate item's code (line*100+tier) is in `avoid` — i.e. excluding the whole
## avoid set would leave nothing to ask. Used to relax an over-large avoid window on a tiny pool.
static func _all_avoided(items: Array, avoid: Array) -> bool:
	for it in items:
		if not avoid.has(int(it.line) * 100 + int(it.tier)):
			return false
	return true

## Generate a regular quest for a player at `level` from the live lines (§7). A quest is a FLAT
## single item — difficulty rises by higher TIER + more FREQUENT quests (level ∝ quest count, §3).
## The ITEM (line, tier) is drawn from the candidate space of every askable line×tier: a line's tiers
## ALWAYS span the full band [QUEST_TIER_BASE, TOP_TIER] (9 items at 4..12), so even a single live line
## offers plenty of distinct asks. Within a line the tier is a NORMAL bell whose PEAK and SPREAD ramp
## with level — μ slides from the floor (peak ≈ t4 early) up to the band centre, σ widens from ~t4–t6
## early to the full t4–t12 late — so early asks stay low/achievable while late asks reach the top
## without ever gating tiers out. Each item's weight is its line's newest-bias weight
## ((rank+1)^QUEST_NEWEST_BIAS) times that bell, so the LINE distribution still leans at the richest content.
## `avoid` is a PRIORITY-ORDERED list of recently/concurrently asked ITEM codes (line*100+tier; oldest
## first, freshest + concurrent stands last): each is HARD-excluded (weight 0), so a new ask never
## repeats one of the previous few — variety can come from a different TIER of the same line, not only a
## different line. If the pool is too small to honour the whole window, it relaxes from the oldest end
## until one item is free, so no two asks in a row repeat while >1 item exists (anti-monotony, §7).
## Reward is EFFORT-BASED on the asked tier (+ `map` for coins): exp=round(clicks/7),
## coins=round(clicks/cpc[map]×depth^(tier-base)), no acorns. Deterministic given `rng`.
## Returns {line, tier, reward, featured}. All numbers OWNER/SIM tunables (docs/economy_model.html).
static func gen_quest(level: int, live_lines: Array, rng: RandomNumberGenerator, avoid: Array = [], map: int = 0) -> Dictionary:
	var lines: Array = live_lines.duplicate()
	lines.sort()                                       # ascending: last entry = newest / highest-value
	# Per-tier bell over the FULL band [QUEST_TIER_BASE, TOP_TIER] — so every line always offers all of
	# its tiers (9 items at BASE=4, TOP=12), even at level 0. weight(t) ∝ exp(-½((t-μ)/σ)²). The band is
	# fixed; the difficulty RAMP lives in μ (the peak) and σ (the spread), which climb with level:
	#   `soft_hi` is the old soft ceiling (climbs +1 every QUEST_LEVELS_PER_TIER levels, capped at TOP).
	#   μ = midpoint(BASE, soft_hi) → starts at the floor (peak = t4 early), slides up to the band centre.
	#   σ = width/4 with a floor of 1.0 → early asks span ~t4–t6 (achievable) but never collapse to a
	#       single tier (which would force repeats); late asks spread the full bell over t4–t12.
	var soft_hi: int = clampi(QUEST_TIER_BASE + int(level / float(QUEST_LEVELS_PER_TIER)), QUEST_TIER_BASE, TOP_TIER)
	var mu: float = (QUEST_TIER_BASE + soft_hi) / 2.0
	var sigma: float = maxf((soft_hi - QUEST_TIER_BASE) / 4.0, 1.0)
	var tier_w: Array = []                             # bell weight per tier, indexed t - QUEST_TIER_BASE
	var tier_sum := 0.0
	for t in range(QUEST_TIER_BASE, TOP_TIER + 1):
		var z: float = (t - mu) / sigma
		var g: float = exp(-0.5 * z * z)
		tier_w.append(g)
		tier_sum += g
	# Candidate ITEMS: every askable line×tier, carrying its line's newest-bias weight × the tier bell
	# (normalised so each line's tiers sum to the line weight — the line distribution is unchanged).
	var items: Array = []
	var base_w: Array = []
	for i in lines.size():
		var ln := int(lines[i])
		var line_w: float = pow(i + 1, QUEST_NEWEST_BIAS)
		for t in range(QUEST_TIER_BASE, TOP_TIER + 1):
			items.append({"line": ln, "tier": t})
			base_w.append(line_w * tier_w[t - QUEST_TIER_BASE] / tier_sum)
	# Hard-exclude every avoided ITEM. `avoid` is PRIORITY-ORDERED (oldest asks first; the most-recent
	# asks and the concurrent fence stands last). If excluding all of it would leave NO candidate free —
	# the live item pool is smaller than the avoid window, common on an early map with few lines — relax
	# from the FRONT (drop the oldest entries) until one item is free, so the freshest asks stay excluded
	# longest. Guarantees no two asks in a row repeat whenever the pool holds >1 distinct item.
	var eff: Array = avoid.duplicate()
	while not eff.is_empty() and _all_avoided(items, eff):
		eff.pop_front()
	var weights: Array = []
	for i in items.size():
		var it: Dictionary = items[i]
		weights.append(0.0 if eff.has(int(it.line) * 100 + int(it.tier)) else base_w[i])
	var pick: int = _weighted_index(weights, rng)
	if pick < 0:
		pick = 0
	var chosen: Dictionary = items[pick]
	var li := int(chosen.line)
	var tier := int(chosen.tier)
	var reward: Dictionary = quest_reward(tier, map)
	var featured: bool = rng.randf() < QUEST_FEATURED_RATE
	if featured:
		# the featured bonus is COINS ONLY, NEVER extra exp (§7 level ∝ quests-done) and NEVER acorns
		# (Option A: acorns are milestone/IAP only). A flat coin sweetener on the asked item.
		reward["coins"] = int(reward.coins) + QUEST_FEATURED_COIN_BONUS
	return {"line": li, "tier": tier, "reward": reward, "featured": featured}

## §7 giver meter: how many giver stands are active for a remaining-exp target —
## ≈ ceil((target - earned_exp) / EXP_PER_QUEST_EST), capped at MAX_GIVERS, and 0 once the
## target is reached. Quests.meter_target sizes the fence to the WHOLE map's remaining exp, so
## the fence stays full through the map and only tapers at the very end. target == -1 means done.
static func active_giver_count(earned_exp: int, target_exp: int, max_givers: int = MAX_GIVERS) -> int:
	if target_exp == -1:
		return 0
	var need := target_exp - earned_exp
	if need <= 0:
		return 0
	return clampi(int(ceil(need / float(EXP_PER_QUEST_EST))), 1, max_givers)

## Burst-pop (§6, T58): one tap on a generator pops a BURST of items, not just one. The COUNT is drawn
## from an odds table — BURST_ODDS when no boost is live (a single item is the norm, multiples are rare)
## or BURST_ODDS_BOOST while a boost is live (multiples become the norm). The boost RAISES THE CHANCE of
## multiples; it does NOT add a flat count, and there is no per-map scale-up (`_map` is unused — kept for
## call-site stability). `boost_bonus > 0` marks a live boost. Clamped to [1, BURST_MAX] as a board-flood
## safety net. Each popped item still costs 1 energy.
static func burst_count(_map: int, boost_bonus: int, rng: RandomNumberGenerator) -> int:
	var odds: Array = BURST_ODDS_BOOST if boost_bonus > 0 else BURST_ODDS
	var n := 1
	var roll := rng.randf()
	var acc := 0.0
	for i in odds.size():
		acc += float(odds[i])
		if roll <= acc:
			n = i + 1
			break
	return clampi(n, 1, BURST_MAX)

## The temporary BOOST (§6/§10 coin sink). One activation arms BOOST_TAPS generator taps that each
## drop BOOST_BONUS extra items, board-wide, then it expires. The arm count rides the grove blob under
## "boost_taps" (0 = none active). Replaces the old permanent burst-upgrade ladder (T57).
static func boost_cost() -> int:
	return BOOST_COST

## The boost's magnitude: extra items per generator tap while it is live (the caller gates on active).
static func boost_bonus() -> int:
	return BOOST_BONUS

## Generator taps left on the live boost (0 = none active), read from the grove blob.
static func boost_taps_left() -> int:
	return int(Save.grove().get("boost_taps", 0))

## Is a boost currently live?
static func boost_active() -> bool:
	return boost_taps_left() > 0

## The single arm path the info-bar chip drives. Refuses (no spend) when a boost is already live or
## when broke; else spends BOOST_COST, arms BOOST_TAPS taps, and persists. Returns true on a real arm.
static func try_activate_boost() -> bool:
	if boost_active():
		return false                          # one boost at a time — no re-buy while live
	if not Save.spend(BOOST_COST, "boost"):
		return false                          # not enough coins
	Save.grove()["boost_taps"] = BOOST_TAPS
	Save.grove_write()
	return true

## Arm one boost for FREE (no coin spend) — the path the habitat's map-3 boost CHARGE drives
## (Habitat.use_boost_charge). Refuses (no arm) when a boost is already live, mirroring try_activate_boost's
## one-at-a-time rule. Returns true on a real arm.
static func arm_boost_free() -> bool:
	if boost_active():
		return false
	Save.grove()["boost_taps"] = BOOST_TAPS
	Save.grove_write()
	return true

## Spend one tap off the live boost — called once per charged generator tap. No-op (never underflows)
## when no boost is active. Persists so the count rides app restarts.
static func consume_boost_tap() -> void:
	var left := boost_taps_left()
	if left <= 0:
		return
	Save.grove()["boost_taps"] = left - 1
	Save.grove_write()

# --- §1 residents: the population sub-game (welcome + auto-merge) ------------------
# Residents are WELCOMED (bought) on a COMPLETED map; two of the same type+tier AUTO-MERGE
# into one a tier up (cascading). The roster is persisted (Save.residents…); the ambient
# display rebuilds from it (stateless), with NO cap. A map is addressed by int `z`; the data
# layer keys by map_id (MAPS[z].id). Cost: coins for core/non-premium, diamonds for premium.

## Can the player welcome residents on map `z`? §1 EARLY POPULATION — opens as soon as the FIRST spot is
## restored (not full completion). The roster CAPACITY then ramps 1 → RESIDENT_SLOTS_MAX as more spots are
## restored (`resident_capacity`). `gates` is retained for signature compatibility (no longer gates the open).
static func can_populate(z: int, unlocks: Dictionary, _gates: Array = []) -> bool:
	return map_spots_restored(z, unlocks) >= 1

## How many of map `z`'s spots are restored (claimed in `unlocks`). Drives both the early-population open
## (≥1) and the roster capacity ramp.
static func map_spots_restored(z: int, unlocks: Dictionary) -> int:
	var n := 0
	for sp in MAPS[z].spots:
		if unlocks.has(String(sp.id)):
			n += 1
	return n

## The resident SLOT capacity on map `z`: 1 at the first restored spot, ramping linearly to
## RESIDENT_SLOTS_MAX once every spot is restored. 0 before any spot (roster not open). The LIVE roster is
## the Habitat (engine/scripts/core/habitat.gd) — Habitat.cap reads this ramp; Habitat.is_full / .sell
## enforce + free slots (a full roster is thinned by a merge or a sell, the live "throw away").
static func resident_capacity(z: int, unlocks: Dictionary) -> int:
	var total := int(MAPS[z].spots.size())
	var done := map_spots_restored(z, unlocks)
	if done <= 0 or total <= 0:
		return 0
	if total <= 1:
		return RESIDENT_SLOTS_MAX
	return 1 + int(floor(float(RESIDENT_SLOTS_MAX - 1) * float(done - 1) / float(total - 1)))

## The resident types OFFERED on map `z`: the shared core + that map's signature (each a
## Dictionary {id, name, premium?}). Delegates to the game data, addressed by the map's id.
static func resident_lines(z: int) -> Array:
	return D.resident_lines(String(MAPS[z].id))

## The home map index for a resident kind, derived from the resident lines each map offers.
## Returns -1 for unknown kinds.
static func resident_home_map(kind: String) -> int:
	for z in MAPS.size():
		for td in resident_lines(z):
			if String(td.get("id", "")) == kind:
				return z
	return -1

## The home map id for a resident kind, or "" for unknown kinds.
static func resident_home_map_id(kind: String) -> String:
	var z := resident_home_map(kind)
	return String(MAPS[z].id) if z >= 0 else ""

## The per-map one-time unlock gift {coins, gems, spirit}. Delegates to the game data.
static func map_unlock_reward(z: int) -> Dictionary:
	return D.map_unlock_reward(z)

## The cost to welcome a t1 of `type_def`: {currency, cost}. Premium (signature, marked) types
## cost diamonds (RESIDENT_PREMIUM_COST); everything else costs coins (RESIDENT_BASE_COST).
static func resident_cost(type_def: Dictionary) -> Dictionary:
	if bool(type_def.get("premium", false)):
		return {"currency": "diamonds", "cost": int(RESIDENT_PREMIUM_COST)}
	return {"currency": "coins", "cost": int(RESIDENT_BASE_COST)}

## The res:// art path for a resident `type_id` at `tier` (the per-tier item-line ladder via Game.art).
## tier defaults to 1 so shop/reveal callers that only show the base form need not pass it.
static func resident_art(type_id: String, tier: int = 1) -> String:
	return Game.art(RESIDENT_ART % [type_id, type_id, tier])

## The data behind the residents SHOP: one card per offered resident on map z — {id, name, cost, currency,
## affordable}. Affordability reads the live wallet (coins/diamonds). Pure model; the scene turns each into
## a Kit shop card (icon node + price pill + on_buy).
static func residents_shop_cards(z: int) -> Array:
	var out: Array = []
	for td in resident_lines(z):
		var cost: Dictionary = resident_cost(td)
		var cur := String(cost.currency)
		var have := Save.diamonds() if cur == "diamonds" else Save.coins()
		out.append({"id": String(td.id), "name": String(td.name), "cost": int(cost.cost),
			"currency": cur, "affordable": have >= int(cost.cost)})
	return out

## Flatten map `z`'s persisted roster into one {type, tier} per resident INSTANCE — what the
## wander layer renders. Stable order: resident_lines order, then tier 1..MAX, pushing one copy
## per counted resident. Reads the counts off Save (no merge here — that's resolve_…).
static func resident_members(z: int) -> Array:
	var map_id := String(MAPS[z].id)
	var out: Array = []
	for type_def in resident_lines(z):
		var tid := String(type_def.id)
		var counts: Array = Save.resident_counts(map_id, tid)
		for t in range(1, RESIDENT_MAX_TIER + 1):
			var n := int(counts[t - 1]) if t - 1 < counts.size() else 0
			for _i in n:
				out.append({"type": tid, "tier": t})
	return out

## Resolve all pending two-of-a-kind merges on map `z`, cascading upward: for each type, for each
## tier below the cap, while ≥2 sit at that tier, consume two and add one a tier up. Persists the
## new counts (Save.set_resident_counts) and returns the merge events [{type, from, to}], in order.
static func resolve_resident_merges(z: int) -> Array:
	var map_id := String(MAPS[z].id)
	var events: Array = []
	for type_def in resident_lines(z):
		var tid := String(type_def.id)
		var counts: Array = Save.resident_counts(map_id, tid).duplicate()
		var changed := false
		for tier in range(1, RESIDENT_MAX_TIER):     # 1..(MAX-1): the top tier never merges further
			while int(counts[tier - 1]) >= 2:
				counts[tier - 1] = int(counts[tier - 1]) - 2
				counts[tier] = int(counts[tier]) + 1
				events.append({"type": tid, "from": tier, "to": tier + 1})
				changed = true
		if changed:
			Save.set_resident_counts(map_id, tid, counts)
	return events

## Add one tier-1 instance of `type_id` to map z's roster and cascade two-of-a-kind merges. The shared
## spend-free core of welcome_resident (paid) and the unlock gift (free). Returns the merge events.
static func grant_resident(z: int, type_id: String) -> Array:
	var map_id := String(MAPS[z].id)
	var counts: Array = Save.resident_counts(map_id, type_id).duplicate()
	counts[0] = int(counts[0]) + 1
	Save.set_resident_counts(map_id, type_id, counts)
	return resolve_resident_merges(z)

## Welcome (buy) one t1 resident of `type_id` on map `z`: charge the cost (coins or diamonds via Save),
## then grant_resident. Returns {ok, events}: ok=false with no events on insufficient funds; ok=true with
## the merge events on success.
static func welcome_resident(z: int, type_id: String) -> Dictionary:
	var type_def: Dictionary = {}
	for td in resident_lines(z):
		if String(td.id) == type_id:
			type_def = td
			break
	if type_def.is_empty():
		return {"ok": false, "events": []}
	var cost: Dictionary = resident_cost(type_def)
	var paid: bool
	if String(cost.currency) == "diamonds":
		paid = Save.spend_diamonds(int(cost.cost))
	else:
		paid = Save.spend(int(cost.cost), "welcome_resident")
	if not paid:
		return {"ok": false, "events": []}
	var events := grant_resident(z, type_id)
	return {"ok": true, "events": events}

## Grant map z's one-time unlock gift if still unclaimed: coins + diamonds + the free signature spirit.
## Sets the per-map `task_reward` flag so it pays exactly once (shared with the legacy completion gift).
## Returns the granted reward {coins, gems, spirit, events} on the first claim, or {} if already claimed
## (so the scene knows whether to show the celebration dialog). Pure model; no FX, no UI.
static func claim_unlock_reward(z: int) -> Dictionary:
	var g := Save.grove()
	var claimed: Dictionary = g.get("task_reward", {})
	var key := String(MAPS[z].id)
	if claimed.has(key):
		return {}
	claimed[key] = true
	g["task_reward"] = claimed
	Save.grove_write()
	var rew: Dictionary = D.map_unlock_reward(z)
	var coins := int(rew.get("coins", 0))
	var gems := int(rew.get("gems", 0))
	var spirit := String(rew.get("spirit", ""))
	if coins > 0:
		Save.add_coins(coins)
	if gems > 0:
		Save.add_diamonds(gems)
	var events: Array = []
	if spirit != "":
		events = grant_resident(z, spirit)
	return {"coins": coins, "gems": gems, "spirit": spirit, "events": events}

static func map_for_spots(i: int) -> int:
	var acc := 0
	for z in MAPS.size():
		acc += MAPS[z].spots.size()
		if i < acc:
			return z
	return MAPS.size() - 1

static func map_spots_done(z: int, unlocks: Dictionary) -> bool:
	# A map with no spots has nothing restored yet, so it is NOT "done". This guards the region-less
	# vine map (a registered map whose regions aren't authored yet, shown as clean base art): without
	# it, a spot-less map would read as vacuously complete and wrongly pay the map reward, get added to
	# `gates`, unlock the next map, and invite residents. Every legacy map ships 8 spots, so this only
	# affects an as-yet-unauthored vine map.
	if MAPS[z].spots.is_empty():
		return false
	for sp in MAPS[z].spots:
		if not unlocks.has(String(sp.id)):
			return false
	return true

static func completed_maps(unlocks: Dictionary) -> int:
	var n := 0
	for z in MAPS.size():
		if map_spots_done(z, unlocks):
			n += 1
	return n

# --- map progression queries (folded from map.gd; the scene keeps thin wrappers) --
static func map_for_id(id: String) -> int:
	for z in MAPS.size():
		if String(MAPS[z].id) == id:
			return z
	return -1

## The index of the home-hub map (the permanent anchor — Core §8 / grove_spec §3). The game
## flags it with `hub: true`; defaults to the first map. Drives the boot landing + the HUD home
## shortcut. (The hub is authored deeper than a finish-once map; its yield loop is the KEYSTONE.)
static func hub_map() -> int:
	for z in MAPS.size():
		if bool(MAPS[z].get("hub", false)):
			return z
	return 0

## A map is fully complete when all its spots are restored AND that completion is recorded in
## `gates` (map indices) — the record now sets automatically the moment the map's spots are done
## (the gate QUEST is retired). The NEXT map unlocks on it (the completion chain).
static func map_complete(z: int, unlocks: Dictionary, gates: Array) -> bool:
	return map_spots_done(z, unlocks) and gate_recorded(gates, z)

## Is map index `z` recorded in `gates`? Compares by INTEGER value, because the save round-trips gate
## indices through JSON, which reloads every number as a float ([0] → [0.0]). Array.has(int) is type-
## strict and would miss the reloaded float, so a plain `gates.has(z)` wrongly re-locked the next map on
## restart (the gate read true in-session as an int, false after reload as a float). int(x) heals both.
static func gate_recorded(gates: Array, z: int) -> bool:
	for x in gates:
		if int(x) == z:
			return true
	return false

## Back-fill `gates` from spots-done state: every map whose spots are ALL restored MUST be recorded in
## `gates`, so map_complete is true and the next map unlocks. Mutates the passed grove blob's `gates`
## array; returns true iff it added anything. IDEMPOTENT and safe to run every boot — it only ADDS
## genuinely-earned gates (map_spots_done already excludes spot-less maps), never removes one. This heals
## a save whose gate write was missed: a pre-§7 save (the gate quest is retired), or one whose spot ids
## were remapped between builds so the old one-shot `if not has("gates")` migration recorded an EMPTY
## gates and then never ran again — which strands the player on a finished map forever (the last-spot
## auto-record never re-fires once every spot is claimed).
static func reconcile_gates(grove: Dictionary) -> bool:
	var unlocks: Dictionary = grove.get("unlocks", {})
	var gates: Array = grove.get("gates", [])
	var changed := false
	for z in MAPS.size():
		if map_spots_done(z, unlocks) and not gate_recorded(gates, z):
			gates.append(z)
			changed = true
	if changed:
		grove["gates"] = gates
	return changed

# A map is visitable once the previous map is complete (all its spots claimed). This stays a
# pure completion-chain, but it is still gated by exp transitively: a map's spots can only be
# claimed as exp crosses their thresholds, and the next map's first threshold is higher than
# this map's last — so the chain advances exactly as exp climbs through the global ladder.
static func map_unlocked(z: int, unlocks: Dictionary, gates: Array = []) -> bool:
	return z == 0 or map_complete(z - 1, unlocks, gates)

static func owned_count(z: int, unlocks: Dictionary) -> int:
	var n := 0
	for s in MAPS[z].spots:
		if unlocks.has(String(s.id)):
			n += 1
	return n

static func frontier_map(unlocks: Dictionary, gates: Array = []) -> int:
	for z in MAPS.size():
		if map_unlocked(z, unlocks, gates) and not map_complete(z, unlocks, gates):
			return z
	return -1

# --- sell / economy formulas ------------------------------------------------------
## What an item sells for at the merchant (§9): Vector2i(coins, premium). Option A: EVERY tier sells
## for its tier in coins SCALED by the item's per-map band (§6 — later maps sell for more). There is NO
## premium-sell pinnacle anymore — selling never mints acorns (acorns are milestone/IAP only), so the
## old t8=1💎 special case + the 32× anti-arbitrage guard are retired. `premium` is always 0 here.
static func sell_reward(code: int) -> Vector2i:
	var tier := code % 100
	# §6.D premium treat lines sell at a flat premium band; everything else at its per-map band.
	var band: float = TREAT_SELL_BAND if is_treat_line(code) else sell_map_band(map_for_code(code))
	return Vector2i(int(round(maxi(1, tier) * band)), 0)

## What it costs to BUY a copy of an item via the board info bar (§10, T55): marked up over the
## coin sale value by BUY_MARKUP. Since sell_reward no longer pays premium, the premium component
## is always 0; buying ALWAYS costs strictly more coins than selling returns.
static func buy_price(code: int) -> Vector2i:
	var sell := sell_reward(code)
	return Vector2i(int(ceil(sell.x * BUY_MARKUP)), 0)

## The per-map coin band for `map` (0-indexed), clamped to the table (a map past the table
## reuses the last entry). Owner/sim feel dial for every item sale.
static func sell_map_band(map: int) -> float:
	if SELL_MAP_BAND.is_empty():
		return 1.0
	return float(SELL_MAP_BAND[clampi(map, 0, SELL_MAP_BAND.size() - 1)])

static func water_to_earn_diamond() -> int:
	return int(pow(2, PREMIUM_TIER - 1))
static func water_a_diamond_buys() -> int:
	return int(WATER_CAP / float(REFILL_DIAMOND_COST))

static func is_coin(code: int) -> bool:
	return int(code / 100.0) == COIN_LINE

static func coin_value(code: int) -> int:
	return int(COIN_VALUES.get(code % 100, 0))

static func item_display_name(code: int) -> String:
	var line := int(code / 100.0)
	if is_coin(code):
		return "Coin"
	if LINES.has(line):
		return String((LINES[line] as Dictionary).get("name", "Item"))
	if SPECIAL_ITEMS.has(line):
		return String((SPECIAL_ITEMS[line] as Dictionary).get("name", "Item"))
	return "Item"

static func item_description(code: int) -> String:
	var line := int(code / 100.0)
	if is_coin(code):
		var coins := coin_value(code)
		return "Tap again to collect %d %s." % [coins, "coin" if coins == 1 else "coins"]
	if SPECIAL_ITEMS.has(line):
		var collect := special_collect(code)
		if not collect.is_empty():
			var amount := int(collect.get("amount", 0))
			var kind := String(collect.get("kind", ""))
			match kind:
				"water":
					return "Tap again to collect %d water. Merge first for more." % amount
				"acorn":
					return "Tap again to collect %d %s. Merge first for more." % [amount, "acorn" if amount == 1 else "acorns"]
				"exp":
					return "Tap again to gain %d exp. Merge first for more." % amount
		return String((SPECIAL_ITEMS[line] as Dictionary).get("desc", ""))
	if LINES.has(line):
		return String((LINES[line] as Dictionary).get("desc", ""))
	return ""

static func generator_display_name(id: String) -> String:
	var d := gen_def(GENERATORS, id)
	if not d.is_empty():
		var lbl := String(d.get("label", ""))
		return lbl.capitalize() if lbl != "" else id.capitalize()
	var kind := accumulator_kind_of(id)
	if kind != "":
		return String((ACCUMULATORS[kind] as Dictionary).get("name", kind.capitalize()))
	if is_treat_gen(id):
		var line := treat_line_of(id)
		if LINES.has(line):
			return "%s generator" % String((LINES[line] as Dictionary).get("name", "Treat"))
		return "Treat generator"
	return "Generator"

static func generator_description(id: String) -> String:
	var d := gen_def(GENERATORS, id)
	if not d.is_empty():
		return ""
	var kind := accumulator_kind_of(id)
	if kind != "":
		var unit := "acorns" if kind == "acorn" else kind
		return "Bonus generator — tap to collect %s. Lasts a few taps, then it's gone." % unit
	if is_treat_gen(id):
		var line := treat_line_of(id)
		var name := item_display_name(line * 100 + TREAT_POP_TIER)
		return "Temporary generator. Tap to pop %s items and special drops." % name
	return ""

## A board piece that is POCKETED rather than merged into goods. The single hook the board's
## tap-to-focus / tap-again-to-collect interaction keys off (board.gd _on_release). Coins AND the §6.B
## resource drops (water/acorn/exp) collect this way; chest/key are OPENED by a drag, not tap-collected.
static func is_collectable(code: int) -> bool:
	return is_coin(code) or not special_collect(code).is_empty()

# §6.B special drop items — coin-like pseudo-lines (chest/key/water/acorn/exp). is_special gates the
# shared plumbing (merge ceiling, art, the not-content exclusions); special_kind selects the behaviour.
static func is_special(code: int) -> bool:
	return SPECIAL_ITEMS.has(int(code / 100.0))

static func special_kind(code: int) -> String:
	return String(SPECIAL_ITEMS.get(int(code / 100.0), {}).get("kind", ""))

static func special_base(code: int) -> String:
	return String(SPECIAL_ITEMS.get(int(code / 100.0), {}).get("base", ""))

static func is_wildcard(code: int) -> bool:
	return special_kind(code) == "wildcard"

# A WILDCARD advances ANY same-tier non-wildcard item one tier, consuming the wildcard. (Two wildcards
# instead merge normally via can_merge.) Returns the advanced target code, or 0 if it can't apply here.
static func wildcard_advance_code(wild: int, target: int) -> int:
	if not is_wildcard(wild) or target <= 0 or is_wildcard(target):
		return 0
	if (wild % 100) != (target % 100):                 # must match the target's tier
		return 0
	if (target % 100) >= merge_top(target):            # target already at its merge ceiling
		return 0
	return target + 1

# The merge CEILING for a code: coins + special items cap low (3); content lines reach TOP_TIER. One
# place so can_merge / openable-pair logic agree (board_model, board_logic).
static func merge_top(code: int) -> int:
	if is_coin(code):
		return COIN_TOP
	if is_special(code):
		return int(SPECIAL_ITEMS.get(int(code / 100.0), {}).get("top", SPECIAL_TOP))
	return TOP_TIER

# §6.B special-drop roll + reward math (PURE — board.gd applies the side effects).
# A merge sometimes shakes a special item loose (alongside the coin drop): one randf, weighted kind.
static func rolls_special_drop(rng: RandomNumberGenerator) -> bool:
	return rng.randf() < SPECIAL_DROP_RATE

static func pick_special_drop(rng: RandomNumberGenerator) -> int:    # → a t1 special code, weighted by kind
	var total := 0
	for w in SPECIAL_DROP_WEIGHTS.values():
		total += int(w)
	var r := rng.randi_range(1, maxi(1, total))
	for line in SPECIAL_DROP_WEIGHTS:
		r -= int(SPECIAL_DROP_WEIGHTS[line])
		if r <= 0:
			return int(line) * 100 + 1
	return 10 * 100 + 1                                              # defensive: a chest t1

# What TAPPING a water/acorn/exp item grants: {kind, amount}. Empty for chest/key (opened, not tapped).
static func special_collect(code: int) -> Dictionary:
	var kind := special_kind(code)
	var tier := code % 100
	if SPECIAL_COLLECT.has(kind):
		return {"kind": kind, "amount": int((SPECIAL_COLLECT[kind] as Dictionary).get(tier, 0))}
	return {}

# Whether a key and a chest may OPEN (both special, one chest + one key — order-independent).
static func can_open_chest(a: int, b: int) -> bool:
	var ka := special_kind(a)
	var kb := special_kind(b)
	return (ka == "chest" and kb == "key") or (ka == "key" and kb == "chest")

# The reward for opening a chest with a key: {coins, acorns}. Scales by the CHEST tier and a KEY-tier
# multiplier (a better key opens a richer chest). `a`/`b` in either order.
static func chest_open_reward(a: int, b: int) -> Dictionary:
	var chest := a if special_kind(a) == "chest" else b
	var key := b if special_kind(a) == "chest" else a
	var ct := chest % 100
	var kt := key % 100
	var mult: float = float(KEY_TIER_MULT[kt]) if kt >= 0 and kt < KEY_TIER_MULT.size() else 1.0
	return {
		"coins": int(round(float(int(CHEST_OPEN_COINS.get(ct, 0))) * mult)),
		"acorns": int(round(float(int(CHEST_OPEN_ACORNS.get(ct, 0))) * mult)),
	}

# --- §6.C utility accumulators (bank a resource over time) -----------------------------
# UNLOCKED is derived: an accumulator is live once map-0's spot at its `unlock_spot` index is claimed.
static func accumulator_unlocked(kind: String, unlocks: Dictionary) -> bool:
	var def: Dictionary = ACCUMULATORS.get(kind, {})
	if def.is_empty():
		return false
	var k := int(def.get("unlock_spot", -1))
	var spots: Array = MAPS[0].spots
	if k < 0 or k >= spots.size():
		return false
	return unlocks.has(String(spots[k].id))

# The kinds unlocked at the current spot state, in registry order.
static func unlocked_accumulators(unlocks: Dictionary) -> Array:
	var out: Array = []
	for kind in ACCUMULATORS:
		if accumulator_unlocked(kind, unlocks):
			out.append(kind)
	return out

# Banked units = +1 every `secs` since `last_ts` (offline-inclusive), capped at `cap`. 0 if never started.
static func accumulator_banked(kind: String, last_ts: float, now: float) -> int:
	var def: Dictionary = ACCUMULATORS.get(kind, {})
	if def.is_empty() or last_ts <= 0.0 or now <= last_ts:
		return 0
	var n := int(floor((now - last_ts) / float(def.get("secs", 1))))
	return clampi(n, 0, int(def.get("cap", 0)))

# True once banked is at the cap (the check-in nudge: collect before it idles full).
static func accumulator_full(kind: String, last_ts: float, now: float) -> bool:
	return accumulator_banked(kind, last_ts, now) >= int(ACCUMULATORS.get(kind, {}).get("cap", 0))

# The reward for collecting `banked` units of `kind`: {kind, amount}.
static func accumulator_reward(kind: String, banked: int) -> Dictionary:
	return {"kind": kind, "amount": maxi(0, banked) * int(ACCUMULATORS.get(kind, {}).get("value", 0))}

# --- §6.C bonus generators (limited-use; gen redesign 2026-06-28) ----------------------
# The accrual helpers above are now VESTIGIAL (kept for grove_sim's legacy income model until the §11
# economy re-tune). Live gameplay uses these: a bonus generator SIDE-SPAWNS off a main-generator tap,
# grants its `value` currency per tap for a random BONUS_CLICKS budget (× a burst while a boost is live),
# then VANISHES.
static func rolls_bonus_spawn(rng: RandomNumberGenerator) -> bool:
	return rng.randf() < BONUS_SPAWN_CHANCE

static func pick_bonus_clicks(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(int(BONUS_CLICKS[0]), int(BONUS_CLICKS[1]))

# A uniform random bonus kind to spawn (registry order).
static func pick_bonus_kind(rng: RandomNumberGenerator) -> String:
	var kinds: Array = ACCUMULATORS.keys()
	return String(kinds[rng.randi_range(0, kinds.size() - 1)]) if not kinds.is_empty() else ""

# The currency granted per tap for a bonus generator of `kind` (× a burst when a boost is live).
static func bonus_value(kind: String) -> int:
	return int(ACCUMULATORS.get(kind, {}).get("value", 0))

# Accumulators ride the generator infra (placement, render, bag), keyed by their `id` ("acc_<kind>").
static func is_accumulator(id: String) -> bool:
	return accumulator_kind_of(id) != ""

static func accumulator_kind_of(id: String) -> String:
	for kind in ACCUMULATORS:
		if String(ACCUMULATORS[kind].get("id", "")) == id:
			return String(kind)
	return ""

# The generator icon for an id — the merge-generator roster first, then the accumulators. One lookup so
# _make_generator renders both kinds of on-board "generator" from the same path.
static func gen_tex(id: String) -> String:
	var d := gen_def(GENERATORS, id)
	if not d.is_empty():
		return String(d.get("tex", ""))
	var kind := accumulator_kind_of(id)
	if kind != "":
		return String(ACCUMULATORS[kind].get("tex", ""))
	if is_treat_gen(id):                                  # §6.D treat gen icon — derived from its line, stateless
		var idx := TREAT_LINES.find(treat_line_of(id))
		return String(TREAT_GEN_TEX[maxi(0, idx) % TREAT_GEN_TEX.size()])
	return ""

# --- §6.D temporary treat generators (the main generator occasionally spawns one) ---------------------
static func rolls_treat_spawn(rng: RandomNumberGenerator) -> bool:
	return rng.randf() < TREAT_SPAWN_CHANCE

# §6.D / idea 4.1 — each map has ONE special treasure line: map M pops MAP_TREAT_LINE[M] (deterministic,
# so the treat always feels like THIS map's treasure, and its icon — TREAT_GEN_TEX[M] — matches).
static func pick_treat_line(map: int) -> int:
	return int(MAP_TREAT_LINE[clampi(map, 0, MAP_TREAT_LINE.size() - 1)])

## A premium treat line (the per-map treasure / Farm reserve) — sells at TREAT_SELL_BAND, not the map band.
static func is_treat_line(code: int) -> bool:
	return TREAT_LINES.has(int(code / 100.0))

static func pick_treat_clicks(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(int(TREAT_CLICKS[0]), int(TREAT_CLICKS[1]))

# A temp treat generator is a board generator with id "treat_<line>" (one at a time). Helpers below
# keep the line ↔ id mapping in one place so the board can place/render/tap/vanish it via the gen infra.
static func is_treat_gen(id: String) -> bool:
	return id.begins_with("treat_")

static func treat_gen_id(line: int) -> String:
	return "treat_%d" % line

static func treat_line_of(id: String) -> int:
	return int(id.trim_prefix("treat_")) if is_treat_gen(id) else 0

# --- progression ------------------------------------------------------------------
# The ONE clock is exp (§3): one uncapped Level, derived from the cumulative exp total via
# level_for_exp / exp_at_level (defined above). The old stars-named forms are retired.

# --- exp level math (the renamed clock; reads the single cumulative `exp`) ----------
# GENTLE ARITHMETIC level curve (uncapped): level n→n+1 costs LEVEL_BASE_EXP + (n-1)·LEVEL_STEP_EXP.
# exp_at_level(L) = cumulative exp to REACH level L = sum of the first (L-1) level costs (closed form).
# Much less front-loaded than the old geometric curve (no "20 levels in map 1").
static func level_for_exp(earned: int) -> int:
	var lvl := 1
	while exp_at_level(lvl + 1) <= earned:
		lvl += 1
	return lvl

static func exp_at_level(level: int) -> int:
	if level <= 1:
		return 0
	var m := level - 1                                   # number of completed level-ups
	return m * LEVEL_BASE_EXP + (m * (m - 1) / 2) * LEVEL_STEP_EXP

# --- the per-spot unlock ladder (§map-unlock) — ONE REGION PER LEVEL --------------------
# Every restoration spot, taken in GLOBAL order (all of map 0's spots, then map 1's, …), unlocks at its
# OWN consecutive level: the first region at L2, the next at L3, and so on. So each level-up grants exactly
# ONE region — the "unlock on every new level" rhythm — regardless of how many spots a zone has (no more
# every-OTHER-level in thin zones, no finale collapsing several regions onto one level). Live claiming
# floors to the level's start (spot_unlock_exp = exp_at_level(level)); the FRONT-LOADED level curve
# (grove_data LEVEL_BASE_EXP / LEVEL_STEP_EXP) is what makes the early regions cheap and sizes the whole
# arc against the click budget. The first region sits at L2 (not L1) so it is a small EARNED first beat —
# a quest or two of effort — never free on a fresh save, never endgame-priced.

# The 0-based position of spot k of map z in the global spot order (map 0's spots first, then map 1's, …).
static func global_spot_index(z: int, k: int) -> int:
	var idx := 0
	for zz in z:
		idx += MAPS[zz].spots.size()
	return idx + k

# The LEVEL at which spot k of map z unlocks = its global order position, offset so the first region is L2.
static func spot_unlock_level(z: int, k: int) -> int:
	return 2 + global_spot_index(z, k)

# Cumulative exp threshold at which spot k of map z becomes claimable = the START of its unlock level.
static func spot_unlock_exp(z: int, k: int) -> int:
	return exp_at_level(spot_unlock_level(z, k))

# The next spot to claim in map z = the lowest-threshold UNCLAIMED spot. Returns
# {k, exp}; k == -1 when every spot of z is already claimed.
static func map_next_unlock(z: int, unlocks: Dictionary) -> Dictionary:
	var best := {"k": -1, "exp": -1}
	for k in MAPS[z].spots.size():
		if unlocks.has(String(MAPS[z].spots[k].id)):
			continue
		var e := spot_unlock_exp(z, k)
		if best.k == -1 or e < int(best.exp):
			best = {"k": k, "exp": e}
	return best

# The exp at which the WHOLE of map z is claimable = the highest unclaimed threshold.
# -1 when every spot is claimed. Drives fence_inert.
static func map_finish_exp(z: int, unlocks: Dictionary) -> int:
	var hi := -1
	for k in MAPS[z].spots.size():
		if unlocks.has(String(MAPS[z].spots[k].id)):
			continue
		hi = maxi(hi, spot_unlock_exp(z, k))
	return hi

# Earn exp into the cumulative progression clock that drives Level. Returns the levels gained
# so the caller can show the Level dialog. The
# level-up GIFT is no longer granted here — it's DEFERRED to the dialog's Collect (see
# level_gift / grant_level_gift below), so the interruption pays out. The sole way Level advances.
static func earn_exp(n: int) -> int:
	var before := level_for_exp(Save.exp_total())
	Save.add_exp(n)
	return level_for_exp(Save.exp_total()) - before

# The water + acorn gift for `levels` levels gained, landing at `new_level` (PURE — no side effects).
# Water is per level; ACORNS are MILESTONE-ONLY (Option A) — paid only when a level that is a multiple of
# LEVEL_DIAMOND_EVERY is crossed, so acorns stay precious. `new_level` defaults to -1 → no acorns (the
# caller should pass the post-gain level). The Level dialog shows the gift; the player collects it.
static func level_gift(levels: int, new_level: int = -1) -> Dictionary:
	var n := maxi(0, levels)
	var gems := 0
	if new_level > 0 and LEVEL_DIAMOND_EVERY > 0:
		var prev := new_level - n
		gems = LEVEL_DIAMONDS * (int(new_level / LEVEL_DIAMOND_EVERY) - int(prev / LEVEL_DIAMOND_EVERY))
	return {"water": LEVEL_WATER_GIFT * n, "gems": gems}

# Apply a level_gift: water (capped), diamonds, and the piggy-bank skim. Called by the Level dialog's
# Collect button (the deferred grant that used to happen inline with progression).
static func grant_level_gift(gift: Dictionary) -> void:
	var water := int(gift.get("water", 0))
	var gems := int(gift.get("gems", 0))
	if water <= 0 and gems <= 0:
		return
	var g := Save.grove()
	g["water"] = mini(WATER_CAP, int(g.get("water", WATER_CAP)) + water)
	Save.grove_write()
	if gems > 0:
		Save.add_diamonds(gems)
		Vault.skim(gems)                      # the piggy bank skims a slice of the level-up premium (§10)

static func item_tex_path(code: int) -> String:
	var line := int(code / 100.0)
	var tier := code % 100
	var base := ""
	if LINES.has(line):
		base = String(LINES[line].base)
	elif SPECIAL_ITEMS.has(line):           # §6.B special drop items render from items/<base>/<base>_<tier>.png
		base = special_base(code)
	if base == "":
		return ""
	return Game.art("items/%s/%s_%d.png" % [base, base, tier])
