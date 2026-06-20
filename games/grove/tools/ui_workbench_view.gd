@tool
extends Control
## UI Workbench — gallery + inspector sidebar.
##
## `make workbench` opens this. The left column is a scroll of the fundamental components, built
## bottom-up from the self-contained kit (cost pill → mail card → mail dialog). CLICK an element to
## select it; the right SIDEBAR then shows that element's own options/sliders. Changing a slider
## rebuilds just that element — and because the components compose, a dialog's pill size still flows
## down into every row.

const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")
const UiFont = preload("res://engine/scripts/ui/ui_font.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Pal = Game.PALETTE
const SETTINGS := "res://games/grove/tools/ui_workbench_settings.json"   # persisted params (in the repo)

const IDS := ["button", "home_button", "icon", "card", "daily_card", "frame", "dialog", "daily", "shop"]
# Gallery layout: TWO side-by-side COLUMNS. The left column is the building-block components; the RIGHT
# column stacks every DIALOG in a single column. Each column is a list of ROWS (a row = side-by-side
# elements, e.g. button + icon). Splitting dialogs into their own column keeps them grouped and balances
# the gallery's height (the tall dialogs no longer each span a full-width row).
const COLUMNS := [
	[["home_button"], ["button", "icon"], ["card"], ["daily_card"], ["frame"]],   # the building blocks
	[["dialog"], ["daily"], ["shop"]],                                            # every dialog, one column
]
# Badge backgrounds live in the kit now (Kit.BADGES) so the game resolves them from the same map.
# Icons the button can show (all resolve via the kit's _icon_tex); "none" = no icon.
const ICONS := ["none", "coin", "gem", "bluegem", "water", "leaf", "gift", "star", "daisy", "faucet", "rain", "news", "mail"]
# Icons the HOME button can show (the home page's rail + nav set; all resolve via the kit's _icon_tex).
const HOME_ICONS := ["gear", "shop", "map", "piggy", "gift", "faucet", "mail", "daisy", "leaf"]
# Each element's params split into two buckets: anything listed here is TEST-ONLY scaffolding (sample
# content, preview counts, tool helpers) and is NOT written to / read from the config file; everything
# else is real design config that IS persisted. The sidebar mirrors this split under two headers.
#   button — icon/size/enabled are just to eyeball the shape; the REAL claim icon lives on the Card.
#   icon   — the whole element is a polish-tuning sandbox (the shipped recipe is fixed in the kit).
#   dialog — entries is a preview count, snap is the drag grid.
const TEST_KEYS := {
	# the Button is a shared-STYLE sandbox: only shadow / use-art / font are real config. Its text, bg,
	# icon, badge, corner are test props — the REAL text/badge/icon for the game live on the Card.
	"button": ["text", "bg", "icon", "icon_size", "enabled", "corner", "badge"],
	# the HOME button is a shared-STYLE sandbox: size / icon scale / caption look / SPARKLE amount persist.
	# The previewed icon, caption text + sparkle toggle are test props — each call site sets its own.
	"home_button": ["icon", "caption", "sparkle"],
	"icon": ["defringe", "feather", "supersample", "shadow"],
	"card": [],
	"daily_card": ["preview", "ribbon"],   # preview state + ribbon are workbench-only viewing toggles
	"frame": ["snap"],                     # snap is the drag-grid helper, not a saved design value
	"dialog": ["entries"],
	"daily": [],
	"shop": [],
}
const CAPTIONS := {
	"button": "Button — shared (bg · icon · state)",
	"home_button": "Home button — rail + nav (shell · icon · sparkle)",
	"icon": "Icon — edge polish (raw vs cleaned)",
	"card": "Mail card — pill + Claim",
	"daily_card": "Daily card — one day (badges)",
	"frame": "Dialog frame — shared chrome",
	"dialog": "Mail dialog — cards",
	"daily": "Daily — day grid (shared frame)",
	"shop": "Shop — packs (shared frame)",
}
var _params := {
	"button": {"text": "Claim", "bg": "green", "icon": "none", "icon_size": 30, "enabled": true, "font": 22, "corner": 16, "art": true, "shadow": false, "badge": "auto"},
	# the HOME button — the round icon button shared by the side rail + bottom nav. px / icon_scale /
	# caption_font / caption_gap / glow / twinkle + the icon polish (defringe/shadow/feather) are the saved
	# STYLE; icon / caption / sparkle preview it.
	"home_button": {"px": 140, "icon_scale": 50, "caption_font": 22, "caption_gap": 4, "glow": 45, "twinkle": 55,
		"defringe": true, "shadow": false, "feather": 2,
		"icon": "gift", "caption": "Daily", "sparkle": true},
	"icon": {"defringe": false, "feather": 1, "supersample": 1, "shadow": false},
	"card": {"title": 20, "body": 15, "badge": "auto", "icon_badge": "disc light", "claim_text": "Claim", "icon_on": false, "icon": "gem"},
	# the shared FRAME is its OWN standalone component (banner · card border/art · ✕ · scroll/list ·
	# padding). EVERY dialog reuses it. width here is just for the frame's own preview; each dialog
	# carries its own width. snap is the drag-grid for the banner/✕ handles.
	"frame": {
		"width": 560, "card_corner": 22, "card_art": true,
		"card_slice_l": 40, "card_slice_t": 40, "card_slice_r": 40, "card_slice_b": 40,
		"card_h_stretch": "stretch", "card_v_stretch": "stretch",
		"banner_font": 32, "banner_h": 92, "banner_icon": 54, "banner_icon_on": true,
		"banner_text_x": 0, "banner_text_y": 0, "banner_burn": 60,
		"banner_x": 0, "banner_y": 0,
		"banner_icon_x": 130, "banner_icon_y": 19,
		"close_size": 64, "close_x": 12, "close_y": 12, "snap": 8,
		"list_max_h": 0, "list_top_pad": 0,
	},
	# the mail DIALOG = the shared frame + the mail cards; only width + the preview count are its own.
	"dialog": {"width": 560, "entries": 4},
	# the small CARD is its own component, shared by daily + shop (cell size, highlight badges, and a
	# preview state/ribbon for trying it as a shop pack). preview + ribbon are workbench-only view toggles.
	"daily_card": {"preview": "today", "ribbon": "", "cell_w": 96, "cell_h": 116, "cell_slice": 28,
		"cell_art": true, "today_badge": "gold glow", "milestone_badge": "amber glow", "sparkle": true,
		"label_y": 12, "claim_y": 14, "info_icon": false},
	# …the daily DIALOG reuses the shared frame + that card, adding the grid knobs + its OWN scroll cap
	# (list_max_h 0 = no scroll, tall enough for every day; the frame's mail-list cap doesn't apply)…
	"daily": {"width": 460, "cols": 3, "list_max_h": 0},
	# …and the SHOP dialog reuses the SAME frame + the SAME card with bigger cells, its own scroll cap
	# (list_max_h 0 = no scroll, show every item), and the GAME's real items.
	"shop": {"width": 520, "cols": 3, "cell_w": 112, "cell_h": 150, "row_gap": 22, "list_max_h": 0},
}
var _selected := "button"
var _columns: Array = []          # one content VBox per gallery column (each in its OWN scroll)
var _sidebar_body: VBoxContainer = null

# polished-icon textures, cached by their opts so an unrelated rebuild doesn't re-run the (slow) polish
var _icon_cache: Dictionary = {}

# drag-to-move (banner icon / ✕), with snap-to-grid
var _drag_kind := ""
var _drag_node: Control = null
var _drag_grab := Vector2.ZERO

func _ready() -> void:
	if Engine.is_editor_hint():
		theme = UiFont.make()
	_load_settings()
	_build()

func _build() -> void:
	if not is_inside_tree():
		return
	for c in get_children():
		remove_child(c)
		c.queue_free()

	var bg := ColorRect.new()
	bg.color = Pal.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

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
	# the DIALOG column is sized to the WIDEST dialog (mail/daily/shop carry their own width) + chrome, so
	# no dialog is clipped inside its column; the building-blocks column takes the remaining width.
	var dlg_w := 0.0
	for did in ["dialog", "daily", "shop"]:
		dlg_w = maxf(dlg_w, float((_params[did] as Dictionary).get("width", 520)))
	var dlg_col_w: float = dlg_w + 96.0
	_columns.clear()
	for ci in COLUMNS.size():
		var col_scroll := ScrollContainer.new()
		col_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO   # a too-wide column scrolls sideways
		col_scroll.size_flags_vertical = Control.SIZE_FILL                      # window-height → its own vertical scroll
		if ci == COLUMNS.size() - 1:
			col_scroll.custom_minimum_size = Vector2(dlg_col_w, 0)              # the DIALOG column: fits the widest dialog
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
	side.custom_minimum_size = Vector2(348, 0)
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
	side.add_child(side_scroll)
	_sidebar_body = VBoxContainer.new()
	_sidebar_body.add_theme_constant_override("separation", 10)
	_sidebar_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_scroll.add_child(_sidebar_body)

	_rebuild_gallery()
	_rebuild_sidebar()

## Build the live element for an id from its current params.
func _make_element(id: String) -> Control:
	var p: Dictionary = _params[id]
	match id:
		"button":
			return Kit.pill_button(String(p.text), _btn_opts())
		"home_button":
			# the round icon button as the rail + nav build it, from the SAME kit transform the game reads.
			# Two variants side by side: nav-style (no caption / no sparkle) and rail-style (caption + the
			# tuned sparkle), so the configurable parts read at a glance. A bottom margin gives the caption
			# tab room (it overflows below the disc, exactly as it does on the rail).
			var ho := Kit.home_button_opts_from_config({"home_button": p})
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 30)
			row.add_child(Kit.home_button({"icon": String(p.icon), "caption": "", "sparkle": false}, ho))
			row.add_child(Kit.home_button({"icon": String(p.icon), "caption": String(p.caption), "sparkle": bool(p.sparkle)}, ho))
			var mc := MarginContainer.new()
			mc.add_theme_constant_override("margin_bottom", int(p.caption_font) + 26)
			mc.add_child(row)
			return mc
		"icon":
			var box := HBoxContainer.new()
			box.add_theme_constant_override("separation", 28)
			box.add_child(_icon_preview("Raw", {"defringe": false, "feather": 0.0, "supersample": 1}))
			box.add_child(_icon_preview("Polished", {"defringe": bool(p.defringe), "feather": float(p.feather), "supersample": int(p.supersample), "shadow": bool(p.shadow)}))
			return box
		"card":
			# the Claim inherits the shared Button's STYLE, but the card picks its OWN (saved) badge
			# background + icon for it. Give the standalone preview a representative width — a real card
			# always lives width-constrained in the dialog, so without one its shrinkable text collapses.
			var card := Kit.mail_card(Kit.DEMO_MAIL[0], int(p.title), int(p.body), _card_btn_opts(), Kit.card_icon_badge(_params))
			card.custom_minimum_size.x = 560   # comfortable width so the title doesn't clip
			return card
		"frame":
			# the SHARED frame on its own, with placeholder content — the one chrome every dialog reuses
			var fo := Kit.dialog_opts_from_config(_params)
			fo["banner_text"] = "Frame"
			var fr := Kit.dialog_frame(_frame_placeholder(), float(p.width), fo)
			_attach_dialog_drag(fr)
			return fr
		"dialog":
			# build from the SHARED kit transform (same one the game uses) + the test-only preview count
			var opts := Kit.dialog_opts_from_config(_params)
			opts["entries_count"] = int(p.entries)
			# NOT draggable — the frame (banner / ✕ positions) is edited on the Frame item, not here
			return Kit.mail_dialog(Kit.DEMO_MAIL, float(p.width), opts)
		"daily_card":
			# the shared small card in a chosen preview state (incl. a shop pack). Rendered at 2× (bigger
			# cell + fonts; the icons scale with cell_w) — a preview ZOOM so the small card is comfortable
			# to edit. The real daily/shop dialogs still use the saved (smaller) size.
			var co := Kit.daily_card_opts_from_config(_params)
			var z := 2.0
			co["cell_w"] = float(co["cell_w"]) * z
			co["cell_h"] = float(co["cell_h"]) * z
			co["cell_font"] = int(15 * z)
			co["claim_font"] = int(15 * z)
			co["count_font"] = int(17 * z)
			co["label_y"] = float(co.get("label_y", 12)) * z   # the position knobs scale with the zoom too
			co["claim_y"] = float(co.get("claim_y", 14)) * z
			var day := _daily_preview_day(String(p.preview))
			if String(p.ribbon) != "":
				day["ribbon"] = String(p.ribbon)
			return Kit.daily_card(day, co)
		"daily":
			# SHARED frame config (from the Dialog item) + the separately-defined day card + grid knobs
			var dopts := Kit.daily_opts_from_config(_params)
			dopts["banner_text"] = "Daily"
			return Kit.daily_dialog(Kit.DEMO_DAILY, float(p.width), dopts)   # frame edited on the Frame item
		"shop":
			# the SAME shared frame + the SAME small card — just shop data (icon+count+price+ribbon)
			var sopts := Kit.shop_opts_from_config(_params)
			sopts["banner_text"] = "Shop"
			return Kit.shop_dialog(Kit.demo_shop(), float(p.width), sopts)   # the GAME's real items
	return Control.new()

