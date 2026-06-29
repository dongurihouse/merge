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

# Deliver quest `qi` by consuming the tile at `cell`: drop the quest from the live fence, remember
# the asked item (anti-monotony window, ≤5), advance exp (the ONE place exp earns), and pay the coin
# reward. Mutates `board`, `quests`, and `recent_items` in place. Returns the OUTCOME the scene needs
# to render — {code, exp, coins, levels_up, cell} — so the fly-to-giver, reward FX, coin float, and
# Level dialog read facts off one dict instead of recomputing them.
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
	var sp_exp := Quests.exp(q)
	var sp_coins := Quests.coins(q)
	var levels_up := G.earn_exp(sp_exp)           # bumps the single exp total; reports levels gained
	if sp_coins > 0:
		Save.add_coins(sp_coins)                  # §7/§10: the quest coin faucet
	return {"code": code, "exp": sp_exp, "coins": sp_coins, "levels_up": levels_up, "cell": cell}

# Collect the coin at `cell`: take it off the board and credit its value (a stashed collect-reward
# overrides the face value). Returns {got, code} for the fly-to-HUD reward FX.
static func collect_coin(board: BoardModel, cell: Vector2i) -> Dictionary:
	var reward := board.take_collect_reward(cell)
	var code := board.take(cell)
	var got := int(reward.amount) if String(reward.get("kind", "")) == "coins" else G.coin_value(code)
	Save.add_coins(got)
	return {"got": got, "code": code}

# Collect the special drop at `cell` (water / acorn / exp). A stashed collect-reward overrides the
# item's own face reward. acorn + exp write Save here; "water" is RETURNED for the caller to fold into
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
		"exp":
			Save.add_exp(amount)
	return {"kind": String(got.kind), "amount": amount}
