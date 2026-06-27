extends Control
## Explore · Rush — beat 2 of the acquire ritual: a timed merge-for-score game on a throwaway grid.
## Traces rain in automatically (no Water); TAP a tile to merge a matching neighbour (the result rerolls
## to a random line) or, with no match, to FLING it to a safe column; a telegraphed TREEFALL periodically
## destroys a column (empty it first for a clean-dodge multiplier). Two clocks end the run — the countdown
## or a full board. Score accrues into the run state (Explore.add_score) and the run reveals its reward
## as an overlay on this frozen board (ui/explore_reward.gd), not a separate screen.
##
## The decision logic is core/explore.gd (pure, tested); this script is the real-time orchestration +
## simple tile visuals. Numbers are the feel-prototype's provisional values (Rush sim retunes later).

const G = preload("res://engine/scripts/core/content.gd")
const Explore = preload("res://engine/scripts/core/explore.gd")
const Save = preload("res://engine/scripts/core/save.gd")     # the rush-intro popup's first-N-rushes counter
const ExploreReward = preload("res://engine/scripts/ui/explore_reward.gd")  # the run's payout, as an overlay on this board
const Audio = preload("res://engine/scripts/core/audio.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")     # the shared screen-juice toolbox
const PieceView = preload("res://engine/scripts/ui/piece_view.gd")   # the home board's merge-piece renderer
const BoardScript = preload("res://engine/scripts/scenes/board.gd")  # reuse its painted field backdrop
const Look = preload("res://engine/scripts/ui/skin.gd")              # safe-area inset for the top bar
const RushFx = preload("res://engine/scripts/ui/rush_fx.gd")        # the toggleable screen-juice effects (workbench rush_fx)

const RUSH_ART := "res://games/grove/assets/ui/rush/%s.png"          # the carved-wood / parchment top-bar pieces
const BOTTOM_HINT_ART := "res://games/grove/assets/ui/rush/bottom_hint_3slice.png"
const BOTTOM_HINT_BOTTOM_GAP_FRAC := 0.05
const BOTTOM_HINT_TEXT_VISUAL_NUDGE_Y := 4.0
const KIT_PATH := "res://games/grove/tools/ui_workbench_kit.gd"      # the shared UI kit (board frame · slot cells · rush bar)

const INK := Color("#43352B")
const PARCH := Color("#F3E7CE")
const GOLD := Color("#FFD166")
const STRAW := Color("#E3B23C")

var _cfg: Dictionary = {}
var _grid: Array = []            # [ROWS][COLS] of {kind,tier,node} or null
var _board: Control = null
var _tele: ColorRect = null
var _cell := 64.0
var _gap := 7.0                  # gutter between cells (matches the home board's GAP)
var _inset := 3.0                # tile inset within its cell
var _bar_bottom := 0.0           # the top bar's bottom Y — the board reserves the screen above it
var _running := false
var _time := 0.0
var _elapsed := 0.0
var _spawn_acc := 0.0
var _mult := 1.0
var _combo := 0
var _last_merge := -999.0
var _tf: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _lbl_time: Label = null
var _lbl_score: Label = null
var _lbl_mult: Label = null
var _fx: Dictionary = {}         # the resolved rush_fx toggles (RushFx.from_config)
var _score_cell: Control = null  # the score / mult bar cells (for the pop effects)
var _mult_cell: Control = null
var _last_sec := -1              # the last whole second shown (drives the per-second timer urgency)
# --- layout chrome the resize relayout tears down + rebuilds (the live tiles persist across it) ---
var _topbar: Control = null
var _exit_btn: Control = null
var _chrome: Control = null            # the board's frame + slot wells + telegraph (rebuilt on resize)
var _activity: Control = null          # the treefall activity bar (between the top bar and the board)
var _act_idle: Control = null          # the calm "no treefall" rail
var _act_warn: Control = null          # the red treefall warning strip
var _act_label: Label = null           # the "Ns" countdown caption on the warning strip
var _act_fill: ColorRect = null        # the draining countdown bar
var _act_fill_w := 0.0                 # the countdown bar's full width
var _act_arrow: Polygon2D = null       # the down-chevron pointing from the bar at the doomed column
var _act_bottom := 0.0                 # the activity bar's bottom Y — the board reserves below this
var _hint: Control = null              # the always-on bottom hint strip
var _hint_h := 0.0                     # its measured height — the board reserves above it
var _last_view := Vector2.ZERO         # the last laid-out viewport size (resize coalesce)
var _relayout_queued := false          # coalesces a burst of size_changed into one relayout per frame

