extends RefCounted
## SHARED PIXEL OPS for the asset-intake dev tools (process_icon / process_group / process_decor /
## slice_grid / slice_badges / slice_islands / cutout_bg / cutout_holes / proc_line).
##
## These tools are the deterministic half of the intake workflow (see CLAUDE.md and
## docs/design/art-style-guide.md): every pixel op lives in a script, all judgement lives in the
## plan. The keying rule below used to be copy-pasted into every one of them, held together by
## "keep in lockstep" comments — so retuning the background threshold for a new art style silently
## changed how a source PNG keyed depending on which tool the plan happened to invoke. It lives
## here now: ONE definition, every tool passes it in.
##
## Nothing here loads or writes files; it operates on an in-memory RGBA8 Image so the tools AND
## the regression suite exercise the same code.

## --- the background rule -----------------------------------------------------------------
## "Bright + achromatic" = background. Tuned on ChatGPT-style cream/checker plates: a tighter
## value threshold measurably leaves a ~1px dirty-white rim (127px of one reference table's leg
## gaps sit in the 0.93-0.97 band), so 0.93 is a floor, not a guess.
const BG_MAX_VAL := 0.93       # value at/below this -> NOT background (basket / coin / etc.)
const BG_MAX_SAT := 0.10       # any real colour saturation -> NOT background

## --- the "already transparent" alpha floor -----------------------------------------------
## TWO values are in use and they are NOT interchangeable; both are kept deliberately so this
## de-duplication changed no output. ALPHA_MIN is the 8-bit floor the newer eng-owned cutters
## use (cutout_bg / cutout_holes / proc_line / slice_islands); ALPHA_CLEAR is the looser float
## floor the older owner-authored tools use (process_icon / process_group / process_decor /
## slice_grid). They disagree on 8-bit alpha 8..12: ALPHA_CLEAR calls those pixels background,
## ALPHA_MIN does not. Unifying them is a RETUNE — it would move pixels — so it is a separate,
## deliberate decision, not a refactor.
const ALPHA_MIN := 8                        # 8-bit alpha floor (integer domain)
const ALPHA_MIN_F := ALPHA_MIN / 255.0      # ... the same floor in the 0..1 Color.a domain
const ALPHA_CLEAR := 0.05                   # the older, looser float floor (== 8-bit 12.75)

## Alpha above which a pixel counts as opaque subject when trimming.
const TRIM_ALPHA := 0.05

## 4-connected neighbourhood, in the order every flood/BFS in these tools walks it.
const NEI := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

## THE background test. `alpha_min` is in the 0..1 Color.a domain — pass ALPHA_CLEAR or
## ALPHA_MIN_F (see above). `max_val` / `max_sat` are usually BG_MAX_VAL / BG_MAX_SAT, but
## proc_line passes its own looser checker thresholds (CHK_VAL / CHK_SAT) — those describe a
## DIFFERENT plate (a baked transparency checkerboard, not a cream field), so they stay local
## to that tool rather than being absorbed here.
static func is_bg(c: Color, max_val: float, max_sat: float, alpha_min: float) -> bool:
	if c.a < alpha_min:
		return true                                # already transparent — count as bg
	var mx: float = maxf(c.r, maxf(c.g, c.b))
	var mn: float = minf(c.r, minf(c.g, c.b))
	var sat: float = 0.0 if mx <= 0.0 else (mx - mn) / mx
	return mx > max_val and sat < max_sat

## MAGENTA DESPILL (guide §8 edge treatment, step 2) — the GDScript twin of
## slice_item_lines.despill_edge, with its measured constants. Clamp R and B toward G, but ONLY in
## a pixel that is (a) within DESPILL_BAND px of transparency and (b) actually key-tinted
## (min(R,B) - G > DESPILL_EXCESS). Both guards are load-bearing: an unconditional clamp is not a
## despill, it is a recolour — coral #D87865 has R 216 against G 120, so `R <= G + 15` would drag
## every coral plane in the art to brown. Interior pink/purple is never touched; an enclosed key
## pocket is the pocket check's job, not this one's.
##
## It has to run AFTER a resize as well as at the key. Un-premultiplying at low alpha re-amplifies
## Lanczos ring: the G channel carries the largest local contrast at a cut edge, so its negative
## lobe undershoots hardest and the boundary pixel drifts magenta again — measured on a nav glyph,
## min(R,B) - G went from 15 on the keyed sheet to 52 after the 334 -> 512 upscale.
const DESPILL_D := 15                       # 8-bit headroom over G that R and B may keep
const DESPILL_EXCESS := 20                  # …applied only above this much magenta excess
const DESPILL_BAND := 3                     # …and only this many px from a transparent pixel

