extends RefCounted
## Home build-and-upgrade progression — PURE logic, no game wiring.
## Spec: docs/superpowers/specs/2026-07-17-home-build-upgrade-map-design.md
## State is a plain Dictionary (make_state); building DEFS, the player level, and the wallet
## are always injected. This module preloads NOTHING — home.gd (the adapter) persists state
## in Save and feeds the live BUILDINGS table + G.level().
##
## A building def: {id, steps: [{cost, min_level, shows}], customizations: [{id, cost, currency}]}
## — `shows` is the art state rendered once that step is PAID; the final step's shows is "built".
## A def may carry `zone` (default "farmhouse"); completing a whole zone unlocks ONE bucket cell.
## State: {built: {id: steps_done}, custom: {id: variant_id}}.

static func make_state() -> Dictionary:
	return {"built": {}, "custom": {}}

static func steps_done(state: Dictionary, id: String) -> int:
	return int(state.built.get(id, 0))

static func is_built(state: Dictionary, def: Dictionary) -> bool:
	return steps_done(state, String(def.id)) >= (def.steps as Array).size()

## The next unpaid step — {index, cost, min_level, shows}; {} once built.
static func next_step(state: Dictionary, def: Dictionary) -> Dictionary:
	if is_built(state, def):
		return {}
	var i := steps_done(state, String(def.id))
	var s: Dictionary = def.steps[i]
	return {"index": i, "cost": int(s.cost), "min_level": int(s.min_level), "shows": String(s.shows)}

## "" = allowed; else the refusal reason: "built" (nothing left) / "level" (gate) / "coins" (price).
## The LEVEL gate is the capacity brake (spec §4): coins alone must never rush a cell-granting build.
static func can_buy_step(state: Dictionary, def: Dictionary, level: int, coins: int) -> String:
	var s := next_step(state, def)
	if s.is_empty():
		return "built"
	if level < int(s.min_level):
		return "level"
	if coins < int(s.cost):
		return "coins"
	return ""

## Advance one step. No wallet knowledge — the adapter spends first, then commits here.
static func buy_step(state: Dictionary, def: Dictionary) -> bool:
	if is_built(state, def):
		return false
	state.built[String(def.id)] = steps_done(state, String(def.id)) + 1
	return true

## The art state this building renders NOW: empty → the last PAID step's `shows` → built,
## with a chosen customization variant overriding a built look.
static func state_id(state: Dictionary, def: Dictionary) -> String:
	var done := steps_done(state, String(def.id))
	if done <= 0:
		return "empty"
	if is_built(state, def):
		var v := String(state.custom.get(String(def.id), ""))
		return v if v != "" else "built"
	return String(def.steps[done - 1].shows)

## Bucket cells earned = ONE per completed ZONE (decision 2026-07-17: each zone unlocks a single
## cell — never a per-building bundle). A zone is complete when EVERY building it carries is built;
## defs group by their `zone` field (default "farmhouse" — today's single-zone world; the picture-book
## pages slot in as zones). A pure re-read (derived, never stored) — the bucket re-syncs from this on
## every access, so a grant can never double-apply.
static func cells_granted(state: Dictionary, defs: Array) -> int:
	var zone_done: Dictionary = {}          # zone -> every building so far built?
	for def in defs:
		var z := String(def.get("zone", "farmhouse"))
		zone_done[z] = bool(zone_done.get(z, true)) and is_built(state, def)
	var total := 0
	for z in zone_done:
		if bool(zone_done[z]):
			total += 1
	return total

## Choose a customization variant — only on a BUILT building, only a variant the def offers.
## Payment is the adapter's job; this is the rules + commit half.
static func set_custom(state: Dictionary, def: Dictionary, variant_id: String) -> bool:
	if not is_built(state, def):
		return false
	for c in def.get("customizations", []):
		if String(c.id) == variant_id:
			state.custom[String(def.id)] = variant_id
			return true
	return false