func _ready() -> void:
	_rng.randomize()
	if Explore.run().is_empty():
		Explore.begin_run({})        # direct-open (tool/test) — neutral loadout
	# Draw this run's lines from what the player has actually SEEN (3 picked, or 2 with the focus boost).
	_cfg = Explore.rush_cfg(Explore.run().get("equip", {}), Save.grove().get("seen", {}), _rng)

	add_child(BoardScript._field_backdrop())   # the painted grove backdrop (ui/board2_bg.png), full-rect → auto-fits

	_layout()                                  # build all four bands + the board chrome for the current size
	# Re-fit every band + the live tiles on a live viewport resize (drag the window / rotate), like the home
	# map and the board action bar. A resize fires size_changed many times — coalesce to one relayout per frame.
	# (Headless harnesses run _ready out of tree → no viewport to watch; the engine's in-tree _ready connects.)
	if get_viewport() != null and not get_viewport().size_changed.is_connected(_on_viewport_resized):
		get_viewport().size_changed.connect(_on_viewport_resized)
	_start()

# (Re)build every band for the current viewport size. The stateless chrome (top bar, activity bar, bottom
# hint, board frame + wells + telegraph) is torn down and rebuilt; the live tiles persist (they hold the run
# grid) and are only repositioned + repainted. Called once at _ready and again on each coalesced resize.
func _layout() -> void:
	if _topbar != null and is_instance_valid(_topbar): _topbar.queue_free()
	if _exit_btn != null and is_instance_valid(_exit_btn): _exit_btn.queue_free()
	if _activity != null and is_instance_valid(_activity): _activity.queue_free()
	if _hint != null and is_instance_valid(_hint): _hint.queue_free()
	if _chrome != null and is_instance_valid(_chrome): _chrome.queue_free()
	_build_topbar()
	_build_activity()
	_build_bottom_hint()
	_build_board_chrome()
	_reposition_tiles()
	_apply_treefall_visual()
	_refresh_readouts()
	_last_view = get_viewport_rect().size

func _on_viewport_resized() -> void:
	if _relayout_queued:
		return
	_relayout_queued = true
	_relayout_after_resize.call_deferred()

func _relayout_after_resize() -> void:
	_relayout_queued = false
	if get_viewport() == null:
		return
	if get_viewport_rect().size == _last_view:
		return                            # no real change — skip the rebuild
	_layout()

# The rush_concept top bar: three CODE-DRAWN gold-badge cells — Time | SCORE (centred, larger) | Mult —
# built by the SHARED kit (Kit.rush_bar, workbench-tunable) with the rush_bar_asset art used only for the
# leaf clusters, the score coin, and the acorn crown. The bar is centred and scaled to fit the width; the
# value Labels come back via meta so _refresh_readouts updates them. The EXIT × keeps the top-right corner.
func _build_topbar() -> void:
	var Kit: GDScript = load(KIT_PATH)
	var vp := get_viewport_rect().size
	var vw: float = vp.x if vp.x > 0.0 else 720.0
	var bar_top := maxf(Look.safe_top(self), 14.0) + 8.0
	var opts: Dictionary = Kit.rush_bar_opts_from_config(Kit.load_config(Kit.CONFIG_PATH))
	# seed the live readouts so a resize mid-run keeps the time / score / mult (not a reset to 0)
	var bar: Control = Kit.rush_bar(opts, {"time": _fmt_time(), "score": str(Explore.score()), "mult": "×%.1f" % _mult})
	var bw: float = bar.size.x
	var scale: float = clampf((vw * 0.74) / maxf(1.0, bw), 0.45, 1.4)   # the bar is ~74% of screen width on any device
	bar.scale = Vector2(scale, scale)
	bar.position = Vector2((vw - bw * scale) * 0.5, bar_top)
	add_child(bar)
	_topbar = bar
	_bar_bottom = bar_top + bar.size.y * scale          # the board reserves the screen below this
	_lbl_time = bar.get_meta("time_label")
	_lbl_score = bar.get_meta("score_label")
	_lbl_mult = bar.get_meta("mult_label")
	_score_cell = bar.get_meta("score_cell")
	_mult_cell = bar.get_meta("mult_cell")
	_fx = RushFx.from_config(Kit.load_config(Kit.CONFIG_PATH))   # the saved screen-juice toggles
	# EXIT — the parchment × in the top-right corner
	var ex_h: float = clampf(float(opts.get("height", 116.0)) * scale * 0.55, 40.0, 92.0)
	var ex := TextureButton.new()
	ex.texture_normal = _tex("exit_x")
	ex.ignore_texture_size = true
	ex.stretch_mode = TextureButton.STRETCH_SCALE
	ex.custom_minimum_size = Vector2(ex_h, ex_h) ; ex.size = Vector2(ex_h, ex_h)
	ex.position = Vector2(vw * 0.97 - ex_h, bar_top + 6.0)
	ex.pressed.connect(func() -> void: _end())
	add_child(ex)
	_exit_btn = ex

