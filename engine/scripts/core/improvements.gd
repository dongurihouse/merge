extends RefCounted
## Pure rules for Grove board-cell improvements (Soil + Magnet).
## Backend layer: no Save, no scene/UI imports, and no RNG.

const G = preload("res://engine/scripts/core/content.gd")

const KIND_SOIL := "soil"
const KIND_MAGNET := "magnet"
const SEED_SOIL_LINE := 14
const SEED_MAGNET_LINE := 15
const SEED_SOIL_CODE := SEED_SOIL_LINE * 100 + 1
const SEED_MAGNET_CODE := SEED_MAGNET_LINE * 100 + 1

static func is_valid_kind(kind: String) -> bool:
	return kind == KIND_SOIL or kind == KIND_MAGNET

static func cap_for(kind: String) -> int:
	match kind:
		KIND_SOIL:
			return int(G.SOIL_MAX)
		KIND_MAGNET:
			return int(G.MAGNET_MAX)
	return 0

static func seed_code_for_kind(kind: String) -> int:
	match kind:
		KIND_SOIL:
			return SEED_SOIL_CODE
		KIND_MAGNET:
			return SEED_MAGNET_CODE
	return 0

static func seed_line_for_kind(kind: String) -> int:
	var code := seed_code_for_kind(kind)
	return int(code / 100.0) if code > 0 else 0

static func kind_for_seed(code: int) -> String:
	if code % 100 != 1:
		return ""
	match int(code / 100.0):
		SEED_SOIL_LINE:
			return KIND_SOIL
		SEED_MAGNET_LINE:
			return KIND_MAGNET
	return ""

static func is_seed(code: int) -> bool:
	return kind_for_seed(code) != ""

static func seed_sell_reward(kind: String) -> Vector2i:
	match kind:
		KIND_SOIL:
			return Vector2i(int(G.SOIL_SEED_SELL_COINS), 0)
		KIND_MAGNET:
			return Vector2i(int(G.MAGNET_SEED_SELL_COINS), 0)
	return Vector2i.ZERO

static func unsocket_price(kind: String) -> Vector2i:
	match kind:
		KIND_SOIL:
			return Vector2i(int(G.SOIL_UNSOCKET_PRICE), 0)
		KIND_MAGNET:
			return Vector2i(0, int(G.MAGNET_UNSOCKET_ACORNS))
	return Vector2i.ZERO

static func blocked_seed_drop_lines(board, bag: Array) -> Array:
	var blocked: Array = []
	for kind in [KIND_SOIL, KIND_MAGNET]:
		var line := seed_line_for_kind(kind)
		if line <= 0:
			continue
		if board != null and board.improvement_count(kind) >= cap_for(kind):
			blocked.append(line)
			continue
		var has_unplaced := false
		if board != null:
			for code in board.items:
				if kind_for_seed(int(code)) == kind:
					has_unplaced = true
					break
		if not has_unplaced:
			for code in bag:
				if kind_for_seed(int(code)) == kind:
					has_unplaced = true
					break
		if has_unplaced:
			blocked.append(line)
	return blocked

static func soil_rank_price(current_rank: int) -> int:
	if current_rank < 1 or current_rank >= int(G.SOIL_MAX_RANK):
		return -1
	return int(G.SOIL_RANK_PRICES[current_rank - 1])

static func is_soil_eligible(code: int) -> bool:
	if code <= 0:
		return false
	if G.is_coin(code) or G.is_collectable(code):
		return false
	return int(code % 100) < int(G.merge_top(code))

static func soil_step_seconds(code: int, rank: int) -> float:
	if not is_soil_eligible(code):
		return 0.0
	var tier := clampi(int(code % 100), 1, G.SOIL_STEP_SECONDS.size())
	var secs := float(G.SOIL_STEP_SECONDS[tier - 1])
	if rank >= 2:
		secs *= 0.70
	return secs

static func grow_amount(rank: int) -> int:
	return 2 if rank >= 3 else 1

static func finish_cost(remaining_secs: float) -> int:
	return maxi(1, int(ceil(maxf(0.0, remaining_secs) / 1800.0)))

static func normalize_activity(raw: Dictionary) -> Dictionary:
	var kind := String(raw.get("kind", ""))
	var rank := clampi(int(raw.get("rank", 1)), 1, int(G.SOIL_MAX_RANK))
	if kind == KIND_MAGNET:
		rank = 1
	return {
		"kind": kind,
		"rank": rank,
		"code": maxi(0, int(raw.get("code", 0))),
		"ends_at": maxf(0.0, float(raw.get("ends_at", 0.0))),
		"watered": bool(raw.get("watered", false)),
	}

static func apply_water(activity: Dictionary, now: float) -> Dictionary:
	var out := normalize_activity(activity)
	if bool(out.watered) or int(out.code) <= 0 or float(out.ends_at) <= now:
		return out
	var remaining := float(out.ends_at) - now
	out["ends_at"] = now + remaining * 0.5
	out["watered"] = true
	return out

static func range_cells(board, magnet_cell: Vector2i) -> Array:
	var out: Array = []
	for dr in range(-1, 2):
		for dc in range(-1, 2):
			var cell := magnet_cell + Vector2i(dr, dc)
			if board.in_bounds(cell) and board.is_open(cell):
				out.append(cell)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return board.idx(a) < board.idx(b))
	return out
