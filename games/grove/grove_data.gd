extends RefCounted
## GROVE game DATA — the content + tuning the engine's content logic reads via
## Game.data(). Pure tables, zero logic: item lines, generators, the bramble curve
## numbers, the quest ramp, zones/spots, waysides, variants, and all economy dials.
## A different game ships its own data module with the SAME const names.

const COLS := 7
const ROWS := 9
const TOP_TIER := 8

# Lines: code = line*100 + tier. Art loads <art_root>/items/<base>_<tier>.png
const LINES := {
	1: {"name": "Wildflower", "base": "flower", "color": Color("#D98BA3")},
	2: {"name": "Berry", "base": "berry", "color": Color("#7FB4D9")},
	3: {"name": "Mushroom", "base": "mushroom", "color": Color("#C9A66B")},
	4: {"name": "Honey", "base": "honey", "color": Color("#E3B23C")},
}

# Generators — the per-zone roster (Core §6, the generator-grant hand-in model). Each
# emits 2 lines and belongs to a zone; `grant_from` is the previous-zone generator you
# HAND IN (to a generator-grant quest) to receive this one — old lines retire; "" =
# granted outright (a zone's surplus, or zone 0's two starters). `cell` is denormalized
# down each lineage (a grant generator sits at its predecessor's cell). PLACEHOLDER content for the §6 engine milestone — the
# 3 generator sprites are reused and zones 1–4 emit code-drawn lines (5–33); the themed
# 16-gen / 32-line map + real art is the parked grove-content task (docs/BACKLOG.md).
const GENERATORS := [
	# zone 0 — the two starters, granted outright (satchel at center, compost early)
	{"id": "satchel", "zone": 0, "cell": Vector2i(4, 3), "lines": [1, 2], "grant_from": "",
		"tex": "ui/gen_satchel.png", "label": "seeds"},
	{"id": "compost", "zone": 0, "cell": Vector2i(2, 1), "lines": [3, 4], "grant_from": "",
		"tex": "ui/gen_compost.png", "label": "compost"},
	# zone 1 — 2 hand-in grants of zone 0, +1 surplus (the beehive cell)
	{"id": "z1a", "zone": 1, "cell": Vector2i(4, 3), "lines": [5, 6], "grant_from": "satchel",
		"tex": "ui/gen_satchel.png", "label": "z1a"},
	{"id": "z1b", "zone": 1, "cell": Vector2i(2, 1), "lines": [7, 8], "grant_from": "compost",
		"tex": "ui/gen_compost.png", "label": "z1b"},
	{"id": "z1c", "zone": 1, "cell": Vector2i(6, 5), "lines": [10, 11], "grant_from": "",
		"tex": "ui/gen_beehive.png", "label": "z1c"},
	# zone 2 — all 3 hand-in grants
	{"id": "z2a", "zone": 2, "cell": Vector2i(4, 3), "lines": [12, 13], "grant_from": "z1a",
		"tex": "ui/gen_satchel.png", "label": "z2a"},
	{"id": "z2b", "zone": 2, "cell": Vector2i(2, 1), "lines": [14, 15], "grant_from": "z1b",
		"tex": "ui/gen_compost.png", "label": "z2b"},
	{"id": "z2c", "zone": 2, "cell": Vector2i(6, 5), "lines": [16, 17], "grant_from": "z1c",
		"tex": "ui/gen_beehive.png", "label": "z2c"},
	# zone 3 — 3 hand-in grants, +1 surplus
	{"id": "z3a", "zone": 3, "cell": Vector2i(4, 3), "lines": [18, 19], "grant_from": "z2a",
		"tex": "ui/gen_satchel.png", "label": "z3a"},
	{"id": "z3b", "zone": 3, "cell": Vector2i(2, 1), "lines": [20, 21], "grant_from": "z2b",
		"tex": "ui/gen_compost.png", "label": "z3b"},
	{"id": "z3c", "zone": 3, "cell": Vector2i(6, 5), "lines": [22, 23], "grant_from": "z2c",
		"tex": "ui/gen_beehive.png", "label": "z3c"},
	{"id": "z3d", "zone": 3, "cell": Vector2i(4, 5), "lines": [24, 25], "grant_from": "",
		"tex": "ui/gen_satchel.png", "label": "z3d"},
	# zone 4 — all 4 hand-in grants
	{"id": "z4a", "zone": 4, "cell": Vector2i(4, 3), "lines": [26, 27], "grant_from": "z3a",
		"tex": "ui/gen_satchel.png", "label": "z4a"},
	{"id": "z4b", "zone": 4, "cell": Vector2i(2, 1), "lines": [28, 29], "grant_from": "z3b",
		"tex": "ui/gen_compost.png", "label": "z4b"},
	{"id": "z4c", "zone": 4, "cell": Vector2i(6, 5), "lines": [30, 31], "grant_from": "z3c",
		"tex": "ui/gen_beehive.png", "label": "z4c"},
	{"id": "z4d", "zone": 4, "cell": Vector2i(4, 5), "lines": [32, 33], "grant_from": "z3d",
		"tex": "ui/gen_satchel.png", "label": "z4d"},
]
const GEN_CELL := Vector2i(4, 3)          # the starter satchel (kept for the open-3x3 math)

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
const QUEST_DEBUT_TIER_CAP := 3           # a freshly-debuted (newest) line eases in at ≤ t3
# §7 soft gate + authored gate quest — PROVISIONAL, sim-tuned.
const MAX_GIVERS := 5                     # fence slots (§7); the metered active count caps here
const STARS_PER_QUEST_EST := 2            # gate_pause sizing: representative ★/quest for the meter
const GATE_ASK_COUNT := 3                 # distinct top-tier lines the great-spirit's gate asks
const GATE_STARS := 5                     # the gate's authored ★ (map-completion beat; off the regular cap)
const GATE_COIN_BONUS := 100              # plus a large coin bonus over the computed overflow
const GATE_TIER_BASE := 5                 # gate ceiling = min(GATE_TIER_BASE + map_index, TOP_TIER): t5→t8 over the 5 maps

