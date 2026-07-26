extends RefCounted
## GROVE game DATA — the content + tuning the engine's content logic reads via
## Game.DATA. Pure tables, zero logic: item lines, generators, the bramble curve
## numbers, the quest ramp, maps/spots, waysides, variants, and all economy dials.
## A different game ships its own data module with the SAME const names.


const COLS := 7
const ROWS := 9
const TOP_TIER := 12
const PREMIUM_TIER := 8  # pins the diamond-earn rate + sell pinnacle, decoupled from TOP_TIER

# Item lines — code = line*100 + tier. Art loads <art_root>/items/<base>/<base>_<tier>.png; a line
# renders code-drawn from its `color` only if a tier sprite is missing. GEN REDESIGN (2026-06-28): the
# 17 BASE lines below (1-5, 21-37, 51) each get their OWN per-line generator (see GENERATORS), introduced one
# per ZONE (= restoration spot). Specials 71-75 are CRAFTED by merging two base lines (Core §6.G) — no
# generator. Wildflower (1) is the title line + the anchor (gen_1, the FTUE starter). Codes skip 9 (= COIN_LINE).
# The §6.E `min_level` field on the Farm lines (61-66) is now VESTIGIAL — those lines aren't in the per-line
# roster (shelved); the staged-line model is retired.
const LINES := {
	# --- THE PICTURE-BOOK ROSTER (12 lines; docs/design/picturebook_lines_recipes.md) -----------
	# 8 BASE lines (own generator, introduced in zone order) + 4 SPECIALS (crafted by merging two
	# ingredient lines at the same tier — Core §6.G; recipes live in ZONES below, and may name
	# another special as an ingredient: tea_cup ← spices+wild berries, the deepest v1 craft).
	# Codes skip 9 (COIN_LINE) and 10-15 (SPECIAL_ITEMS drops); specials sit at 5/8/17/19 so each
	# page reads contiguously. Art: items/<base>/<base>_<tier>.png (v2 cut-paper, sliced 2026-07-17).
	# P1 Fairy Hollow
	1: {"name": "Glow-mushrooms", "base": "fairy_hollow_glowshroom", "color": Color("#E387C9"), "desc": "Softly glowing caps from the hollow. The forest's first light."},
	2: {"name": "Wild Berries", "base": "fairy_hollow_wild_berries", "color": Color("#8C5BA8"), "desc": "Sweet dark berries from the bramble shade."},
	# P2 Snowy Village
	3: {"name": "Snow & Ice", "base": "snowy_village_snow_ice", "color": Color("#BFE6F2"), "desc": "Snowballs and carved ice, colder and grander each merge."},
	4: {"name": "Woolens", "base": "snowy_village_woolens", "color": Color("#D9776B"), "desc": "Knits and warmers for the village winter."},
	5: {"name": "Winter Berries", "base": "snowy_village_winter_berries", "color": Color("#B33A4D"), "desc": "Frost-kissed sprigs. Crafted from wild berries and snow."},
	# P3 Desert Oasis
	6: {"name": "Desert Fruits", "base": "oasis_desert_fruits", "color": Color("#E3B23C"), "desc": "Sun-baked harvests from the oasis palms."},
	7: {"name": "Sand Sculptures", "base": "oasis_sand_sculptures", "color": Color("#D9C08B"), "desc": "Shaped sand, from castle to monument."},
	8: {"name": "Spices", "base": "oasis_spices", "color": Color("#C96A3F"), "desc": "Fragrant market blends. Crafted from wild berries and woolens."},
	# P4 Coral Reef
	16: {"name": "Shells", "base": "coral_reef_shells", "color": Color("#E8D0B0"), "desc": "Tide-turned shells in every spiral and hue."},
	17: {"name": "Corals", "base": "coral_reef_corals", "color": Color("#E08A7A"), "desc": "Living reef sculptures. Crafted from sand and snow."},
	# P5 Cherry-Blossom Garden
	18: {"name": "Koi", "base": "cherry_blossom_koi", "color": Color("#E06A50"), "desc": "Garden koi, calm and bright, rarer with each merge."},
	19: {"name": "Tea Cups", "base": "cherry_blossom_tea_cups", "color": Color("#8FB4D9"), "desc": "A collector's tea service. Crafted from spices and wild berries."},
	# §6.D premium TREAT lines (unchanged — the fleeting treat-generator drops, NOT zone content).
	71: {"name": "Prize pumpkin", "base": "special_pumpkin", "color": Color("#E0832F"), "desc": "A special harvest treasure. Merge high, then sell for coins."},
	72: {"name": "Golden banana", "base": "special_banana", "color": Color("#E3C84A"), "desc": "A rare golden treat line. Merge for better treasure value."},
	73: {"name": "Jewel avocado", "base": "special_avacado", "color": Color("#6BA84F"), "desc": "A glossy treasure fruit. Higher tiers are worth saving."},
	74: {"name": "Ruby cherry", "base": "special_cherry", "color": Color("#D9433F"), "desc": "A bright treasure fruit for coin value."},
	75: {"name": "Sugar melon", "base": "special_watermelon", "color": Color("#5FA86B"), "desc": "A sweet special melon. Merge it before selling."},
}

