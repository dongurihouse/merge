extends RefCounted
## Pure rules for Grove board-cell improvements (Soil + Magnet).
## Backend layer: no Save, no scene/UI imports, and no RNG.

const G = preload("res://engine/scripts/core/content.gd")

const KIND_SOIL := "soil"
const KIND_MAGNET := "magnet"

static func is_valid_kind(kind: String) -> bool:
	return kind == KIND_SOIL or kind == KIND_MAGNET

static func cap_for(kind: String) -> int:
	match kind:
		KIND_SOIL:
			return int(G.SOIL_MAX)
		KIND_MAGNET:
			return int(G.MAGNET_MAX)
	return 0

static func soil_build_price(current_count: int) -> int:
	if current_count < 0 or current_count >= int(G.SOIL_MAX):
		return -1
	return int(G.SOIL_BUILD_PRICES[current_count])

static func magnet_build_price(current_count: int) -> int:
	if current_count < 0 or current_count >= int(G.MAGNET_MAX):
		return -1
	return int(G.MAGNET_BUILD_PRICES[current_count])

static func build_price(kind: String, current_count: int) -> int:
	match kind:
		KIND_SOIL:
			return soil_build_price(current_count)
		KIND_MAGNET:
			return magnet_build_price(current_count)
	return -1

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
