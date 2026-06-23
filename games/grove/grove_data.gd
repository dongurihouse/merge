extends RefCounted
## GROVE game DATA — the content + tuning the engine's content logic reads via
## Game.DATA. Pure tables, zero logic: item lines, generators, the bramble curve
## numbers, the quest ramp, maps/spots, waysides, variants, and all economy dials.
## A different game ships its own data module with the SAME const names.

const VineMaps = preload("res://games/grove/vine/vine_maps.gd")

const COLS := 7
const ROWS := 9
const TOP_TIER := 12
const PREMIUM_TIER := 8  # pins the diamond-earn rate + sell pinnacle, decoupled from TOP_TIER

# Item lines — code = line*100 + tier. Art loads <art_root>/items/<base>/<base>_<tier>.png; a line
# renders code-drawn from its `color` only if a tier sprite is missing. v1 = the home grove
# (Acorn & Bloom, grove_spec §2): ONE line per map across maps 1 Farmhouse · 2 Barn · 3 Pond ·
# 4 Orchard · 5 Meadow. Line code == map number (1-indexed). All five bases are fully arted
# (12 tiers each). Wildflower (1) is the title line + the permanent ANCHOR (Seed satchel never
# retires). Codes skip 9 (= COIN_LINE). Earlier drafts carried 22 lines / 2-per-map; the unused
# lines (Milk, Reed, Lotus, Fish, Snail, Apple, Pear, Plum, …, Firefly) were retired here.
const LINES := {
	1: {"name": "Wildflower", "base": "flower", "color": Color("#D98BA3")},     # map 1 — Farmhouse
	2: {"name": "Feather", "base": "feather", "color": Color("#E8E0D0")},       # map 2 — Barn
	3: {"name": "Garden tools", "base": "tools", "color": Color("#A6794B")},    # map 3 — Pond
	4: {"name": "Honey", "base": "honey", "color": Color("#E3B23C")},           # map 4 — Orchard
	5: {"name": "Mushroom", "base": "mushroom", "color": Color("#C9A66B")},     # map 5 — Meadow
}

# Generators — the v1 home-grove roster (grove_spec §2): ONE generator per map across maps 1–5
# (Farmhouse · Barn · Pond · Orchard · Meadow). Each generator is its map's sole producer and emits
# its ONE line. Generators PERSIST — never handed in / consumed (§6); the next map's generator is
# the reward of a near-end quest, auto-placed on the board. `grant_from` is vestigial (kept "" —
# the hand-in model is retired). `cell` only seeds the FIRST map (map 0); later maps' generators
# auto-place on the first open cell when granted, so their `cell` is unused. The map-1 anchor
# (`seed_satchel`) is live from the first second.
#
# ICON NOTE — maps 3–5 still wear their OLD theme icons (gen_cattails/gen_apples/gen_glowcaps) since
# the icon repaint is PARKED; the intended replacements are gen_honeycomb (Honey) and gen_porcini
# (Mushroom), kept in items/generator/. Tool-shed (Garden tools) has no themed icon yet.
const GENERATORS := [
	# map 1 — Farmhouse: Wildflower. The ANCHOR — live from the first second.
	{"id": "seed_satchel", "map": 0, "cell": Vector2i(4, 3), "lines": [1], "grant_from": "", "anchor": true,
		"tex": "items/generator/gen_wildflowers.png", "label": "seeds"},
	# map 2 — Barn: Feather.
	{"id": "hen_coop", "map": 1, "cell": Vector2i(2, 1), "lines": [2], "grant_from": "",
		"tex": "items/generator/gen_twig_nest.png", "label": "coop"},
	# map 3 — Pond: Garden tools. (icon still cattails — repaint parked)
	{"id": "tool_shed", "map": 2, "cell": Vector2i(2, 1), "lines": [3], "grant_from": "",
		"tex": "items/generator/gen_cattails.png", "label": "tools"},
	# map 4 — Orchard: Honey. (icon still apples — repaint parked, gen_honeycomb ready)
	{"id": "bee_skep", "map": 3, "cell": Vector2i(2, 1), "lines": [4], "grant_from": "",
		"tex": "items/generator/gen_apples.png", "label": "hives"},
	# map 5 — Meadow: Mushroom. (icon still glowcaps — repaint parked, gen_porcini ready)
	{"id": "mushroom_ring", "map": 4, "cell": Vector2i(2, 1), "lines": [5], "grant_from": "",
		"tex": "items/generator/gen_glowcaps.png", "label": "mushrooms"},
]
const GEN_CELL := Vector2i(4, 3)          # the starter satchel (kept for the open-3x3 math)