# Generators — one board generator per BASE picture-book line. Generators persist: they are never handed in
# or consumed. Crafted/special lines are made through recipes, so they have no board generator icon.
const GENERATORS := [
	# ONE generator per BASE line (Core §6.A), born on tap as its zone opens (§6.B). 8 base lines in
	# zone order; `zone` = zone index, `map` = its page BAND (must equal G.zone_map(zone) — the
	# mechanics_tests guard pins it). Specials (ZONES rows with a recipe) have NO generator (crafted).
	{"id": "gen_1",  "line": 1,  "zone": 0,  "map": 0, "cell": Vector2i(4, 3), "anchor": true, "tex": "items/generator/gen_fairy_hollow_glowshroom.png",  "label": "glow-mushrooms"},
	{"id": "gen_2",  "line": 2,  "zone": 1,  "map": 0, "tex": "items/generator/gen_fairy_hollow_wild_berries.png",  "label": "wild berries"},
	{"id": "gen_3",  "line": 3,  "zone": 2,  "map": 1, "tex": "items/generator/gen_snowy_village_snow_ice.png",  "label": "snow & ice"},
	{"id": "gen_4",  "line": 4,  "zone": 3,  "map": 1, "tex": "items/generator/gen_snowy_village_woolens.png",  "label": "woolens"},
	{"id": "gen_6",  "line": 6,  "zone": 5,  "map": 2, "tex": "items/generator/gen_oasis_desert_fruits.png",  "label": "desert fruits"},
	{"id": "gen_7",  "line": 7,  "zone": 6,  "map": 2, "tex": "items/generator/gen_oasis_sand_sculptures.png",  "label": "sand sculptures"},
	{"id": "gen_16", "line": 16, "zone": 8,  "map": 3, "tex": "items/generator/gen_coral_reef_shells.png",  "label": "shells"},
	{"id": "gen_18", "line": 18, "zone": 10, "map": 4, "tex": "items/generator/gen_cherry_blossom_koi.png",  "label": "koi"},
]
const GEN_CELL := Vector2i(4, 3)          # the starter satchel (kept for the open-3x3 math)

# §4 obstacle field — the per-cell LEVEL gate. A sealed cell unseals when the player's Level
# reaches its number, then opens on the next ADJACENT MERGE (the level gates *when*, not *how*;
# any merge opens an eligible neighbour). 0 = open at start (the center 3×3 + the generator).
# A hand-tuned diamond: the L1 inner frontier (T37 — where the merge verb is taught; the board MUST
# grow before L2, or a cramped 9-cell board strands on unlucky seeds — see seed 123) radiates to L22
# at the four corners (the last cells to open). The scene LEVEL WINDOWS have since moved onto the derived
# coin-clock cadence (content.gd's _build_cadence): Fairy Hollow L1-7 · Snowy Village L8-19 · Desert Oasis
# L20-37 · Coral Reef L38-61 · Cherry Blossom L62-87. The MIN_LEVEL grid below was hand-tuned against the
# OLDER windows and was not rescaled with them — the L22 corners now open near the START of Desert Oasis
# (scene 3) rather than the end of scene 4. The grove_sim
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
# §6 single-generator board-mergeability cap. The one anchor pops the items the current quests require
# (idea 3.2), but several quests could span many DISTINCT lines — scattering un-mergeable singletons until
# the board jams. So the generator pops at most this many distinct lines per session (the lowest-indexed
# wanted lines win; the rest become hot as those clear), so pairs always form. STAGED: a tighter cap on the
# tiny zone-1 (Farmhouse) board, the full cap from zone 2 on. OWNER/SIM dial (grove_sim I1 = zero jams judges).

# §6 ZONE PROGRESSION (gen redesign 2026-06-28) — the new per-line model. The world is a run of ZONES,
# each = a restoration spot. Rhythm: base · base · special. 17 base lines + 8 special = 25 zones (= the 25 live restoration spots, [6,4,7,4,4]); a special
# (every 3rd zone) is crafted by merging the two base lines just before it (no generator). Base lines are
# popped one-per-generator; specials have no generator (Core §6.A/G). Built ADDITIVELY alongside the legacy
# map/`lines[]` roster — the board wiring flips to it in a later step. OWNER/content dials.
# §6 THE ZONE TABLE (picture-book roster) — data-driven, replacing the old every-3rd-zone formula:
# one row per zone in play order; a row with a `recipe` introduces a SPECIAL (crafted by merging its
# two ingredient lines at the same tier; an ingredient may itself be a special — tea_cup ← spices).
# Pages band the zones via ZONE_BAND below.
const ZONES := [
	{"line": 1},                            # z0  P1 glow-mushrooms (anchor)
	{"line": 2},                            # z1  P1 wild berries
	{"line": 3},                            # z2  P2 snow & ice
	{"line": 4},                            # z3  P2 woolens
	{"line": 5, "recipe": [2, 3]},          # z4  P2 winter berries = wild berries + snow
	{"line": 6},                            # z5  P3 desert fruits
	{"line": 7},                            # z6  P3 sand sculptures
	{"line": 8, "recipe": [2, 4]},          # z7  P3 spices = wild berries + woolens
	{"line": 16},                           # z8  P4 shells
	{"line": 17, "recipe": [7, 3]},         # z9  P4 corals = sand + snow
	{"line": 18},                           # z10 P5 koi
	{"line": 19, "recipe": [8, 2]},         # z11 P5 tea cups = spices + wild berries (2-level craft)
]
const ZONE_BASE_LINES := [1, 2, 3, 4, 6, 7, 16, 18]   # the 8 base lines, in zone order (derived view of ZONES)
const ZONE_SPECIAL_LINES := [5, 8, 17, 19]            # the 4 crafted specials (rows of ZONES with a recipe)
const ZONE_COUNT := 12                    # 8 base + 4 special zones (the [2,3,3,2,2] banding below)
# Per-PAGE zone counts (P1 Fairy Hollow -> P5 Cherry-Blossom). Pure banding for the per-band
# coin/sell curves (QUEST_CLICKS_PER_COIN / SELL_MAP_BAND) — G.zone_map derives from THIS.
const ZONE_BAND := [2, 3, 3, 2, 2]
# (the old ZONE_MAP_SPOTS const is gone — zone→map is derived live from MAPS via G.zone_map/map_for_spots,
# so it can't drift from the vine-region layout the way a hardcoded [7,4,7,4,1] did.)

