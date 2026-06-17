extends RefCounted
## GROVE game DATA — the content + tuning the engine's content logic reads via
## Game.data(). Pure tables, zero logic: item lines, generators, the bramble curve
## numbers, the quest ramp, maps/spots, waysides, variants, and all economy dials.
## A different game ships its own data module with the SAME const names.

const COLS := 7
const ROWS := 9
const TOP_TIER := 8

# Item lines — code = line*100 + tier. Art loads <art_root>/items/<base>_<tier>.png; until the
# §16 sprites land (PARKED art), a line renders code-drawn from its `color`. v1 = the home grove
# (Acorn & Bloom, grove_spec §2): 24 lines / 12 generators across maps 1 Farmhouse · 2 Barn ·
# 3 Pond · 4 Orchard · 5 Meadow (the 15-map arc ≈104 lines is post-launch). Wildflower (1) is the
# title line + the permanent ANCHOR (Seed satchel's pair never retires). Codes skip 9 (= COIN_LINE).
const LINES := {
	# map 1 — Farmhouse (Radish): the starting lines (keep these bases — sprites may exist)
	1: {"name": "Wildflower", "base": "flower", "color": Color("#D98BA3")},
	2: {"name": "Garden tools", "base": "tools", "color": Color("#A6794B")},
	3: {"name": "Mushroom", "base": "mushroom", "color": Color("#C9A66B")},
	4: {"name": "Honey", "base": "honey", "color": Color("#E3B23C")},
	# map 2 — Barn (Carrot): hen coop + dairy stall
	5: {"name": "Egg", "base": "egg", "color": Color("#F2E4C4")},
	6: {"name": "Feather", "base": "feather", "color": Color("#E8E0D0")},
	7: {"name": "Milk", "base": "milk", "color": Color("#EDEDE6")},
	8: {"name": "Wool", "base": "wool", "color": Color("#DED7C8")},
	# map 3 — Pond (Frog): reed bed + creel
	10: {"name": "Reed", "base": "reed", "color": Color("#8FB36B")},
	11: {"name": "Lotus", "base": "lotus", "color": Color("#E8A8C0")},
	12: {"name": "Fish", "base": "fish", "color": Color("#7FB8C9")},
	13: {"name": "Snail", "base": "snail", "color": Color("#B89A6B")},
	# map 4 — Orchard (Bee): orchard basket + stone-fruit bough + nut-&-blossom
	14: {"name": "Apple", "base": "apple", "color": Color("#D0483B")},
	15: {"name": "Pear", "base": "pear", "color": Color("#BCD06B")},
	16: {"name": "Plum", "base": "plum", "color": Color("#8E5AA8")},
	17: {"name": "Cherry", "base": "cherry", "color": Color("#C8364F")},
	18: {"name": "Walnut", "base": "walnut", "color": Color("#9A6B43")},
	19: {"name": "Blossom", "base": "blossom", "color": Color("#F0B6CE")},
	# map 5 — Meadow (Morel): glow-cap ring + meadow tuft + lantern bloom
	20: {"name": "Glowcap", "base": "glowcap", "color": Color("#E07AA0")},
	21: {"name": "Spore", "base": "spore", "color": Color("#C9B8E0")},
	22: {"name": "Clover", "base": "clover", "color": Color("#6FA86B")},
	23: {"name": "Dandelion", "base": "dandelion", "color": Color("#EAD24A")},
	24: {"name": "Poppy", "base": "poppy", "color": Color("#D8503F")},
	25: {"name": "Firefly", "base": "firefly", "color": Color("#E8E07A")},
}

