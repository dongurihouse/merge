extends RefCounted
## Giver / merchant PORTRAIT busts — a frameless cutout lifted off the painted scene with a
## soft drop-shadow + cream rim (scaled silhouette copies behind), or a plain round placeholder
## chip when the art is absent. Pure view builder: inputs in, a Control out, no scene/instance state.
## Layering: ui/ never imports scenes/ — see docs/design/merge_spec.md §15.

const Game = preload("res://engine/scripts/core/game.gd")
const Pal = Game.PALETTE
const CREAM = Pal.CREAM

# The giver-portrait pool: characters/giver_0.png .. giver_<GIVER_COUNT-1>.png (the forest cast
# sliced from characters_1.png). `which` is any selector (a quest line, a slot index) — it is
# folded into the pool here, so callers don't need to know the count.
const GIVER_COUNT := 16

static func make(which: int, px: float = 124.0) -> Control:
	var face := Control.new()
	face.custom_minimum_size = Vector2(px, px)
	face.size = Vector2(px, px)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path := Game.art("characters/giver_%d.png" % (which % GIVER_COUNT))
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		# owner 2026-06-13: the frameless cutout blended into the painted scene.
		# A soft drop shadow + a cream rim (scaled silhouette copies behind) lift it
		# off the background without a hard square frame.
		var center := Vector2(px / 2.0, px / 2.0)
		var shadow := layer(tex)
		shadow.modulate = Color(0, 0, 0, 0.40)
		shadow.pivot_offset = center
		shadow.scale = Vector2(1.04, 1.04)
		shadow.position = Vector2(0, 7)
		face.add_child(shadow)
		var rim := layer(tex)
		rim.modulate = CREAM
		rim.pivot_offset = center
		rim.scale = Vector2(1.11, 1.11)
		face.add_child(rim)
		face.add_child(layer(tex))
	else:
		var chip := Panel.new()                 # round, not square
		chip.set_anchors_preset(Control.PRESET_FULL_RECT)
		var cs := StyleBoxFlat.new()
		# A neutral placeholder tint cycled by `which` — no character identity (the old fox/hedgehog/
		# squirrel "F/H/S" chip is gone). Only ever seen if a giver_N.png fails to load.
		var fills := [Color("#C96F4A"), Color("#8A5A3B"), Color("#7FA65A"), Color("#7E6BB0")]
		cs.bg_color = fills[which % fills.size()]
		cs.set_corner_radius_all(int(px / 2.0))
		cs.set_border_width_all(3)
		cs.border_color = CREAM
		chip.add_theme_stylebox_override("panel", cs)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.add_child(chip)
	return face

# one full-rect, aspect-centered copy of a bust texture (used for the bust itself plus its
# drop-shadow and cream-rim layers).
static func layer(tex: Texture2D) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t
