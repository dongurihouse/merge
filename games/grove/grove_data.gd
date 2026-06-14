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

# Generators ARE the complexity curve: the satchel from chapter 0; later generators
# REVEAL in the bramble field as their era begins. appears_at is a chapter index.
const GENERATORS := [
	{"id": "satchel", "cell": Vector2i(4, 3), "lines": [1, 2], "appears_at": 0,
		"tex": "ui/gen_satchel.png", "label": "seeds"},   # rel to the active game's art root
	{"id": "compost", "cell": Vector2i(2, 1), "lines": [3], "appears_at": 16,
		"tex": "ui/gen_compost.png", "label": "compost"},
	{"id": "beehive", "cell": Vector2i(6, 5), "lines": [4], "appears_at": 26,
		"tex": "ui/gen_beehive.png", "label": "hive"},
]
const GEN_CELL := Vector2i(4, 3)          # the starter satchel (kept for the open-3x3 math)

const TIER_ODDS := [0.65, 0.25, 0.09, 0.01]   # pop tier 1..4, decaying
const ASK_WEIGHT := 0.6                   # mild lean toward lines the givers want

# Starter items on the open 3x3 (besides the generator cell).
const STARTER_ITEMS := {
	Vector2i(3, 2): 101, Vector2i(3, 4): 101,
	Vector2i(5, 2): 201, Vector2i(5, 4): 201,
	Vector2i(4, 2): 101, Vector2i(4, 4): 201,
}

# Per-zone quest ramp (one entry per zone). quests 5-6/chapter w/ slack.
const ZONE_RAMP := [
	{"tiers": Vector2i(2, 4), "quests": 5, "slack": 1, "two_count_every": 0, "gift": 0},
	{"tiers": Vector2i(3, 5), "quests": 5, "slack": 1, "two_count_every": 0, "gift": 0},
	{"tiers": Vector2i(3, 5), "quests": 5, "slack": 1, "two_count_every": 3, "gift": 0},
	{"tiers": Vector2i(4, 6), "quests": 5, "slack": 1, "two_count_every": 2, "gift": 4},
	{"tiers": Vector2i(5, 7), "quests": 6, "slack": 2, "two_count_every": 2, "gift": 5},
]

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

const EXP_PER_STAR := 10
const LEVEL_XP := [0, 60, 140, 240, 360, 500, 660, 840, 1040, 1260]
const LEVEL_WATER_GIFT := 20
