extends RefCounted
## The four shared FEEL VERBS — merge / land / launch / move — plus the screen-juice
## helpers (haptic, ripple, board_punch). Each composes the fx.gd primitives and takes an
## `intensity` (0..1) so a surface shares the vocabulary while dialing the strength.
## fx.gd stays the primitive library; scenes call these instead of hand-assembling primitives.

const FX = preload("res://engine/scripts/ui/fx.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")
const Features = preload("res://engine/scripts/core/features.gd")
const Tune = preload("res://engine/scripts/core/tuning.gd").FX

const LEAF := Color("#7FB069")
const STRAW := Color("#E3B23C")
const HOT := Color("#E0592B")

## The merge IMPACT. Composes the primitives that the board's _after_merge hand-assembled,
## reproducing its feel exactly at intensity=1.0, hitstop_gate=0. `node` is the produced tile;
## `center`/`host` locate the flash + burst; `tier`/`combo` drive the escalation; `intensity`
## (0..1) lets a surface dial the strength; `hitstop_gate` suppresses the freeze below a combo.
static func merge(host: Node, node: Control, center: Vector2, tier: int, combo: int, intensity := 1.0, hitstop_gate := 0) -> void:
	# squash & stretch on the produced tile + a white flash — the chosen "C" feel. Mirrors the
	# board's merge_impact gate: squash+flash when on, else fall back to a plain pop.
	if Features.on("merge_impact"):
		FX.squash_pop(node)
		var size := node.size.x if node != null and is_instance_valid(node) else 96.0
		FX.flash(host, center, size, _merge_flash_peak(tier, intensity))   # flash self-gates on merge_impact + calm
	else:
		FX.pop(node)
	# reserved big-moment shake — only at the pinnacle tiers, gated as the board did.
	if Features.on("big_moment_shake") and tier >= Tune.ESCALATE_TIER:
		FX.shake(host)
	FX.burst(host, center, _merge_color(tier), _merge_burst_count(tier, combo, intensity))
	var hs := _merge_hitstop(tier, combo, intensity, hitstop_gate)
	if hs > 0.0:
		FX.hitstop(minf(hs, Tune.HITSTOP_MAX))     # the "thunk" — no-op in headless / calm
	Audio.play(_merge_sound(tier), -1.0, _merge_pitch(tier, combo))
	haptic(_merge_weight(tier))

# --- pure helpers (no scene tree — unit-tested in feel_tests.gd) ----------------------

## Burst colour: tier<4 LEAF green, 4..7 STRAW gold, >= MERGE_BURST_HOT_TIER (8) HOT.
static func _merge_color(tier: int) -> Color:
	if tier >= Tune.MERGE_BURST_HOT_TIER:
		return HOT
	return STRAW if tier >= 4 else LEAF

## Pick "merge_success" for the big sounds (tier>=4), "merge_soft" for the small ones.
static func _merge_sound(tier: int) -> String:
	return "merge_success" if tier >= 4 else "merge_soft"

## Haptic weight ladder: heavy at the big-moment tier, firm at 4..7, soft below.
static func _merge_weight(tier: int) -> String:
	if tier >= Tune.ESCALATE_TIER:
		return "heavy"
	return "firm" if tier >= 4 else "soft"

## Flash peak: FLASH_PEAK ramped soft->full over tier 1..>=4, scaled by intensity. 0 at intensity 0.
static func _merge_flash_peak(tier: int, intensity: float) -> float:
	var ramp: Array = Tune.MERGE_FLASH_TIER_RAMP
	return Tune.FLASH_PEAK * float(ramp[clampi(tier - 1, 0, ramp.size() - 1)]) * intensity

## Hitstop duration. Reproduces the board: base = HITSTOP_MERGE + HITSTOP_TIER_BONUS*(tier-1),
## OVERRIDDEN to HITSTOP_BIG at the big-moment tier (a flat hold, not the formula), plus a
## per-combo bonus above the gate; below the gate the freeze is zero. Capped at HITSTOP_MAX,
## scaled by intensity. (Board passes gate 0 -> always fires, tier-scaled — today's feel.)
static func _merge_hitstop(tier: int, combo: int, intensity: float, gate: int) -> float:
	if combo < gate:
		return 0.0
	var base := Tune.HITSTOP_MERGE + Tune.HITSTOP_TIER_BONUS * maxf(0.0, tier - 1)
	if Features.on("big_moment_shake") and tier >= Tune.ESCALATE_TIER:
		base = Tune.HITSTOP_BIG   # big-moment override, matching the board's `hit = HITSTOP_BIG`
	base += Tune.MERGE_HITSTOP_COMBO_BONUS * maxf(0.0, combo - gate)
	return clampf(base, 0.0, Tune.HITSTOP_MAX) * intensity

## Burst particle count: the board's `10 + tier*3` curve + the big-moment bonus (tier>=ESCALATE_TIER)
## + the live-streak combo bonus (merge_combo), scaled by intensity. Feature-gated exactly as the
## board assembled it. FX.burst applies calm-trimming (amount_for) itself — not pre-applied here.
static func _merge_burst_count(tier: int, combo: int, intensity: float) -> int:
	var n := 10 + tier * 3
	if Features.on("big_moment_shake") and tier >= Tune.ESCALATE_TIER:
		n += Tune.BIG_BURST_BONUS
	if Features.on("merge_combo"):
		n += Tune.COMBO_BURST_BONUS
	return int(n * intensity)

## Merge audio pitch: the board's `clampf(0.95 + 0.03*tier, 0.9, 1.3)` base, plus the combo
## climb (COMBO_PITCH_STEP per milestone passed, clamped to COMBO_PITCH_MAX) when merge_combo is on.
## Audio.play applies its own jitter on top — the board relied on that, so this returns the plain pitch.
static func _merge_pitch(tier: int, combo: int) -> float:
	var pitch := clampf(0.95 + 0.03 * tier, 0.9, 1.3)
	if Features.on("merge_combo"):
		pitch = clampf(pitch + Tune.COMBO_PITCH_STEP * _combo_milestones_passed(combo), 0.9, Tune.COMBO_PITCH_MAX)
	return pitch

## How many COMBO_MILESTONES thresholds the streak has reached (drives the pitch nudge).
## Replicates board.gd's _combo_milestones_passed so the verb owns the same logic.
static func _combo_milestones_passed(count: int) -> int:
	var k := 0
	for m in Tune.COMBO_MILESTONES:
		if count >= int(m):
			k += 1
	return k
static func land(host: Node, node: Control, center: Vector2, intensity := 1.0) -> void:
	pass
static func launch(emitter: Control, projectile: Control, intensity := 1.0) -> void:
	pass
static func move(node: Control, from: Vector2, to: Vector2, kind := "slide", dur := -1.0) -> Tween:
	return null
static func haptic(weight := "soft") -> void:
	pass
static func ripple(neighbors: Array, impact_center: Vector2, intensity := 1.0) -> void:
	pass
static func board_punch(board: Control, intensity := 1.0) -> void:
	pass