# Starter items on the open 3x3 (besides the generator cell).
const STARTER_ITEMS := {
	Vector2i(3, 2): 101, Vector2i(3, 4): 101,
	Vector2i(5, 2): 201, Vector2i(5, 4): 201,
	Vector2i(4, 2): 101, Vector2i(4, 4): 201,
}


# Waysides — the coin sink (cosmetic, coin-priced, never a gate). 4 per restored zone.
const WAYSIDE_PROPS := ["Lantern post", "Bird bath", "Flower tub", "Mossy bench", "Beehive skep", "Stone cairn"]
const WAYSIDE_TEX := ["way_lantern", "way_birdbath", "way_flowertub", "way_bench", "way_skep", "way_cairn"]
const WAYSIDE_PER_ZONE := 4

# Spot customizations — coin/gem variants per owned spot (deterministic).
const VARIANT_NAMES_COIN := ["Rosewood", "Whitewash", "Mossy", "Sunbaked", "Riverstone"]
const VARIANT_NAMES_GEM := ["Gilded", "Moonlit", "Blossom", "Starlit", "Amber"]
const VARIANT_TINTS_COIN := [Color("#C96F4A"), Color("#EDE3D2"), Color("#7FA65A"), Color("#E3B23C"), Color("#9CB8C9")]
const VARIANT_TINTS_GEM := [Color("#E8C84A"), Color("#BFD9F2"), Color("#E8A8C0"), Color("#D9C9F2"), Color("#E8B06A")]

const MERCHANT_COINS := 25                # per top-tier item taken

# Diamonds (earned-only).
const LEVEL_DIAMONDS := 3                 # per level-up
const ZONE_DIAMONDS := 10                 # per zone fully restored
const REFILL_DIAMOND_COST := 25           # paid rain, once free refills are spent
const BAG3_DIAMOND_COST := 10             # the third bag slot

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