# §4 obstacle field — the per-cell LEVEL gate. A sealed cell unseals when the player's Level
# reaches its number, then opens on the next ADJACENT MERGE (the level gates *when*, not *how*;
# any merge opens an eligible neighbour). 0 = open at start (the center 3×3 + the generator).
# A hand-tuned diamond: the L1 inner frontier (T37 — where the merge verb is taught; the board MUST
# grow before L2, or a cramped 9-cell board strands on unlucky seeds — see seed 123) radiates to L12
# at the four corners (the last cells to open — still early in a 150-level run; the board is the
# early-game workspace, §4). THIS GRID IS THE OWNER'S FEEL DIAL — re-tune it; the engine reads
# it via G.cell_min_level(). 9 rows × 7 cols, indexed [row][col] = [cell.x][cell.y].
const MIN_LEVEL := [
#    c0  c1  c2  c3  c4  c5  c6
	[11,  7,  5,  5,  5,  7, 11],   # r0  ← outer corners last (~L11)
	[ 9,  5,  3,  3,  3,  5,  9],   # r1
	[ 7,  5,  1,  1,  1,  5,  7],   # r2   inner N/S frontier → L1 (T37: whole diamond shifted −1; L1 now HAS a frontier so the board grows before L2 — fixes the seed-123 strand)
	[ 5,  2,  0,  0,  0,  2,  5],   # r3
	[ 3,  2,  0,  0,  0,  2,  3],   # r4   center 3×3 open · generator at c3
	[ 5,  2,  0,  0,  0,  2,  5],   # r5
	[ 7,  5,  1,  1,  1,  5,  7],   # r6   inner N/S frontier → L1
	[ 9,  5,  3,  3,  3,  5,  9],   # r7
	[11,  7,  5,  5,  5,  7, 11],   # r8
]

const TIER_ODDS := [0.65, 0.25, 0.09, 0.01]   # pop tier 1..4, decaying
const ASK_WEIGHT := 0.6                   # mild lean toward lines the givers want
const ASK_TIER_WEIGHT := 0.0             # §6 spawn TIER-bias strength — OFF by default (owner pacing
                                         # dial). At 0.6 the sim front-loads spend ~3x (parked pacing
                                         # pass); ramp here once the level curve is re-tuned on grove_sim.

# §7 generated-quest reward — PROVISIONAL (owner/sim tunables, pending the Monte-Carlo balance pass).
const STAR_CAP := 3                       # max ★ per quest → level ∝ quest COUNT (§3); held to ~1–3★
# §7 ask shape (a regular quest is a SINGLE ask; tier band, count, line weighting, featured) — PROVISIONAL, sim-tuned.
const QUEST_TIER_BASE := 4                # floor of the asked-tier band (no quest asks below t4); band is always [4..TOP_TIER]
const QUEST_LEVELS_PER_TIER := 2          # the asked-tier bell's CENTRE climbs +1 every N levels, up to the band midpoint
const QUEST_PREMIUM_MIN_LEVEL := 10       # at this asked level and above a quest also pays premium 💎
const QUEST_PREMIUM_GEMS := 1             # the 💎 a high-level quest pays (provisional, sim-tuned)
const QUEST_NEWEST_BIAS := 1.5            # line-pick weight exponent toward the newest/highest-value live line
const QUEST_FEATURED_RATE := 0.15         # share of regular quests flagged featured (coins/premium bonus, no extra ★)
const QUEST_FEATURED_COIN_BONUS := 10     # flat coin bonus on a featured quest
const QUEST_FEATURED_GEM_ODDS := 0.2      # of FEATURED quests, the share that ALSO carry a premium (≈3% of all quests)
const QUEST_FEATURED_GEM_BONUS := 1       # small premium (💎) bonus on those — never extra ★ (§7); buys speed, not possibility
# §7 soft gate — PROVISIONAL, sim-tuned.
const MAX_GIVERS := 4                     # fence slots (§7) — the fence is 4 cards at 25% width; the metered active count caps here
const STARS_PER_QUEST_EST := 2            # representative ★/quest for sizing the active-giver meter
# §6 burst-pop — sim-tuned (T25). A generator tap pops a BURST of items, each still 1 energy (burst cuts
# taps, not the per-item energy economy). Burst = a FREE portion (base BURST_ODDS + per-map scale-up,
# capped on its own at BURST_FREE_MAX) PLUS the player's paid burst-upgrade level added on top — so each
# bought level always adds +1 (decoupled, T25; the old combined cap wasted the top paid levels on deep maps).
const BURST_ODDS := [0.55, 0.30, 0.15]    # base burst pops 1 / 2 / 3 items
const BURST_MAP_EVERY := 2                # +1 base burst every N maps (the free per-map scale-up)
const BURST_FREE_MAX := 4                 # cap on the FREE portion (base + per-map gift) — keeps the gift from trivializing the board
const BURST_MAX := 8                      # absolute ceiling = BURST_FREE_MAX + the 4 paid levels (paid never clips)
const BURST_UPGRADE_COSTS := [120, 360, 840, 1800]   # coin cost L0→1…3→4 (the §10 second coin sink); each buys a guaranteed +1; size = max level

