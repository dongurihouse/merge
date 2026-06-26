extends Control
## Explore · Rush — beat 2 of the acquire ritual: a timed merge-for-score game on a throwaway grid.
## Traces rain in automatically (no Water); TAP a tile to merge a matching neighbour (the result rerolls
## to a random line) or, with no match, to FLING it to a safe column; a telegraphed TREEFALL periodically
## destroys a column (empty it first for a clean-dodge multiplier). Two clocks end the run — the countdown
## or a full board. Score accrues into the run state (Explore.add_score) and the run hands off to Trade.
##
## The decision logic is core/explore.gd (pure, tested); this script is the real-time orchestration +
## simple tile visuals. Numbers are the feel-prototype's provisional values (Rush sim retunes later).

const G = preload("res://engine/scripts/core/content.gd")
const Explore = preload("res://engine/scripts/core/explore.gd")
const SceneWarm = preload("res://engine/scripts/core/scene_warm.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")

const INK := Color("#43352B")
const PARCH := Color("#F3E7CE")
const KIND_COLOR := {"leaf": Color("#5BBF7A"), "petal": Color("#E06AA6"), "pebble": Color("#8EA2B0")}

var _cfg: Dictionary = {}
var _grid: Array = []            # [ROWS][COLS] of {kind,tier,node} or null
var _board: Control = null
var _tele: ColorRect = null
var _cell := 64.0
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

func _ready() -> void:
	_rng.randomize()
	if Explore.run().is_empty():
		Explore.begin_run({})        # direct-open (tool/test) — neutral loadout
	_cfg = Explore.rush_cfg(Explore.run().get("equip", {}))

	var bg := ColorRect.new()
	bg.color = Color("#2C3A2E")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_build_topbar()
	_build_board()
	_start()

func _build_topbar() -> void:
	var bar := HBoxContainer.new()
	bar.position = Vector2(24, 60)
	bar.add_theme_constant_override("separation", 28)
	add_child(bar)
	_lbl_time = _label("0:00", 30, true)
	_lbl_score = _label("0", 30, true)
	_lbl_mult = _label("×1.0", 30, true)
	bar.add_child(_chip("Time", _lbl_time))
	bar.add_child(_chip("Score", _lbl_score))
	bar.add_child(_chip("Mult", _lbl_mult))
	var Kit: GDScript = load("res://games/grove/tools/ui_workbench_kit.gd")
	var giveup: Button = Kit.pill_button("End", {"bg": "cream", "art": true, "font": 18})
	giveup.position = Vector2(24, 140)
	giveup.pressed.connect(func() -> void: _end())
	add_child(giveup)

func _build_board() -> void:
	var vp := get_viewport_rect().size
	var vw: float = vp.x if vp.x > 0.0 else 720.0
	var vh: float = vp.y if vp.y > 0.0 else 1280.0
	var top := 200.0
	var avail_w := vw * 0.96
	var avail_h := vh - top - 40.0
	# size cells to fill the screen on whichever axis binds (the board is 7×9, taller than wide)
	_cell = floor(minf(avail_w / float(G.COLS), avail_h / float(G.ROWS)))
	var bw := _cell * float(G.COLS)
	var bh := _cell * float(G.ROWS)
	_board = Control.new()
	_board.position = Vector2((vw - bw) / 2.0, top + maxf(0.0, (avail_h - bh) / 2.0))
	_board.custom_minimum_size = Vector2(bw, bh)
	add_child(_board)
	# a darker backing so the play area reads as a distinct board region
	var pad := ColorRect.new()
	pad.color = Color(0, 0, 0, 0.22)
	pad.size = Vector2(bw, bh)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.add_child(pad)
	# faint slot cells so the 7×9 grid reads even when sparse
	for r in G.ROWS:
		for c in G.COLS:
			var slot := Panel.new()
			slot.position = Vector2(_cell * c + 2.0, _cell * r + 2.0)
			slot.size = Vector2(_cell - 4.0, _cell - 4.0)
			var ss := StyleBoxFlat.new()
			ss.bg_color = Color(1, 1, 1, 0.04)
			ss.set_corner_radius_all(8)
			ss.border_color = Color(1, 1, 1, 0.07)
			ss.set_border_width_all(1)
			slot.add_theme_stylebox_override("panel", ss)
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_board.add_child(slot)
	# the treefall telegraph (a translucent danger pane over one column)
	_tele = ColorRect.new()
	_tele.color = Color(0.85, 0.25, 0.2, 0.32)
	_tele.size = Vector2(_cell, bh)
	_tele.visible = false
	_tele.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.add_child(_tele)

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
	_mult = Explore.mult_decay(_mult, dt)
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
	var cols := []
	for c in G.COLS:
		if Explore.column_fill(_grid, c) < G.ROWS:
			cols.append(c)
	if cols.is_empty():
		_end()
		return
	var c: int = cols[_rng.randi() % cols.size()]
	var land := _bottom_empty(c)
	var kind: String = _cfg.lines[_rng.randi() % (_cfg.lines as Array).size()]
	var tier := 2 if _rng.randf() < float(_cfg.t2) else 1
	_grid[land][c] = {"kind": kind, "tier": tier, "node": _make_tile(kind, tier, land, c)}
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
	_mult = Explore.mult_after_merge(_mult, int(win.tier))
	Explore.add_score(Explore.merge_points(int(win.tier), _mult))
	Audio.play("button_tap", -3.0)
	_settle()
	_refresh_readouts()

