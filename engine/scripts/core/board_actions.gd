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
		var dest := Vector2i(-1, -1)
		for c in board.empty_ground_cells():     # gen redesign: NO board cap — place freely on any open cell
			if not board.gens.has(c):
				dest = c
				break
		if dest == Vector2i(-1, -1):
			board.bag_add(id)                     # board genuinely full → hold it in the bag
			bagged.append(id)
		else:
			board.place_gen(id, dest)
			landed.append(dest)
	return {"due": true, "landed": landed, "bagged": bagged}

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
	for c in board.empty_ground_cells():
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

static func split_twin_cell(board: BoardModel, target: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_dist := 1 << 30
	for cell in board.empty_ground_cells():
		var dist := absi(cell.x - target.x) + absi(cell.y - target.y)
		if dist < best_dist:
			best = cell
			best_dist = dist
	return best

static func can_split_piece(board: BoardModel, from: Vector2i, target: Vector2i) -> bool:
	if from == target or board.is_gen(target):
		return false
	if not is_scissors(board.item_at(from)):
		return false
	if not is_splittable_code(board.item_at(target)):
		return false
	return split_twin_cell(board, target) != Vector2i(-1, -1)

# Split one eligible content piece into two one-tier-lower twins. The scissors source is consumed only
# after every refusal condition has passed, so full-board / tier-1 / invalid-target drops are no-loss.
static func split_piece(board: BoardModel, from: Vector2i, target: Vector2i) -> Dictionary:
	if not can_split_piece(board, from, target):
		return {}
	var src_code := board.item_at(from)
	var target_code := board.item_at(target)
	var twin := split_twin_cell(board, target)
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

static func retire_line(board: BoardModel, bag: Array, gen_id: String, level: int) -> Dictionary:
	var gid := String(gen_id)
	var out := {"retired": false, "line": 0, "coins": 0, "items": 0, "gen_cells": [], "bag": bag}
	if not G.gen_retirable(gid, level):
		return out                                    # still needed by a later craft — refuse
	var line := int(gid.trim_prefix("gen_"))
	out["line"] = line
	var coins := 0
	var items := 0
	# 1. the leftover stock on the BOARD
	for i in board.items.size():
		var code: int = board.items[i]
		if code > 0 and not G.is_coin(code) and BoardModel.line_of(code) == line:
			coins += int(G.sell_reward(code).x)
			items += 1
			board.take(BoardModel.cell_of(i))
	# 2. the leftover stock in the ITEM BAG
	var kept: Array = []
	for code in bag:
		if int(code) > 0 and not G.is_coin(int(code)) and BoardModel.line_of(int(code)) == line:
			coins += int(G.sell_reward(int(code)).x)
			items += 1
		else:
			kept.append(code)
	out["bag"] = kept
	# 3. the generator itself — every copy, on the board and in the gen_bag (the parallel arrays move in lockstep)
	var cells: Array = []
	for cell in board.gens.keys():
		if String(board.gens[cell]) == gid:
			cells.append(cell)
	for cell in cells:
		board.remove_gen(cell)
	out["gen_cells"] = cells
	var kid: Array = []
	var ktier: Array = []
	var kboost: Array = []
	for i in board.gen_bag.size():
		if String(board.gen_bag[i]) == gid:
			continue
		kid.append(board.gen_bag[i])
		ktier.append(board.gen_bag_tiers[i] if i < board.gen_bag_tiers.size() else 1)
		kboost.append(board.gen_bag_boost[i] if i < board.gen_bag_boost.size() else 0)
	board.gen_bag = kid
	board.gen_bag_tiers = ktier
	board.gen_bag_boost = kboost
	if coins > 0:
		Save.add_coins(coins)                         # spendable only — retirement never advances the clock
	out["retired"] = true
	out["coins"] = coins
	out["items"] = items
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