# ─────────────────────────────────────────────────────────────────────────────
# §1 RESIDENTS — the population sub-game (replaces the removed home-hub coin-yield
# loop). Residents are WELCOMED (bought) on COMPLETED maps; two of the same type+tier
# AUTO-MERGE into one a tier up (cascading). The roster is persisted (Save.residents);
# the ambient display (ambient.gd) is stateless and rebuilt from the roster — NO cap.
# Each map offers a SHARED CORE set (on every map, recolorable) plus a couple of
# SIGNATURE residents (one premium 💎). Art reuses the CHARACTER_ART convention. The
# ENGINE math (welcome / merge / members) lives in content.gd and reads these tables.
const RESIDENT_MAX_TIER := 3              # t1 welcomed → merges up to this tier (cascading)
const RESIDENT_ART := "characters/spirit_%s.png"   # type → clothes asset (reuse the CHARACTER_ART convention)
# The SHARED core residents — offered on every map, recolorable. Each {id, name}.
const RESIDENT_CORE := [
	{"id": "moss", "name": "Moss sprite"},
	{"id": "acorn", "name": "Acorn sprite"},
	{"id": "lantern", "name": "Lantern sprite"},
]
# The per-map SIGNATURE residents — ~2 unique to each map; one marked premium (💎). Keyed by the stable
# slot id, themed to the slot's vine ART (the slot ids stay fixed for save-stability, but the displayed
# map + its critters follow the art: barn=Orchard, pond=Garden, orchard=Mill, meadow=Gate). No signature
# resident ships a sprite yet (all render the shared placeholder), so these names are pure flavor.
const RESIDENT_SIGNATURE := {
	"farmhouse": [{"id": "hen", "name": "Hen-kin"}, {"id": "piglet", "name": "Piglet-kin", "premium": true}],
	"barn": [{"id": "bee", "name": "Bee-kin"}, {"id": "robin", "name": "Robin", "premium": true}],
	"pond": [{"id": "butterfly", "name": "Butterfly-kin"}, {"id": "ladybird", "name": "Ladybird", "premium": true}],
	"orchard": [{"id": "fieldmouse", "name": "Field-mouse"}, {"id": "sparrow", "name": "Sparrow", "premium": true}],
	"meadow": [{"id": "hedgehog", "name": "Hedgehog-kin"}, {"id": "wren", "name": "Wren", "premium": true}],
}
# Welcome PRICING — PROVISIONAL feel dials (sim-tuned later). A t1 core / non-premium
# resident costs coins; a premium (signature, marked) resident costs diamonds.
const RESIDENT_BASE_COST := 40           # 🪙 to welcome a t1 core / non-premium resident
const RESIDENT_PREMIUM_COST := 3         # 💎 to welcome a premium resident

# The full set of resident types OFFERED on `map_id`: the shared core + that map's signature
# (each entry a Dictionary {id, name, premium?}). The order here is the stable roster order the
# engine flattens/merges in (content.resident_members / resolve_resident_merges).
static func resident_lines(map_id: String) -> Array:
	var out: Array = RESIDENT_CORE.duplicate(true)
	out.append_array(RESIDENT_SIGNATURE.get(map_id, []))
	return out

# BACKLOG (post-v1): premium 💎 surprise-capsule (no-loss, cosmetic, guardrails) — see grove_spec §1.

# Starter items on the open 3x3 (besides the generator cell).
const STARTER_ITEMS := {
	Vector2i(3, 2): 101, Vector2i(3, 4): 101,
	Vector2i(5, 2): 201, Vector2i(5, 4): 201,
	Vector2i(4, 2): 101, Vector2i(4, 4): 201,
}


# §6/§9 per-map SELL COIN band — later maps' items sell for MORE coins (each map a real
# economic step-up, not just new art). Indexed by the item's map (0-indexed, maps 1–5). A
# t1–t7 item sells for round(tier_coins × band[map]); t8 stays the FLAT 1💎 pinnacle on every
# map (the 32× anti-arbitrage proof, §9 — only the t1–t7 COIN reward scales, never t8→premium).
# Monotonic by construction. Map 1 == 1.0 keeps the FTUE-era sell proofs exact. OWNER/SIM FEEL
# DIAL — re-tune across the arc (grove_spec §5); the engine reads it via G.SELL_MAP_BAND in
# content.sell_reward(). One entry per MAPS row.
const SELL_MAP_BAND := [1.0, 1.3, 1.7, 2.2, 2.8]   # Farmhouse · Barn · Pond · Orchard · Meadow

# Diamonds (earned-only).
const LEVEL_DIAMONDS := 3                 # per level-up
const MAP_DIAMONDS := 10                 # per map fully restored
const REFILL_DIAMOND_COST := 25           # paid rain, once free refills are spent

# §5 The Bag — 6 owned slots at start, +1 at a time bought with 💎, hard cap 18 (12
# purchasable expansions). Shelving/retrieving are always free, no timers, persisted.
# BAG_SLOT_PRICES is the per-EXPANSION 💎 price, one entry per slot 7..18 (index 0 = the
# 7th slot, … index 11 = the 18th). Escalating bands of 3 keep early expansion gentle
# (the 7th stays the old 10💎) and make the late slots a real, earned premium; buying slots
# is convenience, never possibility (§4/§5 "premium buys speed, never the wall"). The 32×
# is unaffected — this is a 💎 sink, not a coin one. OWNER-TUNABLE (grove number, §5 in
# grove_spec): 12 escalating prices summing to 210💎 to reach the cap from 6.
const BAG_START_SLOTS := 6
const BAG_MAX_SLOTS := 18
const BAG_SLOT_PRICES := [10, 10, 10, 15, 15, 15, 20, 20, 20, 25, 25, 25]

