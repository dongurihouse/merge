extends RefCounted
## Claims — the FREE daily-faucet engine (§4/§10 "an optional faucet — free, capped").
##
## Every claim here is an OPT-IN, player-initiated "tap → a small bonus": NO interstitials,
## NO cost, NO gates (forced friction would break the cozy bed, §1/§9). Each surface is
## CAPPED (a per-type daily cap) AND COOLDOWNED (a per-type minimum gap), persisted via Save's
## claim ledger, so a faucet never becomes the optimal grind — it BUYS SPEED, never
## POSSIBILITY (the §4 line): every wall it eases is already passable for free, slower.
##
## The grove's caps / cooldowns / reward sizes are OWNER-TUNABLE in the active game's
## DATA (games/grove/grove_data.gd → CLAIMS). This file is the theme-agnostic logic only.
##
## LAYERING: this is a core/ leaf — it imports ONLY core/ (Save, Game). It must never
## reach up into ui/ or scenes/ (the layering guard asserts this). So claim() applies the
## effects it can do PURELY (grant 💎 via Save) and RETURNS a result dict for the effects the
## caller must apply in its own layer — chiefly the water refill (board state lives in
## scenes/board.gd, and a refill may carry the player OVER the cap, so the caller adds it).

const Game = preload("res://engine/scripts/core/game.gd")
const Save = preload("res://engine/scripts/core/save.gd")

const D = Game.DATA

# This claim type's tuning row from the active game's DATA (cap / cooldown / reward).
# Unknown id → an empty row (cap 0 / cooldown 0 → treated as "no such faucet": can_show false).
static func _def(kind: String) -> Dictionary:
	return D.CLAIMS.get(kind, {})

static func cap(kind: String) -> int:
	return int(_def(kind).get("cap", 0))

static func cooldown(kind: String) -> float:
	return float(_def(kind).get("cooldown", 0.0))

# Whether `kind` may be offered right now: it must be a real surface AND under its
# daily cap AND past its cooldown (Save owns the ledger). Pure read.
static func can_show(kind: String) -> bool:
	if not D.CLAIMS.has(kind):
		return false
	return Save.claim_can_show(kind, cap(kind), cooldown(kind))

# How many claims of this type remain today (cap − used, floored at 0).
static func remaining_today(kind: String) -> int:
	return maxi(0, cap(kind) - Save.claim_used_today(kind))

# Claim a free faucet. Re-checks the gate (so a stale UI press can't over-grant), records
# the claim, applies the pure side effects, and returns a result the caller acts on:
#   {"ok": false}                              — refused (capped / cooling / unknown)
#   {"ok": true, "kind": "refill_water", "water": N}
#        → the CALLER adds N to its water (board state; this layer can't touch it). The grant
#          is ADDITIVE and may carry the player OVER the cap (the can banks a little spare).
#   {"ok": true, "kind": "free_gems", "gems": N}  → +N 💎 already granted via Save.
static func claim(kind: String) -> Dictionary:
	if not can_show(kind):
		return {"ok": false}
	var def := _def(kind)
	# Resolve the reward FIRST, then record the claim. Recording before the match would burn a
	# daily-cap slot for an in-DATA-but-unhandled type (the `_:` arm) without granting anything.
	var result: Dictionary
	match kind:
		"refill_water":
			# Water lives on the board (scenes/), not in Save — hand the full-can target back up.
			result = {"ok": true, "kind": kind, "water": int(def.get("water", 0))}
		"free_gems":
			# The persistent "Free" stall faucet (§4/§10): tap → a small 💎 grant, capped + cooled.
			# Granted PURELY here (premium lives in Save); the caller plays the reward FX.
			var fg := int(def.get("gems", 0))
			if fg > 0:
				Save.add_diamonds(fg)
			result = {"ok": true, "kind": kind, "gems": fg}
		_:
			return {"ok": false}
	Save.claim_record(kind)
	return result
