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
# grow before L2, or a cramped 9-cell board strands on unlucky seeds — see seed 123) radiates to L22
# at the four corners (the last cells to open). Under the §exp ONE-REGION-PER-LEVEL curve (front-loaded
# LEVEL_BASE_EXP/LEVEL_STEP_EXP → the whole 5-zone game ≈ L26, one region per level from L2): with ~6/4/7/4/4
# spots, the zones span roughly map1 L2–7 · map2 L8–11 · map3 L12–18 · map4 L19–22 · map5 L23–26, so the
# board's inner rings open across maps 1–3 and the L22 corners finish near the end of MAP 4. The grove_sim
# confirms the board drains smoothly to zero sealed cells with ZERO jams across the arc. THIS GRID IS THE
# OWNER'S FEEL DIAL — re-tune it; the engine reads it via G.cell_min_level(). 9 rows × 7 cols, indexed
# [row][col] = [cell.x][cell.y].
const MIN_LEVEL := [
#    c0  c1  c2  c3  c4  c5  c6
	[22, 14, 10, 10, 10, 14, 22],   # r0  ← outer corners last (L22, mid map 3)
	[18, 10,  6,  6,  6, 10, 18],   # r1
	[14, 10,  1,  1,  1, 10, 14],   # r2   inner N/S frontier → L1 (T37: L1 frontier so the board grows before L2 — fixes the seed-123 strand)
	[10,  3,  0,  0,  0,  3, 10],   # r3
	[ 6,  3,  0,  0,  0,  3,  6],   # r4   center 3×3 open · generator at c3
	[10,  3,  0,  0,  0,  3, 10],   # r5
	[14, 10,  1,  1,  1, 10, 14],   # r6   inner N/S frontier → L1
	[18, 10,  6,  6,  6, 10, 18],   # r7
	[22, 14, 10, 10, 10, 14, 22],   # r8
]

const TIER_ODDS := [0.65, 0.25, 0.09, 0.01]   # pop tier 1..4, decaying
const ASK_WEIGHT := 0.6                   # mild lean toward lines the givers want
const ASK_TIER_WEIGHT := 0.0             # §6 spawn TIER-bias strength — OFF by default (owner pacing
                                         # dial). At 0.6 the sim front-loads spend ~3x (parked pacing
                                         # pass); ramp here once the level curve is re-tuned on grove_sim.

