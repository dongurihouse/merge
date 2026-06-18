extends SceneTree
## Dev tool (one-off): slice the home-screen mockup component sheet
## (games/grove/assets/farm/farm_icons.png) into individual kit PNGs.
##
##   godot --headless --path . -s res://games/grove/tools/slice_farm_ui.gd
##
## The sheet has a SOLID cyan background (no alpha). For each named region we crop the
## bbox, then knock out the cyan by flooding inward from the crop border (so the piece's
## own light interior survives), trim transparent margins, and save to ui/kit/.
## Regions were measured by alpha-island detection on the sheet (see the table below).

const SRC := "res://games/grove/assets/farm/farm_icons.png"
const OUT := "res://games/grove/assets/ui/kit/"

# name -> Rect2i(x, y, w, h) on the source sheet (tight bbox from island detection).
# A small pad is added per-region so soft gold edges aren't clipped before knockout.
const REGIONS := {
	"badge_cost":         Vector4i(115, 254, 212, 214),   # clean empty cream badge, dashed border
	"badge_locked":       Vector4i(114, 500, 232, 212),   # lock icon + sprout leaves
	"pill_progress":      Vector4i(120, 752, 603, 109),   # wide cream pill, inner track + flower
	"pill_progress_fill": Vector4i(129, 895, 333, 26),    # thin green progress bar
	"nav_market":         Vector4i(240, 1160, 166, 175),  # green-awning storefront
	"nav_garden":         Vector4i(442, 1149, 185, 194),  # green leaf disc
	"nav_map":            Vector4i(666, 1160, 164, 176),  # globe map disc
	"nav_piggy":          Vector4i(855, 1161, 164, 175),  # piggy-in-jar disc
}
const PAD := 4

var _W := 0
var _H := 0
var _data: PackedByteArray

func _is_cyan(i: int) -> bool:
	var o := i * 4
	var r := _data[o]
	var g := _data[o + 1]
	var b := _data[o + 2]
	return r < 90 and g > 150 and b > 180

func _initialize() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(SRC))
	if img == null:
		print("FAIL: cannot load ", SRC); quit(1); return
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	_W = img.get_width()
	_H = img.get_height()
	_data = img.get_data()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))

	for key in REGIONS:
		var name := String(key)
		var r: Vector4i = REGIONS[name]
		var x0 := maxi(0, r.x - PAD)
		var y0 := maxi(0, r.y - PAD)
		var x1 := mini(_W, r.x + r.z + PAD)
		var y1 := mini(_H, r.y + r.w + PAD)
		var cw := x1 - x0
		var ch := y1 - y0

		# cyan-knockout, flooding inward from the crop's own border so enclosed light
		# interiors of the piece survive (4-conn flood over cyan-like pixels)
		var bg := PackedByteArray(); bg.resize(cw * ch)        # 1 = cyan background
		var q := PackedInt32Array()
		for xx in cw:
			_seed(xx, x0, y0, cw, bg, q)                       # top row
			_seed((ch - 1) * cw + xx, x0, y0, cw, bg, q)       # bottom row
		for yy in ch:
			_seed(yy * cw, x0, y0, cw, bg, q)                  # left col
			_seed(yy * cw + (cw - 1), x0, y0, cw, bg, q)       # right col
		while not q.is_empty():
			var p := q[q.size() - 1]
			q.remove_at(q.size() - 1)
			var px := p % cw
			var py := p / cw
			if px > 0: _try(p - 1, x0, y0, cw, bg, q)
			if px < cw - 1: _try(p + 1, x0, y0, cw, bg, q)
			if py > 0: _try(p - cw, x0, y0, cw, bg, q)
			if py < ch - 1: _try(p + cw, x0, y0, cw, bg, q)

		# build the cropped, alpha-knocked image, tracking the content bbox for trim
		var cut := Image.create(cw, ch, false, Image.FORMAT_RGBA8)
		var tx0 := cw; var ty0 := ch; var tx1 := -1; var ty1 := -1
		for yy in ch:
			for xx in cw:
				var li := yy * cw + xx
				if bg[li] == 1:
					cut.set_pixel(xx, yy, Color(0, 0, 0, 0))
				else:
					var sp := (y0 + yy) * _W + (x0 + xx)
					var o := sp * 4
					cut.set_pixel(xx, yy, Color8(_data[o], _data[o + 1], _data[o + 2], 255))
					tx0 = mini(tx0, xx); ty0 = mini(ty0, yy)
					tx1 = maxi(tx1, xx); ty1 = maxi(ty1, yy)

		if tx1 < 0:
			print("WARN: ", name, " is fully transparent — skipped"); continue
		var tw := tx1 - tx0 + 1
		var th := ty1 - ty0 + 1
		var trimmed := Image.create(tw, th, false, Image.FORMAT_RGBA8)
		trimmed.blit_rect(cut, Rect2i(tx0, ty0, tw, th), Vector2i.ZERO)
		var path: String = OUT + name + ".png"
		trimmed.save_png(ProjectSettings.globalize_path(path))
		print("%s -> %dx%d  (src %d,%d %dx%d)" % [name, tw, th, r.x, r.y, r.z, r.w])
	print("DONE")
	quit()

func _seed(li: int, x0: int, y0: int, cw: int, bg: PackedByteArray, q: PackedInt32Array) -> void:
	var sp := (y0 + li / cw) * _W + (x0 + li % cw)
	if bg[li] == 0 and _is_cyan(sp):
		bg[li] = 1
		q.push_back(li)

func _try(li: int, x0: int, y0: int, cw: int, bg: PackedByteArray, q: PackedInt32Array) -> void:
	var sp := (y0 + li / cw) * _W + (x0 + li % cw)
	if bg[li] == 0 and _is_cyan(sp):
		bg[li] = 1
		q.push_back(li)
