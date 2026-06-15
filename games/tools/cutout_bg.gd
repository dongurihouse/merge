extends SceneTree
## WHITE-REGION CUTTER (eng-owned; sibling to cutout_holes.gd). Clears connected
## white/transparent regions whose area >= MIN_AREA — the background AND enclosed
## openings (e.g. the gaps walled off by a fence's posts + rails, which an
## edge-only flood-fill can NEVER reach). Small white highlights (a fence's
## daisies, ~tens of px) fall under the threshold and survive.
##
## Headless, pure-Image — run directly, then --import:
##   godot --headless --path . -s res://games/tools/cutout_bg.gd -- <png> [png ...] [min=600]
##
## Uses process_icon's OWN background rule (value > 0.93, sat < 0.10).

const BG_MAX_VAL := 0.93
const BG_MAX_SAT := 0.10
const ALPHA_MIN := 8
const NEI := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

func _is_bg(c: Color) -> bool:
	if c.a * 255.0 < ALPHA_MIN:
		return true
	var mx: float = maxf(c.r, maxf(c.g, c.b))
	var mn: float = minf(c.r, minf(c.g, c.b))
	var sat: float = 0.0 if mx <= 0.0 else (mx - mn) / mx
	return mx > BG_MAX_VAL and sat < BG_MAX_SAT

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var min_area := 600
	var paths: Array = []
	for a in args:
		if String(a).begins_with("min="):
			min_area = int(String(a).split("=")[1])
		else:
			paths.append(String(a))
	if paths.is_empty():
		print("usage: cutout_bg.gd -- <png> [png ...] [min=N]")
		quit(2)
		return
	var rc := 0
	for p in paths:
		var gp: String = ProjectSettings.globalize_path(p) if String(p).begins_with("res://") else String(p)
		var img := Image.load_from_file(gp)
		if img == null:
			print("SKIP %s (load failed)" % p)
			rc = 1
			continue
		img.convert(Image.FORMAT_RGBA8)
		var w := img.get_width()
		var h := img.get_height()
		var visited := PackedByteArray()
		visited.resize(w * h)
		var cleared := 0
		var regions := 0
		for sy in h:
			for sx in w:
				var k0 := sy * w + sx
				if visited[k0] != 0:
					continue
				if not _is_bg(img.get_pixel(sx, sy)):
					visited[k0] = 1
					continue
				# BFS this white/transparent region (comp doubles as the queue)
				var comp: Array[Vector2i] = [Vector2i(sx, sy)]
				visited[k0] = 1
				var qi := 0
				while qi < comp.size():
					var px: Vector2i = comp[qi]
					qi += 1
					for d in NEI:
						var n: Vector2i = px + d
						if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h:
							continue
						var kk := n.y * w + n.x
						if visited[kk] == 0 and _is_bg(img.get_pixel(n.x, n.y)):
							visited[kk] = 1
							comp.append(n)
				if comp.size() >= min_area:
					regions += 1
					for px in comp:
						var c := img.get_pixel(px.x, px.y)
						if c.a > 0.0:
							img.set_pixel(px.x, px.y, Color(c.r, c.g, c.b, 0.0))
							cleared += 1
		img.save_png(gp)
		print("BG-CUT %s: %dx%d, %d region(s) >= %d, %d px cleared (err=0)" % [p, w, h, regions, min_area, cleared])
	quit(rc)