# §7 generated-quest reward — EFFORT-BASED (clicks are the unit; merge 2:1 so a tier-N item = 2^(N-1) clicks).
#   exp   = round(clicks / QUEST_CLICKS_PER_EXP)              — flat across maps (the progression clock)
#   coins = round(clicks / QUEST_CLICKS_PER_COIN[map] × QUEST_COIN_DEPTH^(tier-QUEST_TIER_BASE))
#   acorns= NONE — acorns are milestone/IAP only (the t8-sell pinnacle was removed; 1 acorn = COINS_PER_ACORN coins).
const QUEST_CLICKS_PER_EXP := 7           # 1 exp (★) ≈ 7 clicks of effort (owner anchor)
const QUEST_CLICKS_PER_COIN := [8, 7, 6, 5, 4]   # clicks-per-coin per map (Farmhouse→Meadow); later maps pay more coins/click
const QUEST_COIN_DEPTH := 1.05            # per-tier coin multiplier — a deep merge's click is worth ~1.5× a shallow one across the band
const COINS_PER_ACORN := 1024             # acorn↔coin value peg (acorns precious; earned only at milestones / bought)
# The whole-game effort budget: clicks to finish ALL maps (last region restored). COMPRESSED 100K → 30K
# (~3–4 weeks of daily play, not many months). The unlock ladder no longer reads this directly (it is one
# region per level now); the LEVEL curve below is sized so the last region lands near this budget, so this
# stays the single "how long is the whole arc" anchor (docs/economy_model.html recalculates from it).
const ENDGAME_CLICKS := 30000             # 30K-click game (docs/economy_model.html is the live calculator)
# §7 ask shape (a regular quest is a SINGLE ask; tier band, count, line weighting, featured) — PROVISIONAL, sim-tuned.
const QUEST_TIER_BASE := 4                # floor of the asked-tier band (no quest asks below t4); band is always [4..TOP_TIER]
const QUEST_LEVELS_PER_TIER := 2          # the asked-tier bell's CENTRE climbs +1 every N levels, up to the band midpoint
const QUEST_NEWEST_BIAS := 1.5            # line-pick weight exponent toward the newest/highest-value live line
const QUEST_FEATURED_RATE := 0.15         # share of regular quests flagged featured (a flat coin bonus, no extra ★)
const QUEST_FEATURED_COIN_BONUS := 10     # flat coin bonus on a featured quest (featured = COINS ONLY since T58 — acorns precious)
# §7 soft gate — PROVISIONAL, sim-tuned.
const MAX_GIVERS := 4                     # fence slots (§7) — the fence is 4 cards at 25% width; the metered active count caps here
const STARS_PER_QUEST_EST := 2            # representative ★/quest for sizing the active-giver meter
# §6 burst-pop — sim-tuned (T25). A generator tap pops a BURST of items, each still 1 energy (burst cuts
# taps, not the per-item energy economy). Burst = a FREE portion (base BURST_ODDS + per-map scale-up,
# capped on its own at BURST_FREE_MAX) PLUS — while a temporary BOOST is live — BOOST_BONUS extra items
# per tap, board-wide, for BOOST_TAPS taps after one BOOST_COST activation (the §10 coin sink). The
# boost is global and decays one tap at a time, then expires; no permanent stacking (T57, replaces the
# old paid burst-upgrade ladder).
const BURST_ODDS := [0.55, 0.30, 0.15]    # base burst pops 1 / 2 / 3 items
const BURST_MAP_EVERY := 2                # +1 base burst every N maps (the free per-map scale-up)
const BURST_FREE_MAX := 4                 # cap on the FREE portion (base + per-map gift) — keeps the gift from trivializing the board
const BOOST_BONUS := 2                    # extra items per generator tap while a boost is live
const BOOST_TAPS := 10                    # how many generator taps one boost lasts
const BOOST_COST := 120                   # coins to activate one boost (the §10 coin sink)
const BURST_MAX := BURST_FREE_MAX + BOOST_BONUS   # absolute ceiling = free cap + the live boost bonus

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

# What BUYING a copy of an item (the §10 board info-bar buy, T55) costs RELATIVE to its sell value:
# buy_price = ceil(sell_reward × BUY_MARKUP), in the same currency split (coins sub-top, 💎 top). Must
# be > 1 so buying always costs strictly more than selling returns (the buy-low/sell-high loop is
# impossible by construction). OWNER/SIM FEEL DIAL — re-validate the faucet/sink balance on grove_sim.
const BUY_MARKUP := 3.0

# Diamonds/acorns — EARNED-ONLY and precious (Option A — 1 acorn = COINS_PER_ACORN coins).
# Quests pay none; sells pay none (the t8 pinnacle was removed). Acorns come from map completion,
# level MILESTONES, login, and IAP — sized so the whole-game earned acorns ≈ the coin faucet in value.
const LEVEL_DIAMONDS := 3                 # acorns granted per level MILESTONE (not every level)
const LEVEL_DIAMOND_EVERY := 10           # a milestone is every Nth level crossed (L10, L20, …)
const MAP_DIAMONDS := 5                   # acorns per map fully restored
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


# Level-up energy gift. Loosened (20 → 40) to LOOSEN THE EARLY GAME: with the front-loaded level curve below,
# week-1 level-ups are frequent, so a bigger gift surges water early then tapers automatically as leveling
# slows — early leveling is actually FELT without permanently changing the cap/regen monetization socket.
const LEVEL_WATER_GIFT := 40
# §map-unlock — the per-spot exp threshold ladder is now ONE REGION PER LEVEL (content.gd: spot_unlock_level
# / spot_unlock_exp): every spot, in global order, unlocks at its own consecutive level (first region at L2,
# next at L3, …). So each level-up grants exactly one region and zones map cleanly onto a band of levels —
# no per-spot const, no even-split budget math, no finale cap. The level curve below is what paces it.
# The one uncapped LEVEL clock (cosmetic badge + per-level gift). FRONT-LOADED arithmetic curve: early levels
# are cheap so the first week delivers a region (and a level-up beat) every half-day or so; later levels cost
# more (STEP) for a gentle ramp. cost(n) = LEVEL_BASE_EXP + (n-1)*LEVEL_STEP_EXP. Sized so the last region
# (~L26 at 25 spots) lands near the compressed click budget — the whole 5-zone arc in ~3–4 weeks of daily
# play, vs the old flat curve's ~L35 / many-month grind. RE-TUNE on grove_sim (the pacing sim is the judge).
const LEVEL_BASE_EXP := 40        # exp for the FIRST level-up (≈ 280 clicks ≈ a couple minutes) — cheap early
const LEVEL_STEP_EXP := 3         # each level costs +3 more than the last (gentle ramp; 0 = perfectly even)