# §7 ZONE UNLOCK CADENCE — DERIVED, not authored (2026-07-26 re-spine). content.zone_unlock_level(z)
# computes it: each scene's LEVEL WINDOW comes from the authored SCENE_END_LEVEL (below), and ZONE_BAND
# spreads that scene's zones evenly inside its own window. So a generator still arrives as its themed
# scene comes into view, and the alignment is COMPUTED rather than hand-maintained — but that is not a
# structural guarantee for every possible re-tune. It holds at today's dials because the test suite's
# scene-alignment assertions hold it when SCENE_END_LEVEL or ZONE_BAND move — mechanics_tests.gd's
# "scene alignment" case, and tuning_tests.gd's "every zone still lands inside its own scene's window
# after SCENE_END_LEVEL moves", which re-checks the same invariant.
# The dials that move this are SCENE_END_LEVEL (below) and ZONE_BAND. The coin curve (LEVEL_BASE_COINS /
# LEVEL_STEP_COINS) no longer has any say in where the gates fall — it only sets how long a level takes.

# §6.D GENERATOR MERGE LADDER (gen redesign 2026-06-28). Two same-line generators merge 2:1 up to GEN_TOP_TIER;
# higher tier pops more multiples (GEN_TIER_BURST_ODDS). A below-top generator self-produces a duplicate at
# GEN_SELF_DUP_RATE per tap (the merge fuel), spawned at the line's TOP tier; a maxed line breeds nothing.
# NOTE: self-dup is currently OFF (GEN_SELF_DUP_RATE = 0.0) — see the constant. With no fuel the ladder is
# dormant: generators stay at the tier they already hold, and no new leftovers can strand.
# §8 THE PACING DIAL (2026-07-26) — the owner authors the level each cover-up SCENE fully restores at;
# clusters and zones both spread INSIDE the band this defines (content._build_cadence). Replaces the
# old cost-derived floors (CLUSTER_LEVEL_LEAD is retired): the level clock counts QUEST coins only, but
# the cover-up ladder is paid from the whole wallet (~2.2x the clock), so a floor derived from cost bound
# roughly twice as late as the price and doubled the arc to ~316 days. Chosen in DAYS, not levels — solve
# for a day-per-scene target with:
#   godot --headless --path . -s res://games/grove/tools/pacing_calc.gd -- 3 2 20 3,4,5,6,7 "" 60
# Entry i is the level at which cover-up scene i is FULLY RESTORED — its LAST cluster unlocks exactly
# there (content._build_cadence spreads the scene's other clusters and zones inside the band this and
# the previous entry define). MUST be strictly increasing, one entry per cover-up scene.
# Re-solved 2026-07-26 for target days 3/4/5/6/7 per scene (25 days, 3 sessions/day) WITH
# LEVEL_WATER_GIFT modelled as a faucet-side offset in pacing_calc.gd's day_at walk (previously the
# report-mode walk left the gift unmodelled). The earlier [19, 29, 39, 48, 58] solve ran the book in
# ~16 days instead of 25 — about 40% fast — because it didn't account for the extra water the gift
# hands back on every level-up. Raising the levels (not shrinking the gift) restores the target
# calendar; recompute with:
#   godot --headless --path . -s res://games/grove/tools/pacing_calc.gd -- 3 2 20 3,4,5,6,7 "" 60
const SCENE_END_LEVEL := [25, 36, 46, 58, 71]
const GEN_TOP_TIER := 3
# §7 THE ACTIVE-LINE WINDOW (2026-07-25). The quest fence asks from exactly this many lines at a time —
# ANY line, base or crafted-special alike (the window slides over ZONES rows, so it advances on EVERY zone,
# not only base zones). A special no longer needs its ingredient lines to be in the window: its ingredient
# GENERATORS are birthed on tap (Quests.due_gen → G.gens_for_quest_line), so the ingredients come back as
# tools even after their line has left the fence. Peak generator footprint across the whole arc is 5, under
# QUEST_GEN_CAP. Re-run grove_sim after changing this — a tighter window is a real no-strand tightening.
const ACTIVE_LINE_WINDOW := 3
const QUEST_GEN_CAP := 6                   # gen redesign #16 (RE-SCOPED): a QUEST-side cap — the active quests may demand at most this many DISTINCT generators (a base ask needs 1; a merge/special ask needs its 2 ingredient gens). The player's BOARD is uncapped; this just stops merge-quests forcing a huge generator count.
const GEN_SELF_DUP_RATE := 0.0             # DISABLED (owner call 2026-07-23) — was 0.005 (0.5%/tap). The
                                           # duplicate spawned at the LINE TOP, so a sub-top leftover met a
                                           # top-tier copy it could not merge with — and since gen art is
                                           # tier-independent the pair looked identical and the drop silently
                                           # swapped (board.gd swap_gens). Re-enable by restoring 0.005 once
                                           # tier is legible on the board and a refused merge bounces.