# Water (the pacing friction).
const WATER_CAP := 100
const REGEN_SECS := 120                   # +1 water per 2 min, offline included
const POP_COST := 1
const FREE_REFILLS := 3                   # lifetime, on the first empties (FTUE)
const WINBACK_HOURS := 48                 # away >= this → full cap ("it rained")
const WATER_REWARD_MAX_RATIO := 0.3       # invariant: per-spot water rewards < 30% of cost

# Coins on the board.
const COIN_LINE := 9                      # code 9xx; never popped, never asked
const COIN_TOP := 3
const COIN_VALUES := {1: 1, 2: 5, 3: 25}  # tap-collect value per coin tier
const COIN_DROP_RATE := 0.10              # chance a merge also drops a c1

# The world: a sequence of self-contained MAPS (Core §8 / grove_spec §3). Each map is ONE
# image (open space + buildings/props) restored IN PLACE — no free-pan overworld, no walk-inside
# interior; discrete maps reached via a map-select. `hub: true` marks the permanent home hub (the
# Farmhouse — authored deeper; its upgrade→yield loop is the KEYSTONE economy task, BACKLOG).
# Spots sit on the map image at `pos` (0..1 of the fitted image rect), `fsize` px; `kind`
# ("yield"/"decor"/"") is the hub seam (yield is parked — the keystone reads it). Spot costs 3-5★.
# Map art loads <art_root>/map/map_<id>.png (a painted fallback panel until the §16 images land).
static var MAPS: Array = _build_maps()

static func _build_maps() -> Array:
	var maps: Array = [
	# Map 1 — the home hub. Spots carry gameplay only (id/name/kind/cost/pos); the hub renders
	# via the §16 mask-reveal `home` below (not per-spot cutouts), so spots need no `art`/`fsize`.
	# Display names follow each slot's vine ART (farm/orchard/garden/mill/gate); the `id`s stay fixed
	# (farmhouse/barn/pond/orchard/meadow) for save + progression stability, so e.g. id `orchard` shows
	# "The Mill" and id `barn` shows "The Orchard". See RESIDENT_SIGNATURE for the matching critter themes.
	{"id": "farmhouse", "name": "The Farm", "hub": true,
		# §16 mask-reveal home: the hub renders farm_brokenv2 (overgrown) and reveals the clean `farm` per
		# building (mask_<spot>.png) as each is restored; unrestored buildings show a ✿cost badge (map._build_home_spot).
		"home": {"clean": "res://games/grove/assets/map/farm/farm.png", "broken": "res://games/grove/assets/map/farm/farm_brokenv2.png", "data": "res://games/grove/assets/map/farm/farm_home.json"},
		"spots": [
		{"id": "fh_hearth", "name": "Hearth", "kind": "yield", "cost": 3, "pos": Vector2(0.4194, 0.4265)},
		{"id": "fh_kitchen", "name": "Kitchen garden", "kind": "yield", "cost": 3, "pos": Vector2(0.5481, 0.7379)},
		{"id": "fh_well", "name": "Well", "kind": "yield", "cost": 3, "pos": Vector2(0.1574, 0.8778)},
		{"id": "fh_larder", "name": "Larder", "kind": "yield", "cost": 4, "pos": Vector2(0.7454, 0.5065)},
		{"id": "fh_porch", "name": "Porch", "kind": "decor", "cost": 4, "pos": Vector2(0.84, 0.56)},
		{"id": "fh_boxes", "name": "Flower boxes", "kind": "decor", "cost": 4, "pos": Vector2(0.1324, 0.6305)},
		{"id": "fh_lantern", "name": "Lantern post", "kind": "decor", "cost": 5, "pos": Vector2(0.8093, 0.9182)},
	]},
	{"id": "barn", "name": "The Orchard", "spots": [
		{"id": "bn_bales", "name": "Hay bales", "cost": 3, "pos": Vector2(0.30, 0.55)},
		{"id": "bn_stool", "name": "Milking stool", "cost": 4, "pos": Vector2(0.55, 0.30)},
		{"id": "bn_churns", "name": "Milk churns", "cost": 4, "pos": Vector2(0.70, 0.62)},
		{"id": "bn_trough", "name": "Water trough", "cost": 4, "pos": Vector2(0.25, 0.80)},
		{"id": "bn_lantern", "name": "Lantern post", "cost": 4, "pos": Vector2(0.45, 0.20)},
		{"id": "bn_cart", "name": "Hay cart", "cost": 5, "pos": Vector2(0.80, 0.78)},
		{"id": "bn_coop", "name": "Hen coop", "cost": 5, "pos": Vector2(0.15, 0.40)},
		{"id": "bn_plow", "name": "Old plow", "cost": 5, "pos": Vector2(0.60, 0.85)},
	]},
	{"id": "pond", "name": "The Garden", "spots": [
		{"id": "pd_dock", "name": "Little dock", "cost": 4, "pos": Vector2(0.30, 0.60)},
		{"id": "pd_lilies", "name": "Lily pads", "cost": 4, "pos": Vector2(0.60, 0.70)},
		{"id": "pd_reeds", "name": "Reeds", "cost": 4, "pos": Vector2(0.20, 0.35)},
		{"id": "pd_bench", "name": "Mossy bench", "cost": 4, "pos": Vector2(0.75, 0.40)},
		{"id": "pd_stones", "name": "Stepping stones", "cost": 5, "pos": Vector2(0.45, 0.85)},
		{"id": "pd_willow", "name": "Willow", "cost": 5, "pos": Vector2(0.85, 0.25)},
		{"id": "pd_boat", "name": "Rowboat", "cost": 5, "pos": Vector2(0.55, 0.45)},
		{"id": "pd_fireflies", "name": "Firefly jar", "cost": 5, "pos": Vector2(0.15, 0.75)},
	]},
	{"id": "orchard", "name": "The Mill", "spots": [
		{"id": "or_rows", "name": "Apple rows", "cost": 4, "pos": Vector2(0.30, 0.50)},
		{"id": "or_ladder", "name": "Picker's ladder", "cost": 4, "pos": Vector2(0.55, 0.35)},
		{"id": "or_baskets", "name": "Fruit baskets", "cost": 4, "pos": Vector2(0.70, 0.70)},
		{"id": "or_press", "name": "Cider press", "cost": 5, "pos": Vector2(0.25, 0.80)},
		{"id": "or_hives", "name": "Beehives", "cost": 5, "pos": Vector2(0.80, 0.45)},
		{"id": "or_swing", "name": "Tree swing", "cost": 5, "pos": Vector2(0.45, 0.20)},
		{"id": "or_scarecrow", "name": "Scarecrow", "cost": 5, "pos": Vector2(0.15, 0.30)},
		{"id": "or_wagon", "name": "Apple wagon", "cost": 5, "pos": Vector2(0.60, 0.85)},
	]},
	{"id": "meadow", "name": "The Gate", "spots": [
		{"id": "md_path", "name": "Wildflower path", "cost": 4, "pos": Vector2(0.35, 0.60)},
		{"id": "md_picnic", "name": "Picnic blanket", "cost": 4, "pos": Vector2(0.60, 0.75)},
		{"id": "md_kite", "name": "Kite", "cost": 5, "pos": Vector2(0.70, 0.25)},
		{"id": "md_brook", "name": "Brook bridge", "cost": 5, "pos": Vector2(0.25, 0.40)},
		{"id": "md_stand", "name": "Lemonade stand", "cost": 5, "pos": Vector2(0.80, 0.55)},
		{"id": "md_garden", "name": "Secret garden", "cost": 5, "pos": Vector2(0.15, 0.75)},
		{"id": "md_telescope", "name": "Stargazer", "cost": 5, "pos": Vector2(0.50, 0.30)},
		{"id": "md_arch", "name": "Rose arch", "cost": 5, "pos": Vector2(0.45, 0.85)},
	]},
	]
	return _apply_vine_maps(maps)

