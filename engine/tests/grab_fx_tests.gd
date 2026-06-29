extends SceneTree
## Headless unit tests for engine/scripts/ui/grab_fx.gd — the toggleable GRAB feel (an item is picked
## up): a glow tint + a white silhouette outline on the held tile + a light haptic tap. Mirrors the
## feel_tests registry coverage; the highlight is a SUSTAINED state, so grab() turns it on and
## release() takes it off. Also covers the PieceView grab-outline helpers GrabFx leans on.
##   godot --headless --path . -s res://engine/tests/grab_fx_tests.gd

const GrabFx = preload("res://engine/scripts/ui/grab_fx.gd")
const PieceView = preload("res://engine/scripts/ui/piece_view.gd")

var _pass := 0
var _fail := 0
func ok(cond: bool, label: String) -> void:
	if cond: _pass += 1; print("  PASS  ", label)
	else: _fail += 1; print("  FAIL  ", label)

# A holder shaped like a real piece: a cell-sized Control with a named "ItemArt" TextureRect carrying a
# tiny in-memory texture (ImageTexture.get_image() works under headless — no GPU readback needed).
func _piece_holder() -> Control:
	var holder := Control.new()
	holder.size = Vector2(96, 96)
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.6, 0.3, 1.0))   # a solid opaque blob — its alpha is the silhouette shape
	var art := TextureRect.new()
	art.name = PieceView.ART_NAME   # "ItemArt"
	art.texture = ImageTexture.create_from_image(img)
	holder.add_child(art)
	get_root().add_child(holder)
	return holder

func _has_grab_outline(holder: Control) -> bool:
	return holder.get_node_or_null(NodePath("GrabOutline")) != null