# Coins refunded when SELLING a redundant generator (a sub-top leftover), indexed by tier 1..GEN_TOP_TIER-1
# (a tier-3 is never redundant, so never sold). Small on purpose — 0.5%/tap breeding must not be a coin faucet.
const GEN_SELL_COINS := [2, 6]             # tier 1 → 2 coins, tier 2 → 6 coins
const GEN_TIER_BURST_ODDS := [             # burst odds [1,2,3 items] by generator tier (1..3) — higher = more multiples
	[0.80, 0.15, 0.05],   # tier 1
	[0.50, 0.35, 0.15],   # tier 2
	[0.20, 0.45, 0.35],   # tier 3
]
const ASK_TIER_WEIGHT := 0.0             # §6 spawn TIER-bias strength — OFF by default (owner pacing
                                         # dial). At 0.6 the sim front-loads spend ~3x (parked pacing
                                         # pass); ramp here once the level curve is re-tuned on grove_sim.

# §7 generated-quest reward — EFFORT-BASED (clicks are the unit; merge 2:1 so a tier-N item = 2^(N-1) clicks).
#   exp   = round(clicks / QUEST_CLICKS_PER_EXP × line_exp_mult)  — scales by LINE RANK: later lines pay more (§7)
#   coins = round(clicks / QUEST_CLICKS_PER_COIN[map] × QUEST_COIN_DEPTH^(tier-QUEST_TIER_BASE))  — per-map + per-tier
#   merger (special line): QUEST_MERGE_REWARD_FACTOR × its two recipe sources' COMBINED exp & coins (no reward of its own)
#   acorns= NONE — acorns are milestone/IAP only (the t8-sell pinnacle was removed; 1 acorn = COINS_PER_ACORN coins).
const QUEST_CLICKS_PER_EXP := 7           # 1 exp (★) ≈ 7 clicks of effort at the FIRST line (rank 0); later lines ramp up (owner anchor)
const QUEST_CLICKS_PER_COIN := [8, 7, 6, 5, 4]   # clicks-per-coin per page band (Fairy→Cherry); later pages pay more coins/click
const QUEST_COIN_DEPTH := 1.05            # per-tier coin multiplier — a deep merge's click is worth ~1.5× a shallow one across the band
const QUEST_EXP_LINE_SPREAD := 2.0        # per-line EXP ramp: the LAST base line pays this × the FIRST line's exp at the same tier (linear by ZONE_BASE_LINES rank). EXP only — coins keep their per-map curve.
const QUEST_MERGE_REWARD_FACTOR := 1.2    # a merger/special-line quest pays this × its two source lines' COMBINED reward (exp AND coins) — it has no generator/base reward of its own.
const COINS_PER_ACORN := 1024             # acorn↔coin value peg (acorns precious; earned only at milestones / bought)
# §7 ask shape (a regular quest is a SINGLE ask; tier band, count, line weighting, featured) — PROVISIONAL, sim-tuned.
const QUEST_TIER_BASE := 4                # floor of the asked-tier band (no quest asks below t4); band is always [4..TOP_TIER]
const QUEST_LEVELS_PER_TIER := 2          # the asked-tier bell's CENTRE climbs +1 every N levels, up to the band midpoint
const QUEST_NEWEST_BIAS := 1.5            # line-pick weight exponent toward the newest/highest-value live line
const QUEST_FEATURED_RATE := 0.15         # share of regular quests flagged featured (a flat coin bonus, no extra ★)
const QUEST_FEATURED_COIN_BONUS := 10     # flat coin bonus on a featured quest (featured = COINS ONLY since T58 — acorns precious)
# §7 soft gate — PROVISIONAL, sim-tuned.
const MAX_GIVERS := 8                     # fence quest slots (§7, gen redesign #13) — up to 8 quest cards (+ the jar); metered active count caps here. The fence scrolls horizontally when these + the jar overflow the screen.
const MAX_QUESTS_PER_LINE := 4            # per active item line; a one-line fresh game shows 4 quests, then the fence grows as level reaches more lines.
const STARS_PER_QUEST_EST := 2            # representative ★/quest for sizing the active-giver meter
# §6 burst-pop (T58). A generator tap pops a BURST of items, each still 1 energy (burst cuts taps, not the
# per-item energy economy). The COUNT is drawn from an odds table: BURST_ODDS with NO boost (a single item
# is the norm, multiples are rare) or BURST_ODDS_BOOST while a temporary BOOST is live (multiples become the
# norm). The boost RAISES THE CHANCE of multiples — it does NOT add a flat count, and there is no per-map
# scale-up. One BOOST_COST activation arms BOOST_TAPS taps on ONE chosen generator (per-generator, stackable
# across generators), decays one tap at a time, then expires (the §10 coin sink — T57). Both tables top out at BURST_MAX.
const BURST_ODDS       := [0.80, 0.15, 0.05]   # no boost: 1 / 2 / 3 items — a single item is the norm
const BURST_ODDS_BOOST := [0.20, 0.45, 0.35]   # boost live: 1 / 2 / 3 items — multiples are the norm
const BURST_MAX        := 3                     # ceiling on one tap's burst (both tables top out here)
const BOOST_BONUS := 2                    # >0 marks "a boost is live" to burst_count (legacy name — no longer a flat add)
const BOOST_TAPS := 10                    # how many generator taps one boost lasts
const BOOST_COST := 120                   # coins to activate one boost (the §10 coin sink)

