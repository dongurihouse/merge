extends RefCounted
## THE TEACH REGISTRY — one ordered spec array, two derived readers.
##
## This replaces board.gd's hand-maintained pair (_hand_hint_eligible / _hand_hint_ledger_complete),
## whose own comment warned: "a new teach added there and forgotten here is short-circuited before
## eligibility ever runs — it silently never appears, with no error and no failing test."
## Both readers now derive from the SAME array, so they cannot disagree.
##
## A spec:
##   id      the teach's name, and the hand-hint id the scene tracks
##   ledger  the Save.ftue_seen key; several ids may share one (soil_seed covers soil_place)
##   gate    Callable() -> bool — is the feature armed? (FeatureGate.armed, usually)
##   ready   Callable() -> bool — does the board offer this teach's situation RIGHT NOW?
##   rects   Callable() -> Array — [source_rect, target_rect], or [] when a node is missing
##   gesture HandHint.GESTURE_DRAG or GESTURE_TAP
##
## ui/ layer: imports core/ and ui/ only, never scenes/. The specs come FROM the scene.

const Save = preload("res://engine/scripts/core/save.gd")

## The first spec that is unseen AND armed AND ready. "" when none can fire.
static func eligible(specs: Array) -> String:
	for s in specs:
		if not (s is Dictionary):
			continue
		var spec: Dictionary = s
		if Save.ftue_seen(String(spec.get("ledger", ""))):
			continue
		var gate: Callable = spec.get("gate", Callable())
		if gate.is_valid() and not bool(gate.call()):
			continue
		var ready: Callable = spec.get("ready", Callable())
		if ready.is_valid() and not bool(ready.call()):
			continue
		return String(spec.get("id", ""))
	return ""

## Every spec's ledger key is seen — "no teach can possibly be live".
## LEDGER-ONLY BY CONTRACT: board.gd calls this on every board mutation before its frame await,
## so this must never invoke ready() or otherwise scan the board.
static func complete(specs: Array) -> bool:
	for s in specs:
		if not (s is Dictionary):
			continue
		if not Save.ftue_seen(String((s as Dictionary).get("ledger", ""))):
			return false
	return true

## The spec with this id, or {} — the scene's lookup for gesture + rects once eligible() has chosen.
static func spec_for(specs: Array, id: String) -> Dictionary:
	for s in specs:
		if s is Dictionary and String((s as Dictionary).get("id", "")) == id:
			return s
	return {}
