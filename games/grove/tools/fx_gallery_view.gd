@tool
extends "res://games/grove/tools/workbench_view.gd"
## FX Workbench — every motion/juice component in one gallery.
##
## `make fx-workbench` opens this. Left column: the six FEEL VERBS — the four board verbs (land · merge ·
## launch · move), the grab highlight, and the Expedition's screen juice. Right column: the shared reward
## FLIGHT (Coin Flow). CLICK an element to select it; the sidebar then holds that element's toggles,
## knobs, and a ▶ trigger to feel it. Every saved knob is read by the GAME (`{Land,Merge,…}Fx.from_config`,
## `RushFx`, `FX.reward_fx_*`) out of the SAME settings file the UI workbench writes — Save writes only
## these ids and leaves the UI workbench's components untouched.
##
## The gallery/sidebar/persistence framework is the shared base (workbench_view.gd).

const PieceView = preload("res://engine/scripts/ui/piece_view.gd")     # merge pieces for the demo stages

const IDS := ["rush_fx", "land_fx", "merge_fx", "launch_fx", "move_fx", "grab_fx", "fx"]
# LEFT column: the feel verbs, one per row. RIGHT column: the reward flight (a tall preview of its own).
const COLUMNS := [
	[["land_fx"], ["merge_fx"], ["launch_fx"], ["move_fx"], ["grab_fx"], ["rush_fx"]],
	[["fx"]],
]
const TEST_KEYS := {
	"rush_fx": [],          # every key is a saved toggle (no preview-only state)
	# the feel-verb testers — every toggle + knob is saved (read by {Land,Merge,Launch,Move}Fx.from_config).
	"land_fx": [],
	# merge_fx: tier/combo drive the escalation in the preview but are NOT saved (the game passes the live tier/combo).
	"merge_fx": ["tier", "combo"],
	"launch_fx": [],
	# move_fx: `kind` (slide/arc/fall) picks the preview travel; the game passes the live kind, so it is NOT saved.
	"move_fx": ["kind"],
	"grab_fx": [],   # every toggle + knob is saved (read by GrabFx.from_config)
	"fx": [],        # the reward flight round-trips through FX.reward_fx_* (see _save_extras), not this block
}
const CAPTIONS := {
	"fx": "Coin Flow — reward arrivals in board, map, and home context",
	"rush_fx": "Rush FX — screen juice for the Expedition: toggle each effect, Replay to feel it, save (the game honours it)",
	"land_fx": "Land feel — a tile touches down (incl. the player's drop into an empty cell): squash · puff · flash · sound · haptic · neighbour ripple. Toggle + tune, ▶ to feel it, save (the game honours it).",
	"merge_fx": "Merge feel — two tiles fuse: squash · flash · hitstop · burst · shake · sound · ripple · punch. Toggle + tune, ▶ to feel it, save (the game honours it).",
	"launch_fx": "Launch feel — a generator emits a tile: recoil · muzzle puff · toss sound. Toggle + tune, ▶ to feel it, save (the game honours it).",
	"move_fx": "Move feel — a tile travels (slide · arc · fall): cast shadow · motion trail · motion lean. Toggle + tune, ▶ to feel it, save (the game honours it).",
	"grab_fx": "Grab feel — a tile is picked up: soft glow halo · white silhouette outline · light haptic tap. Toggle + tune, ▶ to feel it, save (the game honours it).",
}

const FX = preload("res://engine/scripts/ui/fx.gd")
const RushFx = preload("res://engine/scripts/ui/rush_fx.gd")           # the toggleable Rush screen-juice effects
const LandFx = preload("res://engine/scripts/ui/land_fx.gd")           # the toggleable Land (touchdown) feel
const MergeFx = preload("res://engine/scripts/ui/merge_fx.gd")         # the toggleable Merge (fuse) feel
const LaunchFx = preload("res://engine/scripts/ui/launch_fx.gd")       # the toggleable Launch (emit) feel
const MoveFx = preload("res://engine/scripts/ui/move_fx.gd")           # the toggleable Move (travel) feel
const GrabFx = preload("res://engine/scripts/ui/grab_fx.gd")           # the toggleable Grab (pickup) highlight
const ComboBloom = preload("res://engine/scripts/ui/combo_bloom.gd")   # the shared persistent combo-bloom overlay
const FxWorkbenchView = preload("res://games/grove/tools/fx_workbench_view.gd")
# per-effect knob slider specs for the rush_fx inspector: effect id → [[param, lo, hi], …]
const RUSH_FX_KNOBS := {
	"merge_burst": [["merge_burst_count", 4, 40]],
	"score_tick": [["score_tick_ms", 80, 600]],
	"score_pulse": [["score_pulse_pct", 40, 180]],
	"mult_pop": [["mult_pop_pct", 40, 180]],
	"combo_heat": [["combo_heat_size", 18, 60]],
	"timer_low": [["timer_low_secs", 3, 20]],
	"treefall_crack": [["treefall_debris", 4, 40], ["treefall_shake", 0, 40], ["treefall_hitstop_ms", 0, 160]],
}
var _rush_fx_ctx: Dictionary = {}
# per-effect knob slider specs for the feel-verb inspectors: effect id → [[param, lo, hi], …] (mirror the standalone _KNOBS_FOR).
const LAND_FX_KNOBS := {
	"squash": [["squash_pct", 0, 200], ["squash_ms", 60, 600]],
	"puff":   [["puff_count", 0, 30]],
	"flash":  [["flash_pct", 0, 100]],
	"sound":  [["sound_db", -24, 0]],
	"haptic": [],
	"ripple": [["ripple_pct", 0, 100]],
}
const MERGE_FX_KNOBS := {
	"squash":      [],
	"flash":       [["flash_pct", 0, 100]],
	"hitstop":     [["hitstop_ms", 0, 120]],
	"burst":       [["burst_count", 0, 60]],
	"shake":       [["shake_amp", 0, 20]],
	"sound":       [["pitch_base_pct", 80, 160]],
	"ripple":      [["ripple_pct", 0, 100]],
	"board_punch": [["punch_pct", 0, 100]],
	"world_puff":  [["puff_count", 0, 20], ["puff_size_pct", 40, 300]],
	"combo_words": [["words_size", 16, 60]],
	"combo_bloom": [["bloom_pct", 0, 200]],
}
const LAUNCH_FX_KNOBS := {
	"recoil": [["recoil_pct", 0, 200]],
	"puff":   [["puff_count", 0, 30]],
	"sound":  [["sound_db", -24, 0]],
}
const MOVE_FX_KNOBS := {
	"shadow": [["shadow_alpha_pct", 0, 60]],
	"trail":  [["trail_count", 0, 8]],
	"lean":   [["lean_deg", 0, 20]],
}
const GRAB_FX_KNOBS := {
	"glow":    [["glow_pct", 0, 200]],
	"outline": [["outline_w", 0, 12], ["outline_a", 0, 100]],
	"haptic":  [],
}
const MoveFx_KINDS := ["slide", "arc", "fall"]   # the move preview's travel kinds (preview-only; the game passes the live kind)
var _land_fx_ctx: Dictionary = {}
var _merge_fx_ctx: Dictionary = {}
var _grab_fx_ctx: Dictionary = {}
var _launch_fx_ctx: Dictionary = {}
var _move_fx_ctx: Dictionary = {}
## --- the element set this workbench owns (the base framework reads these) ------------------------