# ─────────────────────────────────────────────────────────────────────────────
# §1 RESIDENTS — the population sub-game (replaces the removed home-hub coin-yield
# loop). Residents are WELCOMED (bought) on COMPLETED maps; two of the same type+tier
# AUTO-MERGE into one a tier up (cascading). The roster is persisted (Save.residents);
# the ambient display (ambient.gd) is stateless and rebuilt from the roster — NO cap.
# Each map has ONE resident LINE — a nature-elemental spirit-folk family welcomed onto the map and
# merged two-of-a-kind up a 12-tier ladder (RESIDENT_MAX_TIER). Each tier ships its own art under
# items/resident_<id>/ (the item-line convention), addressed by RESIDENT_ART. The ENGINE math
# (welcome / merge / members) lives in content.gd and reads these tables.
const RESIDENT_MAX_TIER := 12             # t1 welcomed → merges up to this tier (cascading)
const RESIDENT_SLOTS_MAX := 8            # §1 a map's roster CAP: scales 1 (first spot restored) → this (all spots); a full roster forces a merge or discard
const RESIDENT_ART := "items/resident_%s/resident_%s_%d.png"   # (id, id, tier) → per-tier ladder art (item-line convention)
# ONE resident line per map — keyed by the PAGE id (picture-book world, 2026-07-18; the spirit KIND
# ids stay fixed for save-stability — only the map keys were re-homed from the retired farm slots).
# Each is a nature-elemental spirit-folk family; 12 tiers at items/resident_<id>/resident_<id>_<tier>.png.
const RESIDENT_LINES := {
	"fairy_hollow": {"id": "ember", "name": "Ember"},              # fire / hearth-warmth
	"snowy_village": {"id": "sprout", "name": "Sprout"},           # earth / green growth
	"desert_oasis": {"id": "dewdrop", "name": "Dewdrop"},          # water / oasis-dew
	"coral_reef": {"id": "breeze", "name": "Breeze"},              # air / current
	"sakura": {"id": "starlight", "name": "Starlight"},   # light / aether
}
# The GLOBAL resident bucket (grove_spec §3): four resource LINES, each arted by one of the existing
# resident families (items/resident_<kind>/). breeze (air) is retired — legacy breeze spirits migrate
# to the coin line. Cells come from fully-unlocked cover-up scenes (one per completed scene, max 5;
# see content.cells_from_scenes).
const RESIDENT_LINE_KINDS := {"coin": "sprout", "water": "dewdrop", "boost": "ember", "diamond": "starlight"}
const RESIDENT_KIND_LINES := {"sprout": "coin", "dewdrop": "water", "ember": "boost", "starlight": "diamond", "breeze": "coin"}

# Welcome PRICING — PROVISIONAL feel dials (sim-tuned later). A t1 resident costs coins.
const RESIDENT_BASE_COST := 40           # 🪙 to welcome a t1 resident
const RESIDENT_PREMIUM_COST := 3         # 💎 vestigial — no line is premium in the one-line-per-map model (kept for resident_cost compat)

# The resident line(s) OFFERED on `map_id`: the map's single line as a one-element array (the stable
# roster order the engine flattens/merges in — content.resident_members / resolve_resident_merges).
# Empty for a map with no line. Each entry a Dictionary {id, name}.
static func resident_lines(map_id: String) -> Array:
	var ln: Dictionary = RESIDENT_LINES.get(map_id, {})
	return [ln.duplicate(true)] if not ln.is_empty() else []

# BACKLOG (post-v1): premium 💎 surprise-capsule (no-loss, cosmetic, guardrails) — see grove_spec §1.

# Starter items on the open 3x3 (besides the generator cell). The board OPENS with merge fuel for the
# ANCHOR line only — Wildflower (101) — because gen_1 is the sole generator on a fresh map-0 board and each
# generator pops only its OWN line (gen redesign 2026-06-28). INVARIANT: every seeded line must be
# produceable on map 0 (mechanics_tests guards it) — a starter whose line has no generator is an orphan
# that sits dead on the board forever. (This previously seeded Hearth embers (6101), whose line 61 was
# shelved in the redesign, leaving 3 dead items on every new save — now all Wildflower.)
const STARTER_ITEMS := {
	Vector2i(3, 2): 101, Vector2i(3, 4): 101,
	Vector2i(5, 2): 101, Vector2i(5, 4): 101,
	Vector2i(4, 2): 101, Vector2i(4, 4): 101,
}


# §6/§9 per-map SELL COIN band — later maps' items sell for MORE coins (each map a real
# economic step-up, not just new art). Indexed by the item's map (0-indexed, maps 1–5). A
# t1–t7 item sells for round(tier_coins × band[map]); t8 stays the FLAT 1💎 pinnacle on every
# map (the 32× anti-arbitrage proof, §9 — only the t1–t7 COIN reward scales, never t8→premium).
# Monotonic by construction. Map 1 == 1.0 keeps the FTUE-era sell proofs exact. OWNER/SIM FEEL
# DIAL — re-tune across the arc (grove_spec §5); the engine reads it via G.SELL_MAP_BAND in
# content.sell_reward(). One entry per MAPS row.
const SELL_MAP_BAND := [1.0, 1.3, 1.7, 2.2, 2.8]   # Fairy Hollow · Snowy · Oasis · Reef · Cherry-Blossom

# BUYING a copy of an item (the §10 board info-bar buy, T55) — the SPLIT ladder (owner decision
# 2026-07-18): t1-t3 cost COINS at 10× sell value; t4+ cost ACORNS on a Fibonacci ramp (1·2·3·5·8·
# 13·21·34·55 for t4..t12) — in content.buy_price. BUY_MARKUP is VESTIGIAL (parked-suite parse only;
# impossible by construction). OWNER/SIM FEEL DIAL — re-validate the faucet/sink balance on grove_sim.
const BUY_MARKUP := 3.0