# ambient life + board gameplay tuning
const CHARACTER_TYPES := ["moss", "acorn", "lantern"]   # the wandering character roster (art rows)
const CHARACTER_CAP := 5
const CHARACTER_ART := "characters/spirit_%s.png"              # type → clothes asset (assets keep their names)

# (The §14 FTUE feature-spotlight registry was removed 2026-06-23 with the dormant spotlight
# subsystem — the redesign is specced + parked: docs/superpowers/specs/2026-06-23-ftue-hand-
# gesture-spotlight-design.md + docs/BACKLOG.md. The rebuild re-adds a SPOTLIGHTS table here.)

# (§10 SHOP STOCK — the item-shortcut catalogue (SHOP_ITEM_OFFERS / SHOP_FEATURED_COUNT,
# "buy a mid-tier piece to skip the grind") was removed 2026-06-23: item-buying is moving
# out of the shop and into the board's item info bar. The shop keeps its currency sinks —
# water, the coin pouch, and the §10 IAP layer below. Cosmetic looks were removed earlier
# with the customization feature; both rebuilds are parked in docs/BACKLOG.md.)

# ─────────────────────────────────────────────────────────────────────────────
# §10 LIVE-IAP + STARTER + FREE CLAIMS (T43). The grove's instance of the §4/§10
# monetization layer. The ENGINE (grant/cap/cooldown logic) lives in
# engine/scripts/ui/shop.gd, engine/scripts/core/claims.gd, and the board's energy-wall
# area; these are the OWNER-TUNABLE numbers. DESIGN LAW (§4): premium buys SPEED
# + LOOKS, never POSSIBILITY — every wall is passable for FREE (slower). Cozy
# guardrails (§10, LOCKED): free claims are opt-in, capped + cooldowned.
# ─────────────────────────────────────────────────────────────────────────────

# The full cash → 💎 price ladder (§10 "from an entry tier up to a $49.99/$99.99-class
# top end so a whale can always spend more"). Data-driven: shop.gd renders + grants from
# this. The 💎-per-dollar RISES monotonically up the ladder (the bulk-discount whale curve
# — the top tier is always the best rate), so there's always a higher, better-value tier to
# buy. `pop` marks the merchandised "Popular" card (the mid anchor). LIVE from launch behind
# the honest confirm-stub; a real store SDK + receipt check replaces only the grant middle.
# `key` indexes data/iap_products.json (product id + price live there — the IAP catalog is the single
# source of truth for cost); `gems` is the grant. Prices/rates: $0.99→80 (80.8💎/$, entry) · $4.99→450
# (90.2) · $9.99→1000 (100.1, the merchandised anchor) · $19.99→2200 (110.1) · $49.99→6000 (120.0) ·
# $99.99→13000 (130.0, the whale ceiling, best rate). The 💎/$ rises up the ladder (guarded in tests).
const CASH_PACKS := [
	{"key": "gems_tier1", "gems": 80},
	{"key": "gems_tier2", "gems": 450},
	{"key": "gems_tier3", "gems": 1000, "pop": true},
	{"key": "gems_tier4", "gems": 2200},
	{"key": "gems_tier5", "gems": 6000},
	{"key": "gems_tier6", "gems": 13000},
]

