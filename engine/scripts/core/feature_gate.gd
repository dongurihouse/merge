extends RefCounted
## FEATURE GATES — the level at which a feature's RULES go live, and whether the player has
## been SHOWN it. Two independent states; see docs/superpowers/specs/2026-07-29-feature-level-gating-design.md
##
## armed(id)    the level threshold has passed and every extra condition is met
## revealed(id) the teach has completed (persisted in the ftue ledger as "unlock_<id>")
##
## A feature sits ARMED but unrevealed until the board offers the situation its teach needs.
##
## Unknown id → push_warning + FALSE. This is the INVERSE of Features.on(), deliberately: an
## unknown flag must not silently kill a shipped feature, but an unknown GATE must not silently
## leak an ungated one. Fail closed.
##
## core/ layer: imports core/ only.

const G = preload("res://engine/scripts/core/content.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const Features = preload("res://engine/scripts/core/features.gd")
const Bucket = preload("res://engine/scripts/core/bucket.gd")

const LEDGER_PREFIX := "unlock_"

## The features.gd flag each gate rides on. An id absent here has no flag (rush).
const GATE_FLAG := {
	"weather": &"weather_hours",
	"cascade": &"cascade",
	"mastery": &"mastery",
	"soil": &"improvements",
	"magnet": &"improvements",
}

static func ids() -> Array:
	return G.FEATURE_LEVEL.keys()

static func level_for(id: String) -> int:
	return int(G.FEATURE_LEVEL.get(id, 0))

static func armed(id: String) -> bool:
	if not G.FEATURE_LEVEL.has(id):
		push_warning("FeatureGate.armed(\"%s\"): unknown gate — failing CLOSED" % id)
		return false
	if GATE_FLAG.has(id) and not Features.on(String(GATE_FLAG[id])):
		return false
	if G.level() < level_for(id):
		return false
	return _extra(id)

## The per-feature AND terms — every condition shipping before this spec, preserved.
static func _extra(id: String) -> bool:
	match id:
		"weather":
			return Save.ftue_seen("merge") and Save.ftue_seen("gen_tap")
		"soil":
			return Save.board_tutorial_seen()
		"rush":
			return Bucket.cells_total() > 0
	return true

static func revealed(id: String) -> bool:
	return Save.ftue_seen(LEDGER_PREFIX + id)

static func mark_revealed(id: String) -> void:
	Save.mark_ftue_seen(LEDGER_PREFIX + id)