# Generators — the v1 home-grove roster (grove_spec §2): 12 generators / 24 lines across maps 1–5
# (Core §6, the generator-grant hand-in model). Each emits 2 lines and belongs to a map (map);
# `grant_from` = the previous-map generator you HAND IN to receive this one (old lines retire); ""
# = granted outright (a map's surplus, or map 1's two starters). `cell` is denormalized down each
# lineage (a grant generator sits at its predecessor's cell). 12 gen sprites + ~192 item sprites
# are PARKED art (§16) — generators reuse 3 stand-in sprites for now. ANCHOR: `seed_satchel`
# (Wildflower + Berry) is never handed in, so it persists across the home grove (Mom's line stays
# on the board); keeping its lines ASKABLE past map 1 is a parked engine follow-up (BACKLOG).
const GENERATORS := [
	# map 1 — Farmhouse (Radish): the two starters, granted outright
	{"id": "seed_satchel", "map": 0, "cell": Vector2i(4, 3), "lines": [1, 2], "grant_from": "", "anchor": true,
		"tex": "ui/gen_satchel.png", "label": "seeds"},          # the ANCHOR — Wildflower + Berry, never handed in (Core §6); its lines stay live + askable for the life of the save
	{"id": "pantry_crock", "map": 0, "cell": Vector2i(2, 1), "lines": [3, 4], "grant_from": "",
		"tex": "ui/gen_jar.png", "label": "pantry"},
	# map 2 — Barn (Carrot): hand the pantry crock in → hen coop; the dairy stall is the surplus
	{"id": "hen_coop", "map": 1, "cell": Vector2i(2, 1), "lines": [5, 6], "grant_from": "pantry_crock",
		"tex": "ui/gen_hen_coop.png", "label": "coop"},
	{"id": "dairy_stall", "map": 1, "cell": Vector2i(6, 5), "lines": [7, 8], "grant_from": "",
		"tex": "ui/gen_dairy_stall.png", "label": "dairy"},
	# map 3 — Pond (Frog): two hand-in grants
	{"id": "reed_bed", "map": 2, "cell": Vector2i(2, 1), "lines": [10, 11], "grant_from": "hen_coop",
		"tex": "ui/gen_reed_bed.png", "label": "reeds"},
	{"id": "creel", "map": 2, "cell": Vector2i(6, 5), "lines": [12, 13], "grant_from": "dairy_stall",
		"tex": "ui/gen_creel.png", "label": "creel"},
	# map 4 — Orchard (Bee): two hand-in grants + one surplus
	{"id": "orchard_basket", "map": 3, "cell": Vector2i(2, 1), "lines": [14, 15], "grant_from": "reed_bed",
		"tex": "ui/gen_orchard_basket.png", "label": "orchard"},
	{"id": "stone_fruit_bough", "map": 3, "cell": Vector2i(6, 5), "lines": [16, 17], "grant_from": "creel",
		"tex": "ui/gen_stone_fruit_bough.png", "label": "stonefruit"},
	{"id": "nut_blossom", "map": 3, "cell": Vector2i(4, 5), "lines": [18, 19], "grant_from": "",
		"tex": "ui/gen_nut_blossom.png", "label": "nuts"},
	# map 5 — Meadow (Morel): three hand-in grants
	{"id": "glowcap_ring", "map": 4, "cell": Vector2i(2, 1), "lines": [20, 21], "grant_from": "orchard_basket",
		"tex": "ui/gen_glowcap_ring.png", "label": "glowcap"},
	{"id": "meadow_tuft", "map": 4, "cell": Vector2i(6, 5), "lines": [22, 23], "grant_from": "stone_fruit_bough",
		"tex": "ui/gen_meadow_tuft.png", "label": "tuft"},
	{"id": "lantern_bloom", "map": 4, "cell": Vector2i(4, 5), "lines": [24, 25], "grant_from": "nut_blossom",
		"tex": "ui/gen_satchel.png", "label": "lantern"},
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

# §7 generated-quest reward — PROVISIONAL (owner/sim tunables, pending the Monte-Carlo balance pass).
const STAR_CAP := 3                       # max ★ per quest → level ∝ quest COUNT (§3); held to ~1–3★
const CLICK_TO_VALUE := 1.0               # reward value per expected generator-click (the click→value rate)
# §7 ask shape (level → #asks/tier, line weighting, featured) — PROVISIONAL, sim-tuned.
const QUEST_2ASK_LEVEL := 5               # ≥ this level a quest may carry a 2nd ask
const QUEST_3ASK_LEVEL := 12              # ≥ this level a 3rd ask
const QUEST_TIER_BASE := 2                # floor of the asked-tier band
const QUEST_LEVELS_PER_TIER := 2          # the asked tier-ceiling climbs +1 every N levels (never reaches t8)
const QUEST_2COUNT_RATE := 0.2            # chance an ask wants 2 of the item (vs 1)
const QUEST_NEWEST_BIAS := 2.0            # line-pick weight exponent toward the newest/highest-value live line
const QUEST_FEATURED_RATE := 0.15         # share of regular quests flagged featured (coins/premium bonus, no extra ★)
const QUEST_FEATURED_COIN_BONUS := 10     # flat coin bonus on a featured quest
const QUEST_FEATURED_GEM_ODDS := 0.2      # of FEATURED quests, the share that ALSO carry a premium (≈3% of all quests)
const QUEST_FEATURED_GEM_BONUS := 1       # small premium (💎) bonus on those — never extra ★ (§7); buys speed, not possibility
const QUEST_DEBUT_TIER_CAP := 3           # a freshly-debuted (newest) line eases in at ≤ t3
# §7 soft gate + authored gate quest — PROVISIONAL, sim-tuned.
const MAX_GIVERS := 5                     # fence slots (§7); the metered active count caps here
const STARS_PER_QUEST_EST := 2            # gate_pause sizing: representative ★/quest for the meter
const GATE_ASK_COUNT := 3                 # distinct top-tier lines the great-spirit's gate asks
const GATE_STARS := 5                     # the gate's authored ★ (map-completion beat; off the regular cap)
const GATE_COIN_BONUS := 100              # plus a large coin bonus over the computed overflow
const GATE_TIER_BASE := 5                 # gate ceiling = min(GATE_TIER_BASE + map_index, TOP_TIER): t5→t8 over the 5 maps
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
# §8/§10 HOME-HUB YIELD + UPGRADE-LEVELS — the v1 KEYSTONE coin loop (grove_spec §3,
# T42 Part A). A restored hub YIELD building (kind:"yield" in MAPS map 0 — Hearth ·
# Kitchen garden · Well · Larder) sits at L1, then UPGRADES with coins along L1→L5 —
# each level a richer composited look (§16) AND a higher coin yield. Each yield
# building accrues coins over time to a PER-BUILDING CAP (≈ a day's worth), swept in
# ONE collect-on-return beat (never a per-building tap chore). The ENGINE math
# (spot_is_yield / hub_yield_rate / hub_yield_cap / hub_coins_ready / hub_upgrade_cost)
# lives in content.gd and reads THESE tables — pure numbers here.
#
# THE KEYSTONE INVARIANT ("extend, never self-sustain", §4/§10 — the coin analogue of
# the energy <30% rule): the per-building cap bounds the daily yield WELL UNDER the coin
# SINK demand. Max daily faucet at full L5 = 4 yield bldgs × HUB_YIELD_CAP[5] = 96🪙/day
# (caps are ~a day, so a daily return collects ~that). Held DELIBERATELY LOW so the STANDING
# yield stays under the ongoing sinks even once the finite hub ladder is maxed: a week of max
# yield (672🪙) < the standing burst ladder (3,120🪙), and a month (~2,880🪙) can't even buy the
# hub-upgrade ladder it funds (a NEW ~8,600🪙 sink = 4 × Σ HUB_UPGRADE_COSTS) — so sink ≫ faucet,
# late-game included. ALL PROVISIONAL — OWNER-TUNABLE PACING DIALS, sim-validated by grove_sim.gd
# (the §7 sim, extended with the hub faucet + the hub-upgrade sink: I1/no-strand/I2/Y green).
const HUB_MAX_LEVEL := 5                   # L1 (restore) → L5 (4 coin upgrades per yield building)
# Coin YIELD RATE per yield building, 🪙 PER HOUR, indexed by level (index 0 = unrestored = 0; then
# L1…L5). Rises with each upgrade — the upgrade buys MORE yield, not just a look. DELIBERATELY SMALL:
# the STANDING daily yield ceiling must stay under the ONGOING coin sinks (burst + per-map décor), or
# a fully-restored hub out-faucets the late-game sink (sim-checked — the keystone late-game guardrail).
const HUB_YIELD_RATE := [0.0, 0.25, 0.45, 0.65, 0.85, 1.0] # 🪙/hour at L0…L5
# Per-building ACCRUAL CAP, 🪙, indexed by level (≈ a day's worth: rate × ~24h, rounded warm). Accrual
# clamps here so a yield building never piles up past ~a day — extends sessions, never self-sustains.
const HUB_YIELD_CAP := [0, 6, 11, 16, 20, 24]              # 🪙 cap at L0…L5  (max daily faucet = 4 × 24 = 96🪙)
# UPGRADE COST to raise ONE yield building from level L to L+1, 🪙, indexed by the CURRENT level
# (index 1 = L1→L2 … index 4 = L4→L5; index 0 unused — L0→L1 is the Stars RESTORE, not a coin buy).
# Escalating — the coin sink with teeth (4 buildings × Σ = 4 × 2,150 = 8,600🪙 to fully max the hub).
const HUB_UPGRADE_COST := [0, 150, 350, 650, 1000, 0]      # 🪙 to go L→L+1 (0 at L0 and at the L5 cap = maxed)

# Starter items on the open 3x3 (besides the generator cell).
const STARTER_ITEMS := {
	Vector2i(3, 2): 101, Vector2i(3, 4): 101,
	Vector2i(5, 2): 201, Vector2i(5, 4): 201,
	Vector2i(4, 2): 101, Vector2i(4, 4): 201,
}


# Spot customizations — coin/gem variants per owned spot (deterministic).
const VARIANT_NAMES_COIN := ["Rosewood", "Whitewash", "Mossy", "Sunbaked", "Riverstone"]
const VARIANT_NAMES_GEM := ["Gilded", "Moonlit", "Blossom", "Starlit", "Amber"]
const VARIANT_TINTS_COIN := [Color("#C96F4A"), Color("#EDE3D2"), Color("#7FA65A"), Color("#E3B23C"), Color("#9CB8C9")]
const VARIANT_TINTS_GEM := [Color("#E8C84A"), Color("#BFD9F2"), Color("#E8A8C0"), Color("#D9C9F2"), Color("#E8B06A")]

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
const WATER_REWARD_MAX_RATIO := 0.3       # invariant: chapter water rewards < 30% of cost

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
	# Map 1 — the home hub. pos + fsize + `art` (the cutout image) are the hub layout. They come from the
	# PLACER (games/grove/tools/MapPlacer.tscn → data/map1_placements.json) and are MERGED in at load by
	# _merge_map1_placements via the `art` binding (the cutout's basename is the JSON key). The values
	# below are gameplay (id/cost/kind) + the `art` binding + FALLBACK pos/fsize (used only when the JSON
	# has no entry). No bake step — save in the placer and the game reads it. (Porch & Garden fence have
	# no placed cutout → they keep the fallback pos + furn art.)
	{"id": "farmhouse", "name": "The Farmhouse", "hub": true,
		"bg": "res://assets/map1v2/base_empty.jpg",       # the empty field (map1v2)
		"fence": "res://assets/map1v2/fence.png",         # fixed fence layer, composited over the base
		"full": "res://assets/map1v2/base_full.png",      # reference image, toggleable for testing
		"decor": "res://data/map1v2_decor.json",          # trees/grass placed in the map placer (read at load)
		"clouds": "res://assets/map1v2/clouds.png",       # drift slowly across the sky
		"chimney": {"frames": "res://assets/map1v2/chimney/", "pos": [0.452, 0.205], "size": 300, "fps": 6},  # smoke flipbook over the cottage
		"spots": [
		# `art` points each spot at its map1v2 item cutout; pos/fsize are AUTO-DERIVED from base_items
		# (assets/map1v2/items_layout.json, merged at load by item name = the art's basename).
		{"id": "fh_hearth", "name": "Hearth", "kind": "yield", "cost": 3, "pos": Vector2(0.4194, 0.4265), "fsize": 808, "art": "res://assets/map1v2/items/cottage.png"},
		{"id": "fh_kitchen", "name": "Kitchen garden", "kind": "yield", "cost": 3, "pos": Vector2(0.5481, 0.7379), "fsize": 808, "art": "res://assets/map1v2/items/garden.png"},
		{"id": "fh_well", "name": "Well", "kind": "yield", "cost": 3, "pos": Vector2(0.1574, 0.8778), "fsize": 370, "art": "res://assets/map1v2/items/well.png"},
		{"id": "fh_larder", "name": "Larder", "kind": "yield", "cost": 4, "pos": Vector2(0.7454, 0.5065), "fsize": 450, "art": "res://assets/map1v2/items/shed.png"},
		{"id": "fh_porch", "name": "Porch", "kind": "decor", "cost": 4, "pos": Vector2(0.84, 0.56), "fsize": 170, "art": "res://assets/map1v2/items/doghouse.png"},
		{"id": "fh_boxes", "name": "Flower boxes", "kind": "decor", "cost": 4, "pos": Vector2(0.1324, 0.6305), "fsize": 320, "art": "res://assets/map1v2/items/flowerbox.png"},
		{"id": "fh_lantern", "name": "Lantern post", "kind": "decor", "cost": 5, "pos": Vector2(0.8093, 0.9182), "fsize": 353, "art": "res://assets/map1v2/items/lantern.png"},
		{"id": "fh_fence", "name": "Garden fence", "kind": "decor", "cost": 5, "pos": Vector2(0.37, 0.34), "fsize": 190},
	]},
	{"id": "barn", "name": "The Barn", "spots": [
		{"id": "bn_bales", "name": "Hay bales", "cost": 3, "pos": Vector2(0.30, 0.55)},
		{"id": "bn_stool", "name": "Milking stool", "cost": 4, "pos": Vector2(0.55, 0.30)},
		{"id": "bn_churns", "name": "Milk churns", "cost": 4, "pos": Vector2(0.70, 0.62)},
		{"id": "bn_trough", "name": "Water trough", "cost": 4, "pos": Vector2(0.25, 0.80)},
		{"id": "bn_lantern", "name": "Lantern post", "cost": 4, "pos": Vector2(0.45, 0.20)},
		{"id": "bn_cart", "name": "Hay cart", "cost": 5, "pos": Vector2(0.80, 0.78)},
		{"id": "bn_coop", "name": "Hen coop", "cost": 5, "pos": Vector2(0.15, 0.40)},
		{"id": "bn_plow", "name": "Old plow", "cost": 5, "pos": Vector2(0.60, 0.85)},
	]},
	{"id": "pond", "name": "The Pond", "spots": [
		{"id": "pd_dock", "name": "Little dock", "cost": 4, "pos": Vector2(0.30, 0.60)},
		{"id": "pd_lilies", "name": "Lily pads", "cost": 4, "pos": Vector2(0.60, 0.70)},
		{"id": "pd_reeds", "name": "Reeds", "cost": 4, "pos": Vector2(0.20, 0.35)},
		{"id": "pd_bench", "name": "Mossy bench", "cost": 4, "pos": Vector2(0.75, 0.40)},
		{"id": "pd_stones", "name": "Stepping stones", "cost": 5, "pos": Vector2(0.45, 0.85)},
		{"id": "pd_willow", "name": "Willow", "cost": 5, "pos": Vector2(0.85, 0.25)},
		{"id": "pd_boat", "name": "Rowboat", "cost": 5, "pos": Vector2(0.55, 0.45)},
		{"id": "pd_fireflies", "name": "Firefly jar", "cost": 5, "pos": Vector2(0.15, 0.75)},
	]},
	{"id": "orchard", "name": "The Orchard", "spots": [
		{"id": "or_rows", "name": "Apple rows", "cost": 4, "pos": Vector2(0.30, 0.50)},
		{"id": "or_ladder", "name": "Picker's ladder", "cost": 4, "pos": Vector2(0.55, 0.35)},
		{"id": "or_baskets", "name": "Fruit baskets", "cost": 4, "pos": Vector2(0.70, 0.70)},
		{"id": "or_press", "name": "Cider press", "cost": 5, "pos": Vector2(0.25, 0.80)},
		{"id": "or_hives", "name": "Beehives", "cost": 5, "pos": Vector2(0.80, 0.45)},
		{"id": "or_swing", "name": "Tree swing", "cost": 5, "pos": Vector2(0.45, 0.20)},
		{"id": "or_scarecrow", "name": "Scarecrow", "cost": 5, "pos": Vector2(0.15, 0.30)},
		{"id": "or_wagon", "name": "Apple wagon", "cost": 5, "pos": Vector2(0.60, 0.85)},
	]},
	{"id": "meadow", "name": "The Meadow", "spots": [
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
	_merge_map1_placements(maps)
	return maps


# Merge the placer's saved hub layout (data/map1_placements.json) into the hub map's spots: each spot
# whose `art` cutout is placed takes that placement's `pos` (center fraction) and `fsize` (footprint px,
# in design-canvas units). Both come straight from the JSON — NO texture loads here, so boot stays cheap.
# Read via res:// so it works the same in the editor and in an exported build — the .json must be in the
# export preset's include_filter to ship. No file / no entry → the literal's fallback pos/fsize stay.
static func _merge_map1_placements(maps: Array) -> void:
	var f := FileAccess.open("res://assets/map1v2/items_layout.json", FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY or not data.has("items"):
		return
	var place := {}
	for rec in data["items"]:
		var nm := String(rec.get("item", ""))
		if nm != "":
			place[nm] = rec
	for m in maps:
		if not bool(m.get("hub", false)):
			continue
		for spot in m["spots"]:
			if not spot.has("art"):
				continue
			var cut := String(spot["art"]).get_file().get_basename()
			if not place.has(cut):
				continue
			var rec: Dictionary = place[cut]
			var ps = rec.get("pos", [0.5, 0.5])
			spot["pos"] = Vector2(float(ps[0]), float(ps[1]))
			spot["fsize"] = int(rec.get("fsize", spot.get("fsize", 240)))


const LEVEL_WATER_GIFT := 20
# The one uncapped LEVEL clock, driven by stars EARNED (cumulative): cross a
# threshold → level up. The ramp is the old LEVEL_XP/10, so the existing pacing
# and spot-gates carry over unchanged (level_for_stars(3·rank) == the old
# level_for_exp(30·rank)); past the table a flat tail keeps it UNCAPPED.
# PROVISIONAL — recalibrated with the generated-quest model + the Monte-Carlo
# sim (docs/BACKLOG.md).
const LEVEL_STARS := [0, 6, 14, 24, 36, 50, 66, 84, 104, 126]
const LEVEL_STARS_TAIL := 22       # stars per level past the table (flat tail)

# ambient life + board gameplay tuning
const CHARACTER_TYPES := ["moss", "acorn", "lantern"]   # the wandering character roster (art rows)
const CHARACTER_CAP := 5
const CHARACTER_ART := "map/spirit_%s.png"              # type → clothes asset (assets keep their names)
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
	{"id": "skip_egg5",    "code": 505, "currency": "diamonds", "cost": 14,   "icon": "egg",      "label": "Egg"},          # t5 — a map-2 line, premium
]

# Cosmetic offers (§10 "cosmetics / looks"): a GROVE THEME — a board look the player owns
# once, distinct from the per-spot map variants (VARIANT_* above, applied on the map). Base
# looks are COINS; exclusive looks are PREMIUM (💎). Pure look — owning one changes nothing
# about possibility (§4). `tint` is the swatch the card previews / the look applies.
const SHOP_COSMETICS := [
	{"id": "look_meadow_dawn",   "currency": "coins",    "cost": 500,  "name": "Meadow Dawn",   "tint": Color("#EAD9A8")},
	{"id": "look_harvest_gold",  "currency": "coins",    "cost": 500,  "name": "Harvest Gold",  "tint": Color("#E3B23C")},
	{"id": "look_twilight",      "currency": "diamonds", "cost": 12,   "name": "Twilight",      "tint": Color("#8E7CC3")},
	{"id": "look_blossom_drift", "currency": "diamonds", "cost": 12,   "name": "Blossom Drift", "tint": Color("#E8A8C0")},
]

# How many offers the featured band shows at once — a FEW (§10 "rotate, a few at a time"),
# drawn deterministically from SHOP_ITEM_OFFERS + SHOP_COSMETICS by a day/refresh seed so
# the spread feels fresh without ever overwhelming. Pool = 5 items + 4 looks = 9.
const SHOP_ROTATION_COUNT := 3

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
#   collect_2x   — double ONE home-hub yield collect (§8); a persisted ARMED flag the hub-collect
#                  reads (engine/scripts/core/ads.gd Ads.collect_2x_armed / consume_2x) — the ad
#                  grants no currency directly, it arms the next collect.
#   shop_reroll  — refresh the rotating Shop offers (advances the `shop_reroll` rotation seed).
#   event_topup  — a small event-currency boost (§17); stubbed as a small 💎 grant for now.
const ADS := {
	"refill_water": {"cap": 3, "cooldown": 1800,  "water": WATER_CAP},  # 3/day, 30 min apart — a full can
	"collect_2x":   {"cap": 2, "cooldown": 3600,  "mult": 2},           # 2/day, 1 h apart — arms the next collect
	"shop_reroll":  {"cap": 2, "cooldown": 7200},                       # 2/day, 2 h apart — fresh featured band
	"event_topup":  {"cap": 1, "cooldown": 86400, "gems": 8},           # 1/day — a small event boost (stub)
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
# overrides the week slot when the streak lands here (§18 "bigger milestones, day 7/30").
const LOGIN_MILESTONES := {
	7:  {"gems": 3, "coins": 150},                          # the first-week cap — a real premium beat
	30: {"gems": 15, "coins": 300, "cosmetic": "look_twilight"},  # the month cap — leans premium + a cosmetic unlock
}
const LOGIN_WATER_SAFE_MAX := 15          # §4/§10 guard: the biggest daily water gift the ladder may pay (asserted by tests)