static func despill_magenta(im: Image, alpha_min: float = ALPHA_MIN_F) -> int:
	var w := im.get_width()
	var h := im.get_height()
	# the alpha-edge band: a visible pixel with a transparent one within DESPILL_BAND
	var near_clear := PackedByteArray()
	near_clear.resize(w * h)
	for y in h:
		for x in w:
			if im.get_pixel(x, y).a >= alpha_min:
				continue
			for dy in range(-DESPILL_BAND, DESPILL_BAND + 1):
				for dx in range(-DESPILL_BAND, DESPILL_BAND + 1):
					var nx := x + dx
					var ny := y + dy
					if nx >= 0 and ny >= 0 and nx < w and ny < h:
						near_clear[ny * w + nx] = 1
	var touched := 0
	var d: float = float(DESPILL_D) / 255.0
	var e: float = float(DESPILL_EXCESS) / 255.0
	for y2 in h:
		for x2 in w:
			if near_clear[y2 * w + x2] == 0:
				continue
			var c := im.get_pixel(x2, y2)
			if c.a < alpha_min or minf(c.r, c.b) - c.g <= e:
				continue
			var cap: float = c.g + d
			im.set_pixel(x2, y2, Color(minf(c.r, cap), c.g, minf(c.b, cap), c.a))
			touched += 1
	return touched

## RGB *= A, so a coverage-weighted resize can't pull in the cleared black background.
static func premultiply(im: Image) -> void:
	for y in im.get_height():
		for x in im.get_width():
			var c := im.get_pixel(x, y)
			im.set_pixel(x, y, Color(c.r * c.a, c.g * c.a, c.b * c.a, c.a))

## RGB /= A back to straight alpha; clamp absorbs Lanczos overshoot, near-zero alpha -> clear.
static func unpremultiply(im: Image) -> void:
	for y in im.get_height():
		for x in im.get_width():
			var c := im.get_pixel(x, y)
			if c.a > 0.0039:                       # ~1/255: below this, colour is irrelevant
				im.set_pixel(x, y, Color(
					clampf(c.r / c.a, 0.0, 1.0),
					clampf(c.g / c.a, 0.0, 1.0),
					clampf(c.b / c.a, 0.0, 1.0), c.a))
			else:
				im.set_pixel(x, y, Color(0, 0, 0, 0))

## Flood-fill IN PLACE from every border pixel over `is_bg_fn` pixels, clearing each to
## transparent black. Returns the number of pixels cleared. Only the OUTER field is reached —
## background walled in by the subject survives (that is what cutout_holes / cutout_bg are for).
static func flood_clear_from_border(img: Image, is_bg_fn: Callable) -> int:
	var W := img.get_width()
	var H := img.get_height()
	var seen := PackedByteArray()
	seen.resize(W * H)
	var stack: Array = []
	for x in W:
		stack.append(x)
		stack.append((H - 1) * W + x)
	for y in H:
		stack.append(y * W)
		stack.append(y * W + (W - 1))
	var removed := 0
	while not stack.is_empty():
		var idx: int = stack.pop_back()
		if seen[idx] == 1:
			continue
		seen[idx] = 1
		var x := idx % W
		var y := idx / W
		if not is_bg_fn.call(img.get_pixel(x, y)):
			continue
		img.set_pixel(x, y, Color(0, 0, 0, 0))
		removed += 1
		if x > 0:     stack.append(idx - 1)
		if x < W - 1: stack.append(idx + 1)
		if y > 0:     stack.append(idx - W)
		if y < H - 1: stack.append(idx + W)
	return removed

## Flood from every border over `is_bg_fn` ("passable": transparent OR bg-coloured) pixels and
## return a W*H byte mask with 1 = OUTER field. Nothing is written to the image — the caller
## decides what to do with the outer field and with the enclosed pockets it did NOT mark.
static func mark_outer_field(img: Image, is_bg_fn: Callable) -> PackedByteArray:
	var w := img.get_width()
	var h := img.get_height()
	var outer := PackedByteArray()
	outer.resize(w * h)
	var stack := PackedInt32Array()
	for x in w:
		_seed(img, outer, stack, x, 0, w, h, is_bg_fn)
		_seed(img, outer, stack, x, h - 1, w, h, is_bg_fn)
	for y in h:
		_seed(img, outer, stack, 0, y, w, h, is_bg_fn)
		_seed(img, outer, stack, w - 1, y, w, h, is_bg_fn)
	while not stack.is_empty():
		var idx := stack[stack.size() - 1]
		stack.remove_at(stack.size() - 1)
		var cx := idx % w
		var cy := idx / w
		for d in NEI:
			_seed(img, outer, stack, cx + d.x, cy + d.y, w, h, is_bg_fn)
	return outer

static func _seed(img: Image, outer: PackedByteArray, stack: PackedInt32Array,
		x: int, y: int, w: int, h: int, is_bg_fn: Callable) -> void:
	if x < 0 or y < 0 or x >= w or y >= h:
		return
	var i := y * w + x
	if outer[i] == 1:
		return
	if not is_bg_fn.call(img.get_pixel(x, y)):
		return
	outer[i] = 1
	stack.append(i)

## Tight bounds of everything more opaque than TRIM_ALPHA. Returns a zero-SIZE Rect2i when
## nothing opaque is left (the flood-fill ate the subject) — callers must check `size.x == 0`.
static func trim(img: Image) -> Rect2i:
	var W := img.get_width()
	var H := img.get_height()
	var minx := W
	var miny := H
	var maxx := -1
	var maxy := -1
	for y in H:
		for x in W:
			if img.get_pixel(x, y).a > TRIM_ALPHA:
				minx = mini(minx, x); maxx = maxi(maxx, x)
				miny = mini(miny, y); maxy = maxi(maxy, y)
	if maxx < 0:
		return Rect2i(0, 0, 0, 0)
	return Rect2i(minx, miny, maxx - minx + 1, maxy - miny + 1)