## A demo day for the standalone Daily-card preview, in the chosen state (today shows the today badge,
## mystery shows the milestone badge + chest).
func _daily_preview_day(state: String) -> Dictionary:
	match state:
		"done":    return {"day": 2, "label": "Day 2", "reward": {"water": 10}, "state": "done"}
		"future":  return {"day": 5, "label": "Day 5", "reward": {"coins": 100}, "state": "future"}
		"mystery": return {"day": 7, "label": "Day 7", "reward": {"gems": 30}, "state": "future", "mystery": true}
		"shop":    return {"icon": "gem", "count": 500, "price": "$4.99"}   # the SAME card as a shop pack
		_:         return {"day": 4, "label": "Day 4", "reward": {"coins": 150}, "state": "today"}

## Placeholder content for the standalone Frame preview — faint bars standing in for "any content".
func _frame_placeholder() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 4:
		var bar := PanelContainer.new()
		bar.custom_minimum_size = Vector2(0, 56)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(Pal.BARK, 0.12)
		sb.set_corner_radius_all(10)
		bar.add_theme_stylebox_override("panel", sb)
		v.add_child(bar)
	return v

## One labelled icon preview (raw or polished) for the Icon element.
func _icon_preview(label: String, opts: Dictionary) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var l := Label.new()
	l.text = label
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Color(Pal.CREAM, 0.8))
	v.add_child(l)
	var tr := TextureRect.new()
	tr.custom_minimum_size = Vector2(170, 170)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	opts["size"] = 160
	var key := "%s|%s|%s|%s" % [opts.get("defringe", false), opts.get("feather", 0.0), opts.get("supersample", 1), opts.get("shadow", false)]
	if not _icon_cache.has(key):
		_icon_cache[key] = Kit.polish_icon_tex("gem", opts)
	tr.texture = _icon_cache[key]
	v.add_child(tr)
	return v

