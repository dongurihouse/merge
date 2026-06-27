extends RefCounted
## Shared slot-machine REEL mechanic — the spin choreography + land juice, factored out of the daily
## mystery reveal (ui/login_mystery.gd) so the Rush reward (scenes/explore_trade.gd) reuses the exact
## same "all reels whir → land left→right with a thunk + shine" feel. The CALLER supplies the per-tile
## content via a make_tile Callable (currency rows / spirit faces) and a per-reel `shine` flag; this
## module owns the band, the clipped window, the staggered tweens, the bounce/flash/chime/shine, plus a
## finish() handle that snaps every reel to its landed state (the Rush "Done = skip to the end" path).

const FX = preload("res://engine/scripts/ui/fx.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Pal = Game.PALETTE
const STRAW := Pal.STRAW
const CELL_ART := "res://games/grove/assets/ui/kit/daily_card.png"

# reel spin pacing (owner feel dial). Reels ALL start together and STOP one-by-one (left→right): reel i
# whirs longer → lands later; the last hangs an extra beat. cfg passed to spin_reels overrides any of these.
const REEL_SYMS := 10            # tiles per band (decoys + the target)
const REEL_SPIN := 1.0           # reel 0 spin time (sec)
const REEL_STAGGER := 0.45       # +spin time per reel index (gap between successive STOPS)
const REEL_ANTICIPATE := 0.5     # the LAST reel hangs a touch longer
const REEL_BLUR_ALPHA := 0.78    # band opacity while whirring fast; 1.0 when landed

# --- build --------------------------------------------------------------------------

## Build one reel LANDED on `target`. `pool` are the symbols whizzing past (decoys); `make_tile.call(
## symbol, win_w, win_h)` returns the Control for one tile's content (it gets centred in the window).
## `index` desyncs neighbours + lengthens the band (so reel i lands later). `shine_on_land` marks this
## reel to glow when it lands (premium / high tier). Metas: reward(=target), band, tile_h, n_syms,
## shine, selected, tap (a disabled full-rect button a caller may enable for a pick phase).
static func build_reel(pool: Array, target, cw: float, ch: float, index: int, make_tile: Callable, shine_on_land: bool) -> Control:
	var reel := Control.new()
	reel.custom_minimum_size = Vector2(cw, ch)
	reel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reel.set_meta("reward", target)
	reel.set_meta("selected", false)
	reel.set_meta("shine", shine_on_land)

	var bg := PanelContainer.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_theme_stylebox_override("panel", cell_stylebox())
	reel.add_child(bg)

	var inset: float = 8.0
	var win := Control.new()
	win.name = "ReelWin"
	win.clip_contents = true
	win.mouse_filter = Control.MOUSE_FILTER_IGNORE
	win.set_anchors_preset(Control.PRESET_FULL_RECT)
	win.offset_left = inset
	win.offset_top = inset
	win.offset_right = -inset
	win.offset_bottom = -inset
	reel.add_child(win)
	var win_w: float = cw - inset * 2.0
	var win_h: float = ch - inset * 2.0

	var syms: Array = _reel_symbols(pool, target, REEL_SYMS - 1, index * 3 + 1)
	var band := VBoxContainer.new()
	band.name = "ReelBand"
	band.add_theme_constant_override("separation", 0)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for s in syms:
		var tile := CenterContainer.new()
		tile.custom_minimum_size = Vector2(win_w, win_h)
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(make_tile.call(s, win_w, win_h))
		band.add_child(tile)
	band.custom_minimum_size = Vector2(win_w, win_h * syms.size())
	band.size = Vector2(win_w, win_h * syms.size())
	band.position = Vector2(0, -win_h * float(syms.size() - 1))
	win.add_child(band)
	reel.set_meta("band", band)
	reel.set_meta("tile_h", win_h)
	reel.set_meta("n_syms", syms.size())

	var tap := Button.new()
	tap.name = "ReelTap"
	tap.flat = true
	tap.focus_mode = Control.FOCUS_NONE
	tap.disabled = true
	tap.set_anchors_preset(Control.PRESET_FULL_RECT)
	reel.add_child(tap)
	reel.set_meta("tap", tap)
	return reel

# The reel's scroll symbols: `count` decoys (cycling the pool from `offset` for per-reel desync) then the
# TARGET as the last (landing) tile.
static func _reel_symbols(pool: Array, target, count: int, offset: int) -> Array:
	var syms: Array = []
	var src: Array = pool if not pool.is_empty() else [target]
	for j in count:
		syms.append(src[(j + offset) % src.size()])
	syms.append(target)
	return syms

## The shared parchment-cell stylebox (the daily_card look; a code fallback if the art is absent).
static func cell_stylebox() -> StyleBox:
	if ResourceLoader.exists(CELL_ART):
		var st := StyleBoxTexture.new()
		st.texture = load(CELL_ART)
		st.set_texture_margin_all(28.0)
		st.content_margin_left = 8
		st.content_margin_right = 8
		st.content_margin_top = 7
		st.content_margin_bottom = 7
		return st
	var cf := StyleBoxFlat.new()
	cf.bg_color = Color(Pal.CREAM, 0.9)
	cf.set_corner_radius_all(12)
	cf.set_border_width_all(1)
	cf.border_color = Color(Pal.BARK, 0.4)
	cf.content_margin_left = 8
	cf.content_margin_right = 8
	cf.content_margin_top = 7
	cf.content_margin_bottom = 7
	return cf

# --- spin ---------------------------------------------------------------------------

## Spin every reel at once; stop one-by-one (left→right). Returns {finish: Callable} — call finish() to
## SNAP all reels to their landed state immediately (kills the tweens, no cascade) and fire on_all_landed
## if it hasn't run (the Rush "Done = skip" path). cfg overrides: spin, stagger, anticipate (floats);
## total_cap (float, 0 = uncapped — compress the stagger so the whole cascade fits within total_cap sec).
static func spin_reels(host, reels: Array, dialog: Control, on_all_landed: Callable, cfg: Dictionary = {}) -> Dictionary:
	var n: int = reels.size()
	var state := {"tweens": [], "landed": {}, "done": false}
	if n == 0:
		on_all_landed.call()
		state.done = true
		return {"finish": func() -> void: pass}
	var spin: float = float(cfg.get("spin", REEL_SPIN))
	var stagger: float = float(cfg.get("stagger", REEL_STAGGER))
	var anticipate: float = float(cfg.get("anticipate", REEL_ANTICIPATE))
	var cap: float = float(cfg.get("total_cap", 0.0))
	if cap > 0.0 and n > 1:
		var natural: float = spin + float(n - 1) * stagger + anticipate
		if natural > cap:
			stagger = maxf(0.0, (cap - spin - anticipate) / float(n - 1))
	var land_one := func(i: int) -> void:
		if state.landed.has(i):
			return
		state.landed[i] = true
		_land_reel(reels[i], i, n, dialog, false)
	for i in n:
		var reel: Control = reels[i]
		var band: Control = reel.get_meta("band")
		var tile_h: float = float(reel.get_meta("tile_h"))
		var n_syms: int = int(reel.get_meta("n_syms"))
		band.position.y = 0.0
		band.modulate.a = REEL_BLUR_ALPHA
		var landed_y: float = -tile_h * float(n_syms - 1)
		var dur: float = spin + float(i) * stagger + (anticipate if i == n - 1 else 0.0)
		var ri := i
		var t: Tween = (host as Node).create_tween()
		t.tween_property(band, "position:y", landed_y, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(band, "modulate:a", 1.0, dur * 0.4).set_delay(dur * 0.6)
		t.tween_callback(func() -> void: land_one.call(ri))
		if i == n - 1:
			t.tween_callback(func() -> void:
				if not state.done:
					state.done = true
					on_all_landed.call())
		state.tweens.append(t)
	var finish := func() -> void:
		for t in state.tweens:
			if t != null and t.is_valid():
				t.kill()
		for i in n:
			var reel: Control = reels[i]
			var band: Control = reel.get_meta("band")
			var tile_h: float = float(reel.get_meta("tile_h"))
			var n_syms: int = int(reel.get_meta("n_syms"))
			band.position.y = -tile_h * float(n_syms - 1)
			band.modulate.a = 1.0
			if not state.landed.has(i):
				state.landed[i] = true
				_land_reel(reel, i, n, dialog, true)
		if not state.done:
			state.done = true
			on_all_landed.call()
	return {"finish": finish}

# A reel lands: bounce + flash + escalating chime + shine (if its `shine` meta is set; the `top` meta
# shines hardest + shakes the dialog). `quiet` skips the bounce/flash/chime/shake (the skip-to-end snap)
# but still applies the shine, so the final picture matches a full cascade.
static func _land_reel(reel: Control, idx: int, total: int, dialog: Control, quiet: bool) -> void:
	if not is_instance_valid(reel):
		return
	var band: Control = reel.get_meta("band")
	if is_instance_valid(band):
		band.modulate.a = 1.0
	var top: bool = bool(reel.get_meta("top", false))
	if bool(reel.get_meta("shine", false)):
		shine(reel, top)
	if quiet:
		return
	reel.pivot_offset = Vector2(reel.size.x * 0.5, reel.size.y)
	reel.scale = Vector2(1.14, 0.82)
	var t := reel.create_tween()
	t.tween_property(reel, "scale", Vector2(0.96, 1.08), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(reel, "scale", Vector2.ONE, 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_flash(reel, top)
	if top and is_instance_valid(dialog):
		FX.shake(dialog, FX.Tune.SHAKE_BIG_AMP)
	Audio.play("merge_success", -4.0, 1.04 + float(idx) / float(maxi(1, total)) * 0.5)

# A quick impact flash over a landed reel (gold + bigger for the top prize); fades out fast.
static func _flash(reel: Control, strong: bool) -> void:
	var fl := ColorRect.new()
	fl.color = (Color(1, 0.95, 0.7, 0.85) if strong else Color(1, 1, 1, 0.6))
	fl.set_anchors_preset(Control.PRESET_FULL_RECT)
	fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reel.add_child(fl)
	if not reel.is_inside_tree():
		fl.queue_free()
		return
	var t := fl.create_tween()
	t.tween_property(fl, "modulate:a", 0.0, 0.26 if strong else 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_callback(fl.queue_free)

## The shine: a warm glow BEHIND the band that gently pulses + a one-shot sparkle burst on land. `strong`
## (the richest reel) glows warmer + bursts bigger. Public — login_mystery.reveal_static calls it too.
static func shine(reel: Control, strong: bool) -> void:
	if reel.has_node("Shine"):
		return
	var hi: float = 0.5 if strong else 0.34
	var glow := ColorRect.new()
	glow.name = "Shine"
	glow.color = Color(STRAW, hi)
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reel.add_child(glow)
	reel.move_child(glow, 1)
	if reel.is_inside_tree():
		var pt := glow.create_tween().set_loops()
		pt.tween_property(glow, "color:a", hi * 0.5, 0.8).set_trans(Tween.TRANS_SINE)
		pt.tween_property(glow, "color:a", hi, 0.8).set_trans(Tween.TRANS_SINE)
	FX.burst(reel, reel.size * 0.5, STRAW, 18 if strong else 11)
