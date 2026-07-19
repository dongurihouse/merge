extends RefCounted
## The RESIDENTS management dialog (resident_management_dialog_v2 mock) — opened from the home
## screen's Residents rail tile. One modal sheet over the map:
##   · RESOURCE BANKS — a 2×2 grid of per-line bank cards (icon · name · n/cap · progress · full-in)
##   · COLLECT ALL   — the single collection action (no per-card collect buttons)
##   · HABITAT CELLS — one row: placed spirits · free cells · locked cells
##   · ON HAND       — the scrollable 4-column hand grid (tap to select)
##   · the bottom INSPECTOR — the selected spirit's portrait · name · info · SELL
## The MODEL is entirely engine/scripts/core/bucket.gd; this file is render + taps only.
## Layering: ui/ may import core/ + ui/, never scenes/. The kit is loaded by PATH at runtime
## (the settings.gd/inbox.gd idiom) so this file keeps no hard dependency on a tools script.

const Save = preload("res://engine/scripts/core/save.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const G = preload("res://engine/scripts/core/content.gd")
const Bucket = preload("res://engine/scripts/core/bucket.gd")
const RB = preload("res://engine/scripts/core/resident_bucket.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")
const Overlay = preload("res://engine/scripts/ui/overlay.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const FS = preload("res://engine/scripts/core/tuning.gd").FontScale
const Pal = Game.PALETTE
const D = Game.DATA

const OVERLAY_NAME := "ResidentsOverlay"
const KIT_PATH := "res://games/grove/tools/ui_workbench_kit.gd"
const HAND_COLS := 4
const HABITAT_SLOTS_SHOWN := 5      # the mock's fixed row: granted cells first, the rest locked

# Per-line chrome: icon id + display name + the bank bar's fill colour (Meadow Sky roles).
const LINE_FACE := {
	"coin":    {"icon": "coin",  "label": "Coins",    "fill": Color("#D6A94C")},
	"water":   {"icon": "water", "label": "Water",    "fill": Color("#6FA9C0")},
	"boost":   {"icon": "star",  "label": "Boost",    "fill": Color("#5F9B6D")},
	"diamond": {"icon": "gem",   "label": "Diamonds", "fill": Color("#8677A3")},
}

## Open the dialog. opts: refresh (Callable — the host re-reads wallet/badges after collect/sell),
## on_info (Callable(kind, tier) — the host opens the resident tier ladder).
static func open(host: Control, opts: Dictionary = {}) -> void:
	if Overlay.is_open(host, OVERLAY_NAME):
		return
	var Kit: GDScript = load(KIT_PATH)
	if Kit == null:
		push_warning("Residents: mail kit missing at %s" % KIT_PATH)
		return
	Audio.play("button_tap", -2.0)

	var overlay := Overlay.mount(host, OVERLAY_NAME)
	var veil := ColorRect.new()
	veil.color = Color(Pal.INK, 0.6)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(veil)
	veil.gui_input.connect(func(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
			overlay.queue_free())
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(cc)

	var cfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH)
	var vw: float = host.get_viewport_rect().size.x
	var width: float = vw * Kit.DIALOG_DESIGN_PCT["residents"] / 100.0
	# the CONTENT lays out at the design width MINUS the sheet's insets (the frame scales it by
	# content_scale, so the pads count at 1/scale in layout space) — sized against `width` alone the
	# fixed-size cards overflow the sheet's right edge.
	var scale: float = maxf(0.01, Kit.dialog_content_scale(cfg, "residents"))
	var inner: float = width - 2.0 * float(Kit.frame_border("parchment")["pad_x"]) / scale

	# session view-state shared by every rebuild: the selected spirit {src: "hand"|"placed", idx}.
	var view := {"sel": {}}
	var body := VBoxContainer.new()
	body.name = "ResidentsBody"
	body.add_theme_constant_override("separation", 14)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rebuild(body, Kit, cfg, inner, view, overlay, opts)

	var fopts: Dictionary = Kit.dialog_opts_from_config(cfg)
	fopts["banner_text"] = "Residents"
	fopts["content_scale"] = Kit.dialog_content_scale(cfg, "residents")
	fopts["list_max_h"] = host.get_viewport_rect().size.y * 0.72
	fopts["on_close"] = func() -> void:
		if is_instance_valid(overlay):
			overlay.queue_free()
	var dialog: Control = Kit.dialog_frame(body, width, fopts)
	cc.add_child(dialog)
	FX.pop_in(dialog)

## Repaint the whole body from the live bucket state (collect / sell / select all land here).
static func _rebuild(body: VBoxContainer, Kit: GDScript, cfg: Dictionary, width: float,
		view: Dictionary, overlay: Control, opts: Dictionary) -> void:
	# queue_free (not free): a repaint fires from INSIDE a child button's pressed signal — freeing the
	# emitting button mid-emission is an error, so detach now and let the tree reap it.
	for ch in body.get_children():
		body.remove_child(ch)
		ch.queue_free()
	var refresh_host: Callable = opts.get("refresh", Callable())
	var repaint := func() -> void:
		if is_instance_valid(body):
			_rebuild(body, Kit, cfg, width, view, overlay, opts)
		if refresh_host.is_valid():
			refresh_host.call()

	# --- RESOURCE BANKS: the 2×2 mini bank cards + the one Collect-all action -----------------------
	body.add_child(_section_label("Resource banks"))
	var banks := GridContainer.new()
	banks.name = "ResourceBanksGrid"
	banks.columns = 2
	banks.add_theme_constant_override("h_separation", 12)
	banks.add_theme_constant_override("v_separation", 12)
	banks.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ready_total := 0
	for line in Bucket.LINES:
		var rep: Dictionary = Bucket.line_report(String(line))
		ready_total += int(rep.ready)
		banks.add_child(_bank_card(Kit, String(line), rep, (width - 12.0) * 0.5))
	body.add_child(banks)

	var collect: Button = Kit.cta_button("Collect all", {"btn": Kit.card_btn_opts(cfg)})
	collect.name = "CollectAllButton"
	collect.disabled = ready_total <= 0
	collect.pressed.connect(func() -> void:
		Audio.play("button_tap", -2.0)
		Bucket.collect()
		repaint.call())
	var crow := HBoxContainer.new()
	crow.alignment = BoxContainer.ALIGNMENT_CENTER
	crow.add_child(collect)
	body.add_child(crow)

	# --- HABITAT CELLS: granted cells (placed spirits first, then free), locked to the mock's row ---
	body.add_child(_section_label("Habitat cells"))
	var bag_opts: Dictionary = Kit.bag_card_opts_from_config(cfg)
	var placed: Array = Bucket.placed()
	var cells_total: int = Bucket.cells_total()
	var slots: int = maxi(HABITAT_SLOTS_SHOWN, cells_total)
	var cell_px: float = (width - 10.0 * float(slots - 1)) / float(slots)
	var cbag: Dictionary = bag_opts.duplicate(true)
	cbag["cell_w"] = cell_px
	cbag["cell_h"] = cell_px
	var cells := HBoxContainer.new()
	cells.name = "HabitatCellsRow"
	cells.add_theme_constant_override("separation", 10)
	cells.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in slots:
		var cell: Control
		if i < placed.size():
			var inst: Dictionary = placed[i]
			var idx := i
			cell = _spirit_card(Kit, cbag, String(inst.line), int(inst.tier), cell_px,
				_is_sel(view, "placed", i), func() -> void:
					view["sel"] = {"src": "placed", "idx": idx}
					repaint.call())
			cell.name = "HabitatCell_%02d" % i
		elif i < cells_total:
			cell = Kit.slot_cell({"state": "empty"}, cbag)
			cell.name = "HabitatCellFree_%02d" % i
		else:
			cell = Kit.slot_cell({"state": "locked"}, cbag)
			cell.name = "HabitatCellLocked_%02d" % i
		cell.custom_minimum_size = Vector2(cell_px, cell_px)
		cells.add_child(cell)
	body.add_child(cells)

	# --- ON HAND: the 4-column tap-to-select grid ---------------------------------------------------
	body.add_child(_section_label("On hand"))
	var hand: Array = Bucket.hand()
	var hand_px: float = (width - 10.0 * float(HAND_COLS - 1)) / float(HAND_COLS)
	var hbag: Dictionary = bag_opts.duplicate(true)
	hbag["cell_w"] = hand_px
	hbag["cell_h"] = hand_px
	var grid := GridContainer.new()
	grid.name = "OnHandGrid"
	grid.columns = HAND_COLS
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for i in hand.size():
		var inst: Dictionary = hand[i]
		var idx := i
		var card := _spirit_card(Kit, hbag, String(inst.line), int(inst.tier), hand_px,
			_is_sel(view, "hand", i), func() -> void:
				view["sel"] = {"src": "hand", "idx": idx}
				repaint.call())
		card.name = "OnHandCard_%02d" % i
		grid.add_child(card)
	for _e in range(hand.size(), maxi(hand.size(), HAND_COLS)):
		grid.add_child(Kit.slot_cell({"state": "empty"}, hbag))
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(grid)

	# --- the INSPECTOR: selected portrait · name · info · SELL --------------------------------------
	body.add_child(_inspector(Kit, cfg, width, view, repaint, opts))

## One RESOURCE BANK mini card: icon + name + "n / cap" + the line-coloured bar + the state line.
## A full bank wears the reward-gold rim (the mock's completed-bank accent).
static func _bank_card(Kit: GDScript, line: String, rep: Dictionary, w: float) -> Control:
	var face: Dictionary = LINE_FACE.get(line, {})
	var full := bool(rep.full)
	var card := PanelContainer.new()
	card.name = "ResourceBankCard_" + line
	var sb := StyleBoxFlat.new()
	sb.bg_color = Pal.CREAM.darkened(0.03)
	sb.set_corner_radius_all(16)
	sb.set_border_width_all(3 if full else 2)
	sb.border_color = Pal.STRAW if full else Color(Pal.BARK, 0.25)
	sb.content_margin_left = 12; sb.content_margin_right = 12
	sb.content_margin_top = 10; sb.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(w, 0)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	var icon: Control = Kit.make_icon(String(face.get("icon", "leaf")), 44.0)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(icon)
	var tcol := VBoxContainer.new()
	tcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := Label.new()
	nm.text = String(face.get("label", line)).to_upper()
	nm.add_theme_font_size_override("font_size", FS.SMALL)
	nm.add_theme_color_override("font_color", Pal.INK)
	nm.add_theme_constant_override("outline_size", 0)
	tcol.add_child(nm)
	var val := Label.new()
	val.name = "ResourceBankValue_" + line
	val.text = "%d / %d" % [int(floor(float(rep.pending))), int(round(float(rep.cap)))]
	val.add_theme_font_size_override("font_size", FS.EMPHASIS)
	val.add_theme_color_override("font_color", Pal.INK)
	val.add_theme_constant_override("outline_size", 0)
	tcol.add_child(val)
	top.add_child(tcol)
	col.add_child(top)

	var frac := clampf(float(rep.pending) / maxf(float(rep.cap), 0.001), 0.0, 1.0)
	var bar: Control = Kit.progress_bar(frac, {
		"height": 16.0, "width": w - 24.0, "art": false,
		"fill_color": face.get("fill", Pal.STRAW),
	})
	bar.name = "ResourceBankBar_" + line
	col.add_child(bar)

	var state := Label.new()
	state.name = "ResourceBankState_" + line
	state.text = _bank_state_text(line, rep)
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state.add_theme_font_size_override("font_size", FS.TINY)
	state.add_theme_color_override("font_color", Color(Pal.INK, 0.85))
	state.add_theme_constant_override("outline_size", 0)
	col.add_child(state)
	card.add_child(col)
	return card

## The bank's state line: "FULL" · "FULL IN 2H 18M" (rate-derived) · "IDLE" (nothing producing).
static func _bank_state_text(line: String, rep: Dictionary) -> String:
	if bool(rep.full):
		return "FULL"
	var rate := RB.rate(Bucket.state(), line)
	if rate <= 0.0:
		return "IDLE"
	var hours := (float(rep.cap) - float(rep.pending)) / rate
	var mins := int(ceil(hours * 60.0))
	if mins >= 60:
		return "FULL IN %dH %dM" % [mins / 60, mins % 60]
	return "FULL IN %dM" % maxi(mins, 1)

## A tappable spirit card: the shared slot cell + the spirit's per-tier art + a tier badge; the
## selected card wears an ink rim.
static func _spirit_card(Kit: GDScript, bag_opts: Dictionary, line: String, tier: int, px: float,
		selected: bool, on_tap: Callable) -> Control:
	var kind := Bucket.line_kind(line)
	var cell: Control = Kit.slot_cell({"state": "filled", "on_tap": on_tap,
		"make_content": func(pp: float) -> Control: return _spirit_art(kind, tier, pp)}, bag_opts)
	cell.custom_minimum_size = Vector2(px, px)
	var badge := Label.new()
	badge.name = "SpiritTierBadge"
	badge.text = str(tier)
	badge.add_theme_font_size_override("font_size", FS.TINY)
	badge.add_theme_color_override("font_color", Pal.CREAM)
	badge.add_theme_constant_override("outline_size", 0)
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(Pal.BARK, 0.9)
	bsb.set_corner_radius_all(9)
	bsb.content_margin_left = 7; bsb.content_margin_right = 7
	bsb.content_margin_top = 1; bsb.content_margin_bottom = 1
	var bp := PanelContainer.new()
	bp.add_theme_stylebox_override("panel", bsb)
	bp.add_child(badge)
	bp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(bp)
	var dock := func() -> void:
		if is_instance_valid(bp) and is_instance_valid(cell):
			bp.position = Vector2((cell.size.x - bp.size.x) * 0.5, cell.size.y - bp.size.y - 4.0)
	bp.resized.connect(dock)
	cell.resized.connect(dock)
	if selected:
		var rim := Panel.new()
		rim.name = "SpiritSelectedRim"
		var rsb := StyleBoxFlat.new()
		rsb.bg_color = Color(0, 0, 0, 0)
		rsb.set_border_width_all(4)
		rsb.border_color = Pal.INK
		rsb.set_corner_radius_all(14)
		rim.add_theme_stylebox_override("panel", rsb)
		rim.set_anchors_preset(Control.PRESET_FULL_RECT)
		rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(rim)
	return cell

## The spirit's per-tier ladder art, centred in its box (trimmed to the used rect by content.gd).
static func _spirit_art(kind: String, tier: int, px: float) -> Control:
	var t := TextureRect.new()
	t.custom_minimum_size = Vector2(px, px)
	t.size = Vector2(px, px)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art := G.resident_art(kind, tier)
	if art != "" and ResourceLoader.exists(art):
		t.texture = load(art)
	return t

## The bottom inspector: the selected spirit's portrait + name + info (tier ladder) + SELL — or a
## quiet hint when nothing is selected.
static func _inspector(Kit: GDScript, cfg: Dictionary, width: float, view: Dictionary,
		repaint: Callable, opts: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.name = "ResidentsInspector"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Pal.CREAM.darkened(0.03)
	sb.set_corner_radius_all(16)
	sb.set_border_width_all(2)
	sb.border_color = Color(Pal.BARK, 0.25)
	sb.content_margin_left = 12; sb.content_margin_right = 12
	sb.content_margin_top = 10; sb.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(width, 0)

	var sel: Dictionary = view.get("sel", {})
	var inst := _sel_inst(sel)
	if inst.is_empty():
		var hint := Label.new()
		hint.name = "ResidentsInspectorHint"
		hint.text = "Tap a resident"
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.add_theme_font_size_override("font_size", FS.SMALL)
		hint.add_theme_color_override("font_color", Color(Pal.INK, 0.65))
		hint.add_theme_constant_override("outline_size", 0)
		card.add_child(hint)
		return card

	var line := String(inst.line)
	var tier := int(inst.tier)
	var kind := Bucket.line_kind(line)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var portrait := _spirit_art(kind, tier, 56.0)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(portrait)
	var nm := Label.new()
	nm.name = "ResidentsInspectorName"
	nm.text = "%s · T%d" % [_kind_name(kind), tier]
	nm.add_theme_font_size_override("font_size", FS.EMPHASIS)
	nm.add_theme_color_override("font_color", Pal.INK)
	nm.add_theme_constant_override("outline_size", 0)
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(nm)
	var on_info: Callable = opts.get("on_info", Callable())
	if on_info.is_valid():
		var info := Button.new()
		info.name = "ResidentsInfoButton"
		info.flat = true
		info.focus_mode = Control.FOCUS_NONE
		var empty := StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			info.add_theme_stylebox_override(st, empty)
		info.custom_minimum_size = Vector2(40, 40)
		var ii: Control = Kit.make_icon("info", 34.0)
		ii.position = Vector2(3, 3)
		ii.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.add_child(ii)
		info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		info.pressed.connect(func() -> void: on_info.call(kind, tier))
		row.add_child(info)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)
	# SELL — the coral-outline pill (mock): pays SELL_PER_TIER × tier and frees the slot.
	var sell := Button.new()
	sell.name = "ResidentsSellButton"
	sell.text = "Sell +%d" % (Bucket.SELL_PER_TIER * tier)
	sell.focus_mode = Control.FOCUS_NONE
	sell.add_theme_font_size_override("font_size", FS.SMALL)
	sell.add_theme_color_override("font_color", Pal.CLAY)
	sell.add_theme_constant_override("outline_size", 0)
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Pal.CREAM
	ssb.set_corner_radius_all(14)
	ssb.set_border_width_all(3)
	ssb.border_color = Pal.CLAY
	ssb.content_margin_left = 16; ssb.content_margin_right = 16
	ssb.content_margin_top = 6; ssb.content_margin_bottom = 6
	for st in ["normal", "hover", "pressed", "focus"]:
		sell.add_theme_stylebox_override(st, ssb)
	sell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sell.pressed.connect(func() -> void:
		Audio.play("button_tap", -2.0)
		if String(sel.get("src", "")) == "placed":
			Bucket.sell_placed(int(sel.get("idx", -1)))
		else:
			Bucket.sell_hand(int(sel.get("idx", -1)))
		view["sel"] = {}
		repaint.call())
	row.add_child(sell)
	card.add_child(row)
	return card

# --- small helpers --------------------------------------------------------------------------------
static func _section_label(text: String) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", FS.SMALL)
	l.add_theme_color_override("font_color", Pal.INK)
	l.add_theme_constant_override("outline_size", 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func _is_sel(view: Dictionary, src: String, idx: int) -> bool:
	var sel: Dictionary = view.get("sel", {})
	return String(sel.get("src", "")) == src and int(sel.get("idx", -1)) == idx

## The live instance behind the selection — {} when the selection is stale (sold/moved under it).
static func _sel_inst(sel: Dictionary) -> Dictionary:
	var idx := int(sel.get("idx", -1))
	match String(sel.get("src", "")):
		"hand":
			var h := Bucket.hand()
			return h[idx] if idx >= 0 and idx < h.size() else {}
		"placed":
			var p := Bucket.placed()
			return p[idx] if idx >= 0 and idx < p.size() else {}
	return {}

## The spirit family's display name (grove_data.RESIDENT_LINES carries {id, name} per map).
static func _kind_name(kind: String) -> String:
	for ln in D.RESIDENT_LINES.values():
		if String(ln.get("id", "")) == kind:
			return String(ln.get("name", kind))
	return kind.capitalize()