## The shared Button's params as a kit opts dict. The card + dialog Claim are built ENTIRELY from
## this (no styling of their own), so editing the Button item updates every Claim automatically.
## The shared Button's STYLE (art / bg / corner / font / shadow) as a kit opts dict. The Button's own
## icon is test-only, so the card/dialog pass `overrides` to supply the REAL, saved icon + badge:
##   overrides.badge — a Card-chosen badge that wins over the Button's; overrides.icon — the claim icon
##   ("" = none). Absent overrides fall back to the Button's own values (used by the Button preview).
func _btn_opts(overrides := {}) -> Dictionary:
	var b: Dictionary = _params["button"]
	var badge: String = String(overrides.get("badge", b.get("badge", "auto")))
	var o := {
		"text": String(overrides.get("text", b.text)),
		"bg": String(overrides.get("bg", b.bg)),
		"icon": ("" if String(b.icon) == "none" else String(b.icon)),
		"icon_size": int(b.icon_size),
		"enabled": bool(b.enabled),
		"font": int(b.font),
		"corner": int(b.corner),
		"art": bool(b.art),
		"shadow": bool(b.shadow),
	}
	if overrides.has("icon"):
		o["icon"] = String(overrides["icon"])      # the Card's saved icon choice ("" = none)
	# a specific badge forces art mode and overrides the default bg-based sprite
	if badge != "auto" and Kit.BADGES.has(badge) and String(Kit.BADGES[badge]) != "":
		o["art"] = true
		o["art_rel"] = String(Kit.BADGES[badge])
	return o