# Overlay the vine mask tool's maps onto the hardcoded slots, positionally: slot i becomes vine-driven
# from the i-th maps.json entry when present. The slot KEEPS its id/name/hub (so saves + progression +
# map_for_id stay stable); only its rendering (`vine`) and `spots` (one per region) change. Slots with
# no matching tool entry are left exactly as-is. Any missing/unparseable tool file => no overlay (the
# game falls back to the legacy maps), so this can never break the build.
static func _apply_vine_maps(maps: Array) -> Array:
	var entries := VineMaps.entries()
	for i in range(mini(entries.size(), maps.size())):
		var entry: Dictionary = entries[i]
		# Guard: only overlay once the entry's base art is actually imported. A half-added map (registered
		# in maps.json but not yet copied/imported into assets/map) leaves its legacy slot intact rather
		# than blanking it.
		var base := String(entry.get("base", ""))
		if base == "" or not ResourceLoader.exists(base):
			continue
		# Overlay positionally: the slot keeps its id/name/hub but renders vine-driven. Spots are one per
		# region; a map whose regions aren't authored YET overlays with an EMPTY spot list, so its clean
		# base art shows immediately (map.gd renders base-only when there are no regions) without becoming
		# "complete" — map_spots_done is false for a spot-less map, so it never auto-unlocks the next map
		# or invites residents. Each region the tool authors then appears in-game on the next open.
		maps[i]["vine"] = entry
		maps[i].erase("home")   # vine rendering supersedes the §16 mask-reveal home for this slot
		maps[i]["spots"] = VineMaps.spots_for(String(maps[i].id), entry)
	return maps


const LEVEL_WATER_GIFT := 20
# §map-unlock — the per-spot exp threshold ladder. Spots across all maps form one global
# order (map order, then spot order); each spot's unlock threshold is the running sum of a
# per-spot increment that ESCALATES per map: inc(z) = UNLOCK_BASE + z*UNLOCK_STEP. The first
# spot overall sits at 0 (claimable on a fresh save). PROVISIONAL feel dials.
const UNLOCK_BASE := 3            # per-spot exp increment on the first map
const UNLOCK_STEP := 3            # extra increment added per later map
# The one uncapped LEVEL clock, derived from the cumulative exp total: cross a threshold → level
# up. Level is purely cosmetic now (badge + per-level gift); past the table a flat tail keeps it
# UNCAPPED. PROVISIONAL — recalibrated with the generated-quest model + the Monte-Carlo sim.
const LEVEL_EXP := [0, 6, 14, 24, 36, 50, 66, 84, 104, 126]   # exp to reach L2..L10 (L1 = 0)
const LEVEL_EXP_TAIL := 22        # exp per level past the table (flat, uncapped)