## The reward-flight block is owned by FX itself (it round-trips through FX.set_reward_fx_*), not by
## the params buckets — write its live config rather than the placeholder param block.
func _save_extras(out: Dictionary) -> void:
	out["fx"] = FX.reward_fx_config()

# merge_fx defaults = the registry defaults PLUS the preview-only escalation sliders (tier/combo, not saved).
static func _merge_fx_defaults() -> Dictionary:
	var d := MergeFx.defaults()
	d["tier"] = 3
	d["combo"] = 0
	return d

# move_fx defaults = the registry defaults PLUS the preview-only KIND selector (slide/arc/fall, not saved).
static func _move_fx_defaults() -> Dictionary:
	var d := MoveFx.defaults()
	d["kind"] = "slide"
	return d

var _fx_selected := "coin_pickup"
# --- the FOUR feel-verb stages (ported from the standalone {land,merge,launch,move}_workbench_view) ---
# Each builds a parchment field with a clickable generator / tile / field that TRIGGERS the verb's play
# function, stores its node refs in a per-component ctx member (rebuilt fresh on every slider change via
# _apply_edit → _make_element, exactly like _rush_fx_ctx), and reads the LIVE _params[id] when it fires —
# so a knob change takes effect on the next trigger without a manual rebuild.
const FEEL_INK := Color("#43352B")
const FEEL_PARCH := Color("#F3E7CE")
const FEEL_CSZ := 116.0                       # the demo tile / cell size in the gallery (compact)
const FEEL_FIELD := Vector2(440, 540)         # the parchment field, compact for the gallery cell

## A parchment field backdrop sized FEEL_FIELD, with clip off so bursts/shadows spill freely.
func _feel_field() -> Control:
	var field := Control.new()
	field.custom_minimum_size = FEEL_FIELD
	field.size = FEEL_FIELD
	field.clip_contents = false
	var card := ColorRect.new()
	card.color = FEEL_PARCH
	card.size = FEEL_FIELD
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.add_child(card)
	return field

## A faint cell marker (rounded inset square) centred at `center`, field-local.
func _feel_cell_marker(center: Vector2) -> Panel:
	var cell := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(FEEL_INK.r, FEEL_INK.g, FEEL_INK.b, 0.06)
	sb.set_corner_radius_all(16)
	sb.set_border_width_all(3)
	sb.border_color = Color(FEEL_INK.r, FEEL_INK.g, FEEL_INK.b, 0.18)
	cell.add_theme_stylebox_override("panel", sb)
	cell.size = Vector2(FEEL_CSZ, FEEL_CSZ)
	cell.position = center - Vector2(FEEL_CSZ, FEEL_CSZ) / 2.0
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return cell

# --- LAND: click the generator → a tile flies down + LANDS in the cell ------------------------
func _land_fx_preview() -> Control:
	var gen_pos := Vector2(FEEL_FIELD.x * 0.5, 120.0)
	var land_pos := Vector2(FEEL_FIELD.x * 0.5, FEEL_FIELD.y - 150.0)
	var field := _feel_field()
	field.add_child(_feel_cell_marker(land_pos))
	var gbtn := Button.new()
	gbtn.flat = true
	gbtn.size = Vector2(FEEL_CSZ, FEEL_CSZ)
	gbtn.position = gen_pos - Vector2(FEEL_CSZ, FEEL_CSZ) / 2.0
	gbtn.set_meta("wb_active", true)              # stays clickable despite the gallery's select-on-click
	var gart := PieceView.make_generator("seed_satchel", FEEL_CSZ)
	gart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gbtn.add_child(gart)
	field.add_child(gbtn)
	var hint := _feel_hint("Click the generator ↑ — or ▶ Drop", gen_pos + Vector2(-90, FEEL_CSZ / 2.0 + 6))
	field.add_child(hint)
	_land_fx_ctx = {"field": field, "gen_pos": gen_pos, "land_pos": land_pos, "tile": null}
	gbtn.pressed.connect(_land_fx_play)
	return field