## The Button style + the Card's OWN saved badge / icon / claim text — drives the cost pill + Claim in
## both the Card preview and every dialog row. Delegates to the SAME kit builder the game uses, so the
## transform lives in exactly one place.
func _card_btn_opts() -> Dictionary:
	return Kit.card_btn_opts(_params)

## --- gallery (left) ------------------------------------------------------------------------------

func _rebuild_gallery() -> void:
	if _columns.is_empty():
		return
	for ci in COLUMNS.size():
		var colbox := _columns[ci] as VBoxContainer
		if not is_instance_valid(colbox):
			continue
		for c in colbox.get_children():
			colbox.remove_child(c)
			c.queue_free()
		for row in COLUMNS[ci]:                # each ROW is a line of side-by-side element sections
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
	cap.text = ("●  " if id == _selected else "") + String(CAPTIONS[id]).split(" — ")[0]
	cap.add_theme_font_size_override("font_size", 15)
	cap.add_theme_color_override("font_color", Pal.STRAW if id == _selected else Color(Pal.CREAM, 0.8))
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(cap)
	var holder := CenterContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var el := _make_element(id)
	_make_clickthrough(el, id == "frame")   # only the FRAME keeps its handles grabbable
	holder.add_child(el)
	v.add_child(holder)
	return sec

## Make EVERYTHING in the section mouse-transparent, so a click ANYWHERE — even on top of the component
## itself (a card, a button, the banner) — falls through to the section and selects it. The ONE
## exception: the FRAME element keeps its banner / banner-icon / ✕ active so those handles stay
## draggable there (the other dialogs reuse the frame read-only, so their banner is NOT draggable).
func _make_clickthrough(n: Node, keep_handles: bool) -> void:
	for c in n.get_children():
		if c is Control:
			var is_handle: bool = String(c.name) in ["DialogBanner", "DialogBannerIcon", "DialogClose"]
			if not (keep_handles and is_handle):
				(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_make_clickthrough(c, keep_handles)

## --- drag-to-move with snap (dialog banner icon + ✕) ---------------------------------------------

## Make the dialog's named handles draggable. Re-run on every dialog rebuild (new nodes each time).
func _attach_dialog_drag(d: Control) -> void:
	var banner: Control = d.find_child("DialogBanner", true, false)
	if banner != null:
		banner.mouse_filter = Control.MOUSE_FILTER_STOP
		_make_draggable(banner, "banner")
	var env: Control = d.find_child("DialogBannerIcon", true, false)
	if env != null:
		env.mouse_filter = Control.MOUSE_FILTER_STOP
		_make_draggable(env, "banner_icon")
	var close: Control = d.find_child("DialogClose", true, false)
	if close != null:
		_make_draggable(close, "close")

func _make_draggable(node: Control, kind: String) -> void:
	node.mouse_default_cursor_shape = Control.CURSOR_MOVE
	node.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and (ev as InputEventMouseButton).pressed:
			_drag_kind = kind
			_drag_node = node
			_drag_grab = (ev as InputEventMouseButton).global_position - node.global_position
			get_viewport().set_input_as_handled())

