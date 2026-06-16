extends RefCounted
## Bag-bar BUILDER (Wave 3) — builds the §5 bag-slot row (the owned slots + the trailing +slot
## buy affordance) and fills the slots (a mini bagged item, or the +slot gem price). Stateless:
## the coordinator owns the `bag` array, Save.bag_slots(), and the stash / retrieve / buy-slot
## transactions + the §5 drag-back; this only assembles + fills nodes. Slot handlers are injected
## as Callables so ui/ never imports scenes/ (the §15 layering invariant).
##
## Usage:
##   bag_slots_ui = BagView.build_bar(bag_bar, {owned, has_buy, on_buy, on_slot_input})
##   BagView.rebuild(bag_slots_ui, {bag, owned, has_buy, slot_price})

const Game = preload("res://engine/scripts/core/game.gd")
const Look = preload("res://engine/scripts/ui/skin.gd")
const PieceView = preload("res://engine/scripts/ui/piece_view.gd")
const Pal = Game.PALETTE
const GROUND_EDGE = Pal.GROUND_EDGE
const CREAM = Pal.CREAM

# Build the slot buttons into `bag_bar` and return them. Each OWNED item slot is a drag source for
# the §5 drag-back retrieve (on_slot_input.bind(i)); the trailing +slot — present only while
# has_buy — is a tap (on_buy).
static func build_bar(bag_bar: HBoxContainer, cfg: Dictionary) -> Array:
	var owned: int = cfg.owned
	var has_buy: bool = cfg.has_buy
	var on_buy: Callable = cfg.on_buy
	var on_slot_input: Callable = cfg.on_slot_input
	var slots: Array = []
	var total := owned + (1 if has_buy else 0)
	for i in total:
		var s := Button.new()
		s.focus_mode = Control.FOCUS_NONE
		s.custom_minimum_size = Vector2(84, 84)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(GROUND_EDGE, 0.6)
		sb.set_corner_radius_all(18)
		sb.set_border_width_all(3)
		sb.border_color = Color(CREAM, 0.35)
		s.add_theme_stylebox_override("normal", sb)
		s.add_theme_stylebox_override("hover", sb)
		s.add_theme_stylebox_override("pressed", sb)
		var is_buy := i == owned          # the trailing +slot affordance (only present below cap)
		if is_buy:
			s.pressed.connect(on_buy)
		else:
			s.gui_input.connect(on_slot_input.bind(i))   # §5: a bagged item drags back out
		bag_bar.add_child(s)
		slots.append(s)
	return slots

# Fill each slot: the buyable +slot price (gem SPRITE + a number-only "+N", §13 no baked emoji) on
# the buy slot, else the bagged item (a mini piece). Mirrors _build_bag_bar's order.
static func rebuild(bag_slots_ui: Array, cfg: Dictionary) -> void:
	var bag: Array = cfg.bag
	var owned: int = cfg.owned
	var has_buy: bool = cfg.has_buy
	var slot_price: int = cfg.slot_price
	for i in bag_slots_ui.size():
		var s: Button = bag_slots_ui[i]
		for c in s.get_children():
			c.queue_free()
		if i == owned and has_buy:
			var lock := HBoxContainer.new()
			lock.set_anchors_preset(Control.PRESET_FULL_RECT)
			lock.alignment = BoxContainer.ALIGNMENT_CENTER
			lock.add_theme_constant_override("separation", 2)
			lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var lock_ic := Look.icon("gem", 22.0)
			lock_ic.modulate = Color(CREAM, 0.55)
			lock.add_child(lock_ic)
			var lock_lbl := Label.new()
			lock_lbl.text = "+%d" % slot_price
			lock_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lock_lbl.add_theme_font_size_override("font_size", 22)
			lock_lbl.add_theme_color_override("font_color", Color(CREAM, 0.55))
			lock_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lock.add_child(lock_lbl)
			s.add_child(lock)
			continue
		if i < bag.size():
			var mini_n := PieceView.make_piece(int(bag[i]), 76.0)
			mini_n.position = Vector2(4, 4)
			mini_n.mouse_filter = Control.MOUSE_FILTER_IGNORE
			s.add_child(mini_n)