# Drop a fresh tile from the generator, accelerate into the impact, then fire LandFx.apply at touchdown.
func _land_fx_play() -> void:
	if _land_fx_ctx.is_empty():
		return
	var c := _land_fx_ctx
	var field: Control = c["field"]
	if not (field != null and is_instance_valid(field)):
		return
	if c.get("tile") != null and is_instance_valid(c["tile"]):
		c["tile"].queue_free()
	var tile := PieceView.make_piece(102, FEEL_CSZ)
	var gen_top: Vector2 = c["gen_pos"] - Vector2(FEEL_CSZ, FEEL_CSZ) / 2.0
	var land_top: Vector2 = c["land_pos"] - Vector2(FEEL_CSZ, FEEL_CSZ) / 2.0
	tile.position = gen_top
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.add_child(tile)
	c["tile"] = tile
	var tw := tile.create_tween()
	tw.tween_property(tile, "position", land_top, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		LandFx.apply(field, tile, c["land_pos"], _params["land_fx"]))

# --- GRAB: click the tile → it lights up (glow + white rim + a tap), then settles -------------
func _grab_fx_preview() -> Control:
	var tile_pos := Vector2(FEEL_FIELD.x * 0.5, FEEL_FIELD.y * 0.5)
	var field := _feel_field()
	field.add_child(_feel_cell_marker(tile_pos))
	var tbtn := Button.new()
	tbtn.flat = true
	tbtn.size = Vector2(FEEL_CSZ, FEEL_CSZ)
	tbtn.position = tile_pos - Vector2(FEEL_CSZ, FEEL_CSZ) / 2.0
	tbtn.set_meta("wb_active", true)              # stays clickable despite the gallery's select-on-click
	var tile := PieceView.make_piece(102, FEEL_CSZ)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tbtn.add_child(tile)
	field.add_child(tbtn)
	var hint := _feel_hint("Click the tile — or ▶ Grab", tile_pos + Vector2(-70, FEEL_CSZ / 2.0 + 6))
	field.add_child(hint)
	_grab_fx_ctx = {"field": field, "tile": tile}
	tbtn.pressed.connect(_grab_fx_play)
	return field

# Light the preview tile up with the LIVE grab_fx toggles/knobs, then drop the highlight after a beat so
# it reads as a pickup-then-settle the designer can feel. Mirrors the board: grab() on, release() on drop.
func _grab_fx_play() -> void:
	if _grab_fx_ctx.is_empty():
		return
	var tile: Control = _grab_fx_ctx.get("tile")
	if not (tile != null and is_instance_valid(tile)):
		return
	GrabFx.release(tile)                          # clear any prior preview highlight first (idempotent)
	GrabFx.grab(tile, _params["grab_fx"])
	tile.pivot_offset = tile.size / 2.0
	tile.scale = Vector2(1.12, 1.12)             # the same lift pop the board uses on pickup
	var tw := tile.create_tween()
	tw.tween_property(tile, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: GrabFx.release(tile))

# --- MERGE: click the field → tile A slides into tile B + the two FUSE ------------------------
func _merge_fx_preview() -> Control:
	var merge_pos := Vector2(FEEL_FIELD.x * 0.5 + 60.0, FEEL_FIELD.y * 0.5)
	var src_pos := Vector2(FEEL_FIELD.x * 0.5 - 130.0, FEEL_FIELD.y * 0.5)
	var nb_off := [Vector2(0, -FEEL_CSZ + 6), Vector2(0, FEEL_CSZ - 6), Vector2(-FEEL_CSZ + 6, 0), Vector2(FEEL_CSZ - 6, 0)]
	var field := _feel_field()
	var bloom := ComboBloom.new()
	field.add_child(bloom)
	field.add_child(_feel_cell_marker(merge_pos))
	field.add_child(_feel_cell_marker(src_pos))
	var mbtn := Button.new()                       # the whole field is clickable → merge
	mbtn.flat = true
	mbtn.size = FEEL_FIELD
	mbtn.position = Vector2.ZERO
	mbtn.mouse_filter = Control.MOUSE_FILTER_PASS
	mbtn.set_meta("wb_active", true)
	field.add_child(mbtn)
	var hint := _feel_hint("Click the field — or ▶ Merge", Vector2(40, 40))
	field.add_child(hint)
	_merge_fx_ctx = {"field": field, "merge_pos": merge_pos, "src_pos": src_pos, "nb_off": nb_off,
		"tile_a": null, "tile_b": null, "neighbors": [], "bloom": bloom}
	_merge_fx_spawn()
	mbtn.pressed.connect(_merge_fx_play)
	return field

