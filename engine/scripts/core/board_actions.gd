extends RefCounted
## Board ACTIONS — the pure player-action layer. Where board_model.gd owns the primitive
## mutations (take/place/merge) and board_logic.gd owns the stateless decisions (rolls, hints),
## this owns the COMPOSITE state transitions a player action performs: the full sequence of
## model + economy writes that defines what an action DOES to the game. Backend layer:
## STATELESS statics that take the model + save in and return an OUTCOME dict out — no Node /
## Control / Tween / FX. The scene calls these, then renders the returned outcome. Lifted out of
## scenes/board.gd so the RULES are headless-testable (grove_board_actions_tests.gd) — change a
## rule and assert it without instantiating the Board scene.

const G = preload("res://engine/scripts/core/content.gd")
const BoardModel = preload("res://engine/scripts/core/board_model.gd")
const BoardLogic = preload("res://engine/scripts/core/board_logic.gd")
const Improvements = preload("res://engine/scripts/core/improvements.gd")
const Quests = preload("res://engine/scripts/core/quests.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const Mastery = preload("res://engine/scripts/core/mastery.gd")

# Deliver quest `qi` by consuming the tile at `cell`: drop the quest from the live fence, remember
# the asked item (anti-monotony window, ≤5), and pay the COIN reward through the coin clock (the
# quest coin faucet IS the progression clock — coin-clock redesign, spec 2026-07-17). Mutates
# `board`, `quests`, and `recent_items` in place. Returns the OUTCOME the scene needs to render —
# {code, coins, levels_up, cell} — so the fly-to-giver, reward FX, coin float, and Level dialog
# read facts off one dict instead of recomputing them.
static func deliver_quest(board: BoardModel, quests: Array, recent_items: Array, qi: int, cell: Vector2i) -> Dictionary:
	var q: Dictionary = quests[qi]
	var it: Dictionary = G.quest_item(q)
	var has_item := not it.is_empty()
	var code := (int(it.line) * 100 + int(it.tier)) if has_item else 0
	board.take(cell)
	quests.remove_at(qi)                          # §7: the delivered quest leaves the live fence
	if has_item:                                  # only a real ask enters the anti-monotony window
		recent_items.append(code)                 # remember this ask so the next ≤5 quests avoid it
		while recent_items.size() > 5:
			recent_items.pop_front()
	var rank_ups := Mastery.credit_delivery(code) if has_item else {}
	var sp_coins := Quests.coins(q)
	var levels_up := G.earn_coins(sp_coins)       # organic earn — credits the wallet + the clock
	return {"code": code, "coins": sp_coins, "levels_up": levels_up, "cell": cell, "rank_ups": rank_ups}

# Collect the coin at `cell`: take it off the board and credit its value (a stashed collect-reward
# overrides the face value). Returns {got, code} for the fly-to-HUD reward FX.
static func collect_coin(board: BoardModel, cell: Vector2i) -> Dictionary:
	var reward := board.take_collect_reward(cell)
	var code := board.take(cell)
	var got := int(reward.amount) if String(reward.get("kind", "")) == "coins" else G.coin_value(code)
	# THE CLOCK IS QUESTS ONLY (owner call 2026-07-25). Board pickups are spendable, never clock-advancing:
	# they cost no ask, so letting them level the player made progression a by-product of popping, not of
	# delivering. add_coins credits the wallet without touching coins_earned_lifetime.
	Save.add_coins(got)
	return {"got": got, "code": code}

# Collect the special drop at `cell` (water / acorn). A stashed collect-reward overrides the
# item's own face reward. acorn writes Save here; "water" is RETURNED for the caller to fold into
# its live water mirror (a scene field, capped — not a Save currency). Returns {} when nothing collects.
static func collect_special(board: BoardModel, cell: Vector2i) -> Dictionary:
	var got: Dictionary = G.special_collect(board.item_at(cell))
	var reward := board.take_collect_reward(cell)
	if not reward.is_empty():
		got = reward
	if got.is_empty():
		return {}
	board.take(cell)
	var amount := int(got.amount)
	match String(got.kind):
		"acorn":
			Save.add_diamonds(amount)
	return {"kind": String(got.kind), "amount": amount}

# Birth-on-tap placement: the generator the board owes (Quests.due_gen — the anchor self-heals first,
# then the first quest-required gen the player lacks) lands on a free cell, or falls into the bag when
# the board is full. Mutates the model. Returns {due, landed:[cells], bagged:[ids]} for the pop-in render.
static func produce_due_generators(board: BoardModel, quests: Array) -> Dictionary:
	var gid := Quests.due_gen(quests, Quests.owned_gens(board.gens, board.gen_bag))
	if gid == "":
		return {"due": false, "landed": [], "bagged": []}
	var landed: Array = []
	var bagged: Array = []
	for id in [gid]:                              # one owed gen per tap (kept as a loop to mirror the source)
		var kept := _take_kept_gen_state(String(id))
		var tier := int(kept.get("tier", 1))
		var boost := int(kept.get("boost", 0))
		var dest := Vector2i(-1, -1)
		for c in board.empty_auto_gen_cells():   # auto-placement skips improved cells; manual drops may use them
			if not board.gens.has(c):
				dest = c
				break
		if dest == Vector2i(-1, -1):
			board.bag_add(id, tier, boost)        # board genuinely full → hold it in the bag
			bagged.append(id)
		else:
			board.place_gen(id, dest, tier)
			if boost > 0:
				board.arm_gen_boost(dest, boost)
			landed.append(dest)
	return {"due": true, "landed": landed, "bagged": bagged}

static func _take_kept_gen_state(gid: String) -> Dictionary:
	var g := Save.grove()
	var kept: Dictionary = g.get("gen_kept", {})
	var raw: Variant = kept.get(String(gid), [])
	if not (raw is Array) or (raw as Array).is_empty():
		return {"tier": 1, "boost": 0}
	var arr: Array = raw
	kept.erase(String(gid))
	g["gen_kept"] = kept
	Save.grove_write()
	return {
		"tier": clampi(int(arr[0]), 1, G.GEN_TOP_TIER),
		"boost": maxi(0, int(arr[1]) if arr.size() > 1 else 0),
	}

# Gen stranding fix — SELF-DUP (the merge fuel). The duplicate spawns at the LINE's TOP tier
# (top_gen_tier across board+bag) so every self-dup feeds ONE lineage and merges up — no sub-tier strand
# forms, and a maxed line breeds nothing. Lands on a free cell, else the bag. Mutates the model; returns
# {landed, bagged} for the scene's pop-in render (mirrors produce_due_generators).
static func self_dup_generator(board: BoardModel, src: Vector2i) -> Dictionary:
	var dup_id := board.gen_id_at(src)
	if dup_id == "" or G.gen_def(G.GENERATORS, dup_id).is_empty():
		return {"landed": [], "bagged": []}
	var line := int(G.gen_def(G.GENERATORS, dup_id).get("line", 0))
	var tier := board.top_gen_tier(line)
	if tier <= 0 or tier >= G.GEN_TOP_TIER:
		return {"landed": [], "bagged": []}          # maxed line → no merge fuel, no new strand
	for c in board.empty_auto_gen_cells():
		if not board.gens.has(c):
			board.place_gen(dup_id, c, tier)
			return {"landed": [c], "bagged": []}
	if not board.gen_bag.has(dup_id):
		board.bag_add(dup_id, tier)
		return {"landed": [], "bagged": [dup_id]}
	return {"landed": [], "bagged": []}

# #14 the special CODE crafted by dragging two DIFFERENT base lines at the SAME tier together (0 if
# not a recipe, Core §6.G). The special lands at the ingredients' tier, then climbs its own ladder.
static func recipe_merge_code(a_code: int, b_code: int) -> int:
	if a_code <= 0 or b_code <= 0:
		return 0
	var at := a_code % 100
	if at != (b_code % 100):
		return 0
	var special_line := G.special_for_pair(int(a_code / 100.0), int(b_code / 100.0))
	return (special_line * 100 + at) if special_line > 0 else 0

# Craft a special by consuming the source ingredient and replacing the target with the authored special.
# Returns {code, consumed, target, rank_ups}; {} means the pair is not a recipe and nothing was mutated.
static func apply_recipe(board: BoardModel, from: Vector2i, target: Vector2i) -> Dictionary:
	var a_code := board.item_at(from)
	var b_code := board.item_at(target)
	var code := recipe_merge_code(a_code, b_code)
	if code <= 0:
		return {}
	board.take(from)
	board.place(target, code)
	return {
		"code": code,
		"consumed": a_code,
		"target": target,
		"rank_ups": Mastery.credit_craft(a_code, b_code),
	}

static func is_scissors(code: int) -> bool:
	return G.special_kind(code) == "scissors"

static func is_splittable_code(code: int) -> bool:
	if code <= 0 or code % 100 < 2:
		return false
	var line := int(code / 100.0)
	return G.LINES.has(line) and not G.TREAT_LINES.has(line)

# Where the twin lands: the empty ground cell nearest the target (Manhattan, ties broken by board scan
# order), else `freed` — the scissors' own cell, which board.take(from) empties a beat before the twin
# is placed. That LAST-RESORT cell is what lets a COMPLETELY FULL board split: consuming the scissors
# frees exactly the one cell the twin needs, so the drop no longer refuses for want of a cell that the
# action itself creates. It stays OUT of the nearest search on purpose — a board with any other free
# cell places the twin exactly where it always did, and the cell the player dragged from still empties.
# It only counts when it would really be open ground (in bounds, unsealed, not a generator, not the
# target), so a drop that frees nothing still refuses. Pure — no RNG draw.
static func split_twin_cell(board: BoardModel, target: Vector2i, freed: Vector2i = Vector2i(-1, -1)) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_dist := 1 << 30
	for cell in board.empty_ground_cells():
		var dist := absi(cell.x - target.x) + absi(cell.y - target.y)
		if dist < best_dist:
			best = cell
			best_dist = dist
	if best == Vector2i(-1, -1) and freed != target and board.is_open(freed) and not board.is_gen(freed):
		return freed
	return best

static func can_split_piece(board: BoardModel, from: Vector2i, target: Vector2i) -> bool:
	if from == target or board.is_gen(target):
		return false
	if not is_scissors(board.item_at(from)):
		return false
	if not is_splittable_code(board.item_at(target)):
		return false
	return split_twin_cell(board, target, from) != Vector2i(-1, -1)

# Split one eligible content piece into two one-tier-lower twins. The scissors source is consumed only
# after every refusal condition has passed, so tier-1 / invalid-target / nowhere-to-land drops are no-loss.
static func split_piece(board: BoardModel, from: Vector2i, target: Vector2i) -> Dictionary:
	if not can_split_piece(board, from, target):
		return {}
	var src_code := board.item_at(from)
	var target_code := board.item_at(target)
	var twin := split_twin_cell(board, target, from)
	if twin == Vector2i(-1, -1):
		return {}
	var lowered := int(target_code) - 1
	board.take(from)
	board.place(target, lowered)
	board.place(twin, lowered)
	return {"code": lowered, "consumed": src_code, "target": target, "twin_cell": twin}

# --- §6 LINE RETIREMENT (2026-07-25) -----------------------------------------------------------------
# Clear a line the game will never ask for again (G.gen_retirable): its generator leaves the board AND the
# gen_bag, and every leftover item of that line — on the board and in the item bag — is sold. Guarded on
# the same forward-looking predicate the offer uses, so a line that still feeds a later craft can never be
# retired out from under the player (lines 2/3/4 go dormant and come back as ingredients).
#
# The generator goes AWAY, not into the bag: the bag is the board's pressure-relief valve (§5, 6 slots to
# start, premium-priced to grow), so parking dead tools there would tax the live loop and make retirement
# read as a punishment.
#
# `bag` is the scene's item bag (board_model owns only gen_bag), passed in and returned filtered so the
# whole decision stays a pure, headless-testable static. Returns
#   {retired, line, coins, items, gen_cells, bag}
# — items = how many pieces were sold, gen_cells = board cells freed (for the scene's poof).
## What retiring `line` would clear, WITHOUT mutating: {pieces, coins} over the board AND the item bag.
## THE ONE payout read — the offer card, the info-bar sell label and retire_line itself all price the same
## way, so the number shown can never differ from the number paid.
static func retire_preview(board: BoardModel, bag: Array, line: int) -> Dictionary:
	var pieces := 0
	var coins := 0
	for i in board.items.size():
		var code: int = board.items[i]
		if code > 0 and not G.is_coin(code) and BoardModel.line_of(code) == int(line):
			pieces += 1
			coins += int(G.sell_reward(code).x)
	for c in bag:
		if int(c) > 0 and not G.is_coin(int(c)) and BoardModel.line_of(int(c)) == int(line):
			pieces += 1
			coins += int(G.sell_reward(int(c)).x)
	return {"pieces": pieces, "coins": coins}
# --- §6 LINE FAREWELLS (2026-07-26) -------------------------------------------------------------------
# A line receives a farewell when it has BOARD presence but is outside the current zone's recursive need
# closure. The bag is not presence here: it is the hoard path, and bagged generators/items stay player-held
# without forcing a ceremony. Returning lines come back through the existing due_gen birth-on-tap path.

static func farewells_due(board: BoardModel, level: int) -> Array:
	var present := {}
	for code in board.items:
		var c := int(code)
		if c <= 0 or G.is_coin(c):
			continue
		var line := BoardModel.line_of(c)
		if G.zone_of_line(line) >= 0:
			present[line] = true
	for gid_v in board.gens.values():
		var gid := String(gid_v)
		var line := int(G.gen_def(G.GENERATORS, gid).get("line", 0))
		if line > 0 and G.zone_of_line(line) >= 0:
			present[line] = true
	var out: Array = []
	var z := G.quest_zone_for_level(int(level))
	for zi in G.ZONE_COUNT:
		var line := G.zone_line(int(zi))
		if present.has(line) and not G.line_needed_at_zone(line, z):
			out.append({"line": line, "next_need": G.next_need(line, int(level))})
	return out

static func farewell_preview(board: BoardModel, line: int) -> Dictionary:
	var ln := int(line)
	var out := {"line": ln, "pieces": 0, "coins": 0, "gens": 0, "gen_cells": []}
	if G.zone_of_line(ln) < 0:
		return out
	var coins := 0
	var pieces := 0
	for i in board.items.size():
		var code: int = board.items[i]
		if code > 0 and not G.is_coin(code) and BoardModel.line_of(code) == ln:
			coins += int(G.sell_reward(code).x)
			pieces += 1
	var gid := G.gen_for_line(ln)
	var cells: Array = []
	var keep_tier := 1
	var keep_boost := 0
	if gid != "":
		for cell in board.gens.keys():
			if String(board.gens[cell]) == gid:
				var tier := board.gen_tier_at(cell)
				var boost := board.gen_boost_at(cell)
				if tier > keep_tier or (tier == keep_tier and boost > keep_boost):
					keep_tier = tier
					keep_boost = boost
				cells.append(cell)
	out["pieces"] = pieces
	out["coins"] = coins
	out["gens"] = cells.size()
	out["gen_cells"] = cells
	out["keep_tier"] = keep_tier
	out["keep_boost"] = keep_boost
	return out

static func sweep_line(board: BoardModel, line: int) -> Dictionary:
	var ln := int(line)
	var out := farewell_preview(board, ln)
	if G.zone_of_line(ln) < 0:
		return out
	for i in board.items.size():
		var code: int = board.items[i]
		if code > 0 and not G.is_coin(code) and BoardModel.line_of(code) == ln:
			board.take(BoardModel.cell_of(i))
	var gid := G.gen_for_line(ln)
	var cells: Array = out.get("gen_cells", [])
	for cell_v in cells:
		var cell := Vector2i(cell_v)
		board.remove_gen(cell)
	var keep_tier := int(out.get("keep_tier", 1))
	var keep_boost := int(out.get("keep_boost", 0))
	if gid != "":
		if keep_tier > 1 or keep_boost > 0:
			var g := Save.grove()
			var kept: Dictionary = g.get("gen_kept", {})
			kept[gid] = [keep_tier, keep_boost]
			g["gen_kept"] = kept
	var coins := int(out.get("coins", 0))
	if coins > 0:
		Save.add_coins(coins)                         # spendable only — farewell sweep never advances the clock
	elif gid != "" and (keep_tier > 1 or keep_boost > 0):
		Save.grove_write()
	return out

# Gen stranding fix — SELL a redundant generator (one that has a strictly-higher same-line sibling, so the
# line keeps its top producer). Guarded: a non-redundant generator is refused. Removes it from the model and
# credits GEN_SELL_COINS. Returns {sold, coins} for the scene's poof + coin float.
static func sell_generator(board: BoardModel, cell: Vector2i) -> Dictionary:
	if not board.is_redundant_gen(cell):
		return {"sold": false, "coins": 0}
	var coins := G.gen_sell_coins(board.gen_tier_at(cell))
	board.remove_gen(cell)
	if coins > 0:
		Save.add_coins(coins)                     # spendable only — SELLING NEVER ADVANCES THE CLOCK (quests only)
	return {"sold": true, "coins": coins}

static func place_seed(board: BoardModel, cell: Vector2i) -> Dictionary:
	return {"placed": board.place_seed(cell)}

static func unsocket_improvement(board: BoardModel, cell: Vector2i) -> Dictionary:
	var row := board.improvement_at(cell)
	var kind := String(row.get("kind", ""))
	if not Improvements.is_valid_kind(kind) or board.item_at(cell) != 0:
		return {"unsocketed": false}
	var price := Improvements.unsocket_price(kind)
	if price.x > 0:
		if not Save.spend(price.x, "improvement"):
			return {"unsocketed": false, "price": price}
	if price.y > 0:
		if not Save.spend_diamonds(price.y):
			return {"unsocketed": false, "price": price}
	var out := board.unsocket_improvement(cell)
	if out.is_empty():
		if price.x > 0:
			Save.add_coins(price.x)
		if price.y > 0:
			Save.add_diamonds(price.y)
		return {"unsocketed": false, "price": price}
	out["unsocketed"] = true
	out["price"] = price
	return out

static func rank_soil(board: BoardModel, cell: Vector2i) -> Dictionary:
	var row := board.improvement_at(cell)
	if String(row.get("kind", "")) != Improvements.KIND_SOIL:
		return {"ranked": false, "price": -1}
	var price := Improvements.soil_rank_price(int(row.get("rank", 1)))
	if price < 0:
		return {"ranked": false, "price": price}
	if not Save.spend(price, "improvement"):
		return {"ranked": false, "price": price}
	return {"ranked": board.rank_soil(cell), "price": price}

static func water_soil(board: BoardModel, cell: Vector2i, now: float) -> Dictionary:
	return {"watered": board.apply_water_to_soil(cell, now)}

static func finish_soil(board: BoardModel, cell: Vector2i, now: float) -> Dictionary:
	if not board.is_growing(cell):
		return {"finished": false, "cost": 0}
	var cost := Improvements.finish_cost(board.soil_remaining(cell, now))
	if not Save.spend_diamonds(cost):
		return {"finished": false, "cost": cost}
	return {"finished": board.finish_soil_now(cell, now), "cost": cost}

static func magnet_merge_once(board: BoardModel, magnet_cell: Vector2i, asked_codes: Dictionary = {}, growing_cells: Array = [], chain_cell: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	if chain_cell != Vector2i(-1, -1):
		return {"merged": false, "reason": "chain"}
	var row := board.improvement_at(magnet_cell)
	if String(row.get("kind", "")) != Improvements.KIND_MAGNET:
		return {"merged": false, "reason": "missing"}
	var pairs := BoardLogic.range_pairs(board, Improvements.range_cells(board, magnet_cell))
	for pair in pairs:
		var a: Vector2i = pair[0]
		var b: Vector2i = pair[1]
		var code := board.item_at(a)
		if asked_codes.has(code) or growing_cells.has(a) or growing_cells.has(b):
			continue
		var da := (a - magnet_cell).length_squared()
		var db := (b - magnet_cell).length_squared()
		var target := a
		var source := b
		if db < da or (db == da and BoardModel.idx(b) < BoardModel.idx(a)):
			target = b
			source = a
		var produced := board.merge(source, target)
		return {"merged": true, "from": source, "to": target, "code": produced}
	return {"merged": false, "reason": "none"}
