extends RefCounted
## Tidy Up — EconConfig: the SINGLE source of every coin number. Pure static funcs, no state.
## Numbers are PLACEHOLDERS until the economy is playtested + frozen (the R1/economy-lock step).

# Clearing a job pays a base + a bonus per extra star (★ clear · ★★ goals · ★★★ clean/no-undo).
static func clear_payout(stars: int, first_clear: bool) -> int:
	if first_clear:
		return 40 + maxi(0, stars - 1) * 20      # 40 / 60 / 80
	return 5 * maxi(1, stars)                     # replay trickle: 5 / 10 / 15

# Cost of the next decoration slot in a room (used by the room/reveal milestone).
static func room_slot_cost(slot_index: int) -> int:
	return int(round(120.0 * pow(1.22, slot_index)))   # ~120, 146, 178, 218, ...
