extends RefCounted
## The four shared FEEL VERBS — merge / land / launch / move — plus the screen-juice
## helpers (haptic, ripple, board_punch). Each composes the fx.gd primitives and takes an
## `intensity` (0..1) so a surface shares the vocabulary while dialing the strength.
## fx.gd stays the primitive library; scenes call these instead of hand-assembling primitives.

const FX = preload("res://engine/scripts/ui/fx.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")
const Features = preload("res://engine/scripts/core/features.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const Tune = preload("res://engine/scripts/core/tuning.gd").FX

const LEAF := Color("#7FB069")
const STRAW := Color("#E3B23C")
const HOT := Color("#E0592B")

## The merge IMPACT. Composes the primitives the board's _after_merge hand-assembled. At
## intensity=1.0, hitstop_gate=0 it matches the board's prior feel EXCEPT for two deliberate
## spec escalations the unified verb now applies everywhere (so all merges feel consistent):
##   - the flash peak ramps soft->full over tier 1..>=4 (board used to flash flat at every tier);
##   - the burst goes HOT at tier >= MERGE_BURST_HOT_TIER (board capped at STRAW gold).
## `node` is the produced tile; `center`/`host` locate the flash + burst; `tier`/`combo` drive
## the escalation; `intensity` (0..1) dials strength; `hitstop_gate` suppresses the freeze below a combo.
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

## Merge audio pitch: the board's `clampf(0.95 + 0.03*tier, 0.9, 1.3)` tier base, then — when
## merge_combo is on — the MUSICAL PENTATONIC LADDER on top. Each consecutive merge climbs one
## degree of the PENTA scale (degree = the live combo count, which the game increments per merge in
## the streak window and resets when the window lapses), so a streak literally plays a rising
## pentatonic run and snaps back to the base when it breaks. Stateless + deterministic: the degree
## is the combo already handed in, no separate ladder counter or timer. Audio.play applies its own
## jitter on top — the board relied on that, so this returns the plain center pitch.
static func _merge_pitch(tier: int, combo: int) -> float:
	var base := clampf(0.95 + 0.03 * tier, 0.9, 1.3)
	if Features.on("merge_combo"):
		return _ladder_pitch(base, combo)
	return base

## The pure pentatonic ladder: shift `base` up by the PENTA semitone at degree `combo`, clamped to
## the array (a streak past the top sustains the ceiling note). `combo == 0` → degree 0 → PENTA[0]
## (0 semitones) → factor 1.0 → base unchanged. Pure (no scene tree / global state) — unit-tested.
static func _ladder_pitch(base: float, combo: int) -> float:
	var semitones: float = float(Tune.PENTA[clampi(combo, 0, Tune.PENTA.size() - 1)])
	return base * pow(2.0, semitones / 12.0)

## The land IMPACT — a tile that traveled then touched down. ALWAYS does the squash + a small
## dust PUFF (the cheap visual that actually reads a touchdown). `quiet` only suppresses the
## per-tile SOUND, flash, and haptic — so a bulk settle (a Rush gravity column, a generator
## burst) can't fire N touch-sounds + N flashes + N motor pulses at once, while every tile still
## visibly thumps down. Discrete arrivals (fling-land, a single drop) pass quiet=false for the
## full thunk; the caller fires ONE shared sound for a batch. `intensity` (0..1) dials strength.
static func land(host: Node, node: Control, center: Vector2, intensity := 1.0, quiet := false) -> void:
	_land_squash(node)   # the LAND_SQUASH_K impact pose -> rest; calm-gated; null-safe
	if intensity <= 0.0:
		return
	# the dust puff reads the touchdown — fires even on a quiet bulk settle (it's the SOUND we dedupe)
	FX.burst(host, center, LEAF, _land_puff_count(intensity))   # FX.burst calm-trims itself — not pre-applied here
	if quiet:
		return
	# discrete (loud) landing only: the soft flash + touch sound + haptic
	var size := node.size.x if node != null and is_instance_valid(node) else 96.0
	FX.flash(host, center, size, _land_flash_peak(intensity))   # flash self-gates on merge_impact + calm
	Audio.play("tidy_poof", Tune.LAND_TOUCH_DB, 1.0)
	haptic("soft")

## The land squash: set the initial squashed pose then tween through the LAND_SQUASH_K keys to
## rest with TRANS_BACK/EASE_OUT — the 2-key `1.14/0.86 -> 1.0` impact Rush already uses inline.
## Mirrors fx.squash_pop's calm handling: under calm it skips the stretch and does a gentle uniform
## overshoot (SQUASH_CALM) instead, so motion-accessibility holds. No-op on a null/invalid node.
static func _land_squash(node: Control) -> void:
	if not (node and is_instance_valid(node)):
		return
	node.pivot_offset = node.size / 2.0 if node.size.x > 0.0 and node.size.y > 0.0 else node.custom_minimum_size / 2.0
	if FX.calm():
		var c := node.create_tween()
		c.tween_property(node, "scale", Tune.SQUASH_CALM, Tune.LAND_SQUASH_T[0]).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		c.tween_property(node, "scale", Vector2.ONE, Tune.LAND_SQUASH_T[1]).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		return
	node.scale = Tune.LAND_SQUASH_K[0]
	var t := node.create_tween()
	for i in range(1, Tune.LAND_SQUASH_K.size()):
		t.tween_property(node, "scale", Tune.LAND_SQUASH_K[i], Tune.LAND_SQUASH_T[i - 1]).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# --- land pure helpers (no scene tree — unit-tested in feel_tests.gd) ------------------

## Land flash peak: FLASH_PEAK softened by LAND_FLASH_FACTOR, scaled by intensity. 0 at intensity 0.
## Much softer than a merge flash (which ramps the FLASH_PEAK up by tier).
static func _land_flash_peak(intensity: float) -> float:
	return Tune.FLASH_PEAK * Tune.LAND_FLASH_FACTOR * intensity

## Do the discrete extras (flash + puff + touch sound + haptic) fire? Only for a non-quiet
## landing with real strength — a quiet bulk/gravity settle or a zero-intensity land is squash-only.
static func _land_should_emit(intensity: float, quiet: bool) -> bool:
	return not quiet and intensity > 0.0

## Micro-puff particle count: LAND_PUFF_N scaled by intensity (FX.burst applies its own
## calm-trim via amount_for — not pre-applied here). 0 at intensity 0.
static func _land_puff_count(intensity: float) -> int:
	return int(Tune.LAND_PUFF_N * intensity)
## The launch EMIT — an emitter spits a projectile (the generator pops a tile, the Rush board
## flings one). Composes: the emitter's gen_charge RECOIL (the crouch->spring->settle anticipation,
## reused so a "thing was launched" reads the same everywhere) + a muzzle PUFF at the projectile +
## haptic. `emitter` may be null (no discrete emitter node — skip the recoil). The puff is null-safe:
## a freshly-built projectile may not be parented yet. `intensity` (0..1) dials strength; at
## intensity 0 no puff is emitted (recoil still fires).
## The toss SOUND is OPTIONAL (default off): each emitter keeps its OWN spawn sound (the generator's
## water_pop is its identity; the fling's button_tap tick) by playing it itself — the verb owns the
## recoil + puff + haptic, not the audio. Pass a non-empty `sound` only when a caller wants the verb
## to play it instead.
static func launch(emitter: Control, projectile: Control, intensity := 1.0, sound := "", sound_db := Tune.LAUNCH_TOSS_DB, sound_pitch := 1.1) -> void:
	if emitter and is_instance_valid(emitter):
		FX.gen_charge(emitter)                     # emitter recoil (reuse the generator anticipation)
	if intensity > 0.0 and projectile and is_instance_valid(projectile):
		var p := projectile.get_parent()
		if p is Node:
			FX.burst(p, projectile.position + projectile.size / 2.0, LEAF, _launch_puff_count(intensity))   # muzzle puff (FX.burst calm-trims itself)
	if sound != "":
		Audio.play(sound, sound_db, sound_pitch)
	haptic("tick")

# --- launch pure helpers (no scene tree — unit-tested in feel_tests.gd) ----------------

## Muzzle-puff particle count: LAUNCH_PUFF_N scaled by intensity (floored to int); 0 at intensity 0,
## where launch() also skips the puff entirely (FX.burst applies its own calm-trim — not pre-applied here).
static func _launch_puff_count(intensity: float) -> int:
	return int(Tune.LAUNCH_PUFF_N * intensity)
const PieceView = preload("res://engine/scripts/ui/piece_view.gd")

## The MOVE — a tile TRAVELS between two positions, built to sell the ARRIVAL. Returns the primary
## `position` Tween so the caller can chain `Feel.land` on completion (the impact at the destination
## is the point of the trip). `kind`:
##   "slide" — a flat in-cell slide (the merge loser sliding into the winner). Accelerates INTO the
##             hit (EASE_IN), MOVE_SLIDE_T.
##   "arc"   — an up-and-over toss (the Rush fling). Up-leg EASE_OUT (leaves slowly), down-leg EASE_IN
##             (falls into the target). MOVE_ARC_T_UP + MOVE_ARC_T_DOWN. The caller adds any spin.
##   "fall"  — a gravity drop (the Rush spawn fall / column settle). EASE_IN, distance-scaled between
##             MOVE_FALL_T_MIN..MAX. This is the PERF-CRITICAL path (a whole column settles at once),
##             so it gets NO trail and only the cheap constant-offset shadow.
## The ENHANCEMENTS (cast shadow + motion trail + motion-lean) are purely FELT: hard-gated OFF under
## calm AND under headless (see _move_enhance_enabled), and the cast shadow is SKIPPED entirely when
## the node already carries a piece_view ContactShadow (no double shadow). `dur >= 0` overrides timing.
static func move(node: Control, from: Vector2, to: Vector2, kind := "slide", dur := -1.0) -> Tween:
	if not (node and is_instance_valid(node)):
		return null
	node.position = from
	var d := _move_dur(kind, from, to, dur)
	var t := node.create_tween()
	if kind == "arc":
		_move_build_arc(t, node, from, to)
	else:
		t.tween_property(node, "position", to, d).set_trans(Tween.TRANS_QUAD).set_ease(_move_ease(kind))
	# the enhancements ride alongside the primary tween — never block it, never run headless/calm.
	if _move_enhance_enabled():
		var speed := from.distance_to(to) / maxf(d, 0.001)
		_move_shadow(node, from, to, kind, d)
		_move_trail(node, from, to, kind, speed, d)
		_move_lean(node, from, to, kind, d)
	return t

# The arc's two legs: up-and-over (EASE_OUT, leaves slowly) then down-into-target (EASE_IN, accelerates
# into the hit). The peak sits above the higher endpoint, scaled by the horizontal span — the same shape
# the Rush fling hand-rolled. Spin is the caller's (a parallel rotation tween), so it's untouched here.
static func _move_build_arc(t: Tween, node: Control, from: Vector2, to: Vector2) -> void:
	var span := absf(to.x - from.x)
	var lift := maxf(Tune.MOVE_ARC_LIFT_MIN, span * Tune.MOVE_ARC_LIFT_SPAN)
	var peak := Vector2((from.x + to.x) * 0.5, minf(from.y, to.y) - lift)
	t.tween_property(node, "position", peak, Tune.MOVE_ARC_T_UP).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "position", to, Tune.MOVE_ARC_T_DOWN).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