# ambient life + board gameplay tuning
const CHARACTER_TYPES := ["moss", "acorn", "lantern"]   # the wandering character roster (art rows)
const CHARACTER_CAP := 5
const CHARACTER_ART := "characters/spirit_%s.png"              # type → clothes asset (assets keep their names)
const BASKET_CAP := 3            # the merchant's buy-back basket size
const PORTER_SECS := 180.0       # the porter clears the basket every ~3 min
const TREAT_COST := 10           # an acorn treat for a wandering spirit (a coin sink)

# §14 FTUE feature-spotlight registry (T28). The staged features the game announces
# on FIRST appearance — a spotlight + pulse + a mimed hand gesture showing how to use
# them — IN the order they unlock over the early levels (chrome stages merchant ch1+,
# bag ch2+; the shop sits in the bottom bar from the start). The engine reads this
# table game-agnostically (Spotlight.gesture_for / feature_order); the merge verb is
# NOT here — the idle hint teaches it (§14). `gesture`: "tap" = a mimed finger-tap
# scale-pulse at the target; "drag" = a finger gliding along a short path (sell/stow).
# `label` is the wordless-friendly one-liner the overlay may caption (all via tr()).
const SPOTLIGHTS := [
	# NOTE: NONE of these spotlights are presented right now — merchant/sell + bag + shop
	# were all removed for now (2026-06-18; board.gd + map.gd skip them — see docs/BACKLOG.md
	# "Restore the sell + bag FTUEs" and "Restore the shop FTUE"). The entries stay as the
	# gesture/label source + test fixtures for when they are re-wired.
	{"id": "merchant", "gesture": "drag", "label": "Drag a top item here to sell"},
	{"id": "bag", "gesture": "drag", "label": "Drag a piece here to tuck it away"},
	{"id": "shop", "gesture": "tap", "label": "Tap to visit the shop"},
]

# ─────────────────────────────────────────────────────────────────────────────
# §10 SHOP STOCK — the buy-side sinks (T40). The grove's instance of the §10 Shop:
# the item-shortcut catalogue, the cosmetic/look catalogue, and how many offers the
# storefront features at once. The ENGINE logic (spend/grant/rotate) lives in
# engine/scripts/ui/shop.gd; these are the OWNER-TUNABLE numbers (prices/codes/count).
# DESIGN LAW (§4): premium buys SPEED + LOOKS, never POSSIBILITY — an item-shortcut is
# a grind-SKIP to a piece the player can already reach by merging, never a gate-only or
# purchase-only item; a cosmetic only re-dresses what's there. Cozy: small catalogue, no
# anxiety, no pay-to-win (a shortcut piece is mid-tier — it saves taps, it never wins the
# board). Coins for low tiers / base looks; premium (💎) for deeper skips / exclusive looks.
# ─────────────────────────────────────────────────────────────────────────────

# Item-shortcut offers (§10 "specific items"): buy a MID-TIER piece to skip the grind to
# it. `code` = line*100 + tier (the same encoding the board uses), drawn from EARLY, already-
# askable lines so the shortcut is always a real skip, never a gate. Low tiers (t2–t3) are
# CHEAP COINS; deeper tiers (t4–t5) are PREMIUM (💎) — the §4 "buys speed" curve. The grant
# drops the piece into the bag (the board drains it on open). `icon` rides the card.
const SHOP_ITEM_OFFERS := [
	{"id": "skip_flower3", "code": 103, "currency": "coins",    "cost": 240,  "icon": "flower",   "label": "Wildflower"},   # t3 — a cheap nudge up the home line
	{"id": "skip_tools3",  "code": 203, "currency": "coins",    "cost": 240,  "icon": "tools",    "label": "Garden tools"},  # t3 — the other starter line
	{"id": "skip_mush4",   "code": 304, "currency": "coins",    "cost": 700,  "icon": "mushroom", "label": "Mushroom"},     # t4 — a deeper coin skip
	{"id": "skip_honey4",  "code": 404, "currency": "diamonds", "cost": 8,    "icon": "honey",    "label": "Honey"},        # t4 — premium skip
]

# (Cosmetic "grove theme" looks — SHOP_COSMETICS — were removed with the customization
# feature; the deferred "item & map customization" feature is parked in docs/BACKLOG.md.)

# How many offers the featured band shows — a FEW (§10), a FIXED slice of SHOP_ITEM_OFFERS
# (the first N, in table order). No rotation, no time-based refresh: the shelf is stable.
const SHOP_FEATURED_COUNT := 3

# ─────────────────────────────────────────────────────────────────────────────
# §10 LIVE-IAP + STARTER + REWARDED ADS + OUT-OF-WATER OFFER (T43). The grove's
# instance of the §4/§10 monetization layer. The ENGINE (grant/cap/cooldown logic)
# lives in engine/scripts/ui/shop.gd, engine/scripts/core/ads.gd, and the board's
# energy-wall area; these are the OWNER-TUNABLE numbers. DESIGN LAW (§4): premium &
# ads buy SPEED + LOOKS, never POSSIBILITY — every wall is passable for FREE (slower).
# Cozy guardrails (§10, LOCKED): rewarded-ONLY (no interstitials), opt-in, capped +
# cooldowned; the out-of-water offer has NO countdown, NO fail-shaming, a low cap.
# ─────────────────────────────────────────────────────────────────────────────