# The STARTER PACK (§10) — a ONE-TIME, high-value, low-price bundle surfaced to new
# players (the highest-converting IAP in mobile). Deliberately ~4–5× the entry rate so it
# reads as an unmissable welcome deal; claimable exactly once (Save.starter_claimed). Grants
# diamonds + a water top-up. Separate from the first-purchase doubler below — it is its own
# one-time SKU and does NOT consume the doubler.
const STARTER_PACK := {"key": "starter", "gems": 400, "water": 60}   # price: data/iap_products.json

# The FIRST-PURCHASE DOUBLER (§10) — the FIRST ladder cash pack a player buys grants ×this
# many diamonds, then never again (Save.first_purchase_made). A one-time conversion sweetener
# on the standard ladder (the starter pack is excluded — it's its own SKU).
const FIRST_BUY_MULT := 2

# FREE CLAIMS (§10 — "opt-in, free, capped + cooldowned"). One row per faucet surface: the
# per-type DAILY cap and COOLDOWN (seconds) gate how often it pays, so a faucet never becomes
# the optimal grind (§4 "buys speed, never possibility"; §10 cozy bed). Every claim is FREE —
# a tap, no ad, no cost. `gems`/`water` describe the grant the engine applies:
#   refill_water — the watering-can top-up (a full can) offered free in the water stall. The
#                  grant is ADDITIVE and may carry the can OVER WATER_CAP (banked spare); regen
#                  pauses while over the cap (board_logic.regen), resuming once it drops below.
#   (the free_gems acorn faucet was RETIRED 2026-06-23 — acorns are precious/earned-only, Option A.)
const CLAIMS := {
	"refill_water": {"cap": 3, "cooldown": 1800, "water": WATER_CAP},  # 3/day, 30 min apart — a full can (over-cap ok)
}

# The diamond-priced QUEST-REWARD 2× DOUBLER (§10). After a quest pays a lump of coins, the
# player may pay 💎 to DOUBLE it — but only when the deal beats the shop coin pouch. This is
# the guaranteed coins-per-💎 the doubler delivers: the offer appears only when the reward is
# at least this big (got >= rate), and the price is floor(got / rate) 💎, so the player always
# gets >= `rate` coins per 💎. It MUST exceed the shop pouch rate (shop.gd COIN_PACK /
# COIN_PACK_GEM_COST = 150/5 = 30) so the doubler is always the better buy (a test guards this).
# NOTE: with today's small quest coin rewards (tier − STAR_CAP ≈ 1–9), got rarely reaches this,
# so the doubler is a correct-but-rarely-seen offer until quest coin faucets grow.
const COLLECT_2X_COIN_RATE := 36
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
const VAULT_CAP := 500                    # a generous ceiling so the jar art has a "full" state; the bank never exceeds it
# The crack price ($2.99) + product id live in data/iap_products.json under "piggybank" (the IAP catalog
# is the single source of truth for cost); core/vault.gd::price_usd() reads it from there.

# The daily login calendar (§18) reward tables are now DATA, not consts: the repeating
# WEEK `ladder` (escalating small rewards), the `milestones` keyed by absolute streak day
# (a bigger payout that OVERRIDES the week slot), the MYSTERY `mystery` slots (an auto-spin
# reveal drawing `show` rewards and landing on `win`), and the `water_safe_max` faucet guard
# all live in `games/grove/login_rewards.json`, read by engine/scripts/core/login.gd off
# Game.active() (mirrors strings.json). Re-tune rewards/cadence THERE — no code edit.
# Faucet discipline still holds (mostly COINS; WATER a modest top-up ≤ water_safe_max, far
# under a day's ~720 natural regen; PREMIUM 💎 the weekly capstone + milestones); the streak
# stays FORGIVING (Save.daily soft-decays a missed day, never to day 1).

# The one-time gift for fully unlocking a map (all spots restored + gate delivered). Escalates with the
# map index z: more coins/diamonds on later maps, plus one free signature spirit (the map's non-premium
# critter). z=0 (120 coins / 2 gems) equals the old flat MAP_TASK_REWARD, so the first map is unchanged.
static func map_unlock_reward(z: int) -> Dictionary:
	var sig: Array = RESIDENT_SIGNATURE.get(String(MAPS[z].id), [])
	var spirit: String = String(sig[0].id) if sig.size() > 0 else ""
	return {"coins": 120 + 80 * z, "gems": 2 + z, "spirit": spirit}
