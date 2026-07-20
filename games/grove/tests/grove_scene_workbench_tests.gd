extends SceneTree
## Gates games/grove/tools/scene_workbench_model.gd — the PURE half of the scene-placement
## workbench (load/save round-trip, entry ops, paint order, hit-testing, path resolution).

const M = preload("res://games/grove/tools/scene_workbench_model.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _has_label_text(node: Node, text: String) -> bool:
	for l in node.find_children("*", "Label", true, false):
		if String((l as Label).text) == text:
			return true
	return false

func _doc() -> Dictionary:
	return {
		"schemaVersion": 2,
		"scene": "test_scene",
		"canvas": {"width": 1000, "height": 2000, "anchorConvention": "center-bottom"},
		"base": {"id": "foundation", "image": "base.png", "z": 0},
		"placements": [
			{"id": "tree", "category": "prop", "image": "a.png", "x": 500, "y": 1000, "w": 200, "h": 400, "z": 30, "layer": "rear"},
			{"id": "rock", "category": "prop", "image": "b.png", "x": 500, "y": 1100, "w": 100, "h": 100, "z": 10, "layer": "rear"},
			{"id": "gate", "category": "structure", "image": "c.png", "x": 520, "y": 1080, "w": 300, "h": 300, "z": 30, "layer": "hero"},
		],
	}

func _initialize() -> void:
	print("== Scene workbench model tests ==")
	var d := _doc()

	# --- geometry + order -----------------------------------------------------------
	ok(M.canvas_size(d) == Vector2(1000, 2000), "canvas_size reads the canvas block")
	ok(M.entry_rect(d.placements[0]) == Rect2(400, 600, 200, 400),
		"entry_rect anchors (x,y) at CENTER-BOTTOM")
	ok(M.sorted_order(d) == [1, 0, 2], "paint order sorts by z, stable on ties (authoring order)")
	ok(M.max_z(d) == 30, "max_z scans the placements")

	# --- ops ------------------------------------------------------------------------
	M.move(d, 1, Vector2(-10, 5.4))
	ok(int(d.placements[1].x) == 490 and int(d.placements[1].y) == 1105,
		"move offsets and rounds to whole pixels")
	M.set_pos(d, 1, Vector2(500, 1100))
	ok(int(d.placements[1].x) == 500 and int(d.placements[1].y) == 1100, "set_pos writes the anchor")
	M.scale_by(d, 0, 1.5)
	ok(int(d.placements[0].w) == 300 and int(d.placements[0].h) == 600,
		"scale_by resizes uniformly about the anchor")
	M.scale_by(d, 1, 0.001)
	ok(int(d.placements[1].w) >= 8 and int(d.placements[1].h) >= 8,
		"scale_by clamps at the minimum grabbable size")
	M.bump_z(d, 1, 25)
	ok(int(d.placements[1].z) == 35 and M.sorted_order(d) == [0, 2, 1],
		"bump_z reorders the paint order")
	M.bump_z(d, 1, -999)
	ok(int(d.placements[1].z) == 0, "bump_z floors at z 0")

	# --- add / remove / unique ids --------------------------------------------------
	var i := M.add_entry(d, {"id": "tree", "category": "prop", "image": "a.png", "x": 100, "y": 100, "w": 50, "h": 50})
	ok(String(d.placements[i].id) == "tree_2", "add_entry de-duplicates the id")
	ok(int(d.placements[i].z) == M.max_z(d) and int(d.placements[i].z) > 30,
		"an added entry defaults to the top z")
	var removed := M.remove_at(d, i)
	ok(String(removed.id) == "tree_2" and d.placements.size() == 3, "remove_at pops the entry")

	# --- hit-testing ----------------------------------------------------------------
	var d2 := _doc()
	var all_opaque := func(_i: int, _uv: Vector2) -> bool: return true
	ok(M.hit_at(d2, Vector2(510, 900), all_opaque) == 2,
		"hit_at returns the TOPMOST entry under the point")
	var gate_clear := func(pi: int, _uv: Vector2) -> bool: return pi != 2
	ok(M.hit_at(d2, Vector2(510, 900), gate_clear) == 0,
		"a transparent pixel falls through to the layer beneath")
	ok(M.hit_at(d2, Vector2(10, 10), all_opaque) == -1, "empty canvas → no hit")

	# --- save / load round-trip (with the one-time .bak) ----------------------------
	var dir := OS.get_user_data_dir() + "/scene_wb_test"
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir + "/placements.json"
	for stale in [path, path + ".bak"]:               # idempotent across runs — start from a clean slate
		if FileAccess.file_exists(stale):
			DirAccess.remove_absolute(stale)
	var d3 := _doc()
	d3["pipeline"] = {"mapMode": "scene_mode"}         # unknown top-level keys must survive
	ok(M.save_doc(path, d3), "save_doc writes the file")
	ok(not FileAccess.file_exists(path + ".bak"), "no backup on a first write (nothing to back up)")
	M.move(d3, 0, Vector2(1, 0))
	ok(M.save_doc(path, d3) and FileAccess.file_exists(path + ".bak"),
		"a re-save backs up the previous file once")
	var back := M.load_doc(path)
	ok(back.get("pipeline", {}).get("mapMode") == "scene_mode", "unknown keys round-trip through save")
	ok(back.placements.size() == 3 and int(back.placements[0].x) == 501,
		"placements round-trip through save/load")
	ok(M.load_doc(dir + "/nope.json").is_empty(), "a missing file loads as an empty doc")

	# --- clusters (a tent + its rocks/vegetation/shadow manage as ONE thing) ---------
	var dc := _doc()
	ok(M.clusters(dc).is_empty(), "no tags → no clusters")
	M.set_cluster(dc, 0, "camp")
	M.set_cluster(dc, 1, "camp")
	ok(M.clusters(dc).get("camp", []) == [0, 1], "clusters groups member indices by tag")
	ok(M.cluster_of(dc, 0) == "camp" and M.cluster_of(dc, 2) == "", "cluster_of reads the tag")
	ok(M.unique_cluster_name(dc, "camp") == "camp_2", "unique_cluster_name de-duplicates")
	# tree: rect(400,600 200x400) + rock: rect(450,1000 100x100) → merged bbox
	ok(M.cluster_bbox(dc, "camp") == Rect2(400, 600, 200, 500), "cluster_bbox merges member rects")
	M.move_cluster(dc, "camp", Vector2(10, -20))
	ok(int(dc.placements[0].x) == 510 and int(dc.placements[1].x) == 510
		and int(dc.placements[0].y) == 980 and int(dc.placements[1].y) == 1080,
		"move_cluster shifts every member together")
	ok(int(dc.placements[2].x) == 520, "an untagged neighbour never moves with a cluster")
	M.set_cluster(dc, 0, "")
	ok(M.cluster_of(dc, 0) == "" and not (dc.placements[0] as Dictionary).has("cluster"),
		"untagging erases the key (files stay byte-stable)")

	# membership toggling + renaming (the easy create/update paths)
	var dm := _doc()
	M.set_cluster(dm, 0, "camp")
	ok(M.toggle_cluster_member(dm, 1, "camp") and M.cluster_of(dm, 1) == "camp",
		"toggle joins an untagged entry to the cluster")
	ok(not M.toggle_cluster_member(dm, 1, "camp") and M.cluster_of(dm, 1) == "",
		"toggling a member removes it")
	M.set_cluster(dm, 2, "other")
	ok(M.toggle_cluster_member(dm, 2, "camp") and M.cluster_of(dm, 2) == "camp",
		"toggle re-tags an entry away from another cluster")
	ok(M.rename_cluster(dm, "camp", "base camp") == "base_camp"
		and M.cluster_of(dm, 0) == "base_camp" and M.cluster_of(dm, 2) == "base_camp",
		"rename re-tags every member (spaces normalize to underscores)")
	M.set_cluster(dm, 1, "taken")
	ok(M.rename_cluster(dm, "base_camp", "taken") == "taken_2",
		"a rename collision unique-ifies the applied name")
	ok(M.rename_cluster(dm, "ghost", "x") == "" and M.rename_cluster(dm, "taken", "") == "",
		"renaming a missing cluster or to an empty name is a no-op")

	# scale about the group footing: two 100-px squares side by side double together
	var ds := _doc()
	ds.placements[0] = {"id": "a", "image": "a.png", "x": 400, "y": 1000, "w": 100, "h": 100, "z": 1, "cluster": "duo"}
	ds.placements[1] = {"id": "b", "image": "b.png", "x": 600, "y": 1000, "w": 100, "h": 100, "z": 2, "cluster": "duo"}
	M.scale_cluster(ds, "duo", 2.0)
	ok(int(ds.placements[0].w) == 200 and int(ds.placements[1].w) == 200,
		"scale_cluster resizes every member")
	ok(int(ds.placements[0].x) == 300 and int(ds.placements[1].x) == 700
		and int(ds.placements[0].y) == 1000 and int(ds.placements[1].y) == 1000,
		"scale_cluster spreads anchors about the group footing (bottom stays put)")
	M.scale_cluster(ds, "duo", 0.001)
	ok(int(ds.placements[0].w) >= 8, "scale_cluster clamps at the grabbable floor")

	# cluster restack moves the CLUSTER among its layer's clusters — a shared clusterZ on every
	# member, leaving each member's own z (its order INSIDE the cluster) untouched.
	var dz := _doc()
	M.set_cluster(dz, 0, "grp")                       # z 30
	M.set_cluster(dz, 1, "grp")                       # z 10
	ok(M.cluster_z(dz, "grp") == 10, "cluster_z is the cluster's shared order (legacy → lowest member z)")
	M.bump_cluster_z(dz, "grp", 5)
	ok(int(dz.placements[0].clusterZ) == 15 and int(dz.placements[1].clusterZ) == 15,
		"bump_cluster_z gives every member the same new clusterZ")
	ok(int(dz.placements[0].z) == 30 and int(dz.placements[1].z) == 10,
		"members keep their own z (order inside the cluster is undisturbed)")
	M.bump_cluster_z(dz, "grp", -999)
	ok(int(dz.placements[0].clusterZ) == 0 and int(dz.placements[1].clusterZ) == 0,
		"a floored restack clamps the shared clusterZ at 0")

	# --- layers (item → cluster → LAYER → scene, the fixed back→front band) ------------
	ok(M.LAYERS.size() == 6 and M.LAYERS[0] == "sky" and M.LAYERS[5] == "foreground_objects",
		"the six predefined layers run sky (back) → foreground (front)")
	ok(M.layer_rank("sky") == 0 and M.layer_rank("foreground_objects") == 5,
		"layer_rank orders the band back → front")
	ok(M.layer_rank("nonsense") == M.layer_rank(M.DEFAULT_LAYER),
		"an unknown/legacy layer reads as the default band")
	ok(M.entry_layer({}) == M.DEFAULT_LAYER, "a layerless entry reads as the default band")
	ok(M.entry_cluster_z({"z": 7}) == 7, "a clusterZ-less entry falls back to its own item z")
	ok(M.entry_cluster_z({"z": 7, "clusterZ": 3}) == 3, "clusterZ wins when present")

	# a legacy doc (no layer/clusterZ anywhere) keeps its exact global-z paint order
	ok(M.sorted_order(_doc()) == [1, 0, 2],
		"a pre-layers doc paints in the same order as before (graceful fallback)")

	# layer dominates clusterZ dominates z: push 'gate' to the back layer and it paints first
	var dl := _doc()
	M.set_layer(dl, 2, "sky")
	ok(String(dl.placements[2].layer) == "sky", "set_layer assigns the band")
	ok(M.sorted_order(dl) == [2, 1, 0],
		"a lower layer paints first regardless of z (sky gate under the rear props)")

	# set_layer is cluster-wide; bump_layer walks the band and clamps at its ends
	var dla := _doc()
	M.set_cluster(dla, 0, "camp")
	M.set_cluster(dla, 1, "camp")
	M.set_layer(dla, 0, "backdrop")
	ok(String(dla.placements[0].layer) == "backdrop" and String(dla.placements[1].layer) == "backdrop",
		"set_layer moves the whole cluster into one band")
	ok(M.bump_layer(dla, 1, -1) == "sky" and String(dla.placements[0].layer) == "sky",
		"bump_layer steps the cluster back a band, cluster-wide")
	ok(M.bump_layer(dla, 0, -5) == "sky", "bump_layer clamps at the back of the band")
	M.set_layer(dla, 0, "foreground_objects")
	ok(M.bump_layer(dla, 0, 3) == "foreground_objects", "bump_layer clamps at the front of the band")

	# --- view: a sidebar row press must NOT free the emitting button ------------------
	# (regression: the press handler rebuilds the list; a hard free() there destroys the
	# button mid-signal-emission — "Object was freed while a signal is being emitted")
	var View = load("res://games/grove/tools/scene_workbench_view.gd")
	var broot := OS.get_user_data_dir() + "/scene_wb_view_test"
	DirAccess.make_dir_recursive_absolute(broot + "/test_scene_elements_v1/metadata")
	var vdoc := _doc()
	(vdoc.placements[0] as Dictionary)["cluster"] = "camp"
	(vdoc.placements[1] as Dictionary)["cluster"] = "camp"
	M.save_doc(broot + "/test_scene_elements_v1/metadata/placements.json", vdoc)
	var other_pl := broot + "/another_elements_v2/metadata/placements.json"
	for stale2 in [other_pl, other_pl + ".bak"]:      # idempotent across runs — the switch test re-creates it
		if FileAccess.file_exists(stale2):
			DirAccess.remove_absolute(stale2)
	var view: Control = View.new()
	ok(view.setup(broot, "test_scene"), "the view opens a synthetic bundle (art-less entries allowed)")
	root.add_child(view)
	if view._cluster_box == null:
		view._ready()                                  # _ready does not auto-fire under _initialize (suite convention)
	ok(view.find_child("SceneIcons", true, false) != null
		and view._cluster_box != null,
		"the lean sidebar is dropdown + save + clusters only (no placed list, no palette)")
	# the cluster list now groups rows under the six fixed LAYER headers (Label nodes); find the
	# 'camp' cluster row (an HBox whose first Button names the cluster) beneath its header.
	ok(_has_label_text(view._cluster_box, "— Primary Objects —"),
		"the cluster list is grouped under the predefined layer headers")
	var crow: Button = null
	for c in view._cluster_box.get_children():
		if c is HBoxContainer and c.get_child_count() >= 1 and (c.get_child(0) as Button).text.contains("camp"):
			crow = c.get_child(0) as Button
	ok(crow != null, "the clusters list built a row under its layer header")
	if crow != null:
		crow.pressed.emit()
		ok(is_instance_valid(crow), "a pressed cluster-row survives its own refresh (deferred free)")
		ok(view._sel_cluster == "camp", "the press selected the cluster")
	# selecting a cluster EXPANDS its member rows: [select-item button][✕ remove]
	var member_rows: Array = []
	for c in view._cluster_box.get_children():
		if c is HBoxContainer and c.get_child_count() == 2 and (c.get_child(0) as Button).text.contains("· "):
			member_rows.append(c)
	ok(member_rows.size() == 2, "the selected cluster lists its two member elements")
	if member_rows.size() == 2:
		var mbtn := (member_rows[0] as HBoxContainer).get_child(0) as Button
		mbtn.pressed.emit()
		ok(is_instance_valid(mbtn), "a pressed member-row survives its own refresh (deferred free)")
		ok(view._sel >= 0 and view._sel_cluster == "" and M.cluster_of(view.doc, view._sel) == "camp",
			"clicking a member row selects that single item for move/resize")
		ok(view._cluster_box.get_child_count() >= 3,
			"the member list stays expanded while one of its items is selected")
		var doc_snapshot: Dictionary = view.doc.duplicate(true)   # the kill test must not shift downstream indices
		var n_before: int = view.doc.placements.size()
		# member_rows follow paint order: [rock (z10, index 1), tree (z30, index 0)] — kill the tree row
		var kill := (member_rows[1] as HBoxContainer).get_child(1) as Button
		var kill_id := String((view.doc.placements[0] as Dictionary).id)
		kill.pressed.emit()
		ok(view.doc.placements.size() == n_before - 1, "the ✕ removes that element from the scene")
		var left := {}
		for e in view.doc.placements:
			left[String((e as Dictionary).id)] = true
		ok(not left.has(kill_id), "the removed element is the one whose ✕ was pressed")
		ok(view._sel_cluster == "camp", "the cluster stays selected after a member remove")
		view.doc = doc_snapshot                        # restore the fixture for the tests downstream
		view._rebuild_stage()
		view._select(-1)

	# --- view: click-select + drag-move + wheel-resize through the stage input surface -
	# (regression: "dragging doesn't work" — mouse input formerly relied on _unhandled_input
	# under full-rect STOP-filter Controls, which swallowed every stage event; the stage now
	# OWNS gui_input, and tests drive _on_stage_input directly like the map suites do _on_input)
	ok(view._stage.gui_input.is_connected(view._on_stage_input),
		"the stage Control owns mouse input via gui_input")
	ok(view._stage.mouse_filter == Control.MOUSE_FILTER_STOP,
		"the stage's filter is STOP so the GUI routes stage clicks to it")
	view._select(-1)
	var s2: float = view._layers.scale.x
	# canvas (500,1050) sits inside 'gate' (rect 370,780 300×300, topmost there at z 30)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(500, 1050) * s2
	view._on_stage_input(press)
	ok(view._sel == 2, "a stage click selects the topmost entry under the point")
	var drag := InputEventMouseMotion.new()
	drag.position = Vector2(520, 1030) * s2
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	view._on_stage_input(drag)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = drag.position
	view._on_stage_input(release)
	var gate: Dictionary = view.doc.placements[2]
	ok(int(gate.x) == 540 and int(gate.y) == 1060,
		"dragging on the stage moves the selected entry (anchor follows the grab)")
	ok(view.dirty, "a drag marks the doc dirty")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = drag.position
	view._on_stage_input(wheel)
	ok(int((view.doc.placements[2] as Dictionary).w) == 306,
		"a wheel notch over the stage resizes the selection (+2%)")

	# --- [ / ] move the selection between layers ---------------------------------------
	# 'gate' (index 2) is still selected from the drag/wheel test; it starts in the default band.
	view._select(2)
	ok(M.entry_layer(view.doc.placements[2]) == M.DEFAULT_LAYER, "setup: the item starts in the default layer")
	var lbrack := InputEventKey.new()
	lbrack.keycode = KEY_BRACKETLEFT
	lbrack.pressed = true
	view._key(lbrack)
	ok(String(view.doc.placements[2].layer) == "background_objects" and view.dirty,
		"[ moves the selection back one layer")
	var rbrack := InputEventKey.new()
	rbrack.keycode = KEY_BRACKETRIGHT
	rbrack.pressed = true
	view._key(rbrack)
	ok(String(view.doc.placements[2].layer) == M.DEFAULT_LAYER, "] moves it forward one layer")
	# the sidebar surfaces the selection's current band
	ok(_has_label_text(view._cluster_actions, "layer: Primary Objects   ( [ / ] )"),
		"the sidebar shows the selection's layer + the [ / ] hint")
	view.doc.placements[2].erase("layer")                 # restore the fixture (byte-stable) for downstream tests
	view._select(-1)

	# --- cluster-first stage clicks: a click selects the whole group ------------------
	view._select(-1)
	var on_tree := InputEventMouseButton.new()         # canvas (420,640): inside 'tree' (camp) only
	on_tree.button_index = MOUSE_BUTTON_LEFT
	on_tree.pressed = true
	on_tree.position = Vector2(420, 640) * s2
	view._on_stage_input(on_tree)
	ok(view._sel_cluster == "camp" and view._sel == -1,
		"clicking a clustered item selects its whole CLUSTER")
	var drag2 := InputEventMouseMotion.new()           # drag the group +20,+20
	drag2.position = Vector2(440, 660) * s2
	drag2.button_mask = MOUSE_BUTTON_MASK_LEFT
	view._on_stage_input(drag2)
	var t0: Dictionary = view.doc.placements[0]
	var r0: Dictionary = view.doc.placements[1]
	ok(int(t0.x) == 520 and int(t0.y) == 1020 and int(r0.x) == 520 and int(r0.y) == 1120,
		"dragging with a cluster selected moves every member")
	var up2 := InputEventMouseButton.new()
	up2.button_index = MOUSE_BUTTON_LEFT
	up2.pressed = false
	up2.position = drag2.position
	view._on_stage_input(up2)
	view._select(-1)
	var alt_click := InputEventMouseButton.new()       # Alt force-picks the single member
	alt_click.button_index = MOUSE_BUTTON_LEFT
	alt_click.pressed = true
	alt_click.alt_pressed = true
	alt_click.position = Vector2(440, 660) * s2
	view._on_stage_input(alt_click)
	ok(view._sel == 0 and view._sel_cluster == "",
		"Alt+click force-picks the single item out of its cluster")

	# --- Shift+click paints membership on the stage -----------------------------------
	view._select(-1)
	var click_tree := InputEventMouseButton.new()      # (440,660): tree only (member of camp)
	click_tree.button_index = MOUSE_BUTTON_LEFT
	click_tree.pressed = true
	click_tree.position = Vector2(440, 660) * s2
	view._on_stage_input(click_tree)
	ok(view._sel_cluster == "camp", "setup: the camp cluster is selected")
	var shift_gate := InputEventMouseButton.new()      # (540,920): gate on top (untagged)
	shift_gate.button_index = MOUSE_BUTTON_LEFT
	shift_gate.pressed = true
	shift_gate.shift_pressed = true
	shift_gate.position = Vector2(540, 920) * s2
	view._on_stage_input(shift_gate)
	ok(M.cluster_of(view.doc, 2) == "camp" and view._sel_cluster == "camp",
		"Shift+click on an outsider paints it INTO the selected cluster")
	view._on_stage_input(shift_gate)
	ok(M.cluster_of(view.doc, 2) == "",
		"Shift+click on a member paints it back OUT")
	view._select(-1)
	view._select(2)                                    # a single selected + Shift+click another single…
	var shift_tree := InputEventMouseButton.new()
	shift_tree.button_index = MOUSE_BUTTON_LEFT
	shift_tree.pressed = true
	shift_tree.shift_pressed = true
	shift_tree.position = Vector2(440, 660) * s2
	view._on_stage_input(shift_tree)
	ok(view._sel_cluster == "gate_cluster" and M.cluster_of(view.doc, 2) == "gate_cluster"
		and M.cluster_of(view.doc, 0) == "gate_cluster",
		"…births a new cluster from the pair (re-tagging the hit if needed)")
	var rn := view.find_child("ClusterRename", true, false) as LineEdit
	ok(rn != null and rn.text == "gate_cluster", "a selected cluster offers the rename field")
	if rn != null:
		rn.text_submitted.emit("shrine")
		await process_frame                            # the rename reselects deferred (field lives in the rebuilt box)
		ok(M.clusters(view.doc).has("shrine") and view._sel_cluster == "shrine",
			"submitting the field renames the cluster and follows the selection")

	# --- dynamic silhouette shadows render in the stage (same PropShadow as the game) --
	var art := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	art.fill(Color(1, 1, 1, 1))
	art.save_png(broot + "/art.png")
	(view.doc.placements[2] as Dictionary)["image"] = "art.png"
	M.set_shadow(view.doc, 2, true)
	view._rebuild_stage()
	var sh_node: Control = null
	var prop_node: Control = null
	for c in view._layers.get_children():
		if c.has_meta("pi_shadow") and int(c.get_meta("pi_shadow")) == 2:
			sh_node = c
		elif c.has_meta("pi") and int(c.get_meta("pi")) == 2:
			prop_node = c
	ok(sh_node != null and prop_node != null and sh_node.get_index() == prop_node.get_index() - 1,
		"a shadow-tagged entry draws the dynamic shadow just beneath its layer")
	ok(sh_node != null and sh_node.position == Vector2(540, 1060),
		"the shadow sits at the entry's footing")
	M.move(view.doc, 2, Vector2(10, 0))
	view._refresh_entry_rect(2)
	ok(sh_node != null and sh_node.position == Vector2(550, 1060),
		"the shadow follows a dragged prop's footing")
	M.move(view.doc, 2, Vector2(-10, 0))
	M.set_shadow(view.doc, 2, false)
	ok(not (view.doc.placements[2] as Dictionary).has("shadow"),
		"shadow off erases the key (untagged files stay byte-stable)")
	view._rebuild_stage()

	# --- runtime source crop + crop-bottom feather ------------------------------------
	# The placement metadata is the rendering contract: the interactive workbench must show
	# the SAME cropped, bottom-feathered plate as the deterministic reconstruction, rather
	# than loading the complete source image into the placed TextureRect.
	var crop_art := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for y in range(8):
		for x in range(8):
			crop_art.set_pixel(x, y, Color(float(x) / 8.0, float(y) / 8.0, 0.5, 1.0))
	crop_art.save_png(broot + "/crop_art.png")
	var crop_entry: Dictionary = view.doc.placements[2]
	crop_entry["image"] = "crop_art.png"
	crop_entry["sourceCrop"] = [1, 1, 4, 4]
	# JSON numbers deserialize as floats, even when authored as an integral value.
	# The live workbench must honor the same crop-bottom feather as the compositor.
	crop_entry["sourceCropFeatherBottom"] = 2.0
	view._rebuild_stage()
	var cropped_node: TextureRect = null
	for c in view._layers.get_children():
		if c.has_meta("pi") and int(c.get_meta("pi")) == 2:
			cropped_node = c as TextureRect
	var cropped := cropped_node.texture.get_image() if cropped_node != null else Image.create(1, 1, false, Image.FORMAT_RGBA8)
	ok(cropped.get_width() == 4 and cropped.get_height() == 4,
		"a placed sourceCrop renders its cropped texture, not the full source image")
	ok(absf(cropped.get_pixel(0, 0).r - 1.0 / 8.0) < 0.01
		and absf(cropped.get_pixel(0, 0).g - 1.0 / 8.0) < 0.01,
		"the placed crop starts at the declared source pixel")
	ok(cropped.get_pixel(0, 2).a > 0.99 and cropped.get_pixel(0, 3).a < 0.01,
		"a placed sourceCropFeatherBottom fades only the crop's bottom edge")
	crop_entry.erase("sourceCrop")
	crop_entry.erase("sourceCropFeatherBottom")
	crop_entry["image"] = "art.png"
	view._rebuild_stage()

	# --- add-to-cluster palette (iconed, scoped to the selected cluster) ---------------
	DirAccess.make_dir_recursive_absolute(broot + "/test_scene_elements_v1/03_structures")
	art.save_png(broot + "/test_scene_elements_v1/03_structures/test_scene_lantern_v1.png")
	view._select(-1)
	view._select_cluster("camp")
	var add_btns: Array = []
	for c in view._cluster_box.get_children():
		if c is Button and (c as Button).text.contains("+ "):
			add_btns.append(c)
	ok(add_btns.size() >= 1, "a selected cluster offers the iconed add palette")
	if add_btns.size() >= 1:
		var count_before: int = view.doc.placements.size()
		(add_btns[0] as Button).pressed.emit()
		ok(view.doc.placements.size() == count_before + 1, "pressing a palette row adds a new element")
		ok(M.cluster_of(view.doc, view._sel) == "camp",
			"the added element joins the selected cluster and is in hand")
		var camp_idx: Array = M.clusters(view.doc).get("camp", [])
		var top_z := 0
		for ci in camp_idx:
			if ci != view._sel:
				top_z = maxi(top_z, int((view.doc.placements[ci] as Dictionary).get("z", 0)))
		ok(int((view.doc.placements[view._sel] as Dictionary).get("z", 0)) == top_z + 1,
			"the new member lands just above its cluster's z band")
		M.remove_at(view.doc, view._sel)               # restore the fixture for downstream tests
		view._select(-1)
		view._rebuild_stage()

	# --- scene switching: ⌘S is the ONLY writer — a switch DISCARDS unsaved edits ------
	var icon_list := view.find_child("SceneIcons", true, false)
	ok(icon_list != null, "the workbench carries the scene icon list")
	ok(icon_list is VBoxContainer,
		"the scene list stacks vertically — every scene stays visible however many there are")
	# structural check (not instance identity — the suite convention can leave two _ready
	# generations in the tree): SceneIcons sits in the SceneStrip scroll of its own plain
	# Panel, while the sidebar is a PanelContainer.
	ok(icon_list.get_parent().name == "SceneStrip" and icon_list.get_parent().get_parent() is Panel,
		"the scene list lives in its own far-right column, not the sidebar")
	var icon_only := true
	for sb_c in icon_list.get_children():
		if sb_c is Button and (sb_c as Button).text != "":
			icon_only = false
	ok(icon_only, "scene buttons are icon-only, matching the mock strip")
	ok(M.scenes_in(broot) == ["test_scene"], "scenes_in lists every openable bundle")
	var live_scenes := M.scenes_in("res://games/grove/assets/_concepts/zones")
	ok(live_scenes.has("winter_lantern_lodge"),
		"the modular Lantern Lodge bundle is available as its own Scene Workbench scene")
	var lantern_doc := M.load_doc("res://games/grove/assets/_concepts/zones/winter_lantern_lodge_elements_v1/metadata/placements.json")
	var gazebo_z := -1
	var upper_left_cover_z := -1
	var unlock_cover_count := 0
	var lowest_unlock_cover_z := -1
	for e in M.placements(lantern_doc):
		if String((e as Dictionary).get("id", "")) == "gazebo":
			gazebo_z = int((e as Dictionary).get("z", -1))
		if String((e as Dictionary).get("id", "")) == "edge_covering_upper_left":
			upper_left_cover_z = int((e as Dictionary).get("z", -1))
		if String((e as Dictionary).get("layer", "")) == "unlock_cover":
			unlock_cover_count += 1
			lowest_unlock_cover_z = maxi(lowest_unlock_cover_z, int((e as Dictionary).get("z", -1)))
	ok(upper_left_cover_z >= 0 and upper_left_cover_z < gazebo_z,
		"the Lantern Lodge upper-left cover stays behind the gazebo roof")
	ok(unlock_cover_count == 23 and lowest_unlock_cover_z > 200,
		"the Lantern Lodge unlock cover is a topmost 23-piece removable layer")
	DirAccess.make_dir_recursive_absolute(broot + "/another_elements_v2/metadata")
	var other := {"scene": "another", "canvas": {"width": 500, "height": 500},
		"placements": [{"id": "solo", "image": "s.png", "x": 100, "y": 100, "w": 50, "h": 50, "z": 1}]}
	M.save_doc(broot + "/another_elements_v2/metadata/placements.json", other)
	ok(M.scenes_in(broot) == ["another", "test_scene"], "scenes_in picks up a new bundle")
	ok(view.dirty, "the drag left unsaved edits")
	view._switch_scene("another")
	ok(view.scene_name == "another" and view.doc.placements.size() == 1,
		"switching scenes loads the other bundle in place")
	var persisted := M.load_doc(broot + "/test_scene_elements_v1/metadata/placements.json")
	ok(int(persisted.placements[2].x) == 520,
		"the un-⌘S'd move never reached disk — a switch DISCARDS unsaved edits")
	view._switch_scene("test_scene")
	ok(int((view.doc.placements[2] as Dictionary).x) == 520,
		"switching back reloads the last SAVED state (the move is gone)")
	view.queue_free()

	# --- root scoring + reference images ----------------------------------------------
	var partial := OS.get_user_data_dir() + "/scene_wb_partial_root"
	DirAccess.make_dir_recursive_absolute(partial + "/test_scene_elements_v1/metadata")
	# the partial root has a dir but NO placements.json → 0 openable scenes
	ok(M.pick_root([partial, broot]) == broot,
		"pick_root prefers the root with the most OPENABLE scenes (a partial intake never shadows the full one)")
	ok(M.pick_root([broot, partial]) == broot, "…regardless of candidate order")
	ok(M.pick_root([partial + "/nope"]) == "", "no openable scenes anywhere → empty (the launcher errors out)")
	ok(M.pick_root_for_scene([broot, partial], "test_scene") == broot,
		"pick_root_for_scene chooses the root that actually contains the requested scene")
	ok(M.pick_root_for_scene([broot, partial], "missing_scene") == broot,
		"pick_root_for_scene falls back to the richest root when the requested scene is absent")
	var stale_concept := broot + "/games/grove/assets/_concepts/zones/test_scene_original_mock_v1.png"
	if FileAccess.file_exists(stale_concept):          # idempotent across runs — created again below
		DirAccess.remove_absolute(stale_concept)
	var mock := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	mock.save_png(broot + "/test_scene.png")
	mock.save_png(broot + "/test_scene_market_v2.png")
	DirAccess.make_dir_recursive_absolute(broot + "/test_scene_elements_v1/09_reconstruction")
	mock.save_png(broot + "/test_scene_elements_v1/09_reconstruction/recon.png")
	var refs: Array = M.reference_images(broot, broot + "/test_scene_elements_v1", "test_scene")
	ok(refs.size() == 3, "reference_images collects the root mocks + the reconstruction composites")
	var has_recon := false
	for rp in refs:
		if String(rp).ends_with("recon.png"):
			has_recon = true
	ok(has_recon, "the reconstruction rides along with the scene mocks")
	# original concept mocks (assets/_concepts/zones under the repo root) list FIRST — primary refs
	DirAccess.make_dir_recursive_absolute(broot + "/games/grove/assets/_concepts/zones")
	mock.save_png(broot + "/games/grove/assets/_concepts/zones/test_scene_original_mock_v1.png")
	refs = M.reference_images(broot, broot + "/test_scene_elements_v1", "test_scene")
	ok(refs.size() == 4 and String(refs[0]).ends_with("test_scene_original_mock_v1.png"),
		"the _concepts/zones original mock joins the references, listed first")
	view._switch_scene("test_scene")                   # the dropdown test left the view on 'another'
	ok(view.find_child("RefIcon_1", true, false) != null,
		"multiple mocks build the far-left icon strip (one thumb per reference)")
	(view.find_child("RefIcon_1", true, false) as Button).pressed.emit()
	ok(view._ref_idx == 1, "pressing a strip icon swaps the full-height mock in place")
	ok(view._ref_img != null and is_instance_valid(view._ref_img),
		"the big mock swaps without rebuilding the panel (the strip stays alive)")

	# --- path resolution ------------------------------------------------------------
	var sr := "/repo/games/grove/assets/_concepts/zones"
	ok(M.repo_root_of(sr) == "/repo", "repo_root_of strips the scenes suffix")
	ok(M.repo_root_of("/repo/games/grove/assets/_concepts/zones") == "/repo",
		"a custom scenes root under games resolves repo-relative artwork from the repository root")
	ok(M.repo_root_of("games/grove/assets/_concepts/zones") == ".",
		"a relative custom scenes root under games resolves repo-relative artwork from the project root")
	ok(M.repo_root_of("/elsewhere/scenes") == "/elsewhere/scenes",
		"a root outside a repository keeps its own relative-art base")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