# The full cash → 💎 price ladder (§10 "from an entry tier up to a $49.99/$99.99-class
# top end so a whale can always spend more"). Data-driven: shop.gd renders + grants from
# this. The 💎-per-dollar RISES monotonically up the ladder (the bulk-discount whale curve
# — the top tier is always the best rate), so there's always a higher, better-value tier to
# buy. `pop` marks the merchandised "Popular" card (the mid anchor). LIVE from launch behind
# the honest confirm-stub; a real store SDK + receipt check replaces only the grant middle.
const CASH_PACKS := [
	{"usd": "$0.99", "gems": 80},                # 80.8 💎/$  — the entry tier
	{"usd": "$4.99", "gems": 450},               # 90.2 💎/$
	{"usd": "$9.99", "gems": 1000, "pop": true}, # 100.1 💎/$ — the merchandised anchor
	{"usd": "$19.99", "gems": 2200},             # 110.1 💎/$
	{"usd": "$49.99", "gems": 6000},             # 120.0 💎/$
	{"usd": "$99.99", "gems": 13000},            # 130.0 💎/$ — the whale ceiling, best rate
]

# The STARTER PACK (§10) — a ONE-TIME, high-value, low-price bundle surfaced to new
# players (the highest-converting IAP in mobile). Deliberately ~4–5× the entry rate so it
# reads as an unmissable welcome deal; claimable exactly once (Save.starter_claimed). Grants
# diamonds + a water top-up. Separate from the first-purchase doubler below — it is its own
# one-time SKU and does NOT consume the doubler.
const STARTER_PACK := {"usd": "$1.99", "gems": 400, "water": 60}

# The FIRST-PURCHASE DOUBLER (§10) — the FIRST ladder cash pack a player buys grants ×this
# many diamonds, then never again (Save.first_purchase_made). A one-time conversion sweetener
# on the standard ladder (the starter pack is excluded — it's its own SKU).
const FIRST_BUY_MULT := 2

# REWARDED ADS (§10 — "opt-in, rewarded-ONLY, capped + cooldowned, geo-flagged"). One row
# per ad surface: the per-type DAILY cap and COOLDOWN (seconds) gate how often it pays, so an
# ad never becomes the optimal grind (§4 "buys speed, never possibility"; §10 cozy bed). The
# ad itself is a STUB in this build (an honest confirm — "no ad network"); the real SDK call
# replaces only the play middle. `reward`/`gems`/`water` describe the grant the engine applies:
#   refill_water — at the wall: watch → a FULL can (a free, daily-capped alt to the 💎 refill).
#   collect_2x   — the board quest-reward 2× doubler's faucet: watch → the reward is doubled by
#                  scenes/board.gd (which grants the extra coins itself). The ad grants no currency
#                  directly. (The old hub-yield collect that this once armed was removed.)
#   event_topup  — a small event-currency boost (§17); stubbed as a small 💎 grant for now.
const ADS := {
	"refill_water": {"cap": 3, "cooldown": 1800,  "water": WATER_CAP},  # 3/day, 30 min apart — a full can
	"collect_2x":   {"cap": 2, "cooldown": 3600,  "mult": 2},           # 2/day, 1 h apart — arms the next collect
	"event_topup":  {"cap": 1, "cooldown": 86400, "gems": 8},           # 1/day — a small event boost (stub)
	"free_gems":    {"cap": 3, "cooldown": 1800,  "gems": 5},           # 3/day, 30 min apart — the persistent LiveOps gem faucet ("Free")
}

# The OUT-OF-WATER TRIGGERED OFFER (§10 "the contextual sell" — state-driven, fired at the
# moment of friction: water hits 0). A single, gently-DISCOUNTED top-up — a full can + a little
# premium for the entry price — surfaced beside the free/ad/💎 refill at the wall. Cozy
# guardrails (LOCKED): a LOW daily cap + a long cooldown, NO countdown, NO fail copy — it reads
# as "a little help," never a shakedown. The discount is the value: the same $0.99 entry price
# buys a full refill PLUS gems (a refill alone is 25💎; this throws the can in on top). LIVE
# behind the same confirm-stub as the cash packs.
const OOW_OFFER := {"usd": "$0.99", "water": WATER_CAP, "gems": 30, "cap": 1, "cooldown": 43200}  # 1/day, 12 h apart
# §10/§18 RETURN SURFACES — the piggy bank (accrual vault) + the daily login calendar
# (T44). The ENGINE logic (skim/crack · ladder/claim) lives in engine/scripts/core/
# vault.gd + login.gd; these are the OWNER-TUNABLE numbers. Both reward the daily open
# and obey the §4/§10 faucet law: rewards NEVER make energy self-sustaining (water stays
# a modest top-up; the premium that fills the jar is a SKIM of premium already earned).
# ─────────────────────────────────────────────────────────────────────────────

