extends SceneTree
## Bake the mask-reveal home-screen data: clean/broken bases from assets/farm/, source
## sheets (farm_vinesv2, farm_icons) from assets/_originals/farm/.
## Outputs (committed): assets/farm/badge.png, assets/farm/mask_<spot>.png (per building),
## assets/farm/farm_home.json [{spot,cost,pos:[fx,fy],mask}]. Proof: /tmp/fh_one.png (one building cleaned).
##   godot --headless --path . -s res://games/grove/tools/farm_home_bake.gd

const MIN_AREA := 60
const DILATE := 5                 # grow each vine mask a few px so the reveal fully covers the vine

# The vined buildings in farm.png → which farmhouse spot + its ✿cost. Approx centres (fraction) are
# ONLY used to assign auto-detected vine clumps to a building; the saved pos/mask come from the image.
const BUILDINGS := [
	{"spot": "fh_hearth",  "cost": 3, "c": Vector2(0.42, 0.40)},   # cottage
	{"spot": "fh_larder",  "cost": 4, "c": Vector2(0.78, 0.55)},   # shed
	{"spot": "fh_boxes",   "cost": 4, "c": Vector2(0.13, 0.62)},   # flower boxes
	{"spot": "fh_well",    "cost": 3, "c": Vector2(0.18, 0.80)},   # well
	{"spot": "fh_kitchen", "cost": 3, "c": Vector2(0.58, 0.66)},   # kitchen garden (veg-plot fence)
	{"spot": "fh_porch",   "cost": 4, "c": Vector2(0.55, 0.87)},   # doghouse
	{"spot": "fh_lantern", "cost": 5, "c": Vector2(0.86, 0.84)},   # lantern
]