# Diamonds/acorns — EARNED-ONLY and precious (Option A — 1 acorn = COINS_PER_ACORN coins).
# Quests pay none; sells pay none (the t8 pinnacle was removed). Acorns come from map completion,
# level MILESTONES, login, and IAP — sized so the whole-game earned acorns ≈ the coin faucet in value.
const LEVEL_DIAMONDS := 3                 # acorns granted per level MILESTONE (not every level)
const LEVEL_DIAMOND_EVERY := 10           # a milestone is every Nth level crossed (L10, L20, …)
const MAP_DIAMONDS := 5                   # acorns per map fully restored
const REFILL_DIAMOND_COST := 25           # paid rain, once today's free rain is unavailable

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
const WINBACK_HOURS := 48                 # away >= this → full cap ("it rained")
const WATER_REWARD_MAX_RATIO := 0.3       # invariant: per-spot water rewards < 30% of cost

# Coins on the board.
const COIN_LINE := 9                      # code 9xx; never popped, never asked
const COIN_TOP := 3                       # 3 tiers now (the 12-tier ladder is retired)
# Which ART file each in-game tier wears, per base — the 12-tier sheets stay on disk and the OWNER
# picks the looks (2026-07-18: coin t1/t2/t3 wear art 1/5/12 — coin → pouch → chest; acorn wears
# 3/5/6). A base not listed maps tier N → art N. Read via G.art_tier_for (item_tex_path + the
# piece_view coin branch).
const ART_TIER_PICK := {"coin": [1, 5, 12], "acorn": [3, 5, 6]}
const COIN_VALUES := {1: 2, 2: 4, 3: 10}  # tap-collect value per coin tier
const COIN_DROP_RATE := 0.10              # chance a merge also drops a c1

# §6.B SPECIAL DROP ITEMS — short coin-like PSEUDO-LINES (merge.spec §6.B). Most merge up to a
# small top (SPECIAL_TOP), while individual defs may override it. They are NEVER popped from the generator
# and NEVER asked by quests or sold; they
# DROP occasionally and pay out a reward on use. Codes `line*100 + tier` on dedicated line numbers (10+,
# clear of the 1-5 content lines + 9 = coin). Art at items/<base>/<base>_<tier>.png (already wired). `kind`
# selects the behaviour (built in sequence): chest+key (open for reward), water/acorn/exp (tap-collect the
# currency). OWNER-TUNABLE; drop rates + rewards live with each behaviour as it lands.
const SPECIAL_TOP := 3                     # default special-item merge ceiling (like coins); a def may override with "top"
const SPECIAL_ITEMS := {
	10: {"name": "Chest", "base": "chest", "kind": "chest", "desc": "Tap again to open a reward. Merge first for a richer one."},   # merges (3 tiers); TAP-opened — the key line is retired
	12: {"name": "Water drop", "base": "water", "kind": "water", "desc": "Tap again to collect water. Merge first for more."},   # merges; tap-collect → energy
	13: {"name": "Acorn drop", "base": "acorn", "kind": "acorn", "desc": "Tap again to collect acorns. Merge first for more."},   # merges (3 tiers); tap-collect → acorns (premium)
}
# §6.B special-drop ROLL + collect/open rewards (PROVISIONAL — sim-tuned). On a merge there is a small
# chance to also shake loose a special item (alongside the coin drop), a t1 of a weighted-random kind.
# Tap-collect grants the resource (water/acorn) per tier; a CHEST is opened by a second TAP
# (no key needed — the key line is retired) for a coins+acorns payout scaled by the chest tier.
const SPECIAL_DROP_RATE := 0.02           # P(a merge also drops a special item); cf COIN_DROP_RATE 0.10 (sim-tuned down — drops fed too much water/exp)
const SPECIAL_DROP_WEIGHTS := {10: 1, 12: 1, 13: 1}   # chest·water·acorn (flat; the key + spark lines are retired)
const SPECIAL_COLLECT := {                 # tap-collect amount per tier for the resource kinds
	"water": {1: 8, 2: 20, 3: 50},
	"acorn": {1: 1, 2: 2, 3: 5},   # 3 tiers now (the 12-tier premium ladder is retired)
}
const CHEST_OPEN_COINS := {1: 40, 2: 120, 3: 320}   # base coins for opening a chest of this tier …
const CHEST_OPEN_ACORNS := {1: 0, 2: 1, 3: 3}       # … plus acorns at the higher chest tiers

# §6.C UTILITY ACCUMULATORS — generators that BANK a resource over real time (no water cost) up to a small
# cap; tap to collect, bag-stowable (reuse the generator bag). UNLOCKED across map 1's first 4 restored
# spots (unlock_spot = the map-0 spot index whose claim reveals it). Each banks +1 every `secs`
# (offline-inclusive, like water regen), capped at `cap`; collecting grants banked × `value`. The small
# caps keep them a CHECK-IN reward, never a self-sustaining faucet (§4 energy law; the exp one kept modest
# vs the pacing clock). PROVISIONAL — sim/owner-tuned. Art at `tex` (already wired).
const ACCUMULATORS := {
	"water": {"id": "acc_water", "name": "Rain barrel", "tex": "items/generator/gen_rainbarrel.png", "cap": 2, "secs": 3600, "value": 2, "unlock_spot": 0},
	"coins": {"id": "acc_coins", "name": "Coin press", "tex": "items/generator/gen_coinpress.png", "cap": 5, "secs": 1800, "value": 8, "unlock_spot": 1},
	# (the "exp" Crystal font is RETIRED 2026-07-22: its exp special line no longer exists, so its taps
	# did nothing — dropping the kind stops new side-spawns, and from_dict's is_valid_generator_id
	# gate prunes any stale acc_exp still sitting on an old save's board or bag.)
	"acorn": {"id": "acc_acorn", "name": "Acorn mill", "tex": "items/generator/gen_acornmill.png", "cap": 3, "secs": 7200, "value": 1, "unlock_spot": 3},
}
# §6.C BONUS generators (gen redesign 2026-06-28): the ACCUMULATORS above are no longer constant-accrual.
# A bonus generator SIDE-SPAWNS off a main-generator tap, pops collectable board items for a random
# BONUS_CLICKS budget, then VANISHES. (cap / secs / unlock_spot are now vestigial.) Sim-tuned dials.
const BONUS_SPAWN_CHANCE := 0.03          # P(a main-generator tap also side-spawns a bonus gen) — the 2–5% band
const BONUS_CLICKS := [1, 5]              # the random tap budget a bonus generator lasts [min, max] (owner cut from [5,15], 2026-07-18)