# The treefall ACTIVITY BAR: a fixed-height slot between the top bar and the board that telegraphs the
# treefall. Idle shows a calm parchment rail; when a tree is telegraphed it turns into a red warning strip
# with a draining countdown and a down-chevron over the doomed column. Today it carries ONLY the treefall
# notice (a second indicator — multiplier cooldown / board-fill — is parked). Its bottom sets the board's
# top reserve, so the board never jumps between the idle and warning states.
func _build_activity() -> void:
	var vp := get_viewport_rect().size
	var vw: float = vp.x if vp.x > 0.0 else 720.0
	var vh: float = vp.y if vp.y > 0.0 else 1280.0
	var margin := vw * 0.05
	var w := vw - margin * 2.0
	var h := clampf(vh * 0.05, 44.0, 70.0)
	var top := _bar_bottom + vh * 0.01
	_activity = Control.new()
	_activity.name = "RushActivityBar"
	_activity.position = Vector2(margin, top)
	_activity.size = Vector2(w, h)
	_activity.custom_minimum_size = _activity.size
	_activity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_activity)
	_act_bottom = top + h
	var fs := int(clampf(h * 0.34, 15.0, 23.0))
	var pad := h * 0.28
	# IDLE — a quiet parchment rail (low-key, so it is not a second empty void)
	_act_idle = _act_panel(Vector2(w, h), Color(PARCH, 0.34), Color(INK, 0.16))
	var il := _act_text("No treefall — keep merging", fs, Color(INK, 0.72))
	il.position = Vector2.ZERO ; il.size = Vector2(w, h)
	_act_idle.add_child(il)
	_activity.add_child(_act_idle)
	# WARNING — a red strip: a left caption, a right "Ns" countdown over a draining bar, a down-chevron
	_act_warn = _act_panel(Vector2(w, h), Color(0.78, 0.26, 0.20, 0.95), Color(0.45, 0.12, 0.10))
	var wl := _act_text("Treefall incoming", fs, PARCH)
	wl.position = Vector2(pad, 0.0) ; wl.size = Vector2(w * 0.55 - pad, h)
	wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_act_warn.add_child(wl)
	_act_label = _act_text("", fs, PARCH)
	_act_label.position = Vector2(w * 0.55, 0.0) ; _act_label.size = Vector2(w * 0.45 - pad, h * 0.56)
	_act_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_act_warn.add_child(_act_label)
	var track_w := w * 0.45 - pad
	var track := ColorRect.new()
	track.color = Color(1, 1, 1, 0.28)
	track.position = Vector2(w * 0.55, h * 0.66) ; track.size = Vector2(track_w, h * 0.14)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_act_warn.add_child(track)
	_act_fill = ColorRect.new()
	_act_fill.color = PARCH
	_act_fill.position = Vector2.ZERO ; _act_fill.size = Vector2(track_w, h * 0.14)
	_act_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(_act_fill)
	_act_fill_w = track_w
	# the down-chevron (code-drawn triangle) — its x is aimed at the doomed column in _apply_treefall_visual
	_act_arrow = Polygon2D.new()
	_act_arrow.color = Color(0.78, 0.26, 0.20)
	var a := h * 0.26
	_act_arrow.polygon = PackedVector2Array([Vector2(-a, 0.0), Vector2(a, 0.0), Vector2(0.0, a)])
	_act_arrow.position = Vector2(w * 0.5, h - 1.0)
	_act_warn.add_child(_act_arrow)
	_activity.add_child(_act_warn)
	_act_idle.visible = true
	_act_warn.visible = false

# A flat rounded panel for an activity-bar state (children are positioned absolutely, so a Panel — which
# does NOT arrange children like PanelContainer would — is the right base).
func _act_panel(size: Vector2, bg: Color, border: Color) -> Panel:
	var p := Panel.new()
	p.position = Vector2.ZERO ; p.size = size ; p.custom_minimum_size = size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(int(clampf(size.y * 0.28, 8.0, 18.0)))
	sb.set_border_width_all(2)
	sb.border_color = border
	p.add_theme_stylebox_override("panel", sb)
	return p