func _initialize() -> void:
	var farm := _img("res://games/grove/assets/farm/farm.png")
	var broken := _img("res://games/grove/assets/farm/farm_brokenv2.png")
	var vines := _img("res://games/grove/assets/_originals/farm/farm_vinesv2.png")
	var icons := _img("res://games/grove/assets/_originals/farm/farm_icons.png")
	if farm == null or broken == null or vines == null or icons == null:
		print("FAILED to load"); quit(1); return
	var w := farm.get_width(); var h := farm.get_height()

	# --- badge.png: crop the gold-rimmed circle (icon_13 region) from farm_icons, cyan → transparent ---
	var bx := 285; var by := 963; var bw := 152; var bh := 163
	var id := icons.get_data(); var ikr := id[0]; var ikg := id[1]; var ikb := id[2]
	var badge := Image.create(bw, bh, false, Image.FORMAT_RGBA8)
	for y in bh:
		for x in bw:
			var px := icons.get_pixel(bx + x, by + y)
			var dr := int(px.r8) - ikr; var dg := int(px.g8) - ikg; var db := int(px.b8) - ikb
			if dr * dr + dg * dg + db * db < 2600:
				badge.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				badge.set_pixel(x, y, px)
	badge.save_png(ProjectSettings.globalize_path("res://games/grove/assets/farm/badge.png"))

	# --- vine coverage + connected-component clumps ---
	var vd := vines.get_data(); var kr := vd[0]; var kg := vd[1]; var kb := vd[2]
	var vine := PackedByteArray(); vine.resize(w * h)
	for i in w * h:
		var dr2 := int(vd[i * 4]) - kr; var dg2 := int(vd[i * 4 + 1]) - kg; var db2 := int(vd[i * 4 + 2]) - kb
		vine[i] = 1 if (dr2 * dr2 + dg2 * dg2 + db2 * db2) > 3000 else 0
	var labels := PackedInt32Array(); labels.resize(w * h); labels.fill(-1)
	var clumps := []                  # {area, cx, cy, pixels:PackedInt32Array}
	var stack := PackedInt32Array()
	for start in w * h:
		if labels[start] != -1 or vine[start] == 0: continue
		var cid := clumps.size(); var px := PackedInt32Array(); var ax := 0; var ay := 0
		stack.clear(); stack.push_back(start); labels[start] = cid
		while stack.size() > 0:
			var idx := stack[stack.size() - 1]; stack.remove_at(stack.size() - 1)
			var x := idx % w; var y := idx / w
			px.push_back(idx); ax += x; ay += y
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var nx: int = x + dx; var ny: int = y + dy
					if nx < 0 or ny < 0 or nx >= w or ny >= h: continue
					var ni: int = ny * w + nx
					if labels[ni] == -1 and vine[ni] == 1:
						labels[ni] = cid; stack.push_back(ni)
		if px.size() >= MIN_AREA:
			clumps.append({"n": px.size(), "cx": float(ax) / px.size(), "cy": float(ay) / px.size(), "px": px})

	# --- assign each clump to the nearest building; union pixels per building ---
	var per := []
	for b in BUILDINGS:
		per.append({"px": PackedInt32Array(), "sx": 0.0, "sy": 0.0, "n": 0})
	for c in clumps:
		var best := 0; var bestd := 1e20
		for bi in BUILDINGS.size():
			var ctr: Vector2 = BUILDINGS[bi]["c"]
			var d := Vector2(c["cx"] / w, c["cy"] / h).distance_squared_to(ctr)
			if d < bestd: bestd = d; best = bi
		var p = per[best]
		for idx in c["px"]: p["px"].push_back(idx)
		p["sx"] += c["cx"] * c["n"]; p["sy"] += c["cy"] * c["n"]; p["n"] += c["n"]

	# --- per building: dilate the mask, save it, record centroid + cost ---
	var data := {"buildings": []}
	for bi in BUILDINGS.size():
		var p = per[bi]
		if p["n"] == 0:
			continue
		var m := PackedByteArray(); m.resize(w * h)
		for idx in p["px"]: m[idx] = 1
		m = _dilate(m, w, h, DILATE)
		var mask := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for i in w * h:
			mask.set_pixel(i % w, i / w, Color(1, 1, 1, 1) if m[i] == 1 else Color(0, 0, 0, 0))
		var spot := String(BUILDINGS[bi]["spot"])
		mask.save_png(ProjectSettings.globalize_path("res://games/grove/assets/farm/mask_%s.png" % spot))
		data["buildings"].append({
			"spot": spot, "cost": BUILDINGS[bi]["cost"],
			"pos": [p["sx"] / p["n"] / w, p["sy"] / p["n"] / h],
			"mask": "mask_%s.png" % spot,
		})
		print("  %s  cost %d  pos (%.3f,%.3f)  vine_px %d" % [spot, BUILDINGS[bi]["cost"], p["sx"]/p["n"]/w, p["sy"]/p["n"]/h, p["n"]])

	var jf := FileAccess.open(ProjectSettings.globalize_path("res://games/grove/assets/farm/farm_home.json"), FileAccess.WRITE)
	jf.store_string(JSON.stringify(data, "\t")); jf.close()

	# --- proof: clean just the WELL (fh_well) over the broken base ---
	var proof := broken.duplicate()
	var wellm := PackedByteArray(); wellm.resize(w * h)
	for bi in BUILDINGS.size():
		if String(BUILDINGS[bi]["spot"]) == "fh_well":
			for idx in per[bi]["px"]: wellm[idx] = 1
	wellm = _dilate(wellm, w, h, DILATE)
	for i in w * h:
		if wellm[i] == 1: proof.set_pixel(i % w, i / w, farm.get_pixel(i % w, i / w))
	proof.save_png("/tmp/fh_one.png")
	print("BAKE done: badge + %d masks + farm_home.json ; proof /tmp/fh_one.png (well cleaned)" % data["buildings"].size())
	quit()

func _dilate(m: PackedByteArray, w: int, h: int, r: int) -> PackedByteArray:
	for _pass in r:
		var out := m.duplicate()
		for y in h:
			for x in w:
				if m[y * w + x] == 1: continue
				if (x > 0 and m[y*w+x-1]==1) or (x<w-1 and m[y*w+x+1]==1) or (y>0 and m[(y-1)*w+x]==1) or (y<h-1 and m[(y+1)*w+x]==1):
					out[y * w + x] = 1
		m = out
	return m

func _img(path: String) -> Image:
	var im := Image.load_from_file(ProjectSettings.globalize_path(path))
	if im != null: im.convert(Image.FORMAT_RGBA8)
	return im
