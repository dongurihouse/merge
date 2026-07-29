extends SceneTree
## Dev tool (real renderer; via engine/tools/quiet_godot.sh): render ONE of our UI elements in ISOLATION
## on a FLAT field of the concept mock's OWN background colour, at the mock's OWN pixel size — and, in
## the same sheet, a 1:1 crop of that element out of the mock itself. That pairing is the whole point.
## The method, and the wrong conclusions each rule prevents, is docs/design/verifying-against-a-mock.md.
##
##   make shot-mock OUT=/tmp/nav.png CELLS="mock:nav_home mock:nav_shop nav_home"
##   make shot-mock OUT=/tmp/pill.png CELLS="mock:wallet_water wallet_water wallet_water:cp=halo_reach=0.06w"
##   make shot TOOL=games/grove/tools/mock_compare_shot ARGS="/tmp/x.png mock:nav_home nav_home 1400x900"
##
## WHY IT EXISTS. Darkening is INFERRED from a luma ratio, so it is a function of the ground it falls
## on; a scale difference resamples the very pixels a shadow lives in; a fill difference moves the
## contact reading. Measuring OUR element on OUR screen against THE MOCK's element on ITS screen varies
## all three at once, and the number that comes out is not a comparison of anything. This tool removes
## all three: same background pixels, same scale, and `fill=` forces our face to the mock's own colour
## so the only thing left varying is the thing under test.
##
## Each CELL is `[mock:]REGION[:MOD][:MOD]…`, laid left to right:
##   nav_home            OUR element for that region, at the mock's own face width
##   mock:nav_home       the MOCK's own pixels for it, 1:1, uncompressed
## Regions (which mock, which rect of it, how much of the ground beside it is REAL) are data, not code:
## games/grove/tools/mock_targets.json. Shared MODs, which every element takes:
##   :fill=#RRGGBB       force the face colour — the mock's own, so fill stops being a variable
##   :cp=K=V[,K=V]…      override any cut-paper edge knob (halo_reach, halo_falloff, halo_offset,
##                       corner, …). V is a number, `Nw` (that fraction of the face width, which is how
##                       reaches are actually specified), `#RRGGBB`, `true`/`false`, or `off`.
##   :opt=K=V[,K=V]…     the same, for the element's top-level opts
##   :label=TEXT         the text printed above the cell (`_` reads as a space — one shell word)
## Per-element MODs are in games/grove/tools/mock_elements.gd (`:active`, `:glyph=`, `:count=`, …).
## Because the tuning is an ARGUMENT, before / after / mock come out of ONE launch and one build.
##
## Global `key=value` args: `bg=` override the derived flat field · `pad=` the field margin round each
## element · `labels=0` to drop the label band · `targets=` a different registry JSON.
##
## The tool writes `<sheet>.json` beside the PNG (and prints it): every cell's face rect, how many px of
## GENUINE mock art it carries on each side, and the mock's own field colour + grain sigma. mock_profile.py
## reads that, so a measuring pass can never run against a hand-copied stale rect list.
const Base = preload("res://engine/tools/shot_base.gd")
const Elements = preload("res://games/grove/tools/mock_elements.gd")
const UiFont = preload("res://engine/scripts/ui/ui_font.gd")

const TARGETS := "res://games/grove/tools/mock_targets.json"
const PAD := 44.0            # field either side of an element: wider than any shadow reach in play
const LABEL_H := 30.0
## How far two regions' own field colours may differ (L1 over RGB) before one sheet cannot honestly
## carry both. The profiler divides by ONE field luma for the whole sheet, so a sheet whose cells sat on
## measurably different grounds would report darkenings that are not comparable — which is the exact
## defect this tool exists to remove.
const FIELD_TOLERANCE := 8
## The mods whose value is prose, and so may spell a space as `_`. Everything else is a knob name or a
## number, where that substitution is silent corruption.
const TEXT_MODS := ["label", "cap"]

## Decoded mock PNGs, by registry name — the field pass and the crop pass both want the same pixels.
var _images := {}