# Global so the drag keeps following the cursor even when it leaves the small handle.
func _input(ev: InputEvent) -> void:
	if _drag_kind == "" or _drag_node == null or not is_instance_valid(_drag_node):
		return
	if ev is InputEventMouseMotion:
		var parent := _drag_node.get_parent() as Control
		if parent == null:
			return
		var target: Vector2 = (ev as InputEventMouseMotion).global_position - _drag_grab
		var local: Vector2 = parent.get_global_transform().affine_inverse() * target
		local = _snap_vec(local)
		_drag_node.position = local
		_store_drag(_drag_kind, local)
		get_viewport().set_input_as_handled()
	elif ev is InputEventMouseButton and not (ev as InputEventMouseButton).pressed:
		_drag_kind = ""
		_drag_node = null
		_rebuild_sidebar()      # reflect the dragged position in the sliders (and clamp it)
		_rebuild_gallery()      # re-apply the (possibly clamped) params consistently

func _snap_vec(v: Vector2) -> Vector2:
	var g: float = float(int(_params["frame"]["snap"]))
	if g < 1.0:
		return v
	return Vector2(roundf(v.x / g) * g, roundf(v.y / g) * g)

func _store_drag(kind: String, local: Vector2) -> void:
	var p: Dictionary = _params["frame"]      # banner/✕ positions are FRAME config (shared by every dialog)
	if kind == "banner":
		p["banner_x"] = local.x
		p["banner_y"] = local.y
	elif kind == "banner_icon":
		p["banner_icon_x"] = local.x
		p["banner_icon_y"] = local.y
	elif kind == "close":
		var card := _drag_node.get_parent().get_child(0) as Control   # wrap's first child is the card
		var cw: float = (card.size.x if card != null else float(p["width"]))
		p["close_x"] = local.x - (cw - _drag_node.size.x)             # inverse of the kit's dock() formula
		p["close_y"] = -local.y

