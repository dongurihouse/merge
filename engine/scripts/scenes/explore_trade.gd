extends Control
## Explore · Rewards — the final beat of a Rush run. The run's SCORE is converted DIRECTLY into spirits
## (Explore.trade_count → floor(score / TRADE_RATE), min 1 if any score) and they are REVEALED as
## slot-machine reels — one reel per spirit — reusing the shared ui/slot_reel.gd spin (the same feel as
## the daily mystery reveal). There is NO choice on this screen; its job is the payout. The spirits are
## granted up front via Habitat.grant_chest, so the reveal is cosmetic. Done SKIPS the reveal to the end
## on the first press, and returns to the Map on the second.

const G = preload("res://engine/scripts/core/content.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const Explore = preload("res://engine/scripts/core/explore.gd")
const Habitat = preload("res://engine/scripts/core/habitat.gd")
const Hud = preload("res://engine/scripts/ui/hud.gd")
const SceneWarm = preload("res://engine/scripts/core/scene_warm.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const SlotReel = preload("res://engine/scripts/ui/slot_reel.gd")

const INK := Color("#43352B")
const PARCH := Color("#F3E7CE")
const STRAW := Color("#D9B679")
const DIALOG_MAX_W := 540.0
const SHINE_TIER := 3                              # a spirit landing at tier ≥ this shines (the "jackpot" beat)
const SPIN_CFG := {"spin": 1.2, "stagger": 0.55, "anticipate": 0.5, "total_cap": 3.5}  # slower than the mystery reveal

var _hud_refresh := Callable()
var _root: Control = null
var _granted: Array = []                           # the {kind,tier} spirits this run (already in the hand)
var _reels: Array = []                             # the reel Controls, row order
var _caption: Label = null
var _dialog: Control = null
var _spin: Dictionary = {}                         # {finish: Callable} from SlotReel.spin_reels
var _finished := false

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#EAD9B5")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var hud := Hud.build(self, {"on_level": func() -> void: pass})
	_hud_refresh = hud.get("refresh", Callable())
	_build()

func _build() -> void:
	var Kit: GDScript = load("res://games/grove/tools/ui_workbench_kit.gd")
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_root = center

	# convert the run score straight into spirits + drop them in the hand (the reveal is cosmetic over this)
	var n := Explore.trade_count(Explore.score())
	_granted = Habitat.grant_chest(n)

	var viewport_size := _viewport_size()
	var width: float = minf(viewport_size.x * 0.92, DIALOG_MAX_W)
	var opts: Dictionary = Kit.dialog_opts_from_config(Kit.load_config(Kit.CONFIG_PATH))
	opts["banner_text"] = "Rewards"
	opts["banner_icon_id"] = "star"
	opts["banner_font"] = 30
	opts["list_max_h"] = viewport_size.y * 0.74
	opts["on_close"] = func() -> void: _on_done_pressed()
	var dialog: Control = Kit.dialog_frame(_reveal_body(Kit, width), width, opts)
	dialog.name = "TradeDialog"
	dialog.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dialog.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	center.add_child(dialog)
	FX.pop_in(dialog)
	_dialog = dialog

	if _granted.is_empty():
		_finished = true
		if _caption != null:
			_caption.text = "No spirits this run."
	else:
		_spin = SlotReel.spin_reels(self, _reels, dialog, func() -> void: _on_all_landed(), SPIN_CFG)

func _on_all_landed() -> void:
	_finished = true
	if _caption != null:
		_caption.text = "+%d spirit%s to your hand" % [_granted.size(), "" if _granted.size() == 1 else "s"]

func _viewport_size() -> Vector2:
	if is_inside_tree():
		return get_viewport_rect().size
	return Vector2(640.0, 720.0)

func _reveal_body(Kit: GDScript, width: float) -> Control:
	var col := VBoxContainer.new()
	col.name = "RewardBody"
	col.custom_minimum_size = Vector2(maxf(280.0, width - 92.0), 0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)

	var score_chip: Control = Kit.amount_chip("star", "Score  %d" % Explore.score())
	score_chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(score_chip)

	_caption = _label("Revealing your spirits…", 18)
	_caption.name = "RewardCaption"
	_caption.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_caption)

	var grid := GridContainer.new()
	grid.name = "RewardReels"
	grid.columns = clampi(_granted.size(), 1, 5)
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var cols: int = maxi(1, grid.columns)
	var cw: float = clampf((width - 72.0 - float(cols - 1) * 10.0) / float(cols), 64.0, 116.0)
	var ch: float = cw * 1.04
	var decoys := _decoy_symbols()
	var top_i := _top_tier_index(_granted)
	_reels = []
	for i in _granted.size():
		var sp: Dictionary = _granted[i]
		var reel: Control = SlotReel.build_reel(decoys, sp, cw, ch, i, _spirit_tile, int(sp.get("tier", 1)) >= SHINE_TIER)
		reel.set_meta("top", i == top_i)
		_reels.append(reel)
		grid.add_child(reel)
	col.add_child(grid)

	var done: Button = Kit.pill_button("Done", {"bg": "cream", "art": true, "font": 22})
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	done.pressed.connect(_on_done_pressed)
	col.add_child(done)
	return col

# the faces whizzing past during a spin: every unlocked kind at tier 1 (variety); the reel still lands on
# its real {kind,tier}. SlotReel falls back to [target] when this is empty (a single-kind whir).
func _decoy_symbols() -> Array:
	var g := Save.grove()
	var kinds: Array = Explore.unlocked_pool(g.get("unlocks", {}), g.get("gates", []))
	var out: Array = []
	for k in kinds:
		out.append({"kind": String(k), "tier": 1})
	return out

# the index of the highest-tier granted spirit (the reel that shines hardest); -1 if none.
func _top_tier_index(spirits: Array) -> int:
	var best := -1
	var best_t := -1
	for i in spirits.size():
		var tr := int((spirits[i] as Dictionary).get("tier", 1))
		if tr > best_t:
			best_t = tr
			best = i
	return best

# one reel tile's content: a spirit face (icon + name + tier pips). `sym` = {kind,tier}; SlotReel centres it.
func _spirit_tile(sym, w: float, _h: float) -> Control:
	var d: Dictionary = sym
	var holder := VBoxContainer.new()
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	holder.add_theme_constant_override("separation", 3)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_spirit_icon(String(d.get("kind", "")), w * 0.5))
	var nm := _label(String(d.get("kind", "")), 12, true)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	holder.add_child(nm)
	holder.add_child(_tier_pips(int(d.get("tier", 1))))
	return holder

