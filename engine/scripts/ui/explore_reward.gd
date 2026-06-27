extends RefCounted
## Explore · Rewards — the run's payout, shown as a MODAL OVERLAY on top of the frozen Rush board (no
## scene change). Converts the run score directly into spirits (Explore.trade_count, min 1 if any score),
## grants them via Habitat.grant_chest, and reveals them as a slot cascade — one big reel per spirit,
## reusing the shared ui/slot_reel.gd spin. Done SKIPS the reveal to the end on the first press, then
## returns to the Map. Mounts via ui/overlay.gd, the same way the daily mystery reveal (ui/login_mystery.gd)
## stacks over the calendar.

const G = preload("res://engine/scripts/core/content.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const Explore = preload("res://engine/scripts/core/explore.gd")
const Habitat = preload("res://engine/scripts/core/habitat.gd")
const SceneWarm = preload("res://engine/scripts/core/scene_warm.gd")
const Audio = preload("res://engine/scripts/core/audio.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")
const SlotReel = preload("res://engine/scripts/ui/slot_reel.gd")
const Overlay = preload("res://engine/scripts/ui/overlay.gd")

const KIT_PATH := "res://games/grove/tools/ui_workbench_kit.gd"
const OVERLAY_NAME := "ExploreRewardOverlay"
const INK := Color("#43352B")
const STRAW := Color("#D9B679")
const DIALOG_MAX_W := 540.0
const SHINE_TIER := 3                               # a spirit landing at tier ≥ this shines (the "jackpot" beat)
const MAX_ROWS := 3                                 # cap revealed rows so a huge haul can't make the dialog endless
const SPIN_CFG := {"spin": 1.2, "stagger": 0.55, "anticipate": 0.5, "total_cap": 3.5}

static var _trim_cache := {}                        # path → opaque-cropped texture (so spirit art fills its cell)

## Open the reward reveal as a modal overlay on `host` (the Rush board). opts: on_done (Callable; default
## = warp to the Map). Idempotent — a duplicated open() (double-tap) finds the first overlay and bails.
static func open(host: Control, opts: Dictionary = {}) -> void:
	if Overlay.is_open(host, OVERLAY_NAME):
		return
	var Kit: GDScript = load(KIT_PATH)
	if Kit == null:
		return
	var overlay := Overlay.mount(host, OVERLAY_NAME, Overlay.MODAL_TOP_Z)   # above the board + HUD
	var veil := ColorRect.new()
	veil.color = Color(INK, 0.55)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP                           # swallow taps on the frozen board
	overlay.add_child(veil)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(cc)

	# convert the run score straight into spirits + drop them in the hand (the reveal is cosmetic over this)
	var granted: Array = Habitat.grant_chest(Explore.trade_count(Explore.score()))

	var vp: Vector2 = (host.get_viewport_rect().size if host.is_inside_tree() else Vector2(720.0, 1280.0))
	var width: float = minf(vp.x * 0.92, DIALOG_MAX_W)

	var st := {"finished": false, "spin": {}}
	var on_done: Callable = opts.get("on_done", func() -> void: _warp_map(host))
	var press := func() -> void:
		Audio.play("button_tap", -2.0)
		if not bool(st["finished"]):
			var spin: Dictionary = st["spin"]
			if spin.has("finish"):
				(spin["finish"] as Callable).call()
			return
		_dismiss(overlay, on_done)

	var built := build(Kit, granted, width, vp.y, press)
	var caption: Label = built["caption"]
	cc.add_child(built["dialog"])
	FX.pop_in(built["dialog"])

	if granted.is_empty():
		st["finished"] = true
		caption.text = "No spirits this run."
	else:
		var on_landed := func() -> void:
			st["finished"] = true
			caption.text = "+%d spirit%s to your hand" % [granted.size(), "" if granted.size() == 1 else "s"]
		st["spin"] = SlotReel.spin_reels(overlay, built["reels"], built["dialog"], on_landed, SPIN_CFG)

static func _warp_map(host: Control) -> void:
	if is_instance_valid(host) and host.is_inside_tree():
		SceneWarm.go(host.get_tree(), "res://engine/scenes/Map.tscn")

static func _dismiss(overlay: Control, on_done: Callable) -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()
	if on_done.is_valid():
		on_done.call()

## Build the reveal FACE — the shared framed dialog with a score chip, a caption, a centred row/grid of
## spirit REELS, and a Done pill. Returns {dialog, reels (row order), caption}. The single source for the
## reveal: open() spins + drives Done; tests build it static. `press` wires both Done and the ✕.
static func build(Kit: GDScript, granted: Array, width: float, vh: float, press: Callable) -> Dictionary:
	var col := VBoxContainer.new()
	col.name = "RewardBody"
	col.custom_minimum_size = Vector2(maxf(280.0, width - 92.0), 0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)

	var score_chip: Control = Kit.amount_chip("star", "Score  %d" % Explore.score())
	score_chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(score_chip)

	var caption := _label("Revealing your spirits…", 18)
	caption.name = "RewardCaption"
	caption.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(caption)

	var grid := GridContainer.new()
	grid.name = "RewardReels"
	# pick columns so each cell stays large; wrap to extra rows when there are many spirits (≤4 across, fewer
	# on a narrow screen) — never crush 7 spirits into one tiny row, and keep the icons big.
	var avail: float = width - 64.0
	var cols: int = clampi(granted.size(), 1, mini(maxi(1, int(avail / 110.0)), 4))
	grid.columns = cols
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var cw: float = clampf((avail - float(cols - 1) * 14.0) / float(cols), 92.0, 138.0)
	var ch: float = cw * 1.06
	var decoys := _decoy_symbols()
	# cap the REVEALED reels to MAX_ROWS so a huge haul can't make the dialog endless — the overflow folds
	# into a "+N more" tile (every spirit is still granted to the hand; the reveal is purely cosmetic). When
	# it overflows, show the highest-tier pulls so a rare never hides behind the chip.
	var cap: int = cols * MAX_ROWS
	var display: Array = granted
	var more: int = 0
	if granted.size() > cap:
		var ranked := granted.duplicate()
		ranked.sort_custom(func(a, b) -> bool: return int((a as Dictionary).get("tier", 1)) > int((b as Dictionary).get("tier", 1)))
		display = ranked.slice(0, cap - 1)
		more = granted.size() - display.size()
	var top_i := _top_tier_index(display)
	var reels: Array = []
	for i in display.size():
		var sp: Dictionary = display[i]
		var reel: Control = SlotReel.build_reel(decoys, sp, cw, ch, i, _spirit_tile, int(sp.get("tier", 1)) >= SHINE_TIER)
		reel.set_meta("top", i == top_i)
		reels.append(reel)
		grid.add_child(reel)
	if more > 0:
		grid.add_child(_more_cell(more, cw, ch))
	col.add_child(grid)

	var done: Button = Kit.pill_button("Done", {"bg": "cream", "art": true, "font": 22})
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	done.pressed.connect(press)
	col.add_child(done)

	var opts: Dictionary = Kit.dialog_opts_from_config(Kit.load_config(Kit.CONFIG_PATH))
	opts["banner_text"] = "Rewards"
	opts["banner_icon_id"] = "star"
	opts["banner_font"] = 30
	opts["list_max_h"] = vh * 0.74
	opts["on_close"] = press
	var dialog: Control = Kit.dialog_frame(col, width, opts)
	dialog.name = "RewardDialog"
	dialog.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dialog.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return {"dialog": dialog, "reels": reels, "caption": caption}

# the faces whizzing past during a spin: every unlocked kind at tier 1 (variety); the reel still lands on
# its real {kind,tier}. SlotReel falls back to [target] when this is empty (a single-kind whir).
static func _decoy_symbols() -> Array:
	var g := Save.grove()
	var kinds: Array = Explore.unlocked_pool(g.get("unlocks", {}), g.get("gates", []))
	var out: Array = []
	for k in kinds:
		out.append({"kind": String(k), "tier": 1})
	return out

# the index of the highest-tier granted spirit (the reel that shines hardest); -1 if none.
static func _top_tier_index(spirits: Array) -> int:
	var best := -1
	var best_t := -1
	for i in spirits.size():
		var tr := int((spirits[i] as Dictionary).get("tier", 1))
		if tr > best_t:
			best_t = tr
			best = i
	return best

# one reel tile: just the spirit face, sized to FILL the cell window — no name label, no pips (the icon is
# the read; tier is signalled by the shine). `sym` = {kind,tier}; SlotReel centres it in the window.
static func _spirit_tile(sym, w: float, h: float) -> Control:
	var d: Dictionary = sym
	return _spirit_icon(String(d.get("kind", "")), minf(w, h))

# the overflow tile: a parchment cell reading "+N" for the spirits past the row cap (all still in the hand).
static func _more_cell(n: int, cw: float, ch: float) -> Control:
	var cell := PanelContainer.new()
	cell.name = "RewardMore"
	cell.custom_minimum_size = Vector2(cw, ch)
	cell.add_theme_stylebox_override("panel", SlotReel.cell_stylebox())
	var l := _label("+%d" % n, 30, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell.add_child(l)
	return cell

# Crop a spirit texture to a SQUARE centred on its alpha-weighted VISUAL CENTRE, so every spirit fills its
# cell at a uniform size and reads as centred — not bottom-heavy. The source art frames each subject low in
# a 512² canvas with a thin wisp on top, so the opaque box (or the raw texture) renders small + bottom-heavy;
# centring on the mass fixes it. Cached per path. Returns the raw texture when the image can't be read (the
# headless dummy renderer's get_image() is null) or the crop would be degenerate — never crashes.
static func _trimmed_tex(path: String) -> Texture2D:
	if _trim_cache.has(path):
		return _trim_cache[path]
	var tex: Texture2D = load(path)
	var result: Texture2D = tex
	if tex != null:
		var img := tex.get_image()
		if img != null:
			if img.is_compressed():
				img.decompress()
			var fw := float(img.get_width())
			var fh := float(img.get_height())
			# alpha centroid, computed on a cheap 64² downscale (the full art is ~512²)
			var n := 64
			var small: Image = img.duplicate()
			small.resize(n, n, Image.INTERPOLATE_BILINEAR)
			var sx := 0.0
			var sy := 0.0
			var sw := 0.0
			for yy in n:
				for xx in n:
					var a := small.get_pixel(xx, yy).a
					if a > 0.0:
						sx += float(xx) * a
						sy += float(yy) * a
						sw += a
			if sw > 0.0:
				var cx := (sx / sw + 0.5) / float(n) * fw
				var cy := (sy / sw + 0.5) / float(n) * fh
				# the largest square centred on the centroid that still fits inside the canvas
				var half := minf(minf(cx, fw - cx), minf(cy, fh - cy))
				if half > 8.0:
					var at := AtlasTexture.new()
					at.atlas = tex
					at.region = Rect2(cx - half, cy - half, half * 2.0, half * 2.0)
					result = at
	_trim_cache[path] = result
	return result

# The spirit icon: real art when present, else the placeholder disc with two eyes (named SpiritEye0/1).
static func _spirit_icon(kind: String, px: float) -> Control:
	var icon := Control.new()
	icon.name = "SpiritIcon"
	icon.custom_minimum_size = Vector2(px, px)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path := G.resident_art(kind)
	if path != "" and ResourceLoader.exists(path):
		var t := TextureRect.new()
		t.texture = _trimmed_tex(path)
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

static func _label(text: String, size: int, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", INK)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if bold:
		l.add_theme_constant_override("outline_size", 2)
	return l