# The piggy bank (§10): a RATIONAL skim of earned premium (level-up 3💎 · map-restore
# 10💎 · t8-sell 1💎) banks into the jar; cracking pays one FIXED real-money price. The
# fill grows with play, the price is fixed → the longer you play, the better the deal.
# DESIGN: 25% skim (1/4) — the jar fills visibly over a session while the player still
# pockets 75% directly, so the vault AMPLIFIES (releases premium sooner) rather than
# withholds (§10 "released sooner and amplified", the friendliest first purchase). The
# carried remainder (vault.gd) means even the 1💎 t8 sells accrue (4 sells → +1 banked).
const VAULT_SKIM_NUM := 1                 # skim numerator …
const VAULT_SKIM_DEN := 4                 # … / denominator = 25% of earned premium banked
const VAULT_CLAIM_MIN := 30               # min banked 💎 before the jar may be cracked (an empty pig isn't sold)
const VAULT_PRICE_USD := "$2.99"          # the ONE fixed crack price (mirrors the shop's entry cash tier; real IAP is external)
const VAULT_CAP := 500                    # a generous ceiling so the jar art has a "full" state; the bank never exceeds it

# The daily login calendar (§18): a repeating WEEK ladder (7 entries, days 1..7 in a
# week) of small rewards, escalating in value, with bigger MILESTONES at absolute streak
# day 7 / 30 that OVERRIDE the week slot. A reward is any of {coins, water, gems,
# cosmetic}. Faucet discipline: mostly COINS (the friendly soft currency); WATER stays a
# modest top-up on a couple of days (≤ LOGIN_WATER_SAFE_MAX, far under a day's ~720 natural
# regen — the calendar tops up, it never refills); PREMIUM (💎) lands as the weekly capstone
# and the milestones lean premium/cosmetic. The streak is FORGIVING (Save.daily soft-decays
# a missed day one step, never to day 1). OWNER-TUNABLE — re-tune copy/cadence here.
const LOGIN_LADDER := [
	{"coins": 50},                        # day 1 — a friendly welcome
	{"water": 8},                         # day 2 — a modest splash
	{"coins": 100},                       # day 3
	{"water": 12},                        # day 4 — the largest single-day water gift (≤ safe max)
	{"coins": 150},                       # day 5
	{"gems": 1, "coins": 60},             # day 6 — a first taste of premium (the build toward the cap)
	{"coins": 200, "gems": 1},            # day 7 slot for NON-milestone weeks (14/21/28 — day-7 absolute is the milestone below)
]
# Milestones keyed by ABSOLUTE streak day — a bigger, premium/cosmetic payout that
# overrides the week slot when the streak lands here (§18 "bigger milestones"). The old
# day-7 milestone is gone: slot 7 is now a MYSTERY day (LOGIN_MYSTERY below).
const LOGIN_MILESTONES := {
	30: {"gems": 15, "coins": 300},                         # the month cap — leans premium (the cosmetic unlock was removed with customization)
}
# MYSTERY gift slots (§18 · T46) — keyed by WEEKLY slot (((day-1) % 7) + 1), so they recur
# every week (days 4/7/11/14/…). On these days the calendar opens an AUTO-SPIN reveal instead
# of a fixed grant: it draws `show` DISTINCT rewards from the pool and the spin lands on `win`
# of them. Slot 7 supersedes the old day-7 milestone — its pool is milestone-tier (richer, 2
# wins). Pools are OWNER-TUNABLE; every `water` entry stays ≤ LOGIN_WATER_SAFE_MAX (faucet guard).
const LOGIN_MYSTERY := {
	4: {"show": 3, "win": 1, "pool": [
		{"coins": 120},
		{"water": 12},
		{"coins": 60, "water": 6},
		{"gems": 1},
		{"coins": 150},
	]},
	7: {"show": 5, "win": 2, "pool": [
		{"coins": 200},
		{"gems": 2},
		{"coins": 100, "gems": 1},
		{"water": 14},
		{"coins": 300},
		{"gems": 3},
	]},
}
const LOGIN_WATER_SAFE_MAX := 15          # §4/§10 guard: the biggest daily water gift the ladder may pay (asserted by tests)

# The MAP TASK-STRIP reward (§17 chrome task loop). The strip rides the EXISTING
# restore-the-next-spot goal (no bolted-on quest); finishing a map's spots pays this
# small bonus once. A modest soft-currency + premium dribble — never possibility (§4):
# it celebrates the milestone the player already reached, it does not gate the next.
const MAP_TASK_REWARD := {"coins": 120, "gems": 2}

# The one-time gift for fully unlocking a map (all spots restored + gate delivered). Escalates with the
# map index z: more coins/diamonds on later maps, plus one free signature spirit (the map's non-premium
# critter). z=0 (120 coins / 2 gems) equals the old flat MAP_TASK_REWARD, so the first map is unchanged.
static func map_unlock_reward(z: int) -> Dictionary:
	var sig: Array = RESIDENT_SIGNATURE.get(String(MAPS[z].id), [])
	var spirit: String = String(sig[0].id) if sig.size() > 0 else ""
	return {"coins": 120 + 80 * z, "gems": 2 + z, "spirit": spirit}