# (Re)spawn the two matching tiles + the four dummy neighbours at their start cells.
func _merge_fx_spawn() -> void:
	if _merge_fx_ctx.is_empty():
		return
	var c := _merge_fx_ctx
	var field: Control = c["field"]
	if not (field != null and is_instance_valid(field)):
		return
	for n in c["neighbors"]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	c["neighbors"] = []
	for k in ["tile_a", "tile_b"]:
		if c.get(k) != null and is_instance_valid(c[k]):
			c[k].queue_free()
	for off in c["nb_off"]:
		var nb := PieceView.make_piece(201, FEEL_CSZ)
		nb.position = (c["merge_pos"] + off) - Vector2(FEEL_CSZ, FEEL_CSZ) / 2.0
		nb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		field.add_child(nb)
		c["neighbors"].append(nb)
	var b := PieceView.make_piece(101, FEEL_CSZ)
	b.position = c["merge_pos"] - Vector2(FEEL_CSZ, FEEL_CSZ) / 2.0
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.add_child(b)
	c["tile_b"] = b
	var a := PieceView.make_piece(101, FEEL_CSZ)
	a.position = c["src_pos"] - Vector2(FEEL_CSZ, FEEL_CSZ) / 2.0
	a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.add_child(a)
	c["tile_a"] = a

# Replay: respawn, slide A into B, then fire MergeFx.apply with the live tier/combo + neighbours/board.
func _merge_fx_play() -> void:
	if _merge_fx_ctx.is_empty():
		return
	_merge_fx_spawn()
	var c := _merge_fx_ctx
	var field: Control = c["field"]
	var a: Control = c["tile_a"]
	var b: Control = c["tile_b"]
	if not (a != null and is_instance_valid(a) and b != null and is_instance_valid(b)):
		return
	var merge_top: Vector2 = c["merge_pos"] - Vector2(FEEL_CSZ, FEEL_CSZ) / 2.0
	var p: Dictionary = _params["merge_fx"]
	var finish := func() -> void:
		if a != null and is_instance_valid(a):
			a.queue_free()
		var nb_nodes: Array = []
		for n in c["neighbors"]:
			if n != null and is_instance_valid(n):
				nb_nodes.append(n)
		MergeFx.apply(field, b, c["merge_pos"], int(p.get("tier", 3)), int(p.get("combo", 0)), nb_nodes, field, p)
		var bloom_node: ComboBloom = c.get("bloom") as ComboBloom
		if MergeFx.on(p, "combo_bloom") and bloom_node != null and is_instance_valid(bloom_node):
			bloom_node.bump(int(p.get("combo", 0)), MergeFx.knob(p, "bloom_pct"))
	var tw := MoveFx.apply(a, a.position, merge_top, "slide", _params["move_fx"], MergeFx.knob(p, "merge_slide_ms"))
	if tw != null:
		tw.tween_callback(finish)
	else:
		finish.call()

# --- LAUNCH: click the generator → a tile is EMITTED (pops up-and-away) ------------------------
func _launch_fx_preview() -> Control:
	var gen_pos := Vector2(FEEL_FIELD.x * 0.5, FEEL_FIELD.y * 0.5 + 60.0)
	var field := _feel_field()
	var gbtn := Button.new()
	gbtn.flat = true
	gbtn.size = Vector2(FEEL_CSZ, FEEL_CSZ)
	gbtn.position = gen_pos - Vector2(FEEL_CSZ, FEEL_CSZ) / 2.0
	gbtn.set_meta("wb_active", true)
	var gart := PieceView.make_generator("seed_satchel", FEEL_CSZ)
	gart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gbtn.add_child(gart)
	field.add_child(gbtn)
	var hint := _feel_hint("Click the generator ↑ — or ▶ Launch", gen_pos + Vector2(-90, FEEL_CSZ / 2.0 + 6))
	field.add_child(hint)
	_launch_fx_ctx = {"field": field, "gen_pos": gen_pos, "gen_art": gart, "tile": null}
	gbtn.pressed.connect(_launch_fx_play)
	return field