func _tier_pips(tier: int) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for _i in maxi(1, tier):
		var dot := ColorRect.new()
		dot.color = Color(STRAW, 0.95)
		dot.custom_minimum_size = Vector2(6, 6)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(dot)
	return row

func _on_done_pressed() -> void:
	Audio.play("button_tap", -2.0)
	if not _finished:
		if _spin.has("finish"):
			(_spin["finish"] as Callable).call()
		return
	_on_done()

func _on_done() -> void:
	SceneWarm.go(get_tree(), "res://engine/scenes/Map.tscn")

# --- widgets ---------------------------------------------------------------------
# The spirit icon: real art when present, else the placeholder disc with two eyes (named SpiritEye0/1).
func _spirit_icon(kind: String, px: float) -> Control:
	var icon := Control.new()
	icon.name = "SpiritIcon"
	icon.custom_minimum_size = Vector2(px, px)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path := G.resident_art(kind)
	if path != "" and ResourceLoader.exists(path):
		var t := TextureRect.new()
		t.texture = load(path)
		t.set_anchors_preset(Control.PRESET_FULL_RECT)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.add_child(t)
	else:
		var disc := Panel.new()
		disc.set_anchors_preset(Control.PRESET_FULL_RECT)
		var ds := StyleBoxFlat.new()
		ds.bg_color = Color(STRAW, 0.95)
		ds.set_corner_radius_all(int(px / 2.0))
		disc.add_theme_stylebox_override("panel", ds)
		disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.add_child(disc)
		var eye_size := Vector2(maxf(4.0, px * 0.09), maxf(5.0, px * 0.12))
		var eye_gap := px * 0.24
		for i in 2:
			var eye := ColorRect.new()
			eye.name = "SpiritEye%d" % i
			eye.color = Color(INK, 0.82)
			eye.size = eye_size
			eye.position = Vector2(px * 0.5 + (-0.5 + float(i)) * eye_gap - eye_size.x * 0.5, px * 0.50)
			eye.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.add_child(eye)
	return icon

# kept for tests: a bare spirit face (the placeholder-eye coverage).
func _spirit_widget(kind: String, px: float) -> Control:
	return _spirit_icon(kind, px)

func _label(text: String, size: int, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", INK)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if bold:
		l.add_theme_color_override("font_outline_color", PARCH)
		l.add_theme_constant_override("outline_size", 2)
	return l
