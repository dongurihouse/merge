extends RefCounted
## Read/delegate shim over Save (the single persistence owner). Kept so existing callers
## (main.gd, room.gd) work unchanged; all state now lives in Save — progress.cfg is never
## written again (Save reads it once, for migration only).

const Save = preload("res://scripts/save.gd")

static func cleared() -> int:
	return Save.boards_cleared()

static func add_cleared(n: int = 1) -> void:
	Save.record_board_clear(n)
