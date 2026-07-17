extends RefCounted
## The Save-backed adapter over the PURE home build module (home_build.gd) — the ONLY
## game-facing build API (the bucket.gd pattern). Wallet + level live here; every rule lives
## in the module. State persists under Save.grove()["home"]; the live building DEFS come from
## the active game's data (D.BUILDINGS). Bucket cells are DERIVED from completed buildings
## (cells_total) on every access — never stored.
## Spec: docs/superpowers/specs/2026-07-17-home-build-upgrade-map-design.md

const Save = preload("res://engine/scripts/core/save.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const G = preload("res://engine/scripts/core/content.gd")
const HB = preload("res://engine/scripts/core/home_build.gd")

static func defs() -> Array:
	return Game.DATA.BUILDINGS

static func def_of(id: String) -> Dictionary:
	for d in defs():
		if String(d.id) == id:
			return d
	return {}

## The live persisted state (module shape) — created on first access.
static func state() -> Dictionary:
	var g := Save.grove()
	if not g.has("home"):
		g["home"] = HB.make_state()
		Save.grove_write()
	return g["home"]

static func steps_done(id: String) -> int:
	return HB.steps_done(state(), id)

static func is_built(id: String) -> bool:
	return HB.is_built(state(), def_of(id))

static func state_id(id: String) -> String:
	return HB.state_id(state(), def_of(id))

static func next_step(id: String) -> Dictionary:
	return HB.next_step(state(), def_of(id))

## Bucket cells earned so far — the sum over COMPLETED buildings (the only capacity source).
static func cells_total() -> int:
	return HB.cells_granted(state(), defs())

## Buy the next build step of `id`: gate through the module (level + price), spend, commit.
## Outcome: {ok, reason, built, levels_up} — `reason` "" | "built" | "level" | "coins";
## `built` flips true on the completing step (the scene celebrates + the bucket grows).
static func buy_step(id: String) -> Dictionary:
	var d := def_of(id)
	var st := state()
	var reason := HB.can_buy_step(st, d, G.level(), Save.coins())
	if reason != "":
		return {"ok": false, "reason": reason, "built": HB.is_built(st, d)}
	var step := HB.next_step(st, d)
	if not Save.spend(int(step.cost), "home_build"):
		return {"ok": false, "reason": "coins", "built": false}
	HB.buy_step(st, d)
	Save.grove_write()
	return {"ok": true, "reason": "", "built": HB.is_built(st, d)}

## Buy + apply a customization variant (coins or diamonds per the def). Outcome mirrors buy_step.
static func buy_custom(id: String, variant_id: String) -> Dictionary:
	var d := def_of(id)
	var st := state()
	if not HB.is_built(st, d):
		return {"ok": false, "reason": "built"}
	for c in d.get("customizations", []):
		if String(c.id) != variant_id:
			continue
		var cost := int(c.cost)
		var paid: bool
		if String(c.get("currency", "coins")) == "diamonds":
			paid = Save.spend_diamonds(cost)
		else:
			paid = Save.spend(cost, "home_custom")
		if not paid:
			return {"ok": false, "reason": "coins"}
		HB.set_custom(st, d, variant_id)
		Save.grove_write()
		return {"ok": true, "reason": ""}
	return {"ok": false, "reason": "variant"}