func _initialize() -> void:
	print("== GrabFx tests ==")
	ok(GrabFx != null, "grab_fx module loads")

	# --- registry: defaults / from_config / on -----------------------------------
	var d := GrabFx.defaults()
	ok(bool(d.get("enabled", false)), "defaults: master enabled is ON")
	ok(GrabFx.on(d, "glow") and GrabFx.on(d, "outline") and GrabFx.on(d, "haptic"), \
		"defaults: glow + outline + haptic all ON")
	ok(d.has("glow_pct") and d.has("outline_w") and d.has("outline_a"), \
		"defaults: glow_pct / outline_w / outline_a knobs present")

	var c := GrabFx.from_config({"grab_fx": {"glow": false, "glow_pct": 50}})
	ok(GrabFx.on(c, "glow") == false, "from_config honours a saved 'glow:false' toggle")
	ok(GrabFx.knob(c, "glow_pct") == 50, "from_config honours a saved 'glow_pct' knob")
	ok(GrabFx.on(c, "outline") == true, "from_config leaves un-overridden toggles at their default (on)")
	var cd := GrabFx.from_config({})
	ok(GrabFx.knob(cd, "glow_pct") == GrabFx.KNOBS["glow_pct"], "from_config falls back to the default knob when unset")
	var off := GrabFx.from_config({"grab_fx": {"enabled": false}})
	ok(GrabFx.on(off, "glow") == false and GrabFx.on(off, "outline") == false, \
		"the master switch (enabled:false) turns every cue off")

	# --- grab(): glow adds a soft luminous HALO behind the held tile. A modulate brighten is invisible on
	# already-bright art (it clamps at 1.0), so the glow is a real radial aura, not a tint. -------------
	var h := _piece_holder()
	GrabFx.grab(h, GrabFx.from_config({}))
	ok(h.has_node(NodePath("GrabGlow")), "grab with glow ON adds a glow halo behind the tile")
	GrabFx.release(h)
	ok(not h.has_node(NodePath("GrabGlow")), "release removes the glow halo")

	var h_glowoff := _piece_holder()
	GrabFx.grab(h_glowoff, GrabFx.from_config({"grab_fx": {"glow": false}}))
	ok(not h_glowoff.has_node(NodePath("GrabGlow")), "grab with glow OFF adds no halo")

	# glow strength scales with glow_pct (a stronger pct = a more opaque halo).
	var h_soft := _piece_holder()
	var h_hard := _piece_holder()
	GrabFx.grab(h_soft, GrabFx.from_config({"grab_fx": {"glow_pct": 50}}))
	GrabFx.grab(h_hard, GrabFx.from_config({"grab_fx": {"glow_pct": 200}}))
	var soft_a: float = (h_soft.get_node(NodePath("GrabGlow")) as Control).modulate.a
	var hard_a: float = (h_hard.get_node(NodePath("GrabGlow")) as Control).modulate.a
	ok(hard_a > soft_a, "a higher glow_pct makes the halo more opaque")

	# --- grab(): outline adds a white rim node; off + cleared correctly -----------
	var h_out := _piece_holder()
	GrabFx.grab(h_out, GrabFx.from_config({"grab_fx": {"glow": false, "haptic": false}}))
	ok(_has_grab_outline(h_out), "grab with outline ON adds a GrabOutline rim node")
	GrabFx.release(h_out)
	ok(not _has_grab_outline(h_out), "release removes the GrabOutline rim node")

	var h_noout := _piece_holder()
	GrabFx.grab(h_noout, GrabFx.from_config({"grab_fx": {"outline": false}}))
	ok(not _has_grab_outline(h_noout), "grab with outline OFF adds no rim node")

	# --- PieceView grab-outline helpers (what GrabFx leans on) --------------------
	var h_help := _piece_holder()
	PieceView.add_grab_outline(h_help, Color.WHITE, 0.04, 0.9)
	ok(_has_grab_outline(h_help), "PieceView.add_grab_outline adds the rim node")
	var n_after_first := h_help.get_child_count()
	PieceView.add_grab_outline(h_help, Color.WHITE, 0.04, 0.9)
	ok(h_help.get_child_count() == n_after_first, "add_grab_outline is idempotent (no duplicate rim)")
	PieceView.clear_grab_outline(h_help)
	ok(not _has_grab_outline(h_help), "PieceView.clear_grab_outline removes the rim node")

	# the rim must overlay the sprite's EXACT rect — both its tuned inset (board content_frac, not 0.16)
	# AND its LIFTED position (set_lifted raises the art ~12% on pickup). A fixed FULL_RECT+inset rim is
	# smaller than a large board sprite AND doesn't follow the lift, so it sits shifted below the art (the
	# "outline is shifted on the board" bug). Build the sprite the way make_piece does, lift it, then check.
	var h_tuned := Control.new()
	h_tuned.size = Vector2(96, 96)
	var inset_px := 96.0 * 0.045   # the board's tuned sprite inset (content_frac 91)
	var img_t := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img_t.fill(Color(0.2, 0.6, 0.3, 1.0))
	var art_t := TextureRect.new()
	art_t.name = PieceView.ART_NAME
	art_t.texture = ImageTexture.create_from_image(img_t)
	art_t.set_anchors_preset(Control.PRESET_FULL_RECT)
	art_t.offset_left = inset_px
	art_t.offset_top = inset_px
	art_t.offset_right = -inset_px
	art_t.offset_bottom = -inset_px
	art_t.set_meta("inset_px", inset_px)
	h_tuned.add_child(art_t)
	get_root().add_child(h_tuned)
	PieceView.set_lifted(h_tuned, true)   # raise the art, as pickup does — the rim must follow
	PieceView.add_grab_outline(h_tuned, Color.WHITE, 0.04, 0.9)
	var rim_t = h_tuned.get_node_or_null(NodePath("GrabOutline"))
	ok(rim_t != null \
		and is_equal_approx(rim_t.offset_left, art_t.offset_left) \
		and is_equal_approx(rim_t.offset_top, art_t.offset_top) \
		and is_equal_approx(rim_t.offset_right, art_t.offset_right) \
		and is_equal_approx(rim_t.offset_bottom, art_t.offset_bottom), \
		"grab outline overlays the sprite's exact rect — tracks the tuned inset AND the lift")

	# a GENERATOR's decorations (the gold GenOutline rim + halo + sparkle) trace the sprite, so set_lifted
	# must ride them UP with the art on pickup — else the gold rim stays at rest and reads as "shifted"
	# below the lifted sprite while the generator is dragged. (My white grab rim is already correct.)
	var hg := Control.new()
	hg.size = Vector2(96, 96)
	var ginset := 96.0 * 0.16
	var gart := TextureRect.new()
	gart.name = PieceView.ART_NAME
	gart.set_anchors_preset(Control.PRESET_FULL_RECT)
	gart.offset_left = ginset
	gart.offset_top = ginset
	gart.offset_right = -ginset
	gart.offset_bottom = -ginset
	gart.set_meta("inset_px", ginset)
	hg.add_child(gart)
	var gout := Control.new()   # stand-in for the gold GenOutline (FULL_RECT, like the real one)
	gout.name = "GenOutline"
	gout.set_anchors_preset(Control.PRESET_FULL_RECT)
	hg.add_child(gout)
	get_root().add_child(hg)
	var rise := 96.0 * PieceView.LIFT_RISE
	PieceView.set_lifted(hg, true)
	ok(is_equal_approx(gout.offset_top, -rise) and is_equal_approx(gout.offset_bottom, -rise), \
		"set_lifted raises the generator's gold outline with the sprite (tracks the lift)")
	PieceView.set_lifted(hg, false)
	ok(is_equal_approx(gout.offset_top, 0.0) and is_equal_approx(gout.offset_bottom, 0.0), \
		"set_lifted(false) returns the generator outline to rest")

	# a placeholder tile with NO ItemArt sprite gets no outline (nothing to trace) — but never errors.
	var bare := Control.new()
	bare.size = Vector2(96, 96)
	get_root().add_child(bare)
	PieceView.add_grab_outline(bare, Color.WHITE, 0.04, 0.9)
	ok(not _has_grab_outline(bare), "add_grab_outline is a safe no-op on a tile with no art sprite")

	# --- null-safety: grab/release never error on a null/invalid node -------------
	GrabFx.grab(null, GrabFx.from_config({}))
	GrabFx.release(null)
	PieceView.clear_grab_outline(null)
	ok(true, "grab(null) / release(null) / clear_grab_outline(null) are safe no-ops")

	# haptic is a headless no-op (no vibrator) — grab with haptic on must not error.
	var h_hap := _piece_holder()
	GrabFx.grab(h_hap, GrabFx.from_config({}))
	ok(true, "grab with haptic ON is a safe no-op under headless")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