# The home map: zones + unlock spots. One large free-pan map. Spot costs 3-5★.
const MAP_SIZE := Vector2(2160, 2880)     # 2× the portrait viewport each axis
const POI_SIZE := 300.0                   # a building sprite's footprint on the map
const ZONES := [
	{"id": "farmhouse", "name": "The Farmhouse", "map_pos": Vector2(0.230, 0.760), "spots": [
		{"id": "fh_chest", "name": "Storage chest", "cost": 3, "pos": Vector2(0.33, 0.49), "fsize": 230},
		{"id": "fh_bed", "name": "Quilted bed", "cost": 3, "pos": Vector2(0.70, 0.50), "fsize": 380},
		{"id": "fh_table", "name": "Oak table", "cost": 3, "pos": Vector2(0.45, 0.60), "fsize": 320},
		{"id": "fh_rug", "name": "Braided rug", "cost": 4, "pos": Vector2(0.47, 0.67), "fsize": 320},
		{"id": "fh_plant", "name": "Potted fern", "cost": 4, "pos": Vector2(0.84, 0.56), "fsize": 170},
		{"id": "fh_wheel", "name": "Spinning wheel", "cost": 4, "pos": Vector2(0.30, 0.66), "fsize": 250},
		{"id": "fh_chair", "name": "Rocking chair", "cost": 5, "pos": Vector2(0.17, 0.52), "fsize": 230},
		{"id": "fh_picture", "name": "Framed painting", "cost": 5, "pos": Vector2(0.37, 0.34), "fsize": 190},
	]},
	{"id": "barn", "name": "The Barn", "map_pos": Vector2(0.737, 0.814), "spots": [
		{"id": "bn_bales", "name": "Hay bales", "cost": 3, "pos": Vector2(0.30, 0.55)},
		{"id": "bn_stool", "name": "Milking stool", "cost": 4, "pos": Vector2(0.55, 0.30)},
		{"id": "bn_churns", "name": "Milk churns", "cost": 4, "pos": Vector2(0.70, 0.62)},
		{"id": "bn_trough", "name": "Water trough", "cost": 4, "pos": Vector2(0.25, 0.80)},
		{"id": "bn_lantern", "name": "Lantern post", "cost": 4, "pos": Vector2(0.45, 0.20)},
		{"id": "bn_cart", "name": "Hay cart", "cost": 5, "pos": Vector2(0.80, 0.78)},
		{"id": "bn_coop", "name": "Hen coop", "cost": 5, "pos": Vector2(0.15, 0.40)},
		{"id": "bn_plow", "name": "Old plow", "cost": 5, "pos": Vector2(0.60, 0.85)},
	]},
	{"id": "pond", "name": "The Pond", "map_pos": Vector2(0.516, 0.446), "spots": [
		{"id": "pd_dock", "name": "Little dock", "cost": 4, "pos": Vector2(0.30, 0.60)},
		{"id": "pd_lilies", "name": "Lily pads", "cost": 4, "pos": Vector2(0.60, 0.70)},
		{"id": "pd_reeds", "name": "Reeds", "cost": 4, "pos": Vector2(0.20, 0.35)},
		{"id": "pd_bench", "name": "Mossy bench", "cost": 4, "pos": Vector2(0.75, 0.40)},
		{"id": "pd_stones", "name": "Stepping stones", "cost": 5, "pos": Vector2(0.45, 0.85)},
		{"id": "pd_willow", "name": "Willow", "cost": 5, "pos": Vector2(0.85, 0.25)},
		{"id": "pd_boat", "name": "Rowboat", "cost": 5, "pos": Vector2(0.55, 0.45)},
		{"id": "pd_fireflies", "name": "Firefly jar", "cost": 5, "pos": Vector2(0.15, 0.75)},
	]},
	{"id": "orchard", "name": "The Orchard", "map_pos": Vector2(0.738, 0.210), "spots": [
		{"id": "or_rows", "name": "Apple rows", "cost": 4, "pos": Vector2(0.30, 0.50)},
		{"id": "or_ladder", "name": "Picker's ladder", "cost": 4, "pos": Vector2(0.55, 0.35)},
		{"id": "or_baskets", "name": "Fruit baskets", "cost": 4, "pos": Vector2(0.70, 0.70)},
		{"id": "or_press", "name": "Cider press", "cost": 5, "pos": Vector2(0.25, 0.80)},
		{"id": "or_hives", "name": "Beehives", "cost": 5, "pos": Vector2(0.80, 0.45)},
		{"id": "or_swing", "name": "Tree swing", "cost": 5, "pos": Vector2(0.45, 0.20)},
		{"id": "or_scarecrow", "name": "Scarecrow", "cost": 5, "pos": Vector2(0.15, 0.30)},
		{"id": "or_wagon", "name": "Apple wagon", "cost": 5, "pos": Vector2(0.60, 0.85)},
	]},
	{"id": "meadow", "name": "The Meadow", "map_pos": Vector2(0.242, 0.117), "spots": [
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
const BAG_SLOTS := 2
const BASKET_CAP := 3            # the merchant's buy-back basket size
const PORTER_SECS := 180.0       # the porter clears the basket every ~3 min
const TREAT_COST := 10           # an acorn treat for a wandering spirit (a coin sink)