# Emit a fresh tile: fire LaunchFx.apply as it LEAVES the emitter, then pop it up-and-away.
func _launch_fx_play() -> void:
	if _launch_fx_ctx.is_empty():
		return
	var c := _launch_fx_ctx
	var field: Control = c["field"]
	if not (field != null and is_instance_valid(field)):
		return
	if c.get("tile") != null and is_instance_valid(c["tile"]):
		c["tile"].queue_free()
	var tile := PieceView.make_piece(102, FEEL_CSZ)
	var start: Vector2 = c["gen_pos"] - Vector2(FEEL_CSZ, FEEL_CSZ) / 2.0
	tile.position = start
	tile.pivot_offset = Vector2(FEEL_CSZ, FEEL_CSZ) / 2.0
	tile.scale = Vector2(0.4, 0.4)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.add_child(tile)
	c["tile"] = tile
	LaunchFx.apply(c["gen_art"], tile, c["gen_pos"], _params["launch_fx"])
	var up := start + Vector2(70, -110)
	var settle := start + Vector2(70, -34)
	var tw := tile.create_tween()
	tw.parallel().tween_property(tile, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(tile, "position", up, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(tile, "position", settle, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

# --- MOVE: click the tile → it TRAVELS across the field (slide / arc / fall) -------------------
func _move_fx_preview() -> Control:
	var start_pos := Vector2(120.0, 150.0)
	var dest_pos := Vector2(FEEL_FIELD.x - 120.0, FEEL_FIELD.y - 130.0)
	var field := _feel_field()
	field.add_child(_feel_cell_marker(dest_pos))
	var sbtn := Button.new()
	sbtn.flat = true
	sbtn.size = Vector2(FEEL_CSZ, FEEL_CSZ)
	sbtn.position = start_pos - Vector2(FEEL_CSZ, FEEL_CSZ) / 2.0
	sbtn.set_meta("wb_active", true)
	field.add_child(sbtn)
	var hint := _feel_hint("Click the tile ↓ — or ▶ Send", start_pos + Vector2(-66, -FEEL_CSZ / 2.0 - 30))
	field.add_child(hint)
	_move_fx_ctx = {"field": field, "start_pos": start_pos, "dest_pos": dest_pos, "tile": null}
	_move_fx_reset()
	sbtn.pressed.connect(_move_fx_play)
	return field

# Reset the travelling tile to the start cell so the move replays repeatedly.
func _move_fx_reset() -> void:
	if _move_fx_ctx.is_empty():
		return
	var c := _move_fx_ctx
	var field: Control = c["field"]
	if not (field != null and is_instance_valid(field)):
		return
	if c.get("tile") != null and is_instance_valid(c["tile"]):
		c["tile"].queue_free()
	var tile := PieceView.make_piece(102, FEEL_CSZ)
	tile.position = c["start_pos"] - Vector2(FEEL_CSZ, FEEL_CSZ) / 2.0
	tile.rotation = 0.0
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.add_child(tile)
	c["tile"] = tile

# Send the tile across with the live kind + tunables via MoveFx.apply.
func _move_fx_play() -> void:
	if _move_fx_ctx.is_empty():
		return
	_move_fx_reset()
	var c := _move_fx_ctx
	var p: Dictionary = _params["move_fx"]
	var start_top: Vector2 = c["start_pos"] - Vector2(FEEL_CSZ, FEEL_CSZ) / 2.0
	var dest_top: Vector2 = c["dest_pos"] - Vector2(FEEL_CSZ, FEEL_CSZ) / 2.0
	MoveFx.apply(c["tile"], start_top, dest_top, String(p.get("kind", "slide")), p)

# A small INK hint label placed at `pos`, field-local (mouse-transparent).
func _feel_hint(text: String, pos: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", FEEL_INK)
	l.add_theme_font_size_override("font_size", FS.FINE)
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

# Fire one rush_fx effect (or "__all__") on the live demo context, reading current knob values
# from _params. A single id fires regardless of its toggle (an explicit test trigger);
# "__all__" respects the enabled toggles, mirroring the game.
func _rush_fx_play(which: String) -> void:
	if _rush_fx_ctx.is_empty():
		return
	var p: Dictionary = _params["rush_fx"]
	var c := _rush_fx_ctx
	var sl: Label = c.get("score_label")
	var ml: Label = c.get("mult_label")
	var tl: Label = c.get("time_label")
	if sl != null: sl.text = "0"
	if ml != null: ml.text = "×1.0"
	if tl != null: tl.text = "0:30"
	var want := func(id: String) -> bool:
		return which == id or (which == "__all__" and RushFx.on(p, id))
	if c.get("tile_a") != null: FX.squash_pop(c["tile_a"])
	if c.get("tile_b") != null: FX.squash_pop(c["tile_b"])
	if want.call("merge_burst"): RushFx.merge_burst(c["wrap"], c["tile_ctr"], 3, int(p["merge_burst_count"]))
	if want.call("score_tick"): RushFx.score_tick(sl, 1250, int(p["score_tick_ms"]))
	elif which == "__all__" and sl != null: sl.text = "1,250"
	if want.call("score_pulse"): RushFx.cell_pop(c.get("score_cell"), int(p["score_pulse_pct"]))
	if ml != null: ml.text = "×2.0"
	if want.call("mult_pop"): RushFx.cell_pop(c.get("mult_cell"), int(p["mult_pop_pct"]))
	if want.call("combo_heat"): RushFx.combo_heat(c["wrap"], c["tile_ctr"] - Vector2(0.0, c["tile_px"]), 6, int(p["combo_heat_size"]))
	if tl != null: tl.text = "0:06"
	if want.call("timer_low"): RushFx.timer_low(tl, 6, true, int(p["timer_low_secs"]))
	if want.call("treefall_crack"): RushFx.treefall_crack(c["wrap"], c["demo"], c["tile_ctr"], true, int(p["treefall_debris"]), float(p["treefall_shake"]), int(p["treefall_hitstop_ms"]))

## A ▶ trigger button for a feel-verb inspector (Drop / Merge / Launch / Send) — fires `play` on the live
## stage ctx, exactly like the rush_fx ▶ Replay. `wb_active` keeps it clickable inside the gallery.
func _feel_trigger_button(label: String, play: Callable) -> void:
	var b := Button.new()
	b.text = label
	b.set_meta("wb_active", true)
	b.add_theme_font_size_override("font_size", FS.FINE)
	b.pressed.connect(play)
	_sidebar_body.add_child(b)

## The shared feel-verb inspector body (mirrors the rush_fx case): the master toggle, then per-effect a
## label · "On" toggle · the effect's knob sliders (from the *_FX_KNOBS spec). Every key is saved to config.
## (move_fx builds its own variant inline because it inserts a KIND selector + duration under the master.)
func _feel_fx_sidebar(effects: Array, knobs: Dictionary) -> void:
	_group_header("Saved to config", true)
	_sidebar_body.add_child(_toggle_row("All cues (master)", "enabled"))
	_section_header("Each cue — flip · tune · ▶ to feel it (the game honours these)")
	for e in effects:
		var fid := String(e.get("id", ""))
		_section_header(String(e.get("label", fid)))
		var tip := String(e.get("tip", ""))
		if tip != "":
			var t := Label.new()
			t.text = tip
			t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			t.add_theme_font_size_override("font_size", FS.TOOL)
			t.add_theme_color_override("font_color", Color(Pal.CREAM, 0.6))
			_sidebar_body.add_child(t)
		_sidebar_body.add_child(_toggle_row("On", fid))
		for spec in knobs.get(fid, []):
			_sidebar_body.add_child(_slider_row(spec))

func _fx_sidebar() -> void:
	var saved := Label.new()
	saved.name = "WorkbenchFxSavedSettingsHeader"
	saved.text = "●  Saved to config"
	saved.add_theme_font_size_override("font_size", FS.FINE)
	saved.add_theme_color_override("font_color", Pal.STRAW)
	_sidebar_body.add_child(saved)
	_section_header("Action gates")
	for entry in FxWorkbenchView.FX_DEFS:
		var def: Dictionary = entry
		var fx_id := String(def.get("id", ""))
		var toggle := CheckButton.new()
		toggle.name = "WorkbenchFxActionToggle_%s" % fx_id
		toggle.text = String(def.get("label", fx_id))
		toggle.button_pressed = FX.reward_fx_enabled(fx_id)
		toggle.add_theme_color_override("font_color", Pal.CREAM)
		toggle.toggled.connect(func(on: bool) -> void:
			_fx_set_enabled(fx_id, on))
		_sidebar_body.add_child(toggle)

	_section_header("Feel")
	_sidebar_body.add_child(_fx_slider_row("Icon size", "icon_size", FX.REWARD_FX_MIN_ICON_SIZE, FX.REWARD_FX_MAX_ICON_SIZE, 1))
	_sidebar_body.add_child(_fx_slider_row("Trail count", "trail_count", FX.REWARD_FX_MIN_TRAIL_COUNT, FX.REWARD_FX_MAX_TRAIL_COUNT, 1))

	var test := Label.new()
	test.name = "WorkbenchFxTestSettingsHeader"
	test.text = "○  Test only — not saved"
	test.add_theme_font_size_override("font_size", FS.FINE)
	test.add_theme_color_override("font_color", Color(Pal.CREAM, 0.5))
	_sidebar_body.add_child(test)
	_sidebar_body.add_child(_fx_action_row())
	var replay := Button.new()
	replay.name = "WorkbenchFxReplayButton"
	replay.text = "Replay"
	replay.disabled = not FX.reward_fx_enabled(_fx_selected)
	replay.pressed.connect(_fx_replay)
	_sidebar_body.add_child(replay)
	_sidebar_body.add_child(_fx_slider_row("Amount", "amount", FX.REWARD_FX_MIN_AMOUNT, FX.REWARD_FX_MAX_AMOUNT, 1))
	_sidebar_body.add_child(_fx_slider_row("Source size", "coin_size", FX.REWARD_FX_MIN_SOURCE_SIZE, FX.REWARD_FX_MAX_SOURCE_SIZE, 1))
	var auto := CheckButton.new()
	auto.name = "WorkbenchFxAutoReplayToggle"
	auto.text = "Auto replay"
	var preview := _fx_preview()
	auto.button_pressed = bool(preview.get("_settings").get("auto_replay", false)) if preview != null else false
	auto.add_theme_color_override("font_color", Pal.CREAM)
	auto.toggled.connect(func(on: bool) -> void:
		_fx_set_auto_replay(on))
	_sidebar_body.add_child(auto)

func _fx_action_row() -> Control:
	var row := HBoxContainer.new()
	row.name = "WorkbenchFxPreviewActionRow"
	row.add_theme_constant_override("separation", 10)
	var lbl := Label.new()
	lbl.text = "Preview action"
	lbl.custom_minimum_size = Vector2(118, 0)
	row.add_child(lbl)
	var opt := OptionButton.new()
	opt.name = "WorkbenchFxPreviewActionOption"
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in FxWorkbenchView.FX_DEFS.size():
		var def: Dictionary = FxWorkbenchView.FX_DEFS[i]
		opt.add_item(String(def.get("label", def.get("id", ""))), i)
		if String(def.get("id", "")) == _fx_selected:
			opt.select(i)
	opt.item_selected.connect(func(index: int) -> void:
		var def: Dictionary = FxWorkbenchView.FX_DEFS[index]
		_fx_select(String(def.get("id", "coin_pickup"))))
	row.add_child(opt)
	return row

func _fx_slider_row(label: String, key: String, lo: float, hi: float, step: float) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size = Vector2(118, 0)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lbl)
	var s := HSlider.new()
	s.name = "WorkbenchFx%sSlider" % _pascal_fx_key(key)
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(_fx_global_value(key))
	s.custom_minimum_size = Vector2(0, 28)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(s)
	var val := Label.new()
	val.text = "%d" % int(round(s.value))
	val.custom_minimum_size = Vector2(44, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val)
	s.value_changed.connect(func(x: float) -> void:
		var iv := int(round(x))
		val.text = "%d" % iv
		_fx_set_global_setting(key, iv))
	return row

func _pascal_fx_key(key: String) -> String:
	var out := ""
	for part in key.split("_"):
		out += String(part).capitalize()
	return out

func _fx_global_value(key: String) -> int:
	var preview := _fx_preview()
	if preview != null and preview.has_method("_set_global_setting"):
		var settings: Dictionary = preview.get("_settings")
		if settings.has(key):
			return int(round(float(settings.get(key, 0))))
	match key:
		"amount":
			return FX.reward_fx_amount()
		"icon_size":
			return int(round(FX.reward_fx_icon_size()))
		"trail_count":
			return FX.reward_fx_trail_count()
		"coin_size":
			return int(round(FX.reward_fx_source_size()))
		_:
			return 0

func _fx_preview() -> Control:
	return find_child("FxWorkbenchComponent", true, false) as Control

func _fx_select(id: String) -> void:
	_fx_selected = id
	var preview := _fx_preview()
	if preview != null and is_instance_valid(preview):
		preview.call("_select_action", id)
	else:
		_rebuild_element("fx")
	_rebuild_sidebar.call_deferred()

func _fx_set_enabled(id: String, on: bool) -> void:
	var preview := _fx_preview()
	if preview != null and is_instance_valid(preview):
		preview.call("_set_fx_enabled", id, on)
	else:
		FX.set_reward_fx_enabled(id, on)
	_rebuild_sidebar.call_deferred()

func _fx_set_global_setting(key: String, value: int) -> void:
	var preview := _fx_preview()
	if preview != null and is_instance_valid(preview):
		preview.call("_set_global_setting", key, value)
		return
	match key:
		"amount":
			FX.set_reward_fx_amount(value)
		"icon_size":
			FX.set_reward_fx_icon_size(float(value))
		"trail_count":
			FX.set_reward_fx_trail_count(value)
		"coin_size":
			FX.set_reward_fx_source_size(float(value))

func _fx_set_auto_replay(on: bool) -> void:
	var preview := _fx_preview()
	if preview != null and is_instance_valid(preview):
		preview.call("_set_auto_replay", on)
	else:
		FX.set_reward_fx_auto_replay(on)

func _fx_replay() -> void:
	var preview := _fx_preview()
	if preview != null and is_instance_valid(preview):
		preview.call("_play_selected")

func _fx_def(id: String) -> Dictionary:
	for entry in FxWorkbenchView.FX_DEFS:
		var def: Dictionary = entry
		if String(def.get("id", "")) == id:
			return def
	return FxWorkbenchView.FX_DEFS[0]

## --- persistence -------------------------------------------------------------------------------


## --- the element set this workbench owns ---------------------------------------------------------

func _ids() -> Array:
	return IDS

func _columns_spec() -> Array:
	return COLUMNS

func _captions() -> Dictionary:
	return CAPTIONS

func _test_keys() -> Dictionary:
	return TEST_KEYS

func _default_selected() -> String:
	return "land_fx"

func _default_params() -> Dictionary:
	return {
		# the RUSH FX toggles — the master switch + one per screen-juice effect (RushFx.EFFECTS)
		"rush_fx": {"enabled": true, "merge_burst": true, "score_tick": true, "score_pulse": true, "mult_pop": true,
			"combo_heat": true, "timer_low": true, "treefall_crack": true,
			"merge_burst_count": 20, "score_tick_ms": 400, "score_pulse_pct": 100, "mult_pop_pct": 100,
			"combo_heat_size": 24, "timer_low_secs": 10,
			"treefall_debris": 18, "treefall_shake": 16, "treefall_hitstop_ms": 60,
		},
		# the feel-verb testers — defaults pulled straight from each registry (enabled + per-effect toggles +
		# knobs), so the saved block's keys match {Land,Merge,Launch,Move}Fx.from_config exactly.
		"land_fx": LandFx.defaults(),
		# merge_fx ALSO carries the two preview-only test sliders (tier/combo) — excluded from save via TEST_KEYS.
		"merge_fx": _merge_fx_defaults(),
		"launch_fx": LaunchFx.defaults(),
		# move_fx ALSO carries the preview-only KIND selector (slide/arc/fall) — excluded from save via TEST_KEYS.
		"move_fx": _move_fx_defaults(),
		"grab_fx": GrabFx.defaults(),
		# the reward flight has no params of its own here — FX owns its config (see _save_extras).
		"fx": {},
	}

func _sidebar_notes(_id: String) -> void:
	if _selected == "fx":
		_sidebar_note("Coin Flow is one shared reward-flight component. Saved settings tune the shared feel and gate which actions use it; test settings only change this preview.")

## The RUSH bar demo is drawn from the UI workbench's saved bar/badge design (this workbench does not
## own those knobs — it only borrows their look so the juice lands on the real bar).
func _shared_bar_opts() -> Dictionary:
	var cfg := Kit.load_config(SETTINGS)
	return Kit.rush_bar_opts_from_config({
		"rush_bar": cfg.get("rush_bar", {}),
		"gold_badge": cfg.get("gold_badge", {}),
	})

## Build the live element for an id from its current params.
func _make_element(id: String) -> Control:
	match id:
		"fx":
			var fx := FxWorkbenchView.new()
			fx.name = "FxWorkbenchComponent"
			fx.embedded = true
			fx.show_sidebar = false
			fx.preview_scale = 0.68
			fx.set("_preview_action", _fx_selected)
			fx.custom_minimum_size = Vector2(540, 760)
			fx.size = fx.custom_minimum_size
			return fx
		"rush_fx":
			# the screen-juice tester: a sample bar + two demo TILES (so the merge burst lands on a board-like
			# spot). The sidebar has a ▶ Replay per effect + that effect's knobs; this "▶ Replay all" button fires
			# every ENABLED effect. The game reads the SAME toggles + knobs (RushFx). No auto-play — replay on demand.
			var fbo := _shared_bar_opts()
			var demo: Control = Kit.rush_bar(fbo, {"time": "0:30", "score": "0", "mult": "×1.0"})
			var bsc := 0.6
			demo.scale = Vector2(bsc, bsc)
			var tpx := 76.0
			var wrap := Control.new()
			wrap.custom_minimum_size = Vector2(maxf(demo.size.x * bsc, tpx * 3.0) + 40.0, demo.size.y * bsc + tpx + 132.0)
			var tcx := wrap.custom_minimum_size.x * 0.5
			demo.position = Vector2(tcx - demo.size.x * bsc * 0.5, 14.0)
			wrap.add_child(demo)
			# the two demo tiles — the "merge" happens between them, so the leaf burst reads on a real tile
			var tiles_y := demo.size.y * bsc + 22.0
			var ta := PieceView.make_piece(101, tpx)
			ta.position = Vector2(tcx - tpx - 6.0, tiles_y) ; ta.mouse_filter = Control.MOUSE_FILTER_IGNORE
			wrap.add_child(ta)
			var tb := PieceView.make_piece(201, tpx)
			tb.position = Vector2(tcx + 6.0, tiles_y) ; tb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			wrap.add_child(tb)
			var tile_ctr := Vector2(tcx, tiles_y + tpx * 0.5)
			var btn := Button.new()
			btn.text = "▶  Replay all"
			btn.add_theme_font_size_override("font_size", FS.FINE)
			btn.custom_minimum_size = Vector2(190.0, 52.0) ; btn.size = btn.custom_minimum_size
			btn.position = Vector2(tcx - 95.0, tiles_y + tpx + 14.0)
			btn.set_meta("wb_active", true)              # stays clickable despite the gallery's select-on-click
			wrap.add_child(btn)
			_rush_fx_ctx = {
				"score_label": demo.get_meta("score_label"), "mult_label": demo.get_meta("mult_label"),
				"time_label": demo.get_meta("time_label"), "score_cell": demo.get_meta("score_cell"),
				"mult_cell": demo.get_meta("mult_cell"), "tile_a": ta, "tile_b": tb,
				"wrap": wrap, "demo": demo, "tile_ctr": tile_ctr, "tile_px": tpx,
			}
			btn.pressed.connect(func() -> void: _rush_fx_play("__all__"))
			return wrap
		"land_fx":
			return _land_fx_preview()
		"merge_fx":
			return _merge_fx_preview()
		"launch_fx":
			return _launch_fx_preview()
		"move_fx":
			return _move_fx_preview()
		"grab_fx":
			return _grab_fx_preview()
		_:
			return Control.new()

func _element_sidebar(_id: String) -> void:
	match _selected:
		"fx":
			_fx_sidebar()
		"rush_fx":
			_group_header("Saved to config", true)
			_sidebar_body.add_child(_toggle_row("All effects (master)", "enabled"))
			_section_header("Each effect — flip · tune · ▶ to feel it (the game honours these)")
			for e in RushFx.EFFECTS:
				var fid := String(e.get("id", ""))
				_section_header(String(e.get("label", fid)))
				_sidebar_body.add_child(_toggle_row("On", fid))
				var rb := Button.new()
				rb.name = "RushFxReplay_%s" % fid
				rb.text = "▶  Replay"
				rb.set_meta("wb_active", true)
				rb.add_theme_font_size_override("font_size", FS.FINE)
				rb.pressed.connect(func() -> void: _rush_fx_play(fid))
				_sidebar_body.add_child(rb)
				for spec in RUSH_FX_KNOBS.get(fid, []):
					_sidebar_body.add_child(_slider_row(spec))
		"land_fx":
			_feel_trigger_button("▶  Drop", _land_fx_play)
			_feel_fx_sidebar(LandFx.EFFECTS, LAND_FX_KNOBS)
		"merge_fx":
			_feel_trigger_button("▶  Merge", _merge_fx_play)
			_group_header("Saved to config", true)
			_section_header("Approach")
			_sidebar_body.add_child(_slider_row(["merge_slide_ms", 60, 260]))
			_group_header("Preview only — not saved", false)
			_sidebar_body.add_child(_slider_row(["tier", 1, 12]))    # drives colour / flash / pitch escalation
			_sidebar_body.add_child(_slider_row(["combo", 0, 10]))   # climbs the pentatonic ladder + gates hitstop
			_feel_fx_sidebar(MergeFx.EFFECTS, MERGE_FX_KNOBS)
		"launch_fx":
			_feel_trigger_button("▶  Launch", _launch_fx_play)
			_feel_fx_sidebar(LaunchFx.EFFECTS, LAUNCH_FX_KNOBS)
		"move_fx":
			_feel_trigger_button("▶  Send", _move_fx_play)
			_group_header("Saved to config", true)
			_sidebar_body.add_child(_toggle_row("All cues (master)", "enabled"))
			_group_header("Preview only — not saved", false)
			_sidebar_body.add_child(_option_row("Kind", "kind", MoveFx_KINDS))   # slide / arc / fall (the game passes the live kind)
			_group_header("Saved to config", true)
			_sidebar_body.add_child(_slider_row(["duration_ms", 60, 600]))       # travel speed — applies to every kind
			_section_header("Each cue — flip · tune · ▶ to feel it (the game honours these)")
			for e in MoveFx.EFFECTS:
				var mfid := String(e.get("id", ""))
				_section_header(String(e.get("label", mfid)))
				_sidebar_body.add_child(_toggle_row("On", mfid))
				for spec in MOVE_FX_KNOBS.get(mfid, []):
					_sidebar_body.add_child(_slider_row(spec))
		"grab_fx":
			_feel_trigger_button("▶  Grab", _grab_fx_play)
			_feel_fx_sidebar(GrabFx.EFFECTS, GRAB_FX_KNOBS)