# --- move pure helpers (no scene tree — unit-tested in feel_tests.gd) ------------------

## The shared gate for ALL of cast-shadow / motion-trail / motion-lean: they are purely FELT, so they
## never run under calm (motion accessibility) NOR under headless (no renderer, no felt effect, and a
## per-frame ghost/shadow would only burden the deterministic test clock).
static func _move_enhance_enabled() -> bool:
	return not FX.calm() and DisplayServer.get_name() != "headless"

## Accelerate-INTO-impact easing for the flat kinds: EASE_IN (slow to leave, fastest at the target) for
## slide + fall. (arc builds its own two-leg easing in _move_build_arc and never asks this.)
static func _move_ease(_kind: String) -> int:
	return Tween.EASE_IN

## Travel duration. An explicit `dur >= 0` always wins. Else: slide is a flat MOVE_SLIDE_T; arc is its
## two fixed legs; fall is DISTANCE-SCALED between MOVE_FALL_T_MIN..MAX (a short drop is snappy, a
## full-board drop has weight) — reproducing the Rush fall's `0.10 + dist/(cell*ROWS)*0.24` feel via
## the MOVE_FALL_* dials.
static func _move_dur(kind: String, from: Vector2, to: Vector2, dur := -1.0) -> float:
	if dur >= 0.0:
		return dur
	match kind:
		"arc":
			return Tune.MOVE_ARC_T_UP + Tune.MOVE_ARC_T_DOWN
		"fall":
			var dist := absf(to.y - from.y)
			var f := clampf(dist / Tune.MOVE_FALL_DIST_REF, 0.0, 1.0)
			return lerpf(Tune.MOVE_FALL_T_MIN, Tune.MOVE_FALL_T_MAX, f)
		_:
			return Tune.MOVE_SLIDE_T