func _fling(rc: Vector2i) -> void:
	var danger := int(_tf.col) if String(_tf.ph) == "tele" else -1
	var tgt := Explore.fling_target(_grid, rc.y, danger, _rng)
	if tgt < 0:
		return
	var cell: Dictionary = _grid[rc.x][rc.y]
	_grid[rc.x][rc.y] = null
	_grid[_bottom_empty(tgt)][tgt] = cell
	_settle()

# --- treefall --------------------------------------------------------------------
func _start_timber() -> void:
	_tf.ph = "tele"
	_tf.t = 0.0
	_tf.col = _rng.randi() % G.COLS
	_tele.position = Vector2(_cell * int(_tf.col), 0)
	_tele.visible = true

func _drop_timber() -> void:
	var col := int(_tf.col)
	var hits := Explore.timber_hits(_grid, col)
	for r in G.ROWS:
		var cell = _grid[r][col]
		if cell != null:
			(cell.node as Node).queue_free()
			_grid[r][col] = null
	if hits == 0 and _running:
		_mult = Explore.clean_dodge_mult(_mult)      # clean dodge — emptied the column in time
	_tele.visible = false
	_tf.ph = "idle"
	_tf.t = 0.0
	_tf.next = (7.0 + _rng.randf() * 3.0) * float(_cfg.calm_mul)
	_settle()
	_refresh_readouts()

# --- grid <-> nodes --------------------------------------------------------------
func _settle() -> void:
	Explore.gravity(_grid)
	for r in G.ROWS:
		for c in G.COLS:
			var cell = _grid[r][c]
			if cell != null:
				(cell.node as Control).position = Vector2(_cell * c + 3.0, _cell * r + 3.0)

func _coord_of(node: Control) -> Vector2i:
	for r in G.ROWS:
		for c in G.COLS:
			var cell = _grid[r][c]
			if cell != null and cell.node == node:
				return Vector2i(r, c)
	return Vector2i(-1, -1)

func _make_tile(kind: String, tier: int, r: int, c: int) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(_cell - 6.0, _cell - 6.0)
	b.size = Vector2(_cell - 6.0, _cell - 6.0)
	b.position = Vector2(_cell * c + 3.0, _cell * r + 3.0)
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", INK)
	b.pressed.connect(func() -> void: _on_tile(b))
	_board.add_child(b)
	var cell := {"kind": kind, "tier": tier, "node": b}
	_paint(cell)
	return b

## Repaint a tile's colour (by kind) and tier number from its cell dict.
func _paint(cell: Dictionary) -> void:
	var b := cell.node as Button
	if b == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = KIND_COLOR.get(String(cell.kind), Color("#CDBD99"))
	sb.set_corner_radius_all(10)
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	b.text = str(int(cell.tier))

# --- end -------------------------------------------------------------------------
func _end() -> void:
	if not _running:
		return
	_running = false
	set_process(false)
	# Explore.run() already holds the accrued score (added per merge); hand off to Trade.
	SceneWarm.go(get_tree(), "res://engine/scenes/ExploreTrade.tscn")

# --- readouts / widgets ----------------------------------------------------------
func _refresh_readouts() -> void:
	if _lbl_time != null:
		var s := int(ceil(_time))
		_lbl_time.text = "0:%02d" % s
	if _lbl_score != null:
		_lbl_score.text = str(Explore.score())
	if _lbl_mult != null:
		_lbl_mult.text = "×%.1f" % _mult

func _chip(caption: String, value: Label) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	var cap := _label(caption, 16)
	cap.modulate = Color(1, 1, 1, 0.65)
	box.add_child(cap)
	box.add_child(value)
	return box

func _label(text: String, size: int, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", PARCH)
	if bold:
		l.add_theme_color_override("font_outline_color", INK)
		l.add_theme_constant_override("outline_size", 3)
	return l
