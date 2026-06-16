extends RefCounted
## THE FTUE feature-spotlight MECHANISM (Core §14 / T28) — game-agnostic logic.
## Static singleton (like Features/Save): no scene presence, resolves in headless `-s`
## runs. Two halves:
##   1. the first-appearance GATE — should_spotlight(id) is true iff the flag is ON and
##      the feature has never been spotlit; mark_spotlit(id) records it (persisted), so a
##      feature is announced exactly ONCE, ever. "No feature appears unannounced" (§14).
##   2. the game's REGISTRY readers — which features get spotlit, in what staged order, and
##      the gesture (tap/drag) each teaches. The DATA lives in the active game
##      (games/<name>/*_data.gd → G.SPOTLIGHTS); this engine logic just reads it, so a
##      different game ships its own table with the SAME shape.
##
## The presentation (veil + pulse + mimed hand) is ui/spotlight_overlay.gd; the scenes
## (board/map) call should_spotlight() at a feature's first appearance and, if true, show
## the overlay and mark_spotlit(). The merge verb is NOT registered here — the idle hint
## teaches it (§14).

const Features = preload("res://engine/scripts/core/features.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const G = preload("res://engine/scripts/core/content.gd")

const DEFAULT_GESTURE := "tap"   # a feature with no declared gesture mimes a tap

# --- the first-appearance gate ----------------------------------------------------

## True iff the spotlight mechanism is ON (the §11 flag) AND `feature_id` has never been
## spotlit. The scene calls this the instant a feature first appears; a true result means
## "announce it now". Always false once the flag is off — the whole mechanism disables.
static func should_spotlight(feature_id: String) -> bool:
	if not Features.on("ftue_feature_spotlight"):
		return false
	return not Save.spotlight_seen(feature_id)

## Record that `feature_id` has been spotlit (persisted), so it is never announced again.
## Idempotent — re-marking a seen feature is a no-op (Save dedupes).
static func mark_spotlit(feature_id: String) -> void:
	Save.mark_spotlight_seen(feature_id)

# --- the game's spotlight registry (read from G.SPOTLIGHTS) ------------------------

## The full registry entry for `feature_id` ({} if the game doesn't spotlight it).
static func entry_for(feature_id: String) -> Dictionary:
	for e in G.SPOTLIGHTS:
		if String(e.get("id", "")) == feature_id:
			return e
	return {}

## The gesture the overlay mimes for `feature_id`: "tap" or "drag" (§14). Falls back to a
## tap for an unregistered/incomplete feature so a typo can't leave the guide gesture-less.
static func gesture_for(feature_id: String) -> String:
	var e := entry_for(feature_id)
	var g := String(e.get("gesture", DEFAULT_GESTURE))
	return g if g == "tap" or g == "drag" else DEFAULT_GESTURE

## The wordless one-liner the overlay may caption for `feature_id` ("" if none). The
## caller wraps it in tr() (every string ships translatable, §13).
static func label_for(feature_id: String) -> String:
	return String(entry_for(feature_id).get("label", ""))

## The staged order the game teaches its features in (§14: "one at a time over the early
## levels") — the ids of G.SPOTLIGHTS in declaration order. The merge verb is absent (the
## idle hint teaches it).
static func feature_order() -> Array:
	var out: Array = []
	for e in G.SPOTLIGHTS:
		out.append(String(e.get("id", "")))
	return out