# §6.D TEMPORARY TREAT GENERATORS — the main generator occasionally pops one out; it pops a burst of a
# premium "treat" line (the §6.E Farm lines, which are NOT in the main pool, so they appear ONLY here) at
# a head-start tier, for a random number of taps, then VANISHES. Scarce + fleeting (grab it before it's
# gone), no water cost. The treat items merge + sell (the Farm lines carry the later-map sell band), and
# each treat tap also showers a §6.B special drop. PROVISIONAL — sim/owner-tuned.
const TREAT_SPAWN_CHANCE := 0.0           # SHELVED (gen redesign 2026-06-28, task 1): treat gens no longer spawn; lines 71–75 kept for later reuse. (was 0.02)
const TREAT_CLICKS := [4, 9]              # the random tap budget a temp generator lasts [min, max]
# Every premium treat line — sells at TREAT_SELL_BAND and is a valid treat-drop target. The 5 fruit
# treasures are the per-map ACTIVE specials (MAP_TREAT_LINE below). (The Farm lines 61-66 USED to sit here
# as reserve treat content; they were moved into the main pool — wired onto the seed_satchel anchor and
# staged via min_level — so they are normal Farmhouse content now, NOT treats. Sell at the map band.)
const TREAT_LINES := [71, 72, 73, 74, 75]
# §6.D / idea 4.1 — the ONE special treasure line each map's treat generator pops, indexed by map:
# Farm→Prize pumpkin · Orchard→Golden banana · Pond Garden→Jewel avocado · Mill→Ruby cherry ·
# Meadow Gate→Sugar melon. Its themed icon falls out of TREAT_GEN_TEX[map] (same order).
const MAP_TREAT_LINE := [71, 72, 73, 74, 75]
const TREAT_POP_TIER := 2                 # treat items pop at this tier (a head start — "better rewards")
const TREAT_DROP_RATE := 0.5              # each treat tap ALSO drops a §6.B special item this often
const TREAT_SELL_BAND := 3.5              # §6.D premium treat lines sell at this flat band (> SELL_MAP_BAND's 2.8 top) — DIAL
const TREAT_GEN_TEX := [                   # the per-spawn icon (picked at random; the wired treat art)
	"items/generator/gen_seedcart.png", "items/generator/gen_beehive.png",
	"items/generator/gen_lilyfountain.png", "items/generator/gen_applepress.png",
	"items/generator/gen_wildflowerarch.png",
]

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
	# THE PICTURE BOOK (2026-07-18): the world is the five scene PAGES, in play order, replacing the
	# farm maps. Each page renders its generated zone manifest (assets/map/<scene>/page.json —
	# built from the scene-workbench bundles by tools/build_page_manifests.py; re-run it after
	# fine-tuning in `make sw`, then `make import`). Pages are STRICTLY the scene-workbench scenes
	# (decision 2026-07-18): the farmhouse build items no longer ride page 1 — unlockables arrive
	# via the zoning tool + coverings instead. Page 1 (Fairy Hollow, the FTUE anchor) stays the hub;
	# its `spots` list is kept for save-compat only. Pages 2-5 are `open` for book browsing —
	# the frontier gate arrives with the pages build system (recipes/frontier, picturebook spec §9).
	{"id": "fairy_hollow", "name": "Fairy Hollow", "hub": true,
		"page_manifest": "res://games/grove/assets/map/hollow/page.json",
		"covering_frames": [],
		"coverup_mode": true,
		# TOP-DOWN unlock order: the top-of-scene cluster unlocks first. The market canvas is tall and
		# cover-fills the viewport, so its BOTTOM sits behind the bottom nav bar — a bottom-first order
		# hides the one ready lock off-screen. Top-first keeps the next unlockable clearly in view.
		# min_level is NOT data — content.cluster_min_level derives it from the authored SCENE_END_LEVEL
		# band (content._build_cadence), not from this cost ladder.
		# Costs scaled x0.092 from the old ladder (46,740 -> 4,290 coins total) to fit the 25-day
		# calendar (SCENE_END_LEVEL, games/grove/tools/pacing_calc.gd's PRICE CHECK) — 2026-07-26.
		"clusters": [
			{"id": "mushroom_hall", "cost": 1},
			{"id": "tea_stall", "cost": 2},
			{"id": "crystal_map_stall", "cost": 4},
			{"id": "stream_bridge", "cost": 6},
			{"id": "flower_crate", "cost": 10},
			{"id": "lantern_gate", "cost": 15},
		],
		"spots": [
		{"id": "fh_hearth", "name": "Hearth", "kind": "yield", "cost": 3, "pos": Vector2(0.4194, 0.4265)},
		{"id": "fh_kitchen", "name": "Kitchen garden", "kind": "yield", "cost": 3, "pos": Vector2(0.5481, 0.7379)},
		{"id": "fh_well", "name": "Well", "kind": "yield", "cost": 3, "pos": Vector2(0.1574, 0.8778)},
		{"id": "fh_larder", "name": "Larder", "kind": "yield", "cost": 4, "pos": Vector2(0.7454, 0.5065)},
		{"id": "fh_porch", "name": "Porch", "kind": "decor", "cost": 4, "pos": Vector2(0.84, 0.56)},
		{"id": "fh_boxes", "name": "Flower boxes", "kind": "decor", "cost": 4, "pos": Vector2(0.1324, 0.6305)},
		{"id": "fh_lantern", "name": "Lantern post", "kind": "decor", "cost": 5, "pos": Vector2(0.8093, 0.9182)},
	]},
	{"id": "snowy_village", "name": "Snowy Village", "open": true,
		"page_manifest": "res://games/grove/assets/map/winter/page.json",
		"covering_frames": [], "coverup_mode": true,
		# TOP-DOWN unlock order (winter bundle, unlock_ prefix).
		"clusters": [
			{"id": "lodge", "cost": 20},
			{"id": "christmas_tree", "cost": 28},
			{"id": "gazebo", "cost": 37},
			{"id": "dock", "cost": 48},
			{"id": "entrance_arch", "cost": 61},
		],
		"spots": []},
	{"id": "desert_oasis", "name": "Desert Oasis", "open": true,
		"page_manifest": "res://games/grove/assets/map/oasis/page.json",
		"covering_frames": [], "coverup_mode": true,
		# TOP-DOWN unlock order (oasis bundle, lock_ prefix).
		"clusters": [
			{"id": "adobe", "cost": 75},
			{"id": "watchtower", "cost": 92},
			{"id": "market_stall", "cost": 110},
			{"id": "travel_tent", "cost": 133},
			{"id": "caravan", "cost": 161},
		],
		"spots": []},
	{"id": "coral_reef", "name": "Coral Reef", "open": true,
		"page_manifest": "res://games/grove/assets/map/coral/page.json",
		"covering_frames": [], "coverup_mode": true,
		# TOP-DOWN unlock order (coral bundle, unlock_region_ prefix).
		"clusters": [
			{"id": "shipwreck", "cost": 193},
			{"id": "anchor", "cost": 229},
			{"id": "chest", "cost": 271},
			{"id": "statue", "cost": 317},
			{"id": "clam", "cost": 367},
		],
		"spots": []},
	{"id": "sakura", "name": "Cherry-Blossom Garden", "open": true,
		"page_manifest": "res://games/grove/assets/map/sakura/page.json",
		"covering_frames": [], "coverup_mode": true,
		# TOP-DOWN unlock order (sakura bundle, unlock_region_ prefix).
		"clusters": [
			{"id": "pavilion", "cost": 422},
			{"id": "pond_bridge", "cost": 486},
			{"id": "temizuya", "cost": 560},
			{"id": "torii", "cost": 642},
		],
		"spots": []},
	]
	return maps