## Motion-trail ghost count scaled by SPEED: 0 at a crawl, ramping to MOVE_TRAIL_N at/above
## MOVE_TRAIL_SPEED_REF (a slow settle barely trails; a fast fling smears). Floored to int so a slow
## move makes literally zero ghosts.
static func _move_trail_count(speed: float) -> int:
	var f := clampf(speed / Tune.MOVE_TRAIL_SPEED_REF, 0.0, 1.0)
	return int(f * Tune.MOVE_TRAIL_N)

## Per-KIND trail count — the PERF GUARD. "fall" is shared by the Rush gravity settle, which drops a
## whole COLUMN at once; spawning ghosts per tile across a full settle would tank the frame, so fall
## makes NO trail (0) regardless of speed. slide/arc trail by speed.
static func _move_trail_count_for(kind: String, speed: float) -> int:
	if kind == "fall":
		return 0
	return _move_trail_count(speed)

## Does `node` (or a descendant) already carry a piece_view ContactShadow? Board pieces AND Rush tiles
## both wrap a PieceView holder whose first child is a "ContactShadow" (when item_backing is on), so a
## move-shadow on top would DOUBLE the grounding. When true, move() skips its own cast shadow.
static func _move_has_contact_shadow(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if node.has_node(NodePath(PieceView.SHADOW_NAME)):
		return true
	for ch in node.get_children():
		if _move_has_contact_shadow(ch):
			return true
	return false

# --- move enhancements (scene-tree; only run off-headless, off-calm) -------------------

## A soft cast shadow that follows under the node for the duration of the move — but ONLY for nodes
## that DON'T already cast one (board pieces + Rush tiles carry their own piece_view ContactShadow, so
## they're skipped: no double shadow). For an "arc" the blob shrinks/fades as the tile rises and snaps
## back on land; for slide/fall it's a constant-offset blob. A single ColorRect ellipse — cheap; frees
## itself when the travel ends.
static func _move_shadow(node: Control, from: Vector2, to: Vector2, kind: String, dur: float) -> void:
	if not (node and is_instance_valid(node)) or not node.is_inside_tree():
		return
	var parent := node.get_parent()
	if not (parent is CanvasItem):
		return
	if _move_has_contact_shadow(node):
		return   # already grounded by piece_view — don't double the shadow
	var sz := node.size
	if sz.x <= 0.0 or sz.y <= 0.0:
		sz = node.custom_minimum_size
	var sh := ColorRect.new()
	sh.color = Color(0.05, 0.05, 0.05, Tune.MOVE_SHADOW_ALPHA)
	sh.size = sz * Tune.MOVE_SHADOW_SCALE
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sh.z_index = -1   # under the tile
	(parent as Node).add_child(sh)
	(parent as Node).move_child(sh, 0)   # behind the moving node
	sh.pivot_offset = sh.size * 0.5
	var base_off := Tune.MOVE_SHADOW_OFFSET + (sz - sh.size) * 0.5
	sh.position = from + base_off
	var t := sh.create_tween()
	t.tween_property(sh, "position", to + base_off, dur)   # follow the node along the ground
	if kind == "arc":
		# the blob shrinks + fades as the tile rises, then snaps back as it lands.
		var up := Tune.MOVE_ARC_T_UP
		t.parallel().tween_property(sh, "scale", Vector2(0.6, 0.6), up).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(sh, "modulate:a", 0.4, up).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.chain().tween_property(sh, "scale", Vector2.ONE, Tune.MOVE_ARC_T_DOWN).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(sh, "modulate:a", 1.0, Tune.MOVE_ARC_T_DOWN)
	t.chain().tween_callback(sh.queue_free)

## A cheap motion TRAIL — a few faded afterimage ghosts dropped along the path, each fading out over
## MOVE_TRAIL_T then self-freeing. The ghost count scales with speed (and is 0 for "fall" — the perf
## guard). We snapshot the node's CURRENT look with node.duplicate() ONCE PER GHOST at staggered offsets
## along the straight from->to line (cheap: at most MOVE_TRAIL_N duplicates for the whole move, none on
## a settle). SIMPLIFICATION: the ghosts are placed on the straight chord (not the arc's curve) and
## carry no spin — they read as a faint smear behind a fast fling, which is all the trail is for; a
## per-frame curve-faithful trail would be far heavier on these composite Control subtrees.
static func _move_trail(node: Control, from: Vector2, to: Vector2, kind: String, speed: float, dur: float) -> void:
	if not (node and is_instance_valid(node)) or not node.is_inside_tree():
		return
	var parent := node.get_parent()
	if not (parent is Node):
		return
	var n := _move_trail_count_for(kind, speed)
	if n <= 0:
		return
	for i in n:
		var f := float(i + 1) / float(n + 1)   # spaced strictly between the endpoints
		var ghost := node.duplicate()
		if not (ghost is CanvasItem):
			ghost.free()
			continue
		var g := ghost as Control
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g.modulate = Color(1, 1, 1, Tune.MOVE_TRAIL_ALPHA * (1.0 - f * 0.5))
		g.z_index = node.z_index - 1
		(parent as Node).add_child(g)
		g.position = from.lerp(to, f)
		var t := g.create_tween()
		t.tween_interval(dur * f)            # appear as the node passes this point
		t.tween_property(g, "modulate:a", 0.0, Tune.MOVE_TRAIL_T)
		t.tween_callback(g.queue_free)

## A small MOVE_LEAN_DEG tilt INTO the travel direction, righting on arrival — a body-language cue that
## the tile is moving with intent. SKIPPED for "arc": the fling already owns a ±22° spin and a lean
## would fight it. The tilt sign follows horizontal travel direction.
static func _move_lean(node: Control, from: Vector2, to: Vector2, kind: String, dur: float) -> void:
	if kind == "arc":
		return   # the fling's own spin owns the rotation — don't fight it
	if not (node and is_instance_valid(node)):
		return
	node.pivot_offset = node.size * 0.5 if node.size.x > 0.0 else node.custom_minimum_size * 0.5
	var dir := signf(to.x - from.x)
	if dir == 0.0:
		return   # a pure vertical fall has no lean direction
	var lean := deg_to_rad(Tune.MOVE_LEAN_DEG) * dir
	var t := node.create_tween()
	t.tween_property(node, "rotation", lean, dur * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "rotation", 0.0, dur * 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
## A real handheld VIBRATION pulse — the tactile spine all four verbs already CALL (merge/land/
## launch pass a weight). `weight` picks the pulse length from Tune.HAPTIC_MS. Hard-off when the
## player's "haptics" setting (Settings card) is OFF and under headless (no vibrator, no felt effect,
## and a vibrate would touch a real device input on a test bot). A global THROTTLE (HAPTIC_THROTTLE_MS)
## collapses a burst of near-simultaneous pulses (a settling column firing N lands) into one buzz, so
## the motor never machine-guns. The throttle DECISION is a pure helper (_haptic_allowed) so it unit-tests
## without a vibrator.
static var _last_haptic := -100000
static func haptic(weight := "soft") -> void:
	if not _haptics_enabled() or DisplayServer.get_name() == "headless":
		return
	var now := Time.get_ticks_msec()
	if not _haptic_allowed(now, _last_haptic):
		return
	_last_haptic = now
	Input.vibrate_handheld(_haptic_weight_ms(weight))

# --- haptic pure helpers (no vibrator — unit-tested in feel_tests.gd) ------------------

## The "haptics" player setting (Settings card, default ON), read the same pull-based way FX.calm()
## reads "calm" — so toggling it applies immediately, no caching.
static func _haptics_enabled() -> bool:
	return Save.get_setting("haptics", true)

## Weight -> pulse length (ms) via Tune.HAPTIC_MS, with a 14ms fallback for an unknown weight.
static func _haptic_weight_ms(weight: String) -> int:
	return int(Tune.HAPTIC_MS.get(weight, 14))

## The pure THROTTLE decision: is a pulse allowed at `now_ms` given the last allowed pulse at `last_ms`?
## True when at least HAPTIC_THROTTLE_MS has elapsed (so a rapid burst collapses to one buzz). Passing
## `now`/`last` in keeps it deterministic + testable without the real clock or a vibrator.
static func _haptic_allowed(now_ms: int, last_ms: int) -> bool:
	return now_ms - last_ms >= Tune.HAPTIC_THROTTLE_MS

## The RIPPLE — the up-to-4 orthogonal neighbours of a discrete impact (a merge or a land) jiggle
## OUTWARD from the hit, staggered so the wave reads as travelling. Each neighbour squashes along the
## AXIS pointing away from `impact_center` (RIPPLE_SQUASH * intensity), held briefly, then springs back
## to 1.0 — a SINE in/out so it never snaps. The neighbour list is gathered SCENE-SIDE (the scene owns
## the grid); this verb only animates the nodes it's handed. Hard no-op under calm (motion accessibility),
## and per-neighbour null/invalid-safe (a freed or empty cell is skipped, never errors). Every tween ends
## on Vector2.ONE, so a neighbour can't leak off-scale even if it's interrupted partway by the next ripple
## (create_tween on the SAME node auto-kills the prior one, so a re-rippled neighbour restarts cleanly
## rather than stacking — no scale leak).
static func ripple(neighbors: Array, impact_center: Vector2, intensity := 1.0) -> void:
	if FX.calm():
		return
	var i := 0
	for nb in neighbors:
		if nb == null or not is_instance_valid(nb) or not (nb is Control):
			continue
		var n := nb as Control
		var sz := n.size if n.size.x > 0.0 and n.size.y > 0.0 else n.custom_minimum_size
		n.pivot_offset = sz / 2.0
		var pose := _ripple_pose(n.global_position + sz / 2.0, impact_center, intensity)
		var t := n.create_tween()   # same-node create_tween kills any prior ripple — restarts clean, no stacking
		if i > 0:
			t.tween_interval(i * Tune.RIPPLE_STAGGER_MS / 1000.0)
		t.tween_property(n, "scale", pose, 0.05).set_trans(Tween.TRANS_SINE)
		t.tween_property(n, "scale", Vector2.ONE, 0.08).set_trans(Tween.TRANS_SINE)
		i += 1

# --- ripple pure helper (no scene tree — unit-tested in feel_tests.gd) ----------------

## The squash pose for a neighbour at `nb_center` reacting to an impact at `impact_center`: push the
## scale OFF 1.0 by RIPPLE_SQUASH*intensity along the (abs) direction away from the impact, so a tile to
## the side stretches along X and a tile above/below along Y. A neighbour sitting exactly on the impact
## (zero direction) gets no push (rests at 1.0). Pure — testable without the tween clock.
static func _ripple_pose(nb_center: Vector2, impact_center: Vector2, intensity: float) -> Vector2:
	var dir := (nb_center - impact_center).normalized()
	return Vector2.ONE + dir.abs() * (Tune.RIPPLE_SQUASH * intensity)

## The BOARD PUNCH — a whole-board scale pulse on a BIG merge (tier >= ESCALATE_TIER): the board snaps up
## to 1 + PUNCH*intensity then springs back to 1.0 (a QUAD-out punch, BACK-out settle for a tiny overshoot).
## Reserved for the pinnacle moments only — co-fires with feel.merge's reserved shake there. Returns the
## scale Tween (so a caller could chain) or null when suppressed. Hard no-op under calm + null-safe; the
## settle always lands on Vector2.ONE, so the board can't leak off-scale.
static func board_punch(board: Control, intensity := 1.0) -> Tween:
	if FX.calm() or board == null or not is_instance_valid(board):
		return null
	board.pivot_offset = board.size / 2.0
	var t := board.create_tween()   # same-node create_tween kills any prior punch — no stacking
	t.tween_property(board, "scale", Vector2.ONE * (1.0 + Tune.PUNCH * intensity), Tune.PUNCH_T * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(board, "scale", Vector2.ONE, Tune.PUNCH_T * 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return t