func _on_section_input(ev: InputEvent, id: String) -> void:
	var hit: bool = (ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
	hit = hit or (ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed)
	if hit:
		select(id)

func select(id: String) -> void:
	if id == _selected:
		return
	_selected = id
	# DEFER: select() runs inside a section's gui_input dispatch — rebuilding (freeing the very
	# section that is mid-emit) here would hit "Object is locked and can't be freed". Defer so the
	# tree is mutated only after the input dispatch returns.
	_rebuild_gallery.call_deferred()      # refresh the selection highlight
	_rebuild_sidebar.call_deferred()      # swap in this element's options

func _section_style(selected: bool) -> StyleBox:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(14)
	if selected:
		sb.bg_color = Color(1, 1, 1, 0.05)
		sb.set_border_width_all(2)
		sb.border_color = Pal.STRAW
	else:
		sb.bg_color = Color(0, 0, 0, 0.22)
		sb.set_border_width_all(1)
		sb.border_color = Color(Pal.CREAM, 0.1)
	return sb

## --- sidebar (right) -----------------------------------------------------------------------------

func _rebuild_sidebar() -> void:
	if _sidebar_body == null or not is_instance_valid(_sidebar_body):
		return
	for c in _sidebar_body.get_children():
		_sidebar_body.remove_child(c)
		c.queue_free()
	var head := Label.new()
	head.text = "Options"
	head.add_theme_font_size_override("font_size", 26)
	_sidebar_body.add_child(head)
	var save := Button.new()
	save.text = "Save settings"
	save.pressed.connect(_save_settings)
	_sidebar_body.add_child(save)
	var sub := Label.new()
	sub.text = String(CAPTIONS[_selected])
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(Pal.CREAM, 0.65))
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sidebar_body.add_child(sub)
	if _selected == "daily_card":
		var note := Label.new()
		note.text = "This single day card is reused by the Daily dialog. (The Claim is the shared Button.) Preview a state below; the badges show on today / milestone."
		note.add_theme_font_size_override("font_size", 12)
		note.add_theme_color_override("font_color", Color(Pal.STRAW, 0.85))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_sidebar_body.add_child(note)
	if _selected == "dialog" or _selected == "daily" or _selected == "shop":
		var note := Label.new()
		var card_src := "" if _selected == "dialog" else " the card is on the Daily card item;"
		note.text = "The frame (banner · border · ✕ · scroll · padding) is SHARED — edit it on the Frame item.%s Here: this dialog's content." % card_src
		note.add_theme_font_size_override("font_size", 12)
		note.add_theme_color_override("font_color", Color(Pal.STRAW, 0.85))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_sidebar_body.add_child(note)
	if _selected == "card" or _selected == "dialog":
		var note := Label.new()
		note.text = "Claim inherits the Button's STYLE (font / corner / art / shadow). Its badge + icon are the Card's own saved choice."
		note.add_theme_font_size_override("font_size", 12)
		note.add_theme_color_override("font_color", Color(Pal.STRAW, 0.85))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_sidebar_body.add_child(note)
	_sidebar_body.add_child(HSeparator.new())

	# Every element splits its controls into the two buckets (see TEST_KEYS): the persisted design
	# config first, then the transient test/preview scaffolding that the config file never touches.
	match _selected:
		"button":
			_group_header("Saved to config", true)            # only the shared STYLE persists
			_sidebar_body.add_child(_toggle_row("Drop shadow", "shadow"))
			_sidebar_body.add_child(_toggle_row("Use art", "art", true))   # sprite (scaled whole) vs code-drawn
			_sidebar_body.add_child(_slider_row(["font", 12, 40]))
			_group_header("Test only — not saved", false)      # preview props; text/badge/icon live on the Card
			_sidebar_body.add_child(_text_row("Text", "text"))
			_sidebar_body.add_child(_option_row("Background", "bg", ["green", "cream"]))
			if bool(_params["button"]["art"]):
				_sidebar_body.add_child(_option_row("Badge", "badge", Kit.BADGES.keys()))
			else:
				_sidebar_body.add_child(_slider_row(["corner", 0, 40]))
			_sidebar_body.add_child(_option_row("Icon", "icon", ICONS))
			_sidebar_body.add_child(_slider_row(["icon_size", 8, 60]))
			_sidebar_body.add_child(_toggle_row("Enabled", "enabled"))
		"home_button":
			_group_header("Saved to config", true)              # the shared shell / icon / caption / sparkle style
			_sidebar_body.add_child(_slider_row(["px", 90, 200]))
			_sidebar_body.add_child(_slider_row(["icon_scale", 30, 80]))   # icon as % of the disc
			_sidebar_body.add_child(_slider_row(["caption_font", 14, 34]))
			_sidebar_body.add_child(_slider_row(["caption_gap", -10, 40]))   # tab offset below the disc (negative tucks up)
			_section_header("Icon polish (like the Icon sandbox)")
			_sidebar_body.add_child(_toggle_row("Defringe", "defringe"))
			_sidebar_body.add_child(_toggle_row("Drop shadow", "shadow"))
			_sidebar_body.add_child(_slider_row(["feather", 0, 4]))
			_section_header("Sparkle (engine FX — no baked art)")
			_sidebar_body.add_child(_slider_row(["glow", 0, 100]))       # the breathing halo amount
			_sidebar_body.add_child(_slider_row(["twinkle", 0, 100]))    # the drifting-star density
			_group_header("Test only — not saved", false)        # the rail/nav each set their own icon + caption
			_sidebar_body.add_child(_option_row("Icon", "icon", HOME_ICONS))
			_sidebar_body.add_child(_text_row("Caption", "caption"))
			_sidebar_body.add_child(_toggle_row("Sparkle", "sparkle"))   # preview the sparkle on the right-hand disc
		"card":
			_group_header("Saved to config", true)
			_sidebar_body.add_child(_option_row("Icon badge", "icon_badge", Kit.ICON_BADGES.keys()))
			_sidebar_body.add_child(_option_row("Button badge", "badge", Kit.BADGES.keys()))
			_sidebar_body.add_child(_text_row("Claim text", "claim_text"))
			_sidebar_body.add_child(_toggle_row("Claim icon", "icon_on", true))   # whether the Claim shows an icon
			if bool(_params["card"]["icon_on"]):
				_sidebar_body.add_child(_option_row("Icon", "icon", ICONS.slice(1)))   # ICONS minus "none"
			_sidebar_body.add_child(_slider_row(["title", 12, 30]))
			_sidebar_body.add_child(_slider_row(["body", 10, 24]))
		"icon":
			_group_header("Test only — not saved", false)   # a polish-tuning sandbox; the recipe is fixed in the kit
			_sidebar_body.add_child(_toggle_row("Defringe", "defringe"))
			_sidebar_body.add_child(_toggle_row("Drop shadow", "shadow"))
			_sidebar_body.add_child(_slider_row(["feather", 0, 4]))
			_sidebar_body.add_child(_slider_row(["supersample", 1, 4]))
		"frame":
			_frame_sidebar()         # the shared frame's own config (Card / Banner / Close / List)
		"dialog":
			_group_header("Saved to config", true)
			_sidebar_body.add_child(_slider_row(["width", 360, 720]))
			_group_header("Test only — not saved", false)
			_sidebar_body.add_child(_slider_row(["entries", 1, 12]))   # how many rows to preview
		"daily_card":
			_group_header("Saved to config", true)
			_sidebar_body.add_child(_option_row("Today badge", "today_badge", Kit.DAY_BADGES))
			_sidebar_body.add_child(_option_row("Milestone badge", "milestone_badge", Kit.DAY_BADGES))
			_sidebar_body.add_child(_toggle_row("Sparkle (today)", "sparkle"))   # animated twinkles on the claimable card
			_sidebar_body.add_child(_toggle_row("Info icon (top-right)", "info_icon"))
			_sidebar_body.add_child(_slider_row(["label_y", 0, 90]))     # the "Day N" text drop from the top
			_sidebar_body.add_child(_slider_row(["claim_y", 0, 90]))     # how far the action lifts in from the base
			_sidebar_body.add_child(_slider_row(["cell_w", 60, 160]))
			_sidebar_body.add_child(_slider_row(["cell_h", 70, 180]))
			_sidebar_body.add_child(_slider_row(["cell_slice", 0, 80]))
			_sidebar_body.add_child(_toggle_row("Cell art", "cell_art"))
			_group_header("Test only — not saved", false)
			_sidebar_body.add_child(_option_row("Preview", "preview", ["today", "mystery", "done", "future", "shop"]))
			_sidebar_body.add_child(_option_row("Ribbon", "ribbon", Kit.POPULAR_BADGES))   # the popular badge
		"daily":
			_group_header("Saved to config", true)
			_sidebar_body.add_child(_slider_row(["width", 320, 720]))
			_sidebar_body.add_child(_slider_row(["cols", 1, 7]))
			_sidebar_body.add_child(_slider_row(["list_max_h", 0, 1000]))   # height cap; 0 = no scroll
		"shop":
			_group_header("Saved to config", true)
			_sidebar_body.add_child(_slider_row(["width", 360, 720]))
			_sidebar_body.add_child(_slider_row(["cols", 1, 5]))
			_sidebar_body.add_child(_slider_row(["cell_w", 80, 160]))
			_sidebar_body.add_child(_slider_row(["cell_h", 100, 200]))
			_sidebar_body.add_child(_slider_row(["row_gap", 6, 60]))        # spacing between rows + sections
			_sidebar_body.add_child(_slider_row(["list_max_h", 0, 1000]))   # height cap; 0 = no scroll