# (The scatter-covering art `_covering_frames()` + map/<scene>/coverings/ was removed once every
# map row settled on `covering_frames: []` — the coverup LAYER carries locked-region cover now, and
# scene_coverings.scatter() stayed dead. scene_coverings.reveal() is still live for coverup reveals.)

# (The vine-mask overlay `_apply_vine_maps` was retired with the discrete-map / mask-reveal model —
# the home build-and-upgrade redesign renders the layered cut-paper zone instead, spec 2026-07-17.)


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
# (~L26 at 25 spots) lands near the click budget — the whole 5-zone arc in a few weeks of daily play.
# §7 NOTE (2026-06-29): quest exp is now per-line RANK-RAMPED (1.0→2.0 by line) + merger 1.2×, so a quest
# pays ~1.67× more exp per click than the old FLAT model — the live curve's STEP was raised to absorb that
# (else regions unlock ~1.67× too fast). The LIVE curve is economy_tuning.json (base 10 / step 4, re-tuned on
# grove_sim); these consts are only the absent-JSON FALLBACK. RE-TUNE on grove_sim (the pacing sim is the judge).
const LEVEL_BASE_EXP := 40        # FALLBACK first level-up cost — the live value is economy_tuning.json (cheap early)
const LEVEL_STEP_EXP := 3         # FALLBACK per-level ramp — the live step is higher to absorb the §7 exp ramp
# The COIN clock (home redesign): level derives from LIFETIME ORGANIC coin earnings
# (Save.coins_earned_lifetime) through the same gentle arithmetic curve shape.
# Solved by games/grove/tools/pacing_calc.gd's solve mode for the 3/4/5/6/7-day-per-scene
# calendar (25 days total) at 3 sessions/day (2026-07-26). These two dials set the CALENDAR
# ONLY — how long a level takes to earn — not WHERE the gates fall: SCENE_END_LEVEL below is
# the authored gate table, in level-space, independent of this curve.
const LEVEL_BASE_COINS := 1       # first level-up cost, solved for the 25-day calendar
const LEVEL_STEP_COINS := 2       # per-level ramp, solved for the 25-day calendar

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
	"refill_water": {"cap": 1, "cooldown": 1800, "water": WATER_CAP},  # 1/day — a full can (over-cap ok)
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
	var ln: Dictionary = RESIDENT_LINES.get(String(MAPS[z].id), {})
	var spirit: String = String(ln.get("id", ""))
	return {"coins": 120 + 80 * z, "gems": 2 + z, "spirit": spirit}
