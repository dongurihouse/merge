extends RefCounted
## Ads — the REWARDED-AD engine (§4/§10 "an optional faucet — rewarded-ONLY").
##
## Every ad here is an OPT-IN, player-initiated "watch → a bonus": NO interstitials,
## NO forced ads (forced ads would break the cozy bed, §1/§9). Each surface is CAPPED
## (a per-type daily cap) AND COOLDOWNED (a per-type minimum gap), persisted via Save's
## ad ledger, so an ad never becomes the optimal grind — it BUYS SPEED, never
## POSSIBILITY (the §4 line): every wall it eases is already passable for free, slower.
##
## The grove's caps / cooldowns / reward sizes are OWNER-TUNABLE in the active game's
## DATA (games/grove/grove_data.gd → ADS). This file is the theme-agnostic logic only.
##
## THE AD ITSELF IS A STUB in this build — there is no ad network wired. The UI plays an
## honest little confirm ("test build — no ad network") and then calls claim(); the real
## SDK hookup (load → show → on-reward callback, geo-flagged) replaces ONLY the play
## middle, exactly like the cash-pack confirm in shop.gd. Nothing else here changes.
##
## LAYERING: this is a core/ leaf — it imports ONLY core/ (Save, Game). It must never
## reach up into ui/ or scenes/ (the layering guard asserts this). So claim() applies the
## effects it can do PURELY (grant 💎 via Save, advance the shop rotation seed) and RETURNS
## a result dict for the effects the caller must apply in its own layer — chiefly the water
## refill (board state lives in scenes/board.gd) and the board quest-reward 2× doubler.

const Game = preload("res://engine/scripts/core/game.gd")
const Save = preload("res://engine/scripts/core/save.gd")

const D = Game.DATA

# The known ad surfaces (also the keys of DATA.ADS). Exposed so callers/tests can
# enumerate without reaching into the data module.
const TYPES := ["refill_water", "collect_2x", "shop_reroll", "event_topup", "free_gems"]

# This ad type's tuning row from the active game's DATA (cap / cooldown / reward).
# Unknown id → an empty row (cap 0 / cooldown 0 → treated as "no such ad": can_show false).
static func _def(ad_type: String) -> Dictionary:
	return D.ADS.get(ad_type, {})

static func cap(ad_type: String) -> int:
	return int(_def(ad_type).get("cap", 0))

static func cooldown(ad_type: String) -> float:
	return float(_def(ad_type).get("cooldown", 0.0))

# Whether `ad_type` may be offered right now: it must be a real surface AND under its
# daily cap AND past its cooldown (Save owns the ledger). Pure read.
static func can_show(ad_type: String) -> bool:
	if not D.ADS.has(ad_type):
		return false
	return Save.ad_can_show(ad_type, cap(ad_type), cooldown(ad_type))

# How many watches of this type remain today (cap − used, floored at 0).
static func remaining_today(ad_type: String) -> int:
	return maxi(0, cap(ad_type) - Save.ad_used_today(ad_type))

# Seconds until this type is watchable again (0 if ready now). For a gentle "ready
# soon" read — never a punitive countdown.
static func cooldown_left(ad_type: String) -> float:
	return Save.ad_cooldown_left(ad_type, cooldown(ad_type))

# Claim a rewarded ad (called AFTER the stub/SDK reports the reward earned). Re-checks
# the gate (so a stale UI press can't over-grant), records the watch, applies the pure
# side effects, and returns a result the caller acts on:
#   {"ok": false}                              — refused (capped / cooling / unknown)
#   {"ok": true, "kind": "refill_water", "water": N}
#        → the CALLER sets its water to N (board state; this layer can't touch it).
#   {"ok": true, "kind": "collect_2x"}
#        → the watch is recorded (capped/cooled); the board quest-reward doubler grants the
#          doubled coins itself. No currency granted here, no hub-yield flag armed.
#   {"ok": true, "kind": "shop_reroll"}        → the Shop rotation seed was advanced.
#   {"ok": true, "kind": "event_topup", "gems": N}  → +N 💎 already granted via Save.
static func claim(ad_type: String) -> Dictionary:
	if not can_show(ad_type):
		return {"ok": false}
	Save.ad_record(ad_type)
	var def := _def(ad_type)
	match ad_type:
		"refill_water":
			# Water lives on the board (scenes/), not in Save — hand the target back up.
			return {"ok": true, "kind": ad_type, "water": int(def.get("water", 0))}
		"collect_2x":
			# The board quest-reward doubler's faucet — it only needs the watch recorded + an ok
			# (it doubles the reward itself). No hub-yield arming: the hub-collect that read the
			# flag was removed (residents replace the hub yield), so nothing consumes a flag now.
			return {"ok": true, "kind": ad_type}
		"shop_reroll":
			# Advance the deterministic Shop rotation (same seam T40's `shop_reroll` uses).
			bump_shop_reroll()
			return {"ok": true, "kind": ad_type}
		"event_topup":
			# A small premium grant (the "event" context is stubbed for now, §17).
			var gems := int(def.get("gems", 0))
			if gems > 0:
				Save.add_diamonds(gems)
			return {"ok": true, "kind": ad_type, "gems": gems}
		"free_gems":
			# The persistent "Free" rail faucet (§4/§10): watch → a small 💎 grant, capped + cooled.
			# Granted PURELY here (premium lives in Save); the caller plays the reward FX.
			var fg := int(def.get("gems", 0))
			if fg > 0:
				Save.add_diamonds(fg)
			return {"ok": true, "kind": ad_type, "gems": fg}
		_:
			return {"ok": false}

# --- the shop-reroll seam ---------------------------------------------------------
# Advance the saved rotation counter the Shop's rotation_seed() adds on top of the day
# index (T40 added the `shop_reroll` key) — so a free reroll slides the featured band
# to a fresh window. Kept here so the ad path and any future "reroll" button share it.
static func bump_shop_reroll() -> void:
	var g := Save.grove()
	g["shop_reroll"] = int(g.get("shop_reroll", 0)) + 1
	Save.grove_write()