## A bold top-level group header — the two buckets: gold ● = saved to config, dim ○ = test-only.
func _group_header(title: String, saved: bool) -> void:
	_sidebar_body.add_child(HSeparator.new())
	var l := Label.new()
	l.text = ("●  " if saved else "○  ") + title
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Pal.STRAW if saved else Color(Pal.CREAM, 0.5))
	_sidebar_body.add_child(l)

## A small section header in the sidebar (a separator + an accent label), to group settings.
func _section_header(title: String) -> void:
	_sidebar_body.add_child(HSeparator.new())
	var l := Label.new()
	l.text = title
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", Pal.STRAW)
	_sidebar_body.add_child(l)

## The shared FRAME's options: the saved-to-config bucket (sub-grouped by function), then test-only.
func _frame_sidebar() -> void:
	_group_header("Saved to config", true)
	_section_header("Card")
	_sidebar_body.add_child(_slider_row(["width", 360, 720]))
	_sidebar_body.add_child(_toggle_row("9-slice art", "card_art", true))   # rebuilds the sidebar to swap the slider
	if bool(_params["frame"]["card_art"]):
		for k in ["card_slice_l", "card_slice_t", "card_slice_r", "card_slice_b"]:
			_sidebar_body.add_child(_slider_row([k, 0, 200]))
		_sidebar_body.add_child(_option_row("H stretch", "card_h_stretch", ["stretch", "tile", "tile_fit"]))
		_sidebar_body.add_child(_option_row("V stretch", "card_v_stretch", ["stretch", "tile", "tile_fit"]))
	else:
		_sidebar_body.add_child(_slider_row(["card_corner", 0, 60]))

	_section_header("Banner")
	_sidebar_body.add_child(_slider_row(["banner_font", 16, 56]))
	_sidebar_body.add_child(_slider_row(["banner_h", 50, 160]))
	_sidebar_body.add_child(_slider_row(["banner_text_x", -150, 150]))
	_sidebar_body.add_child(_slider_row(["banner_text_y", -80, 80]))
	_sidebar_body.add_child(_slider_row(["banner_burn", 0, 100]))   # engrave intensity (0 = off)
	_sidebar_body.add_child(_toggle_row("Banner icon", "banner_icon_on"))
	_sidebar_body.add_child(_slider_row(["banner_icon", 24, 110]))
	_sidebar_body.add_child(_slider_row(["banner_x", -200, 200]))
	_sidebar_body.add_child(_slider_row(["banner_y", -120, 120]))
	_sidebar_body.add_child(_slider_row(["banner_icon_x", 0, 700]))
	_sidebar_body.add_child(_slider_row(["banner_icon_y", 0, 160]))

	_section_header("Close")
	_sidebar_body.add_child(_slider_row(["close_size", 30, 96]))
	_sidebar_body.add_child(_slider_row(["close_x", -100, 100]))
	_sidebar_body.add_child(_slider_row(["close_y", -100, 100]))

	_section_header("List")
	_sidebar_body.add_child(_slider_row(["list_max_h", 0, 900]))
	_sidebar_body.add_child(_slider_row(["list_top_pad", -80, 200]))   # gap above row 1 (negative tucks it up)

	_group_header("Test only — not saved", false)
	_sidebar_body.add_child(_slider_row(["snap", 1, 40]))            # the drag-to-move grid

