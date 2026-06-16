extends RefCounted
## THE PIGGY BANK — the accrual vault (Core §10). A persistent jar that SKIMS a small
## slice of the premium (💎) you EARN at the three play sites — a level-up, a fully
## restored map, a t8 sell — into a banked balance you can release only by paying ONE
## FIXED real-money price. The fill grows with play; the price is fixed — so the longer
## you play, the better the deal (the endowment hook, §10). Cracking grants the banked
## diamonds and resets the jar. It is the friendliest first purchase for a non-payer:
## premium they already earned, released sooner and amplified — squarely the §4 "buys
## speed, never possibility" line (the wallet is only ever ADDED to here, never gated).
##
## PURE engine (core/ layer — no ui/, no scenes/): the skim MATH + the crack live here;
## the balance persists via Save.vault() ({bank, carry}); the OWNER-TUNABLE numbers
## (the skim fraction, the fixed price, the claim threshold) live in the active game's
## data (games/grove/grove_data.gd · VAULT_*). The diegetic jar surface is ui/vault.gd.
##
## The skim is a RATIONAL fraction (num/den) with a carried sub-unit REMAINDER, so a
## skim of many small earns (a 1💎 t8 sell, skim 1/4) accrues honestly instead of
## truncating every small earn to nothing: 4 such sells bank exactly 1💎. The cumulative
## banked total is always floor(total_earned × num/den) — no loss, no over-credit.

const Save = preload("res://engine/scripts/core/save.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const D = Game.DATA                                  # the active game's data (§10 VAULT_*)

# --- the owner-tunable grove numbers (compile-time consts on the active game's DATA) ---
# Read directly off D the same way content.gd reads D.COLS — these live in grove_data.gd's
# VAULT/LOGIN section, so the owner re-tunes the deal there without touching this engine.

## The skim fraction numerator / denominator (e.g. 1/4 = 25% of earned premium is banked).
static func skim_num() -> int:
	return int(D.VAULT_SKIM_NUM)

static func skim_den() -> int:
	return maxi(1, int(D.VAULT_SKIM_DEN))

## The minimum banked balance before the jar may be cracked (an empty pig isn't sold).
static func claim_min() -> int:
	return maxi(0, int(D.VAULT_CLAIM_MIN))

## The single fixed real-money price the crack costs (display string, e.g. "$2.99").
static func price_usd() -> String:
	return String(D.VAULT_PRICE_USD)

## A generous ceiling so the jar art has a "full" state; the bank never exceeds it.
static func cap() -> int:
	return maxi(claim_min(), int(D.VAULT_CAP))

# --- the skim (called at the three earning sites) -----------------------------------

## Bank a slice of `earned` premium. Adds earned×num into the carry pool; every `den`
## carried units convert to 1 whole banked 💎 (the remainder stays carried for next time).
## A skim of 0 / negative is a safe no-op. Clamped to the cap. Persists in one write.
static func skim(earned: int) -> void:
	if earned <= 0:
		return
	var num := skim_num()
	var den := skim_den()
	var bank := Save.vault_bank()
	var carry := Save.vault_carry() + earned * num
	bank += carry / den            # integer division — whole diamonds released
	carry = carry % den            # the sub-unit remainder carries forward
	var c := cap()
	if bank >= c:
		bank = c
		carry = 0                  # at the cap, stop accruing the remainder too
	Save.set_vault(bank, carry)

# --- reads ---------------------------------------------------------------------------

## The banked, claimable diamonds currently in the jar.
static func balance() -> int:
	return Save.vault_bank()

## Whether the jar is full enough to crack (at/above the claim threshold).
static func claimable() -> bool:
	return balance() >= claim_min()

# --- the crack (release + reset) -----------------------------------------------------

## Release the banked diamonds to the wallet and reset the jar to empty. Returns the
## amount granted (0 if empty). The grant + reset happen as ONE persisted step, so a
## crash can never take the bank without paying it out. (The real-money CHARGE is the
## ui/vault.gd confirm-stub's job — this is the grant side, mirroring the shop's cash
## packs: confirming pays out the diamonds directly in this test build.)
static func crack() -> int:
	var got := balance()
	if got <= 0:
		return 0
	Save.add_diamonds(got)         # wallet += banked (persists)
	Save.set_vault(0, 0)           # reset jar + carry (persists)
	return got