func _act_text(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _tex(name: String) -> Texture2D:
	var p := RUSH_ART % name
	return load(p) if ResourceLoader.exists(p) else null

# The Rush board is the SAME board component as the home board — the shared gold frame (Kit.board_panel)
# + the shared slot-cell wells (Kit.slot_cell) — only every cell is OPEN (no brambles). Its size and
# position derive from the screen (like the home board): cells fit the screen on whichever axis binds,
# centred, reserving the top bar above and the safe-area below, with the frame's overhang accounted for.
const FRAME_OUT := 48.0          # the board frame's overhang past the grid (matches the home planter feel)
const BOARD_MARGIN := 8.0

func _cellxy(r: int, c: int) -> Vector2:
	return Vector2(float(c) * (_cell + _gap), float(r) * (_cell + _gap))

func _cell_rest(r: int, c: int) -> Vector2:                 # where a tile rests inside its cell
	return _cellxy(r, c) + Vector2(_inset, _inset)

func _tile_px() -> float:
	return _cell - 2.0 * _inset

func _build_board_chrome() -> void:
	var Kit: GDScript = load(KIT_PATH)
	var cfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH)
	var vp := get_viewport_rect().size
	var vw: float = vp.x if vp.x > 0.0 else 720.0
	var vh: float = vp.y if vp.y > 0.0 else 1280.0
	var top_reserve := _act_bottom + vh * 0.015             # the screen below the activity bar
	var bot_reserve := Look.safe_bottom(self) + _hint_h + vh * 0.04   # leave room for the bigger bottom hint
	# fit cells to the screen on whichever axis binds, accounting for the frame overhang + gutters
	var w_csz := (vw - 2.0 * BOARD_MARGIN - 2.0 * FRAME_OUT - float(G.COLS - 1) * _gap) / float(G.COLS)
	var h_csz := (vh - top_reserve - bot_reserve - 2.0 * FRAME_OUT - float(G.ROWS - 1) * _gap) / float(G.ROWS)
	_cell = floorf(maxf(24.0, minf(w_csz, h_csz)))
	var bw := float(G.COLS) * _cell + float(G.COLS - 1) * _gap
	var bh := float(G.ROWS) * _cell + float(G.ROWS - 1) * _gap
	# the board node PERSISTS across relayouts (it holds the live tiles); only reposition it on a rebuild
	if _board == null:
		_board = Control.new()
		_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_board)
	_board.custom_minimum_size = Vector2(bw, bh)
	_board.size = Vector2(bw, bh)
	# centre the grid in the band between the activity bar and the bottom hint (frame overhang clears both)
	var band_top := top_reserve + FRAME_OUT
	var band_h := vh - bot_reserve - FRAME_OUT - band_top
	_board.position = Vector2((vw - bw) * 0.5, band_top + maxf(0.0, (band_h - bh) * 0.5))
	# the STATELESS chrome (frame + wells + telegraph) — rebuilt each layout, kept BEHIND the tiles
	_chrome = Control.new()
	_chrome.name = "RushBoardChrome"
	_chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.add_child(_chrome)
	_board.move_child(_chrome, 0)
	# the SHARED board frame (gold planter), behind the cells, overhanging the grid by FRAME_OUT
	var frame: Control = Kit.board_panel(Vector2(bw + FRAME_OUT * 2.0, bh + FRAME_OUT * 2.0), Kit.board_panel_opts_from_config(cfg))
	frame.position = Vector2(-FRAME_OUT, -FRAME_OUT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chrome.add_child(frame)
	# the SHARED slot-cell wells — every cell OPEN (no locked brambles)
	var slot_opts: Dictionary = Kit.bag_card_opts_from_config(cfg)
	slot_opts["cell_w"] = _cell
	slot_opts["cell_h"] = _cell
	for r in G.ROWS:
		for c in G.COLS:
			var slot: Control = Kit.slot_cell({"state": "empty"}, slot_opts)
			slot.position = _cellxy(r, c)
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_chrome.add_child(slot)
	# the treefall telegraph (a translucent danger pane over one column)
	_tele = ColorRect.new()
	_tele.color = Color(0.85, 0.25, 0.2, 0.32)
	_tele.size = Vector2(_cell, bh)
	_tele.visible = false
	_tele.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chrome.add_child(_tele)

# Snap every live tile to its cell at the current cell size, repainting its piece — used after a relayout
# (the grid array survives a resize; only the on-screen geometry changed).
func _reposition_tiles() -> void:
	for r in G.ROWS:
		if r >= _grid.size():
			continue
		for c in G.COLS:
			if c >= (_grid[r] as Array).size():
				continue
			var cell = _grid[r][c]
			if cell == null:
				continue
			var node := cell.node as Control
			if node == null or not is_instance_valid(node):
				continue
			node.size = Vector2(_tile_px(), _tile_px())
			node.custom_minimum_size = node.size
			node.position = _cell_rest(r, c)
			_paint(cell)

# Sync the treefall telegraph to the current _tf state: which activity sub-panel shows, the on-board danger
# pane, and the chevron's x (aimed at the doomed column). Idempotent — safe to call after a relayout.
func _apply_treefall_visual() -> void:
	var tele := String(_tf.get("ph", "idle")) == "tele"
	if _act_idle != null and is_instance_valid(_act_idle): _act_idle.visible = not tele
	if _act_warn != null and is_instance_valid(_act_warn): _act_warn.visible = tele
	if _tele != null and is_instance_valid(_tele):
		_tele.visible = tele
		if tele:
			_tele.position = Vector2(_cellxy(0, int(_tf.col)).x, 0)
	if tele and _act_arrow != null and is_instance_valid(_act_arrow) \
			and _board != null and _activity != null:
		var col_screen_x := _board.position.x + _cellxy(0, int(_tf.col)).x + _cell * 0.5
		_act_arrow.position.x = clampf(col_screen_x - _activity.position.x, 8.0, _activity.size.x - 8.0)

# An ALWAYS-ON micro-hint along the bottom safe area, teaching the two secondary verbs the
# top popup leaves out: tap-again-to-fling and clearing a column before a treefall. The
# source art is used as a 3-slice: fixed side caps + horizontally stretched center.
func _build_bottom_hint() -> void:
	var vp := get_viewport_rect().size
	var vw: float = vp.x if vp.x > 0.0 else 720.0
	var vh: float = vp.y if vp.y > 0.0 else 1280.0
	var tex := load(BOTTOM_HINT_ART) as Texture2D
	var tex_w := float(tex.get_width())
	var tex_h := float(tex.get_height())
	var strip_w := minf(vw * 0.91, 760.0)
	var strip_h := clampf(vh * 0.037, 42.0, 56.0)
	var src_cap_w := minf(roundf(tex_h * 1.12), floorf((tex_w - 1.0) * 0.5))
	var cap_w := src_cap_w * (strip_h / tex_h)
	var center_w := maxf(1.0, strip_w - cap_w * 2.0)
	var center_src_w := maxf(1.0, tex_w - src_cap_w * 2.0)
	var strip := Control.new()
	strip.name = "RushBottomHintStrip"
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.size = Vector2(strip_w, strip_h)
	strip.custom_minimum_size = strip.size
	strip.set_meta("slice_mode", "three")
	strip.set_meta("cap_source_px", src_cap_w)
	strip.add_child(_bottom_hint_slice("RushBottomHintLeftCap", tex, Rect2(0.0, 0.0, src_cap_w, tex_h), Vector2.ZERO, Vector2(cap_w, strip_h)))
	strip.add_child(_bottom_hint_slice("RushBottomHintCenterSlice", tex, Rect2(src_cap_w, 0.0, center_src_w, tex_h), Vector2(cap_w, 0.0), Vector2(center_w, strip_h)))
	strip.add_child(_bottom_hint_slice("RushBottomHintRightCap", tex, Rect2(tex_w - src_cap_w, 0.0, src_cap_w, tex_h), Vector2(cap_w + center_w, 0.0), Vector2(cap_w, strip_h)))
	var l := Label.new()
	l.name = "RushBottomHint"
	l.text = "Tap again to fling · empty a column before the treefall"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var text_vpad := strip_h * 0.08
	var text_nudge := BOTTOM_HINT_TEXT_VISUAL_NUDGE_Y
	l.position = Vector2(cap_w * 0.65, text_vpad + text_nudge)
	l.size = Vector2(maxf(1.0, strip_w - cap_w * 1.3), maxf(1.0, strip_h - text_vpad - text_nudge))
	l.add_theme_font_size_override("font_size", int(clampf(strip_h * 0.48, 20.0, 27.0)))
	l.add_theme_color_override("font_color", Color("#F8E9D0"))
	l.add_theme_color_override("font_outline_color", Color("#3D251B", 0.65))
	l.add_theme_constant_override("outline_size", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(l)
	add_child(strip)
	var bottom_gap := maxf(14.0, vh * BOTTOM_HINT_BOTTOM_GAP_FRAC)
	strip.position = Vector2((vw - strip_w) * 0.5, vh - Look.safe_bottom(self) - bottom_gap - strip_h)
	_hint = strip
	_hint_h = strip_h

func _bottom_hint_slice(node_name: String, tex: Texture2D, src: Rect2, pos: Vector2, sz: Vector2) -> TextureRect:
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = src
	var t := TextureRect.new()
	t.name = node_name
	t.texture = atlas
	t.position = pos
	t.size = sz
	t.custom_minimum_size = sz
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

# The rush-start teaching popup: a parchment pill reading "Tap to Merge!" that POPS in with the
# board's signature back-ease overshoot, holds, then fades + drifts up and frees itself — a ~1.5s
# beat. Non-blocking (taps pass straight through to the board). Gated by the caller to first rushes.
const HINT_POP := 0.18
const HINT_HOLD := 0.9
const HINT_FADE := 0.34
func _show_tap_hint() -> void:
	var vp := get_viewport_rect().size
	var vw: float = vp.x if vp.x > 0.0 else 720.0
	var vh: float = vp.y if vp.y > 0.0 else 1280.0
	var pill := PanelContainer.new()
	pill.name = "RushTapHint"
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE                 # a hint, not a wall
	# A DARK parchment-ink pill with a gold rim — reads crisply over the light cream board (a
	# PARCH pill would vanish into it). Soft shadow lifts it off the field.
	var sb := StyleBoxFlat.new()
	sb.bg_color = INK
	sb.border_color = GOLD
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(24)
	sb.content_margin_left = 30.0 ; sb.content_margin_right = 30.0
	sb.content_margin_top = 16.0 ; sb.content_margin_bottom = 16.0
	sb.shadow_color = Color(0.16, 0.11, 0.07, 0.34)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 5)
	pill.add_theme_stylebox_override("panel", sb)
	var lbl := Label.new()
	lbl.text = "Tap to Merge!"
	lbl.add_theme_font_size_override("font_size", 34)
	lbl.add_theme_color_override("font_color", PARCH)
	lbl.add_theme_color_override("font_outline_color", Color(INK, 0.5))
	lbl.add_theme_constant_override("outline_size", 2)
	pill.add_child(lbl)
	add_child(pill)
	# centre it in the upper third, clear of the board action below
	pill.reset_size()
	var sz := pill.get_combined_minimum_size()
	pill.pivot_offset = sz * 0.5
	pill.position = Vector2((vw - sz.x) * 0.5, vh * 0.40 - sz.y * 0.5)
	# POP → HOLD → FADE+RISE → free (the same back-ease overshoot the merge juice uses)
	pill.scale = Vector2(0.6, 0.6)
	pill.modulate.a = 0.0
	var t := pill.create_tween()
	t.tween_property(pill, "modulate:a", 1.0, HINT_POP * 0.6)
	t.parallel().tween_property(pill, "scale", Vector2.ONE, HINT_POP).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(HINT_HOLD)
	t.tween_property(pill, "modulate:a", 0.0, HINT_FADE)
	t.parallel().tween_property(pill, "position:y", pill.position.y - 26.0, HINT_FADE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_callback(pill.queue_free)

func _start() -> void:
	_grid = []
	for _r in G.ROWS:
		var row := []
		for _c in G.COLS:
			row.append(null)
		_grid.append(row)
	_time = float(_cfg.time)
	_elapsed = 0.0
	_spawn_acc = 0.0
	_mult = 1.0
	_combo = 0
	_last_merge = -999.0
	_tf = {"ph": "idle", "t": 0.0, "next": 6.5 * float(_cfg.calm_mul), "col": 0}
	_running = true
	_refresh_readouts()
	set_process(true)
	# The "Tap to Merge!" teaching popup — only on a player's first few rushes (then it retires).
	if Explore.rush_intro_should_show(Save.rush_intro_seen()):
		Save.mark_rush_intro_seen()
		_show_tap_hint()

# --- frame loop ------------------------------------------------------------------
func _process(dt: float) -> void:
	if not _running:
		return
	dt = minf(dt, 0.1)
	_elapsed += dt
	_time -= dt
	if _time <= 0.0:
		_time = 0.0
		_refresh_readouts()
		_end()
		return
	_mult = Explore.mult_decay(_mult, dt, _elapsed - _last_merge)
	if _combo > 0 and _elapsed - _last_merge > Explore.COMBO_RESET:
		_combo = 0
	var prog := 1.0 - _time / float(_cfg.time)
	_spawn_acc += dt
	if _spawn_acc >= Explore.spawn_interval(prog, float(_cfg.spawn_mul)):
		_spawn_acc = 0.0
		_spawn()
	_tf.t = float(_tf.t) + dt
	if String(_tf.ph) == "idle" and float(_tf.t) >= float(_tf.next):
		_start_timber()
	elif String(_tf.ph) == "tele" and float(_tf.t) >= Explore.WARN:
		_drop_timber()
	_refresh_readouts()

# --- spawning --------------------------------------------------------------------
func _spawn() -> void:
	var danger := int(_tf.col) if String(_tf.ph) == "tele" else -1   # the column a tree is telegraphed to crush
	var cols := []
	var safe := []
	for c in G.COLS:
		if Explore.column_fill(_grid, c) < G.ROWS:
			cols.append(c)
			if c != danger:
				safe.append(c)                  # don't seed a trace into the doomed line
	if cols.is_empty():
		_end()
		return
	if safe.is_empty():
		return                                  # only the doomed line has room — skip this tick; the tree clears it shortly
	var c: int = safe[_rng.randi() % safe.size()]
	var land := _bottom_empty(c)
	var line: int = _cfg.lines[_rng.randi() % (_cfg.lines as Array).size()]
	var tier := 2 if _rng.randf() < float(_cfg.t2) else 1
	_grid[land][c] = {"kind": line, "tier": tier, "node": _make_tile(line, tier, land, c)}
	if Explore.board_full(_grid):
		_end()

func _bottom_empty(c: int) -> int:
	for r in range(G.ROWS - 1, -1, -1):
		if _grid[r][c] == null:
			return r
	return -1

# --- tap: merge a match, else fling ----------------------------------------------
func _on_tile(node: Control) -> void:
	if not _running:
		return
	var rc := _coord_of(node)
	if rc.x < 0:
		return
	var cell: Dictionary = _grid[rc.x][rc.y]
	if int(cell.tier) < Explore.MAX_TIER:
		var m := Explore.neighbor_match(_grid, rc.x, rc.y)
		if m.x >= 0:
			_merge(rc, m)
			return
	_fling(rc)

func _merge(win_rc: Vector2i, lose_rc: Vector2i) -> void:
	var win: Dictionary = _grid[win_rc.x][win_rc.y]
	var lose: Dictionary = _grid[lose_rc.x][lose_rc.y]
	(lose.node as Node).queue_free()
	_grid[lose_rc.x][lose_rc.y] = null
	win.tier = int(win.tier) + 1
	win.kind = _cfg.lines[_rng.randi() % (_cfg.lines as Array).size()]   # the result rerolls to a random line
	_paint(win)
	_combo = Explore.combo_after(_combo, _elapsed - _last_merge)
	_last_merge = _elapsed
	var pre_mult := _mult
	_mult = Explore.mult_after_merge(_mult, int(win.tier))
	var pts := Explore.merge_points(int(win.tier), _mult)
	Explore.add_score(pts)
	# JUICE: the result tile squash-pops + the points float up (always); the toggleable rush_fx layer adds
	# the leaf burst, the score / mult cell pops, and the heating combo callout.
	var node := win.node as Control
	var ctr := node.global_position + Vector2(_cell, _cell) / 2.0
	FX.squash_pop(node)
	FX.floating_text(self, ctr, "+%d" % pts, PARCH, 22)
	if RushFx.on(_fx, "merge_burst"):
		RushFx.merge_burst(self, ctr, int(win.tier), RushFx.knob(_fx, "merge_burst_count"))
	if RushFx.on(_fx, "score_pulse"):
		RushFx.cell_pop(_score_cell, RushFx.knob(_fx, "score_pulse_pct"))
	if RushFx.on(_fx, "mult_pop") and _mult > pre_mult + 0.001:
		RushFx.cell_pop(_mult_cell, RushFx.knob(_fx, "mult_pop_pct"))
	if _combo >= 3:
		if RushFx.on(_fx, "combo_heat"):
			RushFx.combo_heat(self, ctr - Vector2(0, 42), _combo, RushFx.knob(_fx, "combo_heat_size"))
		else:
			FX.floating_text(self, ctr - Vector2(0, 42), "COMBO ×%d" % _combo, GOLD, 26)
	if int(win.tier) >= 4:
		FX.flash(_board, node.position + Vector2(_cell, _cell) / 2.0, _cell)
		FX.celebrate_at(self, ctr - Vector2(0, 74), "BUILD!", STRAW)
		FX.hitstop(0.05)
	Audio.play("button_tap", -3.0)
	# the score updates here only (it changes on merge); tick it up or snap it per the toggle
	if RushFx.on(_fx, "score_tick"):
		RushFx.score_tick(_lbl_score, Explore.score(), RushFx.knob(_fx, "score_tick_ms"))
	elif _lbl_score != null:
		_lbl_score.text = str(Explore.score())
	_settle()
	_refresh_readouts()

func _fling(rc: Vector2i) -> void:
	var danger := int(_tf.col) if String(_tf.ph) == "tele" else -1
	var tgt := Explore.fling_target(_grid, rc.y, danger, _rng)
	if tgt < 0:
		return
	var cell: Dictionary = _grid[rc.x][rc.y]
	var node := cell.node as Control
	var start := node.position                      # where the tile is now (its old column)
	_grid[rc.x][rc.y] = null
	_grid[_bottom_empty(tgt)][tgt] = cell
	_settle(node)                                   # settle every OTHER tile (the source column falls); the toss owns this one
	var fc := _coord_of(node)                       # the flung tile's new resting cell
	_fly_to(node, start, _cell_rest(fc.x, fc.y))
	Audio.play("button_tap", -5.0, 1.2)             # a light toss tick

# --- treefall --------------------------------------------------------------------
func _start_timber() -> void:
	_tf.ph = "tele"
	_tf.t = 0.0
	_tf.col = _rng.randi() % G.COLS
	_apply_treefall_visual()

func _drop_timber() -> void:
	var col := int(_tf.col)
	var hits := Explore.timber_hits(_grid, col)
	for r in G.ROWS:
		var cell = _grid[r][col]
		if cell != null:
			(cell.node as Node).queue_free()
			_grid[r][col] = null
	# JUICE: the board jolts when the timber lands; a clean dodge celebrates, a hit flashes the column.
	var col_local := Vector2(_cellxy(0, col).x + _cell * 0.5, float(G.ROWS) * (_cell + _gap) * 0.5)
	if RushFx.on(_fx, "treefall_crack"):
		RushFx.treefall_crack(
				self, _board, _board.global_position + col_local, false,
				RushFx.knob(_fx, "treefall_debris"),
				float(RushFx.knob(_fx, "treefall_shake")),
				RushFx.knob(_fx, "treefall_hitstop_ms"))   # debris + heavier jolt + crack
	else:
		FX.shake(_board)
	if hits == 0 and _running:
		_mult = Explore.clean_dodge_mult(_mult)      # clean dodge — emptied the column in time
		FX.celebrate_at(self, _board.global_position + col_local, "CLEAN DODGE!", GOLD)
	else:
		FX.flash(_board, col_local, _cell)
	_tf.ph = "idle"
	_tf.t = 0.0
	_tf.next = (7.0 + _rng.randf() * 3.0) * float(_cfg.calm_mul)
	_apply_treefall_visual()
	_settle()
	_refresh_readouts()

# --- grid <-> nodes --------------------------------------------------------------
func _settle(except: Control = null) -> void:
	Explore.gravity(_grid)
	for r in G.ROWS:
		for c in G.COLS:
			var cell = _grid[r][c]
			if cell != null:
				var node := cell.node as Control
				if node == except:
					continue                                # the fling toss owns this tile's motion
				var rest := _cell_rest(r, c)
				if node.position.y < rest.y - 1.0:
					_fall_to(node, rest, node.position.y)   # a cleared tile DROPS into the gap (gravity)
				else:
					node.position = rest                    # already settled / a same-row or sideways move

# A flung tile TOSSES in an arc from `start` to its new resting cell `dest` — up-and-over with a slight
# spin, then a gravity drop and a small landing squash. The board's other tiles settle separately.
func _fly_to(node: Control, start: Vector2, dest: Vector2) -> void:
	if not (node and is_instance_valid(node)):
		return
	node.position = start
	node.pivot_offset = node.size * 0.5
	var span := absf(dest.x - start.x)
	var peak := Vector2((start.x + dest.x) * 0.5, minf(start.y, dest.y) - maxf(_cell * 0.7, span * 0.28))
	var spin := deg_to_rad(22.0) * (1.0 if dest.x >= start.x else -1.0)
	var t := node.create_tween()
	t.tween_property(node, "position", peak, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(node, "rotation", spin, 0.16).set_trans(Tween.TRANS_SINE)
	t.tween_property(node, "position", dest, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(node, "rotation", 0.0, 0.18).set_trans(Tween.TRANS_SINE)
	t.tween_property(node, "scale", Vector2(1.16, 0.84), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _coord_of(node: Control) -> Vector2i:
	for r in G.ROWS:
		for c in G.COLS:
			var cell = _grid[r][c]
			if cell != null and cell.node == node:
				return Vector2i(r, c)
	return Vector2i(-1, -1)

func _make_tile(line: int, tier: int, r: int, c: int) -> Control:
	var b := Button.new()
	b.flat = true
	b.custom_minimum_size = Vector2(_tile_px(), _tile_px())
	b.size = Vector2(_tile_px(), _tile_px())
	b.position = _cell_rest(r, c)
	var empty := StyleBoxEmpty.new()      # transparent surface — the merge-piece art IS the tile
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, empty)
	b.pressed.connect(func() -> void: _on_tile(b))
	_board.add_child(b)
	var cell := {"kind": line, "tier": tier, "node": b}
	_paint(cell)
	_fall_to(b, b.position, -_cell)   # JUICE: the trace FALLS in from the top of the board (not a pop-in)
	return b

# A tile FALLS from `from_y` to its resting cell `rest`, accelerating like gravity, with a small squash on
# impact — used for freshly-spawned traces (from above the board) and for tiles settling down after a clear.
func _fall_to(node: Control, rest: Vector2, from_y: float) -> void:
	if not (node and is_instance_valid(node)):
		return
	node.position = Vector2(rest.x, from_y)
	node.pivot_offset = node.size * 0.5
	var dist := maxf(0.0, rest.y - from_y)
	var dur := clampf(0.10 + dist / maxf(1.0, _cell * float(G.ROWS)) * 0.24, 0.10, 0.36)
	var t := node.create_tween()
	t.tween_property(node, "position:y", rest.y, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(node, "scale", Vector2(1.14, 0.86), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## (Re)render a tile as the home board's merge piece for its line+tier (code = line*100 + tier).
func _paint(cell: Dictionary) -> void:
	var b := cell.node as Button
	if b == null:
		return
	for ch in b.get_children():
		ch.queue_free()                  # drop the old piece (e.g. after a tier-up reroll)
	var piece := PieceView.make_piece(int(cell.kind) * 100 + int(cell.tier), _tile_px())
	piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(piece)

# --- end -------------------------------------------------------------------------
func _end() -> void:
	if not _running:
		return
	_running = false
	set_process(false)
	# Explore.run() already holds the accrued score (added per merge); reveal the reward ON TOP of the
	# frozen board (a modal overlay, not a scene change). Done returns to the Map.
	ExploreReward.open(self, {})

# --- readouts / widgets ----------------------------------------------------------
func _refresh_readouts() -> void:
	if _lbl_time != null:
		var s := int(ceil(_time))
		_lbl_time.text = "0:%02d" % s
		if s != _last_sec:                          # once per whole second: drive the low-time urgency
			_last_sec = s
			if RushFx.on(_fx, "timer_low"):
				RushFx.timer_low(_lbl_time, s, false, RushFx.knob(_fx, "timer_low_secs"))
	# the score is updated in _merge (it only changes there); leaving it out here lets it TICK uninterrupted
	if _lbl_mult != null:
		_lbl_mult.text = "×%.1f" % _mult
	# the treefall countdown: "Ns" + the draining bar, while a tree is telegraphed
	if _act_warn != null and is_instance_valid(_act_warn) and _act_warn.visible:
		var remain := maxf(0.0, Explore.WARN - float(_tf.get("t", 0.0)))
		if _act_label != null:
			_act_label.text = "%ds" % int(ceil(remain))
		if _act_fill != null:
			_act_fill.size.x = _act_fill_w * clampf(remain / maxf(0.01, Explore.WARN), 0.0, 1.0)

func _fmt_time() -> String:
	return "0:%02d" % int(ceil(_time))

func _label(text: String, size: int, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", INK)          # dark text reads crisply on the light meadow board
	if bold:
		l.add_theme_color_override("font_outline_color", PARCH)
		l.add_theme_constant_override("outline_size", 3)
	return l