func _slider_row(spec: Array) -> Control:
	var key: String = spec[0]
	var lo: float = float(spec[1])
	var hi: float = float(spec[2])
	var params: Dictionary = _params[_selected]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lbl := Label.new()
	lbl.text = key.replace("_", " ").capitalize()
	lbl.custom_minimum_size = Vector2(118, 0)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lbl)
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
		_rebuild_gallery())
	return row

func _text_row(label: String, key: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size = Vector2(118, 0)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lbl)
	var le := LineEdit.new()
	le.text = String(_params[_selected].get(key, ""))
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.text_changed.connect(func(t: String) -> void:
		_params[_selected][key] = t
		_rebuild_gallery())
	row.add_child(le)
	return row

func _toggle_row(label: String, key: String, rebuild_sidebar := false) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size = Vector2(118, 0)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lbl)
	var cb := CheckButton.new()
	cb.button_pressed = bool(_params[_selected].get(key, false))
	cb.toggled.connect(func(on: bool) -> void:
		_params[_selected][key] = on
		_rebuild_gallery()
		if rebuild_sidebar:
			_rebuild_sidebar.call_deferred())   # defer — we're inside this toggle's own signal
	row.add_child(cb)
	return row

func _option_row(label: String, key: String, options: Array) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size = Vector2(118, 0)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lbl)
	var ob := OptionButton.new()
	var cur := String(_params[_selected].get(key, options[0]))
	for i in options.size():
		ob.add_item(String(options[i]).capitalize(), i)
		if String(options[i]) == cur:
			ob.select(i)
	ob.item_selected.connect(func(idx: int) -> void:
		_params[_selected][key] = String(options[idx])
		_rebuild_gallery())
	row.add_child(ob)
	return row

## --- persistence -------------------------------------------------------------------------------

## Is this element/key a persisted design setting (vs transient test scaffolding from TEST_KEYS)?
func _is_config(id: String, key: String) -> bool:
	return not (key in TEST_KEYS.get(id, []))

func _save_settings() -> void:
	# write ONLY the config bucket — test/preview scaffolding (button icon, dialog entries, …) is excluded
	var out := {}
	for id in _params.keys():
		var sub := {}
		for k in (_params[id] as Dictionary).keys():
			if _is_config(id, k):
				sub[k] = _params[id][k]
		out[id] = sub
	var f := FileAccess.open(SETTINGS, FileAccess.WRITE)
	if f == null:
		push_warning("UI Workbench: could not write %s" % SETTINGS)
		return
	f.store_string(JSON.stringify(out, "\t"))
	f.close()
	print("WORKBENCH: settings saved -> %s" % SETTINGS)

## Merge the saved file over the defaults, copying ONLY config keys present in both — so test
## scaffolding is never restored, and an older or newer settings file can't corrupt the live schema.
func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS):
		return
	var f := FileAccess.open(SETTINGS, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if not (data is Dictionary):
		return
	# MIGRATION: the shared frame's keys used to live under "dialog"; they're a standalone "frame" now.
	# An older file has them under "dialog" — lift those into "frame" so prior tuning isn't lost.
	if data.has("dialog") and data["dialog"] is Dictionary and not data.has("frame"):
		var fr := {}
		for k in (_params["frame"] as Dictionary).keys():
			if (data["dialog"] as Dictionary).has(k):
				fr[k] = data["dialog"][k]
		if not fr.is_empty():
			data["frame"] = fr
	for id in _params.keys():
		if data.has(id) and data[id] is Dictionary:
			for k in (_params[id] as Dictionary).keys():
				if _is_config(id, k) and (data[id] as Dictionary).has(k):
					_params[id][k] = data[id][k]
