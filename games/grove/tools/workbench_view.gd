@tool
extends Control
## Workbench base — the shared gallery + inspector-sidebar framework.
##
## Two workbenches ride on this: the UI workbench (`make w`, components + dialogs) and the FX
## workbench (`make fx`, the reward flight + the six feel verbs). A subclass supplies its
## own element set (`_ids` / `_columns_spec` / `_captions` / `_test_keys` / `_default_params`), builds
## each element (`_make_element`) and each element's inspector (`_element_sidebar`); everything else —
## the two-column scrolling gallery, click-to-select, per-element in-place rebuilds, the sidebar row
## widgets, and persistence — lives here.
##
## BOTH workbenches persist into the SAME file (`ui_workbench_settings.json`), because that file is the
## game's live design config (Kit.CONFIG_PATH, `{Land,Merge,…}Fx.from_config`). So a save MERGES: it
## rewrites only the ids this workbench owns and leaves every other id in the file untouched.

const Kit = preload("res://games/grove/ui_kit.gd")
const UiFont = preload("res://engine/scripts/ui/ui_font.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const FS = preload("res://engine/scripts/core/tuning.gd").FontScale
const Pal = Game.PALETTE

const SETTINGS := "res://games/grove/ui_kit_settings.json"   # persisted params (in the repo)
const PHONE_W := 1080.0   # the project's portrait base width; dialog widths are a % of it (and of the live
                          # screen in-game), so the workbench previews the same responsive width the game uses
const PHONE_H := 1920.0   # the project's portrait base height; the map card's height is a % of it (see map_card)
const SIDEBAR_W := 348.0  # fixed left inspector width; long labels wrap inside this rail instead of growing it

# The settings file this workbench reads/writes. Overridable so a test can redirect the round-trip at a
# scratch copy instead of the repo's live design config.
var _settings_path := SETTINGS
var _params := {}
var _selected := ""
var _focus_only := ""             # if set (a component id), _build() renders JUST that element centred — a
                                  # focused, repeatable capture (make shot-workbench EL=<id>); "" = full gallery
var _columns: Array = []          # one content VBox per gallery column (each in its OWN scroll)
var _sidebar_body: VBoxContainer = null
var _sections: Dictionary = {}    # id -> the element's gallery section (PanelContainer), for in-place rebuilds
var _dirty: Dictionary = {}       # id -> true: linked elements queued to rebuild, one per frame (coalesced)
var _awaiting: Dictionary = {}    # id -> true: elements showing a raw placeholder until a worker polish lands
var _building := ""               # the id whose section is mid-build (so the polish previews know who to await)

## --- what a subclass supplies --------------------------------------------------------------------

## Every element id this workbench owns. Also the set of ids it reads/writes in the settings file.
func _ids() -> Array:
	return []

## Gallery layout: a list of COLUMNS, each a list of ROWS, each row a list of element ids.
func _columns_spec() -> Array:
	return []

## id -> "Short name — the long description shown in the sidebar".
func _captions() -> Dictionary:
	return {}

## id -> the keys that are TEST-ONLY scaffolding (never written to / read from the settings file).
func _test_keys() -> Dictionary:
	return {}

## id -> the ids that COMPOSE from it and must rebuild when it changes.
func _dependents() -> Dictionary:
	return {}

## The starting param block for every id (the schema; the settings file is merged over it).
func _default_params() -> Dictionary:
	return {}

## Which element is selected when the workbench opens.
func _default_selected() -> String:
	var ids := _ids()
	return String(ids[0]) if not ids.is_empty() else ""

## Build the live element for an id from its current params.
func _make_element(_id: String) -> Control:
	return Control.new()

## Build the selected element's inspector rows into `_sidebar_body`.
func _element_sidebar(_id: String) -> void:
	pass

## Optional explanatory notes, added under the caption before the controls.
func _sidebar_notes(_id: String) -> void:
	pass

## Optional rows between the notes and the element's own controls (the UI workbench's Shadow toggle).
func _sidebar_common_rows(_id: String) -> void:
	pass

## Optional wrapper around a built element before it goes in its gallery section.
func _wrap_element(el: Control, _id: String) -> Control:
	return el

## Elements whose named handles stay grabbable inside the gallery (the UI workbench's Frame).
func _keep_handles(_id: String) -> bool:
	return false

## Fixed width for the LAST gallery column (the UI workbench sizes it to the global dialog width);
## 0 = let it take its natural share.
func _last_column_width() -> float:
	return 0.0

## Runs before the settings file is merged in (schema fixups on the defaults).
func _before_load() -> void:
	pass

## Extra ids/values to write on save, beyond the params buckets.
func _save_extras(_out: Dictionary) -> void:
	pass

## Fix up an older settings file before its values are merged into _params.
func _load_migrate(_data: Dictionary) -> void:
	pass

## --- lifecycle -----------------------------------------------------------------------------------

func _init() -> void:
	_params = _default_params()
	_selected = _default_selected()

func _ready() -> void:
	if Engine.is_editor_hint():
		theme = UiFont.make()
	_before_load()
	_load_settings()
	_build()

func _build() -> void:
	if not is_inside_tree():
		return
	# Headless editor (`godot --import` / `--export`) instantiates this @tool scene but has no UI to
	# show. Building the gallery there is pointless AND fatal: it kicks off polish_async
	# WorkerThreadPool tasks whose GDScript lambdas are still pending when the import process exits,
	# crashing the pool's destructor at shutdown (SIGSEGV). The interactive workbench, the in-editor
	# @tool, and the headless `-s` tests are NOT editor-hint+headless, so they still build.
	if Engine.is_editor_hint() and DisplayServer.get_name() == "headless":
		return
	for c in get_children():
		remove_child(c)
		c.queue_free()

	var bg := ColorRect.new()
	bg.color = Pal.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# FOCUS capture: render JUST one element, centred, with no sidebar/gallery chrome — a clean, repeatable
	# single-component shot (make shot-workbench EL=<id>). Used to capture the mystery spin-reveal dialog
	# (and any other component) for visual regression without cropping it out of the full gallery.
	if _focus_only != "" and _ids().has(_focus_only):
		var cc := CenterContainer.new()
		cc.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(cc)
		cc.add_child(_make_element(_focus_only))
		return

	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.add_theme_constant_override("separation", 0)
	add_child(hb)

	# right — the gallery: each COLUMN gets its OWN vertical scroll (both fill the window height), so the
	# tall dialogs column scrolls INDEPENDENTLY of the building-blocks column. The dialog column is a
	# fixed-width panel on the right; the building blocks take the remaining width.
	var gal_row := HBoxContainer.new()
	gal_row.add_theme_constant_override("separation", 0)
	gal_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gal_row.size_flags_vertical = Control.SIZE_FILL
	hb.add_child(gal_row)
	var cols := _columns_spec()
	var last_w := _last_column_width()
	_columns.clear()
	for ci in cols.size():
		var col_scroll := ScrollContainer.new()
		col_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO   # a too-wide column scrolls sideways
		col_scroll.size_flags_vertical = Control.SIZE_FILL                      # window-height → its own vertical scroll
		if ci == cols.size() - 1 and last_w > 0.0:
			col_scroll.custom_minimum_size = Vector2(last_w, 0)                 # the DIALOG column: fits the widest dialog
			col_scroll.size_flags_horizontal = Control.SIZE_FILL
		else:
			col_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL         # building blocks take the rest
		gal_row.add_child(col_scroll)
		var col_margin := MarginContainer.new()
		col_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for side in ["left", "right", "top", "bottom"]:
			col_margin.add_theme_constant_override("margin_" + side, 24)
		col_scroll.add_child(col_margin)
		var colbox := VBoxContainer.new()
		colbox.add_theme_constant_override("separation", 18)
		colbox.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		col_margin.add_child(colbox)
		_columns.append(colbox)

	# left — the options sidebar (fixed width)
	var side := PanelContainer.new()
	side.name = "WorkbenchSidebar"
	side.custom_minimum_size = Vector2(SIDEBAR_W, 0)
	side.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	side.size_flags_vertical = Control.SIZE_FILL
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Color(0, 0, 0, 0.42)
	ssb.border_width_right = 2
	ssb.border_color = Color(Pal.CREAM, 0.12)
	ssb.set_content_margin_all(18)
	side.add_theme_stylebox_override("panel", ssb)
	# scope a SMALL font to the sidebar — the global 40px default made the row labels balloon and
	# crowd the sliders out. Keep the rounded face, drop the heavy outline for small text.
	var st := UiFont.make()
	st.default_font_size = 16
	for t in ["Label", "Button", "LineEdit", "OptionButton", "CheckButton"]:
		st.set_constant("outline_size", t, 0)
	side.theme = st
	hb.add_child(side)
	hb.move_child(side, 0)   # sidebar on the LEFT, gallery to its right
	var side_scroll := ScrollContainer.new()
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_child(side_scroll)
	_sidebar_body = VBoxContainer.new()
	_sidebar_body.add_theme_constant_override("separation", 10)
	_sidebar_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_scroll.add_child(_sidebar_body)

	_rebuild_gallery()
	_rebuild_sidebar()

## --- gallery -------------------------------------------------------------------------------------

func _rebuild_gallery() -> void:
	if _columns.is_empty():
		return
	var cols := _columns_spec()
	for ci in cols.size():
		var colbox := _columns[ci] as VBoxContainer
		if not is_instance_valid(colbox):
			continue
		for c in colbox.get_children():
			colbox.remove_child(c)
			c.queue_free()
		for row in cols[ci]:                   # each ROW is a line of side-by-side element sections
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation", 18)
			line.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			for id in row:
				line.add_child(_section(id))
			colbox.add_child(line)
		# scroll-past room at the bottom of EACH column, so the last element never sits flush against the
		# window edge — you can scroll a little past it to see its full base.
		var tail := Control.new()
		tail.custom_minimum_size = Vector2(0, 200)
		tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		colbox.add_child(tail)

func _section(id: String) -> Control:
	var sec := PanelContainer.new()
	sec.add_theme_stylebox_override("panel", _section_style(id == _selected))
	sec.mouse_filter = Control.MOUSE_FILTER_STOP            # catches clicks on the non-button areas
	sec.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	sec.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN   # natural width so a row pairs sit side by side
	sec.size_flags_vertical = Control.SIZE_SHRINK_BEGIN     # top-align within the row
	sec.gui_input.connect(_on_section_input.bind(id))

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sec.add_child(v)
	var cap := Label.new()
	# short caption in the gallery (the full description rides the sidebar) so paired sections stay narrow
	cap.text = ("●  " if id == _selected else "") + String(_captions()[id]).split(" — ")[0]
	cap.add_theme_font_size_override("font_size", FS.FINE)
	cap.add_theme_color_override("font_color", Pal.STRAW if id == _selected else Color(Pal.CREAM, 0.8))
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(cap)
	var holder := CenterContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_building = id                          # so the polish previews know which element to mark awaiting
	var el := _make_element(id)
	_building = ""
	el = _wrap_element(el, id)              # e.g. cast the SHARED shadow behind the preview
	_make_clickthrough(el, _keep_handles(id))
	holder.custom_minimum_size = el.custom_minimum_size
	holder.add_child(el)
	v.add_child(holder)
	_sections[id] = sec
	return sec

## Apply an edit to the SELECTED element: rebuild it NOW (live feedback on the control you're dragging),
## then queue its dependents to rebuild one-per-frame (post-change, so the sliders never freeze). The
## queue is a Set, so a fast drag that fires many times just re-marks the same ids — no rebuild backlog.
func _apply_edit() -> void:
	_sync_preview_config()   # publish the unsaved edit so EVERY disk-reading preview reflects it now, not only on Save
	_rebuild_element(_selected)
	_mark_dirty(_dependents().get(_selected, []))

## Push the live (unsaved) params into Kit's config cache so every builder that reads the config from disk
## previews them at once. Many shared builders — the mail/shop cards, the reward chips, the borderless
## paper-role buttons — resolve their look from Kit.load_config(CONFIG_PATH) rather than from params handed
## down through opts, so WITHOUT this only the directly-param-fed previews would update live and a shared
## edit (e.g. the cut-paper edge) wouldn't reach the rest of the button family until Save. MERGES over the
## current config so the sibling workbench's ids (it shares this file) are left untouched. No file write.
func _sync_preview_config() -> void:
	var cfg: Dictionary = Kit.load_config(_settings_path).duplicate(true)
	for id in _params.keys():
		if not (_params[id] is Dictionary):
			continue
		var sub: Dictionary = cfg.get(id, {}) if cfg.get(id, {}) is Dictionary else {}
		sub = sub.duplicate()
		for k in (_params[id] as Dictionary).keys():
			if _is_config(id, k):
				sub[k] = _params[id][k]
		cfg[id] = sub
	Kit.set_config_cache(_settings_path, cfg)

## Queue ids to rebuild on the staggered pump (see _process). Coalesced via the _dirty Set.
func _mark_dirty(ids: Array) -> void:
	for id in ids:
		_dirty[id] = true
	if not _dirty.is_empty():
		set_process(true)

# Drain the dirty queue ONE element per frame (so the screen keeps repainting between heavy linked
# rebuilds instead of freezing through all of them), then settle elements waiting on a worker polish:
# once their off-thread bake lands, rebuild them so the raw placeholder swaps to the polished texture.
func _process(_delta: float) -> void:
	if not _dirty.is_empty():
		var id: String = String(_dirty.keys()[0])
		_dirty.erase(id)
		_rebuild_element(id)
	elif not _awaiting.is_empty() and Kit.pump_polish() == 0:
		var ids: Array = _awaiting.keys()
		_awaiting.clear()
		for id in ids:
			_rebuild_element(id)
	if _dirty.is_empty() and _awaiting.is_empty():
		set_process(false)

## Rebuild a single element's section in place (swap the node at its position in the row), leaving every
## OTHER section untouched. No-op if the gallery hasn't been built yet (the initial _rebuild_gallery does).
func _rebuild_element(id: String) -> void:
	var old: Node = _sections.get(id)
	if old == null or not is_instance_valid(old):
		return
	var parent := (old as Control).get_parent()
	if parent == null:
		return
	var idx := (old as Control).get_index()
	var fresh := _section(id)          # also re-registers _sections[id] = fresh
	parent.add_child(fresh)
	parent.move_child(fresh, idx)
	old.queue_free()

## Make EVERYTHING in the section mouse-transparent, so a click ANYWHERE — even on top of the component
## itself (a card, a button, the banner) — falls through to the section and selects it. The ONE
## exception: the FRAME element keeps its banner / banner-icon / ✕ active so those handles stay
## draggable there (the other dialogs reuse the frame read-only, so their banner is NOT draggable).
func _make_clickthrough(n: Node, keep_handles: bool) -> void:
	for c in n.get_children():
		if c is Control:
			var is_handle: bool = String(c.name) in ["DialogBanner", "DialogBannerIcon", "DialogClose"]
			var keep_active: bool = (c as Control).has_meta("wb_active")   # an interactive preview control (e.g. a ▶ Replay)
			if not ((keep_handles and is_handle) or keep_active):
				(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_make_clickthrough(c, keep_handles)

func _on_section_input(ev: InputEvent, id: String) -> void:
	var hit: bool = (ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
	hit = hit or (ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed)
	if hit:
		select(id)

func select(id: String) -> void:
	if id == _selected:
		return
	var prev := _selected
	_selected = id
	# DEFER: select() runs inside a section's gui_input dispatch — rebuilding (freeing the very
	# section that is mid-emit) here would hit "Object is locked and can't be freed". Defer so the
	# tree is mutated only after the input dispatch returns. Refresh ONLY the two sections whose
	# highlight changed (the old + the new selection), not the whole gallery.
	_rebuild_element.call_deferred(prev)
	_rebuild_element.call_deferred(id)
	_rebuild_sidebar.call_deferred()      # swap in this element's options

func _section_style(selected: bool) -> StyleBox:
	# LIGHT cell so a dark drop-shadow reads against it (a dark cell hid the shadow knobs' effect). A cool
	# light slate also keeps the cream badges legible (cream-on-cream would wash out).
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(14)
	if selected:
		sb.bg_color = Color("#E3ECEF")
		sb.set_border_width_all(2)
		sb.border_color = Pal.STRAW
	else:
		sb.bg_color = Color("#C7D4DB")
		sb.set_border_width_all(1)
		sb.border_color = Color(Pal.INK, 0.18)
	return sb

## --- sidebar -------------------------------------------------------------------------------------

func _rebuild_sidebar() -> void:
	if _sidebar_body == null or not is_instance_valid(_sidebar_body):
		return
	for c in _sidebar_body.get_children():
		_sidebar_body.remove_child(c)
		c.queue_free()
	var head := Label.new()
	head.text = "Options"
	head.add_theme_font_size_override("font_size", FS.BODY)
	_sidebar_body.add_child(head)
	var save := Button.new()
	save.text = "Save settings"
	save.pressed.connect(_save_settings)
	_sidebar_body.add_child(save)
	var sub := Label.new()
	sub.text = String(_captions()[_selected])
	sub.add_theme_font_size_override("font_size", FS.FINE)
	sub.add_theme_color_override("font_color", Color(Pal.CREAM, 0.65))
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sidebar_body.add_child(sub)
	_sidebar_notes(_selected)
	_sidebar_body.add_child(HSeparator.new())
	_sidebar_common_rows(_selected)
	# Every element splits its controls into the two buckets (see _test_keys): the persisted design
	# config first, then the transient test/preview scaffolding that the config file never touches.
	_element_sidebar(_selected)
	_constrain_sidebar_text(_sidebar_body)

func _constrain_sidebar_text(node: Node) -> void:
	if node is Label:
		var label := node as Label
		if label.autowrap_mode != TextServer.AUTOWRAP_OFF or label.get_parent() == _sidebar_body:
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.custom_minimum_size.x = 0.0
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for child in node.get_children():
		_constrain_sidebar_text(child)

func _wrap_sidebar_row_label(label: Label) -> void:
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER

## A small dim note paragraph in the sidebar.
func _sidebar_note(text: String, color := Color(Pal.STRAW, 0.85)) -> void:
	var note := Label.new()
	note.text = text
	note.add_theme_font_size_override("font_size", FS.TOOL)
	note.add_theme_color_override("font_color", color)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sidebar_body.add_child(note)

## A bold top-level group header — the two buckets: gold ● = saved to config, dim ○ = test-only.
func _group_header(title: String, saved: bool) -> void:
	_sidebar_body.add_child(HSeparator.new())
	var l := Label.new()
	l.text = ("●  " if saved else "○  ") + title
	l.add_theme_font_size_override("font_size", FS.FINE)
	l.add_theme_color_override("font_color", Pal.STRAW if saved else Color(Pal.CREAM, 0.5))
	_sidebar_body.add_child(l)

## A small section header in the sidebar (a separator + an accent label), to group settings.
func _section_header(title: String) -> void:
	_sidebar_body.add_child(HSeparator.new())
	var l := Label.new()
	l.text = title
	l.add_theme_font_size_override("font_size", FS.FINE)
	l.add_theme_color_override("font_color", Pal.STRAW)
	_sidebar_body.add_child(l)

## A wrapped explanatory note in the sidebar — for saying WHY a control group is absent or inert,
## so a knob that cannot bite is never left on screen looking broken.
func _note(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 220.0
	l.add_theme_font_size_override("font_size", FS.FINE)
	l.add_theme_color_override("font_color", Color(Pal.CREAM, 0.55))
	_sidebar_body.add_child(l)

func _slider_row(spec: Array, target := "") -> Control:
	var key: String = spec[0]
	var lo: float = float(spec[1])
	var hi: float = float(spec[2])
	var params: Dictionary = _params[target if target != "" else _selected]
	if not params.has(key):
		params[key] = clampf(lo, lo, hi)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lbl := Label.new()
	lbl.text = key.replace("_", " ").capitalize()
	lbl.custom_minimum_size = Vector2(118, 0)
	_wrap_sidebar_row_label(lbl)
	row.add_child(lbl)
	# An ABSOLUTE font size is quantized to the FontScale ladder — the slider steps tier by tier,
	# so a tuned-and-saved size can only ever be a named tier (the app has no other legal sizes).
	# Relative font knobs are excluded: a ± px NUDGE (lo < 0) or a % (its key isn't a font size).
	var tiers: Array = FS.tiers_in(lo, hi) if (key == "font" or key.ends_with("_font")) and lo >= 0.0 else []
	if tiers.size() >= 2:
		return _tier_slider_row(row, params, key, tiers)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 1
	s.value = float(params[key])
	params[key] = s.value          # keep the param in sync if the value was out of range (clamped)
	s.custom_minimum_size = Vector2(0, 28)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(s)
	var val := Label.new()
	val.text = "%d" % int(params[key])
	val.custom_minimum_size = Vector2(44, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val)
	s.value_changed.connect(func(x: float) -> void:
		params[key] = x
		val.text = "%d" % int(x)
		_apply_edit())
	return row

## A font-size slider that steps over the FontScale TIERS instead of raw px: the slider's value is
## an INDEX into `tiers`, so every stop is a named tier and the saved config can't hold a loose size.
## The readout shows the px it resolves to. Any pre-existing loose value snaps to its nearest tier.
func _tier_slider_row(row: HBoxContainer, params: Dictionary, key: String, tiers: Array) -> Control:
	var idx := maxi(0, tiers.find(FS.snap(float(params[key]))))
	params[key] = float(tiers[idx])          # migrate a loose saved value onto the ladder
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = tiers.size() - 1
	s.step = 1
	s.value = idx
	s.set_meta("font_tiers", tiers)   # the px ladder this index-slider steps over (read by tests/tooling)
	s.custom_minimum_size = Vector2(0, 28)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(s)
	var val := Label.new()
	val.text = "%d" % int(params[key])
	val.custom_minimum_size = Vector2(44, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val)
	s.value_changed.connect(func(x: float) -> void:
		var px: int = int(tiers[clampi(int(x), 0, tiers.size() - 1)])
		params[key] = float(px)
		val.text = "%d" % px
		_apply_edit())
	return row

func _text_row(label: String, key: String, target := "") -> Control:
	var params: Dictionary = _params[target if target != "" else _selected]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size = Vector2(118, 0)
	_wrap_sidebar_row_label(lbl)
	row.add_child(lbl)
	var le := LineEdit.new()
	le.text = String(params.get(key, ""))
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.text_changed.connect(func(t: String) -> void:
		params[key] = t
		_apply_edit())
	row.add_child(le)
	return row

# A colour swatch row: a ColorPickerButton bound to a 6-digit hex param (no '#', no alpha). Writes the
# hex back on change and re-renders the preview live — the only colour control in the workbench so far.
func _color_row(label: String, key: String, target := "") -> Control:
	var params: Dictionary = _params[target if target != "" else _selected]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size = Vector2(118, 0)
	_wrap_sidebar_row_label(lbl)
	row.add_child(lbl)
	var btn := ColorPickerButton.new()
	btn.custom_minimum_size = Vector2(0, 28)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.edit_alpha = false
	btn.color = Color.from_string("#" + String(params.get(key, "FFFFFF")).lstrip("#"), Color.WHITE)
	btn.color_changed.connect(func(c: Color) -> void:
		params[key] = c.to_html(false)   # store "rrggbb" (6 hex digits, no '#', no alpha)
		_apply_edit())
	row.add_child(btn)
	return row

func _toggle_row(label: String, key: String, rebuild_sidebar := false, target := "") -> Control:
	var params: Dictionary = _params[target if target != "" else _selected]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size = Vector2(118, 0)
	_wrap_sidebar_row_label(lbl)
	row.add_child(lbl)
	var cb := CheckButton.new()
	cb.button_pressed = bool(params.get(key, false))
	cb.toggled.connect(func(on: bool) -> void:
		params[key] = on
		_apply_edit()
		if rebuild_sidebar:
			_rebuild_sidebar.call_deferred())   # defer — we're inside this toggle's own signal
	row.add_child(cb)
	return row

func _option_row(label: String, key: String, options: Array, rebuild_sidebar := false, target := "") -> Control:
	var params: Dictionary = _params[target if target != "" else _selected]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size = Vector2(118, 0)
	_wrap_sidebar_row_label(lbl)
	row.add_child(lbl)
	var ob := OptionButton.new()
	var cur := String(params.get(key, options[0]))
	for i in options.size():
		ob.add_item(String(options[i]).capitalize(), i)
		if String(options[i]) == cur:
			ob.select(i)
	ob.item_selected.connect(func(idx: int) -> void:
		params[key] = String(options[idx])
		_apply_edit()
		if rebuild_sidebar:
			_rebuild_sidebar.call_deferred())   # defer — we're inside this option's own signal
	row.add_child(ob)
	return row

## --- persistence ---------------------------------------------------------------------------------

## Is this element/key a persisted design setting (vs transient test scaffolding from _test_keys)?
func _is_config(id: String, key: String) -> bool:
	return not (key in _test_keys().get(id, []))

## Write this workbench's ids back into the shared settings file, MERGING over whatever is already
## there — the other workbench owns the ids we don't. Test/preview scaffolding is excluded.
func _save_settings() -> void:
	var out := {}
	if FileAccess.file_exists(_settings_path):
		var prev = JSON.parse_string(FileAccess.get_file_as_string(_settings_path))
		if prev is Dictionary:
			out = prev
	for id in _params.keys():
		var sub := {}
		for k in (_params[id] as Dictionary).keys():
			if _is_config(id, k):
				sub[k] = _params[id][k]
		out[id] = sub
	_save_extras(out)
	var f := FileAccess.open(_settings_path, FileAccess.WRITE)
	if f == null:
		push_warning("Workbench: could not write %s" % _settings_path)
		return
	f.store_string(JSON.stringify(out, "\t"))
	f.close()
	Kit.clear_config_cache(_settings_path)   # so any live Kit reader picks up the new file (not the stale cache)
	print("WORKBENCH: settings saved -> %s" % _settings_path)

## Merge the saved file over the defaults, copying ONLY config keys present in both — so test
## scaffolding is never restored, and an older or newer settings file can't corrupt the live schema.
func _load_settings() -> void:
	if not FileAccess.file_exists(_settings_path):
		return
	var f := FileAccess.open(_settings_path, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if not (data is Dictionary):
		return
	_load_migrate(data)
	for id in _params.keys():
		if data.has(id) and data[id] is Dictionary:
			for k in (_params[id] as Dictionary).keys():
				if _is_config(id, k) and (data[id] as Dictionary).has(k):
					_params[id][k] = data[id][k]