func _initialize() -> void:
	var ctx := await Base.begin(self, {"tool": "mock_compare", "default_out": "/tmp/mock_compare.png",
		"save": false})
	if ctx.is_empty():
		return                        # refused: begin() printed why and quit(2)
	var args: Array = ctx["args"]
	var out: String = ctx["out"]
	# 1:1 PIXELS, ALWAYS. The game stretches its 1080x1920 canvas to the window, which on a wide capture
	# window letterboxes the drawing into a sub-rect and RESAMPLES every element on the way — a measuring
	# rig cannot afford either. Disabling the stretch makes a `WxH` arg buy real room instead of a scale
	# factor, so a sweep of six tunings fits in ONE launch.
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	UiFont.apply()                    # the real global font — a caption must read as it ships

	var reg := _registry(String(Base.opt(args, "targets", TARGETS)))
	if reg.is_empty():
		quit(2)
		return

	var specs: Array = []
	var wxh := RegEx.create_from_string("^[0-9]+x[0-9]+$")     # shot_base's window-size arg, not a cell
	for a in args.slice(1):
		if "=" in String(a).split(":")[0] or wxh.search(String(a)) != null:
			continue                                # a `key=value` global (or the size) is not a cell
		specs.append(String(a))
	if specs.is_empty():
		specs = ["mock:nav_home", "nav_home"]       # the default sheet: the mock's tab beside ours

	var pad := maxf(0.0, float(Base.opt(args, "pad", str(PAD))))
	var label_h := 0.0 if Base.opt(args, "labels", "1") == "0" else LABEL_H

	# --- resolve every cell, and the ONE flat field the sheet may honestly use -------------------
	var plans: Array = []
	for spec in specs:
		var p := _plan(String(spec), reg)
		if p.is_empty():
			quit(2)
			return
		plans.append(p)
	var field := _field(plans, reg)
	if field.is_empty():
		quit(2)
		return
	var bg_col := Color(Base.opt(args, "bg", String(field["hex"])))

	var bg := ColorRect.new()
	bg.color = bg_col
	bg.size = Vector2(4000, 4000)                   # covers the window, so the crop is never dark
	root.add_child(bg)

	# --- lay the sheet out ----------------------------------------------------------------------
	var cell_w := 0.0
	var face_h := 0.0
	var any_floating := false
	for p in plans:
		cell_w = maxf(cell_w, float(p["drawn_w"]) + pad * 2.0)
		face_h = maxf(face_h, float(p["face_h"]))
		any_floating = any_floating or not bool(p["bleed_bottom"])
	var body_bottom := label_h + pad + face_h
	var content := Vector2(cell_w * float(plans.size()), body_bottom + (pad if any_floating else 0.0))

	var cells: Array = []
	for i in plans.size():
		var p: Dictionary = plans[i]
		var x := float(i) * cell_w + (cell_w - float(p["drawn_w"])) * 0.5
		# an element that BLEEDS off the bottom of the screen must bleed off the bottom of the sheet the
		# same way, so its shadow-free cut edge is the sheet's edge and not a floating line.
		var y := (body_bottom - float(p["face_h"])) if bool(p["bleed_bottom"]) else (label_h + pad)
		var face_x := x + float(p["face_dx"])
		# how many px of GENUINE mock art the cell carries on each side. Past it the cell is the flat
		# field, where a profile reads a serene 0.000 and means nothing; mock_profile.py refuses to
		# report beyond these, so a crop that ran out of mock cannot be mistaken for a shadow that ended.
		var ground := {"left": int(pad), "right": int(pad), "top": int(pad),
			"bottom": 0 if bool(p["bleed_bottom"]) else int(pad)}
		if bool(p["is_mock"]):
			ground = _add_mock(bg, p, Vector2(face_x, y), pad)
			if ground.is_empty():
				quit(2)
				return
		else:
			var node: Control = p["node"]
			node.position = Vector2(face_x, y)
			bg.add_child(node)
		if label_h > 0.0:
			var lbl := Label.new()
			lbl.text = String(p["label"])
			lbl.clip_text = true
			lbl.position = Vector2(float(i) * cell_w, 4.0)
			lbl.size = Vector2(cell_w, label_h)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.add_theme_color_override("font_color", Color("#20303A"))
			lbl.add_theme_font_size_override("font_size", 17)
			bg.add_child(lbl)
		cells.append({"spec": p["spec"], "label": String(p["label"]), "region": p["region"],
			"is_mock": bool(p["is_mock"]), "bleed_bottom": bool(p["bleed_bottom"]),
			"cell_x": int(round(float(i) * cell_w)), "cell_w": int(round(cell_w)),
			"face_x": int(round(face_x)), "face_y": int(round(y)),
			"face_w": int(round(float(p["face_w"]))), "face_h": int(round(float(p["face_h"]))),
			"real_ground": ground})

	await create_timer(0.4).timeout
	# a sheet wider than the framebuffer would be CROPPED, and a cropped last cell still profiles — as
	# nonsense. REFUSE rather than save it; the fix is a bigger `WxH` arg (shot_base honours it).
	if content.x > root.size.x or content.y > root.size.y:
		print("REFUSED: %d cells need %dx%d but the window is %s — pass a bigger WxH arg." % \
			[plans.size(), int(content.x), int(content.y), str(root.size)])
		print("A cropped cell still profiles, and the numbers look ordinary. Nothing was saved.")
		quit(2)
		return
	var err := Base.capture(self, out, args, Rect2i(0, 0, int(content.x), int(content.y)))
	var side := {"sheet": out, "canvas": [int(content.x), int(content.y)], "field": field, "cells": cells}
	var f := FileAccess.open(out + ".json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(side))
		f.close()
	print("MOCK_COMPARE saved=%s err=%d canvas=%dx%d bg=%s field=%s cells=%s" % \
		[out, err, int(content.x), int(content.y), bg_col.to_html(false), JSON.stringify(field),
		JSON.stringify(cells)])
	quit()


# --- the registry -------------------------------------------------------------------------

func _registry(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		print("REFUSED: no target registry at %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary) or not parsed.has("regions") or not parsed.has("mocks"):
		print("REFUSED: %s is not a mock-target registry (needs `mocks` and `regions`)" % path)
		return {}
	return parsed


## Parse `[mock:]REGION[:MOD]…` into everything the layout pass needs, building our element as it goes.
## An unknown region REFUSES: it would otherwise fall through to a blank cell, which still profiles.
func _plan(spec: String, reg: Dictionary) -> Dictionary:
	var parts := spec.split(":")
	var is_mock := String(parts[0]) == "mock"
	var at := 1 if is_mock else 0
	if parts.size() <= at:
		print("REFUSED: '%s' names no region" % spec)
		return {}
	var region_name := String(parts[at])
	var regions: Dictionary = reg["regions"]
	if not regions.has(region_name):
		var names: Array = regions.keys()
		names.sort()
		print("REFUSED: no region '%s' in the target registry." % region_name)
		print("  known regions: %s" % ", ".join(PackedStringArray(names)))
		return {}
	var region: Dictionary = regions[region_name]
	var mods: Dictionary = {}
	for i in range(at + 1, parts.size()):
		var m := String(parts[i])
		var eq := m.find("=")
		if eq < 0:
			mods[m] = "1"
		else:
			# `_` reads as a space in the TEXT mods only: the whole cell spec arrives as ONE shell word,
			# so a caption cannot contain a real space and still be one argument. Applying it to every
			# mod turns `cp=halo_reach=…` into `halo reach`, which the panel then ignores in silence —
			# the tuning renders as the baseline and gets compared as if it were the tuning.
			var key := m.substr(0, eq)
			var val := m.substr(eq + 1)
			mods[key] = val.replace("_", " ") if key in TEXT_MODS else val
	var face: Array = region["face"]
	var clean: Array = region.get("clean", face)
	var bleed := String(region.get("bleed", "")) == "bottom"
	var base := {"spec": spec, "region": region_name, "is_mock": is_mock, "bleed_bottom": bleed,
		"rect": Rect2i(int(face[0]), int(face[1]), int(face[2]), int(face[3])),
		"clean": Rect2i(int(clean[0]), int(clean[1]), int(clean[2]), int(clean[3])),
		"mock": String(region["mock"])}
	if is_mock:
		var img := _mock_image(reg, String(region["mock"]))
		if img == null:
			return {}
		base.merge({"image": img, "drawn_w": float(face[2]), "face_w": float(face[2]),
			"face_h": float(face[3]), "face_dx": 0.0,
			"label": String(mods.get("label", "MOCK %s  1:1" % region_name))})
		return base
	var element := String(region["element"])
	if mods.has("fill") and not Elements.takes_fill(element):
		print("REFUSED: the '%s' element cannot be handed a face colour, so `fill=` would be" % element)
		print("silently ignored and the fill would stay a variable in the comparison.")
		return {}
	var built: Dictionary = Elements.build(element, region.get("args", {}), float(face[2]), mods)
	if built.is_empty():
		print("REFUSED: could not build the '%s' element for region '%s'" % [element, region_name])
		return {}
	base.merge(built)
	base["label"] = String(mods.get("label", spec))
	return base


# --- the flat field -----------------------------------------------------------------------

## THE background every cell sits on: the mean over the patches of GENUINELY empty mock the region
## declares. Derived, not a pasted hex — a hex goes stale the moment a region moves to another mock,
## and nobody re-derives it.
##
## `sigma` is the mock's own paper GRAIN over those patches, in luma. It is the floor the whole method
## bottoms out at: an rms fit better than it is not a better match, it is unmeasurable.
func _field(plans: Array, reg: Dictionary) -> Dictionary:
	var per_region := {}
	var best := {}
	for p in plans:
		var name: String = p["region"]
		if per_region.has(name):
			continue
		var region: Dictionary = reg["regions"][name]
		var img := _mock_image(reg, String(region["mock"]))
		if img == null:
			return {}
		var m := _patch_stats(img, region.get("field", []))
		if m.is_empty():
			print("REFUSED: region '%s' declares no usable `field` patches — the sheet has no" % name)
			print("honest background to paint, and a guessed one moves every darkening on it.")
			return {}
		per_region[name] = m
		if best.is_empty():
			best = m
	# EVERY cell must sit on the same ground or none of the numbers compare — which is the original sin
	# this whole rig exists to undo. Refuse rather than average two grounds into one plausible colour.
	for name in per_region:
		var d: int = _l1(per_region[name]["rgb"], best["rgb"])
		if d > FIELD_TOLERANCE:
			print("REFUSED: region '%s' sits on a field %d (L1) away from the sheet's first region." % [name, d])
			print("One sheet cannot honestly carry both — the profiler divides by ONE field luma.")
			print("Split them into two sheets.")
			return {}
	var out: Dictionary = best.duplicate()
	out["regions"] = per_region
	return out


func _mock_image(reg: Dictionary, mock_name: String) -> Image:
	if _images.has(mock_name):
		return _images[mock_name]
	var mocks: Dictionary = reg["mocks"]
	if not mocks.has(mock_name):
		print("REFUSED: no mock '%s' in the target registry" % mock_name)
		return null
	var path := String((mocks[mock_name] as Dictionary)["png"])
	# Image.load_from_file, NOT load(): a concept PNG is an imported texture, and whatever compression
	# that import carries would move the very luma this sheet exists to measure.
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null:
		print("REFUSED: could not read %s" % path)
		return null
	_images[mock_name] = img
	return img


## Mean colour, mean luma and luma sigma over a list of [x,y,w,h] patches of the mock.
func _patch_stats(img: Image, patches: Array) -> Dictionary:
	var n := 0
	var sum := Vector3.ZERO
	var lumas: Array[float] = []
	var bounds := Rect2i(Vector2i.ZERO, img.get_size())
	for raw in patches:
		var r := Rect2i(int(raw[0]), int(raw[1]), int(raw[2]), int(raw[3])).intersection(bounds)
		for x in range(r.position.x, r.position.x + r.size.x):
			for y in range(r.position.y, r.position.y + r.size.y):
				var c := img.get_pixel(x, y)
				sum += Vector3(c.r, c.g, c.b) * 255.0
				lumas.append((0.299 * c.r + 0.587 * c.g + 0.114 * c.b) * 255.0)
				n += 1
	if n == 0:
		return {}
	var mean := sum / float(n)
	var mean_luma := 0.0
	for l in lumas:
		mean_luma += l
	mean_luma /= float(n)
	var var_sum := 0.0
	for l in lumas:
		var_sum += (l - mean_luma) * (l - mean_luma)
	var rgb := [int(round(mean.x)), int(round(mean.y)), int(round(mean.z))]
	return {"rgb": rgb, "hex": "#%02X%02X%02X" % [rgb[0], rgb[1], rgb[2]],
		"luma": snappedf(mean_luma, 0.01), "sigma": snappedf(sqrt(var_sum / float(n)), 0.001),
		"px": n}


func _l1(a: Array, b: Array) -> int:
	return abs(int(a[0]) - int(b[0])) + abs(int(a[1]) - int(b[1])) + abs(int(a[2]) - int(b[2]))


# --- the mock's own pixels ------------------------------------------------------------------

## The mock's own pixels for one region, 1:1, with the FACE landing at `at`. The crop is clipped to the
## region's `clean` window — the part of the mock that is genuinely empty ground — so it can never
## carry a neighbouring element in beside the one under test. Whatever the sheet does not crop, it does
## not claim: the returned `real_ground` is exactly what was cropped, and the profiler stops there.
func _add_mock(parent: Control, plan: Dictionary, at: Vector2, pad: float) -> Dictionary:
	var img: Image = plan["image"]
	var r: Rect2i = plan["rect"]
	var clean: Rect2i = plan["clean"]
	var bleed: bool = plan["bleed_bottom"]
	var down := (img.get_height() - (r.position.y - int(pad))) if bleed \
		else (r.size.y + int(pad) * 2)
	var want := Rect2i(r.position.x - int(pad), r.position.y - int(pad),
		r.size.x + int(pad) * 2, down)
	var box := want.intersection(clean).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if box.size.x <= 0 or box.size.y <= 0:
		print("REFUSED: region '%s' crops to nothing — its `clean` window and `face` rect do not" % \
			String(plan["region"]))
		print("overlap. Re-measure them against the mock.")
		return {}
	var tex := TextureRect.new()
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE          # set BEFORE size: it clamps the min otherwise
	tex.texture = ImageTexture.create_from_image(img.get_region(box))
	tex.size = Vector2(box.size)
	tex.position = at - Vector2(r.position - box.position)
	parent.add_child(tex)
	return {"left": r.position.x - box.position.x, "top": r.position.y - box.position.y,
		"right": (box.position.x + box.size.x) - (r.position.x + r.size.x),
		"bottom": 0 if bleed else (box.position.y + box.size.y) - (r.position.y + r.size.y)}
