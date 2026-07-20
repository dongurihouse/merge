extends "res://games/grove/tests/grove_test_base.gd"
## grove · info bar — focused tests for player-facing selected-item copy.

const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")
const FX = preload("res://engine/scripts/ui/fx.gd")

func _resource_suffix(resource: Resource, suffix: String) -> bool:
	return resource != null and String(resource.resource_path).ends_with(suffix)

func _button_shell(button: Button) -> Texture2D:
	var style := button.get_theme_stylebox("normal")
	return (style as StyleBoxTexture).texture if style is StyleBoxTexture else null

func _node_texture_path(node: Node) -> String:
	if node is TextureRect and (node as TextureRect).texture != null:
		return String((node as TextureRect).texture.resource_path)
	if node is NinePatchRect and (node as NinePatchRect).texture != null:
		return String((node as NinePatchRect).texture.resource_path)
	return ""

func _test_meadow_shared_components() -> void:
	# danger keeps its baked nine-patch shell …
	for spec in [["danger", "button_danger.png"]]:
		var button := Kit.pill_button("Action", {"bg": spec[0], "art": true})
		var style := button.get_theme_stylebox("normal")
		ok(style is StyleBoxTexture and _resource_suffix(_button_shell(button), "ui/meadow_v2/%s" % spec[1]),
			"pill_button %s uses the canonical Meadow shell" % spec[0])
		ok(style is StyleBoxTexture and (style as StyleBoxTexture).get_texture_margin(SIDE_LEFT) > 0.0
			and (style as StyleBoxTexture).get_texture_margin(SIDE_TOP) > 0.0,
			"pill_button %s declares nine-slice margins" % spec[0])
		ok(button.text == "Action" and button.mouse_filter != Control.MOUSE_FILTER_IGNORE,
			"pill_button %s retains native text and its hit target" % spec[0])
		button.free()
	# … while CREAM is now the flat paper-cut surface too — texture_cream masked to the button's rounded
	# rect and drawn BEHIND the label — so a cream chip and a green Claim read as cut from the same paper.
	var cream := Kit.pill_button("Action", {"bg": "cream", "art": true})
	var cream_style := cream.get_theme_stylebox("normal")
	var cream_paper := cream.find_child("ButtonPaperSurface", true, false) as TextureRect
	ok(cream_paper != null and _resource_suffix(cream_paper.texture, "ui/meadow_v2/texture_cream.png") \
		and cream_paper.material is ShaderMaterial and cream_paper.show_behind_parent,
		"pill_button cream wears the flat cream paper, masked and drawn behind its label")
	ok(cream_style is StyleBoxFlat and not (cream_style as StyleBoxFlat).draw_center \
		and (cream_style as StyleBoxFlat).get_corner_radius(CORNER_TOP_LEFT) > 0,
		"the cream button's stylebox contributes only the rounded edge — the paper is the fill")
	ok(cream.text == "Action" and cream.mouse_filter != Control.MOUSE_FILTER_IGNORE,
		"pill_button cream retains native text and its hit target")
	cream.free()
	# … while GREEN (the primary action role) is the flat paper-cut surface: the action-green paper
	# masked to the button's rounded rect, drawn BEHIND the button's own text, plus a drop shadow.
	var green := Kit.pill_button("Action", {"bg": "green", "art": true})
	var green_style := green.get_theme_stylebox("normal")
	var green_paper := green.find_child("ButtonPaperSurface", true, false) as TextureRect
	ok(green_paper != null and _resource_suffix(green_paper.texture, "ui/meadow_v2/texture_action_green.png") \
		and green_paper.material is ShaderMaterial and green_paper.show_behind_parent,
		"pill_button green wears the flat action-green paper, masked and drawn behind its label")
	ok(green_style is StyleBoxFlat and not (green_style as StyleBoxFlat).draw_center \
		and (green_style as StyleBoxFlat).get_corner_radius(CORNER_TOP_LEFT) > 0,
		"the green button's stylebox contributes only the rounded edge — the paper is the fill")
	ok(green.find_children("", "Panel", true, false).size() >= 1,
		"pill_button green casts the shared drop shadow")
	ok(green.text == "Action" and green.mouse_filter != Control.MOUSE_FILTER_IGNORE,
		"pill_button green retains native text and its hit target")
	green.free()
	var default_button := Kit.pill_button("Action")
	ok(default_button.find_child("ButtonPaperSurface", true, false) != null,
		"pill_button defaults to the green paper-cut surface")
	default_button.free()

	var board := Kit.board_panel(Vector2(420, 360), {"shadow": true})
	var board_surface := board.find_child("MeadowBoardSurface", true, false) as Panel
	var board_style := board_surface.get_theme_stylebox("panel") as StyleBoxFlat if board_surface != null else null
	var board_paper := board.find_child("MeadowBoardPaper", true, false) as TextureRect
	var board_shadow := board.find_child("MeadowBoardShadow", true, false) as Panel
	ok(board_style != null and board_style.bg_color.is_equal_approx(Color("#3F6D7D")) \
		and board_style.border_color.r == Color("#F6EBDD").r \
		and board_style.get_border_width(SIDE_LEFT) == 2,
		"board_panel draws one structural-slate panel with a light code edge")
	ok(board_paper != null and _resource_suffix(board_paper.texture, "ui/meadow_v2/texture_structural_slate.png") \
		and board_paper.material is ShaderMaterial,
		"board_panel masks the flat structural-slate paper texture to its code shape")
	ok(board_shadow != null and board.find_children("MeadowBoardShadow", "Panel", true, false).size() == 1 \
		and board.find_child("MeadowBoardFrame", true, false) == null,
		"board_panel owns one overall shadow and no pre-cut frame ring")
	board.free()

	for spec in [["empty", false, "texture_meadow.png", Color("#A8D3B9")], ["locked", false, "texture_receding_blue.png", Color("#8296AF")], ["locked", true, "texture_receding_blue.png", Color("#8296AF")]]:
		var cell := Kit.slot_cell_background(Vector2(112, 112), spec[0], spec[1], {"cell_shadow": 1.0})
		var style := cell.get_theme_stylebox("panel")
		var paper := cell.find_child("SlotCellPaperTexture", true, false) as TextureRect
		ok(style is StyleBoxFlat and (style as StyleBoxFlat).bg_color.is_equal_approx(spec[3]) \
			and (style as StyleBoxFlat).shadow_size == 0 \
			and cell.position == Vector2(3.0, 3.0) and cell.size == Vector2(106.0, 106.0),
			"slot-cell state %s/%s draws a flat code surface with no cell shadow" % [spec[0], spec[1]])
		ok(paper != null and _resource_suffix(paper.texture, "ui/meadow_v2/%s" % spec[2]) \
			and paper.material is ShaderMaterial \
			and cell.find_child("MeadowSlotShadow", true, false) == null,
			"slot-cell state %s/%s masks one flat paper texture without a shadow layer" % [spec[0], spec[1]])
		cell.free()

	var locked_cell := Kit.slot_cell({"state": "locked"}, {"cell_w": 112.0, "cell_h": 112.0})
	var lock_marks := locked_cell.find_children("SlotCellLockMark", "TextureRect", true, false)
	var lock_mark := lock_marks[0] as TextureRect if lock_marks.size() == 1 else null
	ok(lock_mark != null and _resource_suffix(lock_mark.texture, "ui/meadow_v2/acorn_lock.svg") \
		and locked_cell.find_child("SlotCellLockedPlaceholder", true, false) == null,
		"locked cell shows one combined acorn-lock mark with no overlapping padlock")
	locked_cell.free()

	for spec in [[-8, 1], [0, 1], [1, 2], [24, 25], [99, 25]]:
		var badge := Kit.level_badge({}, spec[0], 37, 128.0)
		var art := badge.find_child("lv_badge_art", true, false) as TextureRect
		ok(art != null and _resource_suffix(art.texture, "ui/meadow_v2/level_badge_%02d.png" % spec[1]),
			"level badge tier %d clamps to stable Meadow variant %02d" % [spec[0], spec[1]])
		ok(art != null and art.texture.get_width() == 256 and art.texture.get_height() == 256,
			"level badge variant %02d remains 256 x 256" % spec[1])
		ok(badge.find_child("lv_num", true, false) is Label and badge.find_child("lv_circle", true, false) == null,
			"level badge keeps native lv_num above one shared base")
		badge.free()

	var badge_opts := Kit.level_badge_opts_from_config({"level_badge": {
		"num_size": 41, "leaf_x": 55, "circle_design": "6", "size": 77}})
	ok(is_equal_approx(float(badge_opts.get("num_size", 0)), 41.0)
		and not badge_opts.has("leaf_x") and not badge_opts.has("circle_design") and not badge_opts.has("size"),
		"stale layered-part sliders no longer control the Meadow level badge")

	var dialog_content := Label.new()
	dialog_content.text = "Body"
	var dialog := Kit.dialog_frame(dialog_content, 520.0, {"banner_text": "Mail"})
	var dialog_title := dialog.find_child("DialogTitle", true, false) as Label
	var dialog_card := dialog.find_child("MeadowDialogPanel", true, false) as PanelContainer
	var dialog_style := dialog_card.get_theme_stylebox("panel") if dialog_card != null else null
	ok(dialog_title != null and dialog_title.text == "MAIL"
		and dialog.find_child("MeadowTitleBanner", true, false) == null,
		"active shared-dialog coverage composes the simple v2 ink title (ribbon retired)")
	ok(dialog_style is StyleBoxFlat and (dialog_style as StyleBoxFlat).shadow_size > 0,
		"active shared-dialog coverage draws the simple cream sheet")
	dialog.free()

	var level_body := Label.new()
	level_body.text = "Progress"
	var level_frame := Kit.level_frame(level_body, 460.0, {"banner_text": "Level 12"})
	ok(_node_texture_path(level_frame.find_child("MeadowTitleBanner", true, false)).ends_with("ui/meadow_v2/title_banner.png"),
		"active Level-dialog coverage uses the shared Meadow ribbon")
	level_frame.free()

	var jar := Kit._vault_jar(320, 500, 200.0, 250.0)
	var jar_fill := jar.find_child("VaultAcornFill", true, false) as Control
	ok(_node_texture_path(jar.find_child("VaultJarShell", true, false)).ends_with("ui/meadow_v2/vault_jar_shell.png")
		and _node_texture_path(jar.find_child("VaultAcornFillArt", true, false)).ends_with("ui/meadow_v2/vault_acorn_fill.png")
		and _node_texture_path(jar.find_child("VaultPlate", true, false)).ends_with("ui/meadow_v2/vault_plate.png")
		and jar_fill != null and jar_fill.clip_contents
		and is_equal_approx(jar_fill.size.y, 128.0) and is_equal_approx(jar_fill.position.y, 72.0),
		"active Vault coverage layers shell, clipped fill, and plate")
	jar.free()
	var vault := Kit.vault_dialog({"balance": 320, "cap": 500, "price": "$4.99", "claimable": true})
	var vault_cta: Button = null
	for candidate in vault.find_children("*", "Button", true, false):
		if (candidate as Button).text == "$4.99":
			vault_cta = candidate as Button
			break
	var vault_paper := vault_cta.find_child("ButtonPaperSurface", true, false) as TextureRect if vault_cta != null else null
	ok(vault_paper != null and _resource_suffix(vault_paper.texture, "ui/meadow_v2/texture_action_green.png"),
		"production Vault CTA inherits the green paper-cut surface")
	vault.free()

	for icon_id in ["settings", "mail", "vault", "daily", "expedition", "gift", "news"]:
		ok(Kit._icon_path(icon_id).ends_with("ui/meadow_v2/icon_%s.png" % icon_id),
			"active icon coverage routes %s to its compatible Meadow asset" % icon_id)
	ok(String(Kit.daily_opts_from_config({}).banner_icon_id) == "daily"
		and String(Kit.settings_opts_from_config({}).banner_icon_id) == "settings"
		and String(Kit.vault_opts_from_config({}).banner_icon_id) == "vault",
		"daily, Settings, and Vault dialogs consume their compatible Meadow icons")

func _initialize() -> void:
	begin("grove · info bar")
	_test_meadow_shared_components()

	var content := G.new()
	var has_copy_helpers := content.has_method("item_display_name") and content.has_method("item_description")
	ok(has_copy_helpers, "content exposes canonical item display-name and description helpers")
	if has_copy_helpers:
		ok(content.call("item_display_name", 101) == "Glow-mushrooms", "regular lines keep their authored display names")
		ok(String(content.call("item_description", 101)).contains("forest"), "regular lines carry a player-useful hint")
		ok(content.call("item_display_name", 1201) == "Water drop", "special drops have real display names")
		ok(String(content.call("item_description", 1202)).contains("20 water"), "collectable special drops describe their tier reward")
		ok(content.call("item_display_name", 902) == "Coin", "coin items have a real display name")
		ok(String(content.call("item_description", 902)).contains("4 coins"), "coin items explain their collect value")
		for special_line in G.SPECIAL_ITEMS:
			var special_code := int(special_line) * 100 + 1
			ok(content.call("item_display_name", special_code) != "Item", "special item line %d has player-facing copy" % int(special_line))
			ok(String(content.call("item_description", special_code)) != "", "special item line %d has info-bar detail" % int(special_line))
		for treat_line in G.TREAT_LINES:
			var treat_code := int(treat_line) * 100 + G.TREAT_POP_TIER
			ok(content.call("item_display_name", treat_code) != "Item", "treat item line %d has player-facing copy" % int(treat_line))
			ok(String(content.call("item_description", treat_code)) != "", "treat item line %d has info-bar detail" % int(treat_line))
	var has_generator_copy_helpers := content.has_method("generator_display_name") and content.has_method("generator_description")
	ok(has_generator_copy_helpers, "content exposes canonical generator display-name and description helpers")
	if has_generator_copy_helpers:
		ok(content.call("generator_display_name", "acc_water") == "Rain barrel", "accumulators have real generator names")
		ok(String(content.call("generator_description", "acc_water")).contains("water"), "accumulators describe their banked reward")
		ok(String(content.call("generator_display_name", G.treat_gen_id(71))).contains("Prize pumpkin"), "treat generators name their treasure line")
		ok(String(content.call("generator_description", G.treat_gen_id(71))).contains("Prize pumpkin"), "treat generators describe their premium output")

	fresh("info_bar_copy")
	var board_scene = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(board_scene)
	await process_frame
	if board_scene.board == null:
		board_scene._ready()
	await create_timer(0.05).timeout
	var info_button := board_scene.get("_info_btn") as Button
	var live_hides_info := bool(Kit.info_bar_opts_from_config(Kit.load_config(Kit.CONFIG_PATH)).get("hide_info_button", false))
	ok(info_button != null, "the info bar exposes its info button")
	ok(info_button != null and info_button.visible and not info_button.disabled, \
		"the empty info bar shows an enabled tutorial info button")
	var info_bar := board_scene.find_child("ActionBarInfoBar", true, false) as Control
	ok(info_bar != null, "the board exposes the live action-bar info bar")
	var empty_info_center_delta := absf(info_button.get_global_rect().get_center().y - info_bar.get_global_rect().get_center().y) if info_button != null and info_bar != null else 999.0
	ok(empty_info_center_delta <= 1.0, \
		"the empty info button is vertically centered in the workbench-tuned info bar")
	ok(board_scene.get_node_or_null("BoardTutorialOverlay") != null, \
		"a fresh board opens the how-to-play tutorial on first run")
	ok(bool(Save.grove().get("board_tutorial_seen", false)), \
		"opening the first-run board tutorial marks it seen")
	var board_intro: Control = board_scene.get_node_or_null("BoardTutorialOverlay") as Control
	var intro_art := board_intro.find_child("TutorialImageArt", true, false) as TextureRect if board_intro != null else null
	var intro_vp: Vector2 = board_scene.get_viewport_rect().size
	ok(board_intro != null and board_intro.find_child("TutorialCloseButton", true, false) == null, \
		"the tutorial image has no separate close button")
	ok(board_intro != null and board_intro.find_child("TutorialImageFrame", true, false) == null, \
		"the tutorial image is not wrapped in a card frame")
	ok(intro_art != null and intro_art.get_global_rect().size.distance_to(intro_vp) < 2.0, \
		"the tutorial image fills the full screen")
	if board_intro != null:
		_push_tap(intro_art.get_global_rect().get_center() if intro_art != null else board_intro.get_global_rect().get_center())
		await process_frame
	ok(board_scene.get_node_or_null("BoardTutorialOverlay") == null, \
		"tapping anywhere on the tutorial image closes it")
	board_scene._on_info_pressed()
	await process_frame
	ok(board_scene.get_node_or_null("BoardTutorialOverlay") != null, \
		"the empty info button reopens the board how-to-play tutorial")
	var reopened_intro: Node = board_scene.get_node_or_null("BoardTutorialOverlay")
	if reopened_intro != null:
		reopened_intro.queue_free()
		await process_frame
	var desc_label: Label = board_scene.get("_info_desc_label") as Label
	ok(desc_label != null and desc_label.visible and desc_label.text.contains("Drag an item to the bag"), \
		"the empty info bar mentions dragging an item to the bag for space")
	await process_frame
	var live_info_rect := info_bar.get_global_rect() if info_bar != null else Rect2()
	ok(info_bar != null and live_info_rect.encloses(board_scene._info_label.get_global_rect()), \
		"the empty info-bar title stays inside the live Meadow action tray")
	ok(info_bar != null and desc_label != null and live_info_rect.encloses(desc_label.get_global_rect()), \
		"the empty info-bar help copy stays inside the live Meadow action tray")
	var live_tray_rect: Rect2 = board_scene.bottom_bar.get_global_rect() if board_scene.bottom_bar != null else Rect2()
	ok(board_scene.bottom_bar != null and live_tray_rect.encloses(board_scene._info_label.get_global_rect()), \
		"the empty info-bar title stays inside the outer Meadow action tray")
	ok(board_scene.bottom_bar != null and desc_label != null and live_tray_rect.encloses(desc_label.get_global_rect()), \
		"the empty info-bar help copy stays inside the outer Meadow action tray")
	var live_info_tray := board_scene.bottom_bar.find_child("ActionBarInfoTray", true, false) as Control
	ok(live_info_tray != null and board_scene.home_btn != null \
			and absf(live_info_tray.get_global_rect().size.y - board_scene.home_btn.get_global_rect().size.y) <= 1.0, \
		"the centre info tray stands the same height as the Home tile beside it")
	ok(live_info_tray != null and board_scene.bag_btn != null \
			and absf(live_info_tray.get_global_rect().size.y - board_scene.bag_btn.get_global_rect().size.y) <= 1.0, \
		"the centre info tray stands the same height as the Bag tile beside it")
	ok(board_scene._info_label.get_line_count() <= 2, \
		"the empty info-bar title fits in at most two lines at the phone viewport")
	ok(desc_label != null and desc_label.get_line_count() <= 3, \
		"the empty info-bar help copy fits in at most three compact lines at the phone viewport")
	var empty_info_slot := info_button.get_parent() as Control
	ok(empty_info_slot != null and not empty_info_slot.get_global_rect().intersects(board_scene._info_label.get_global_rect()), \
		"the empty info-button slot does not overlap the instructional title")
	ok(not info_button.get_global_rect().intersects(board_scene._info_label.get_global_rect()), \
		"the empty info button does not overlap the instructional title")

	var cell := Vector2i(-1, -1)
	for c in board_scene.board.empty_ground_cells():
		if not board_scene.board.is_gen(c):
			cell = c
			break
	ok(cell.x >= 0, "the focused info-bar test found an empty board cell")
	if cell.x >= 0:
		board_scene.board.place(cell, 1201)
		board_scene._rebuild_pieces()
		board_scene._select_item(cell)
		ok(info_button.visible == (not live_hides_info) and info_button.disabled == live_hides_info, \
			"selecting an item applies the configured info button visibility")
		ok(board_scene._info_label.text == "Water drop", "the info bar title is the item name without tier suffix")
		ok(desc_label != null and desc_label.visible and desc_label.text.begins_with("Tier 1"), \
			"the info bar subtitle starts with the selected item's tier")
		ok(desc_label != null and desc_label.visible and desc_label.text.contains("8 water"), \
			"the info bar subtitle keeps the selected item's useful hint")
		ok(board_scene._info_label.autowrap_mode != TextServer.AUTOWRAP_OFF and not board_scene._info_label.clip_text, \
			"the info bar title wraps instead of ellipsizing when it overflows")
		ok(desc_label != null and desc_label.autowrap_mode != TextServer.AUTOWRAP_OFF and not desc_label.clip_text, \
			"the info bar subtitle wraps instead of ellipsizing when it overflows")
		# the title is enlarged for prominence; the subtitle stays SMALLER than it so long, sentence-length
		# descriptions still fit the narrow phone bar (matching the subtitle to the big title overflows it).
		var title_font: int = board_scene._info_label.get_theme_font_size("font_size")
		var sub_font: int = desc_label.get_theme_font_size("font_size")
		ok(sub_font < title_font, \
			"the info bar subtitle stays smaller than the enlarged title (%d) so long descriptions fit" % title_font)
		var selected_icon_slot := board_scene.get("_info_icon") as Control
		var selected_art := selected_icon_slot.get_child(0) as Control if selected_icon_slot != null and selected_icon_slot.get_child_count() > 0 else null
		var expected_icon_px_raw = board_scene.get("_info_item_px")
		var expected_icon_px := float(expected_icon_px_raw) if expected_icon_px_raw != null else -1.0
		ok(expected_icon_px > float(board_scene.get("_info_inner_px")), \
			"the live info bar item artwork size is based on bar height, not the info button slot")
		ok(selected_art != null and is_equal_approx(selected_art.custom_minimum_size.x, expected_icon_px), \
			"the live info bar selected item uses the height-based artwork size")
		var selected_art_sprite := selected_art.get_node_or_null(NodePath("ItemArt")) as Control if selected_art != null else null
		ok(selected_art_sprite != null \
			and is_equal_approx(selected_art_sprite.offset_left, 0.0) \
			and is_equal_approx(selected_art_sprite.offset_top, 0.0), \
			"the live info bar selected item uses the full artwork box without board-cell inset")
		board_scene._on_info_pressed()
		await process_frame
		ok(board_scene.get_node_or_null("LadderOverlay") != null, "the selected special item opens its tier info")
		var special_ladder: Array = board_scene._ladder_entries(12)
		ok(special_ladder.size() == G.merge_top(1201), "special item ladders stop at their merge ceiling")
		var special_overlay: Node = board_scene.get_node_or_null("LadderOverlay")
		if special_overlay != null:
			special_overlay.queue_free()
			await process_frame
		board_scene._clear_selection()
		ok(info_button.visible and not info_button.disabled, "clearing focus restores the tutorial info button")
		ok(desc_label != null and desc_label.visible and desc_label.text.contains("Drag an item to the bag"), \
			"clearing focus restores the empty info bar bag-space hint")

	# Focus + two-tap collect (real click routing): tapping a coin FOCUSES its cell (a corner-bracket
	# frame appears) and a SECOND tap of the now-focused cell COLLECTS it. The frame is the on-board
	# cue that makes the two-tap discoverable — without it players read the collect as broken.
	var coin_cell := Vector2i(-1, -1)
	for c in board_scene.board.empty_ground_cells():
		if not board_scene.board.is_gen(c) and c != cell:
			coin_cell = c
			break
	ok(coin_cell.x >= 0, "the collect test found a second empty cell")
	if coin_cell.x >= 0:
		board_scene.board.place(coin_cell, 902)   # a tier-2 coin worth 5
		board_scene._rebuild_pieces()
		var half := Vector2(board_scene.csz, board_scene.csz) / 2.0
		var gat: Vector2 = board_scene.board_area.get_global_transform() * (board_scene._cell_pos(coin_cell) + half)
		var coins0 := Save.coins()
		_push_tap(gat)                                   # tap 1 → focus
		await create_timer(0.05).timeout
		ok(board_scene._selected_cell == coin_cell, "tap 1 focuses the coin cell")
		ok(board_scene._focus_ring != null and is_instance_valid(board_scene._focus_ring) and board_scene._focus_ring.visible, \
			"tap 1 shows the corner-bracket focus frame")
		ok(board_scene._focus_ring.position == board_scene._cell_pos(coin_cell), "the focus frame sits on the focused cell")
		ok(board_scene.board.item_at(coin_cell) == 902, "tap 1 does NOT collect the coin")
		_push_tap(gat)                                   # tap 2 → collect
		await create_timer(0.05).timeout
		ok(board_scene.board.item_at(coin_cell) == 0, "tap 2 of the focused coin collects it")
		ok(Save.coins() == coins0 + G.coin_value(902), "collecting credits the coin value (+%d)" % G.coin_value(902))
		ok(not board_scene._focus_ring.visible, "collecting clears the focus frame")

	# Regression (the live bug): emulate_touch_from_mouse=true delivers a mouse AND a synthesized touch
	# event per physical tap, so _on_board_input sees each press/release TWICE. Without dedup the 2nd press
	# clears the focus the 1st captured, so the second tap reads _press_was_selected=false and merely
	# RE-FOCUSES the coin instead of collecting. Drive a coin with the DOUBLE-event tap and confirm collect.
	var dbl_cell := coin_cell   # reuse the now-empty cell from the first collect (fresh board has few open cells)
	if dbl_cell.x >= 0 and board_scene.board.item_at(dbl_cell) == 0:
		board_scene.board.place(dbl_cell, 902)
		board_scene._rebuild_pieces()
		var dhalf := Vector2(board_scene.csz, board_scene.csz) / 2.0
		var dat: Vector2 = board_scene._cell_pos(dbl_cell) + dhalf   # board_area-local (gui_input space)
		var dcoins0 := Save.coins()
		_tap_emulated(board_scene, dat)   # tap 1 → focus
		await create_timer(0.05).timeout
		ok(board_scene._selected_cell == dbl_cell, "double-event tap 1 focuses the coin")
		_tap_emulated(board_scene, dat)   # tap 2 → must COLLECT, not just re-focus
		await create_timer(0.05).timeout
		ok(board_scene.board.item_at(dbl_cell) == 0, "double-event tap 2 COLLECTS (emulate_touch_from_mouse dedup)")
		ok(Save.coins() == dcoins0 + G.coin_value(902), "double-event collect credits the coin value")

	# A regular board item that is neither a collectable nor wanted by a live quest should use the
	# same visible focus affordance: tap 1 focuses it, tap 2 opens its tier ladder instead of no-oping.
	var regular_cell := dbl_cell
	if regular_cell.x < 0 or board_scene.board.item_at(regular_cell) != 0:
		regular_cell = _first_empty_cell(board_scene, [cell, coin_cell])
	ok(regular_cell.x >= 0, "the focused regular-item ladder test found an empty cell")
	if regular_cell.x >= 0:
		var saved_quests: Array = board_scene.quests.duplicate(true)
		board_scene.quests = []
		var regular_code := 101
		board_scene.board.place(regular_cell, regular_code)
		board_scene._rebuild_pieces()
		ok(not G.is_collectable(regular_code), "the regular test item is not tap-collectable")
		ok(board_scene.board.collect_reward_at(regular_cell).is_empty(), "the regular test item has no custom collect reward")
		ok(board_scene._quest_for_code(regular_code) < 0, "the regular test item is not a quest-ready delivery")
		var rhalf := Vector2(board_scene.csz, board_scene.csz) / 2.0
		var rat: Vector2 = board_scene.board_area.get_global_transform() * (board_scene._cell_pos(regular_cell) + rhalf)
		_push_tap(rat)                                   # tap 1 -> focus
		await create_timer(0.05).timeout
		ok(board_scene._selected_cell == regular_cell, "tap 1 focuses the regular item")
		ok(board_scene.get_node_or_null("LadderOverlay") == null, "tap 1 does not open the tier dialog")
		var rat2: Vector2 = board_scene.board_area.get_global_transform() * (board_scene._cell_pos(regular_cell) + rhalf)
		_push_tap(rat2)                                  # tap 2 -> tier dialog
		await create_timer(0.05).timeout
		ok(board_scene.get_node_or_null("LadderOverlay") != null, "tap 2 of the focused regular item opens the tier dialog")
		ok(board_scene.board.item_at(regular_cell) == regular_code, "opening the tier dialog leaves the regular item on the board")
		var regular_overlay: Node = board_scene.get_node_or_null("LadderOverlay")
		if regular_overlay != null:
			regular_overlay.queue_free()
			await process_frame
		board_scene.board.place(regular_cell, 0)
		board_scene._rebuild_pieces()
		board_scene._clear_selection()
		board_scene.quests = saved_quests

	# Producing dialog (tap generator → ⓘ): the lines a generator currently makes, drilling into each line's
	# tier ladder. Logic (_gen_line_entries / _pop_pool_ctx) + the info-button wiring.
	var gens: Dictionary = board_scene.board.gens
	ok(not gens.is_empty(), "the fresh board has its anchor generator")
	if not gens.is_empty():
		var gcell: Vector2i = gens.keys()[0]
		var gid: String = board_scene.board.gen_id_at(gcell)
		var entries: Array = board_scene._gen_line_entries(gid)
		ok(not entries.is_empty(), "the generator reports its lines")
		# SHOW ALL: every line in the WHOLE game (every generator / every map) gets a cell — the full roadmap.
		var all_game_lines: Array = []
		for gen in G.GENERATORS:
			var gl := int(gen.get("line", 0))   # gen redesign: one line per generator (the lines[] array is retired)
			if gl > 0 and not all_game_lines.has(gl):
				all_game_lines.append(gl)
		var entry_lines: Array = []
		var all_valid := true
		var has_other_map := false
		for e in entries:
			entry_lines.append(int(e.line))
			if not G.LINES.has(int(e.line)):
				all_valid = false
			if int(e.line) == 18:                 # Koi — the LAST page's (band 4) line, far from the anchor
				has_other_map = true
		ok(all_valid, "every Producing entry is a real game line")
		var all_present := true
		for gl in all_game_lines:
			if not entry_lines.has(int(gl)):
				all_present = false
		ok(all_present and entries.size() == all_game_lines.size(), "every base line in the game gets a cell (show-all roadmap)")
		ok(has_other_map, "lines from later maps appear too (not just the tapped generator's own roster)")
		# in_pool must match the SELECTED generator's own pop line. The global quest context may span
		# several wanted lines, but a per-line generator still only produces its own line.
		var gen_line := int(G.gen_def(G.GENERATORS, gid).get("line", 0))
		var hot_lines: Array = []
		for e in entries:
			if bool(e.in_pool):
				hot_lines.append(int(e.line))
		ok(hot_lines == [gen_line], "Producing highlights only the selected generator's own line")
		var saved_quests: Array = board_scene.quests.duplicate(true)
		board_scene.quests = [
			{"line": gen_line, "tier": 4, "reward": {"exp": 1, "coins": 0}},
			{"line": 2, "tier": 4, "reward": {"exp": 1, "coins": 0}},
			{"line": 3, "tier": 4, "reward": {"exp": 1, "coins": 0}},
		]
		var quest_lines := {}
		for _q in board_scene.quests:
			quest_lines[int(_q.line)] = true
		ok(quest_lines.size() > 1, "test setup: active quests span multiple lines")
		var mixed_hot: Array = []
		for e in board_scene._gen_line_entries(gid):
			if bool(e.in_pool):
				mixed_hot.append(int(e.line))
		ok(mixed_hot == [gen_line], "Producing stays selected-generator-only when quests want several lines")
		board_scene.quests = saved_quests
		# seen/code: a wholly-unseen line carries no piece (code 0); marking its tier-1 lights it with that code.
		var probe := int(entries[0].line)
		var g := Save.grove()
		g["seen"] = {}
		ok(int(board_scene._gen_line_entries(gid)[0].code) == 0, "an unseen line carries no representative piece (code 0)")
		g["seen"][str(probe * 100 + 1)] = true
		var lit: Array = board_scene._gen_line_entries(gid)
		ok(bool(lit[0].seen) and int(lit[0].code) == probe * 100 + 1, "a seen line shows its lowest-seen tier piece")
		board_scene.board.gen_tiers[gcell] = 2
		board_scene._rebuild_all()
		var tier2_gen_file := G.gen_tex(gid, 2).get_file()
		ok(_has_texture_suffix(board_scene.gen_nodes.get(gcell), tier2_gen_file), "tier-2 generator uses resolved board art")
		board_scene._select_generator(gcell)
		ok(desc_label != null and desc_label.visible and desc_label.text.begins_with("Tier 2"), "generator info bar shows the selected generator tier")
		ok(_has_texture_suffix(board_scene._info_icon, tier2_gen_file), "generator info bar preview uses resolved tier art")
		# wiring: selecting the generator enables ⓘ, and ⓘ opens the Producing overlay (feature is on).
		board_scene._select_generator(gcell)
		ok(board_scene._info_btn.disabled == live_hides_info, "selecting a generator applies the configured info button visibility")
		board_scene._on_info_pressed()
		await process_frame
		ok(board_scene.get_node_or_null("GenLinesOverlay") != null, "the info button opens the Producing dialog overlay")
		var ov: Node = board_scene.get_node_or_null("GenLinesOverlay")
		if ov != null:
			ov.queue_free()
		board_scene._clear_selection()

	# Special generators: accumulators and temporary treat generators are board generators too. A still
	# tap must leave them focused with useful copy, even though their tap action is collect/pop instead of
	# the normal seed burst.
	var acc_cell := _first_empty_cell(board_scene, [])
	ok(acc_cell.x >= 0, "the accumulator focus test found an empty cell")
	if acc_cell.x >= 0:
		board_scene.board.place_gen("acc_water", acc_cell)
		board_scene._rebuild_all()
		var acc_at: Vector2 = board_scene._cell_pos(acc_cell) + Vector2(board_scene.csz, board_scene.csz) / 2.0
		_tap_emulated(board_scene, acc_at)
		await create_timer(0.05).timeout
		ok(board_scene._selected_cell == acc_cell, "tapping an accumulator generator focuses its cell")
		ok(board_scene._info_label.text.contains("Rain barrel"), "focused accumulator shows its real name")
		var acc_desc: Label = board_scene.get("_info_desc_label") as Label
		ok(acc_desc != null and acc_desc.visible and acc_desc.text.contains("water"), "focused accumulator shows useful info text")
		ok(board_scene._info_btn.disabled, "accumulators disable the producing-ladder button because they bank currency")
		board_scene._clear_selection()

		board_scene.board.gens.erase(acc_cell)
		board_scene.board.place_gen("acc_coins", acc_cell)
		Save.grove()["bonus_clicks"] = 3
		var bonus_drop_cell := _first_empty_cell(board_scene, [acc_cell])
		if bonus_drop_cell.x < 0:
			for i in board_scene.board.items.size():
				var c := BoardModel.cell_of(i)
				if c != acc_cell and board_scene.board.is_open(c) and not board_scene.board.is_gen(c):
					board_scene.board.take(c)
					bonus_drop_cell = c
					break
		ok(bonus_drop_cell.x >= 0, "the bonus generator item-pop test found room for a board item")
		board_scene._rebuild_all()
		var coins0 := Save.coins()
		var coin_items0 := 0
		for v in board_scene.board.items:
			if G.is_coin(v):
				coin_items0 += 1
		_tap_emulated(board_scene, acc_at)
		await create_timer(0.05).timeout
		var coin_items1 := 0
		for v in board_scene.board.items:
			if G.is_coin(v):
				coin_items1 += 1
		ok(Save.coins() == coins0, "tapping a bonus coin generator does not pay the coin pill directly")
		ok(coin_items1 > coin_items0, "tapping a bonus coin generator pops coin items onto the board")
		ok(int(Save.grove().get("bonus_clicks", 0)) == 2, "tapping a bonus generator spends one of its own taps")
		board_scene._clear_selection()

	var treat_cell := acc_cell if acc_cell.x >= 0 else _first_empty_cell(board_scene, [])
	var treat_id := G.treat_gen_id(71)
	ok(treat_cell.x >= 0, "the treat generator focus test found an empty cell")
	if treat_cell.x >= 0:
		board_scene.board.gens.erase(treat_cell)
		board_scene.board.place_gen(treat_id, treat_cell)
		Save.grove()["treat_clicks"] = 2
		board_scene._rebuild_all()
		var treat_entries: Array = board_scene._gen_line_entries(treat_id)
		ok(treat_entries.size() == 1 and int(treat_entries[0].line) == 71, "a treat generator reports only its treasure line")
		var treat_at: Vector2 = board_scene._cell_pos(treat_cell) + Vector2(board_scene.csz, board_scene.csz) / 2.0
		_tap_emulated(board_scene, treat_at)
		await create_timer(0.05).timeout
		ok(board_scene._selected_cell == treat_cell, "tapping a live treat generator focuses its cell")
		ok(board_scene._info_label.text.contains("Prize pumpkin"), "focused treat generator names its treasure")
		var treat_desc: Label = board_scene.get("_info_desc_label") as Label
		ok(treat_desc != null and treat_desc.visible and treat_desc.text.contains("Prize pumpkin"), "focused treat generator explains its output")
		ok(board_scene._info_btn.disabled == live_hides_info, "treat generators apply the configured info button visibility")
		board_scene._on_info_pressed()
		await process_frame
		ok(board_scene.get_node_or_null("GenLinesOverlay") != null, "the treat generator info button opens its producing overlay")
		var tov: Node = board_scene.get_node_or_null("GenLinesOverlay")
		if tov != null:
			tov.queue_free()
		board_scene._clear_selection()

	# Workbench parity: when the saved info-bar config hides the info button, the live board hides the
	# actual tappable icon too, even after an item is selected into the bar.
	var hidden_cfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH).duplicate(true)
	var hidden_info: Dictionary = (hidden_cfg.get("info_bar", {}) as Dictionary).duplicate(true)
	hidden_info["hide_info_button"] = true
	hidden_cfg["info_bar"] = hidden_info
	Kit._config_cache[Kit.CONFIG_PATH] = hidden_cfg
	var hidden_board = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(hidden_board)
	await process_frame
	if hidden_board.board == null:
		hidden_board._ready()
	await create_timer(0.05).timeout
	ok(hidden_board._info_btn != null and hidden_board._info_btn.visible and not hidden_board._info_btn.disabled, \
		"the empty info bar keeps the tutorial info button visible even when selected-item info is hidden")
	var hidden_cell := Vector2i(-1, -1)
	for c in hidden_board.board.empty_ground_cells():
		if not hidden_board.board.is_gen(c):
			hidden_cell = c
			break
	if hidden_cell.x >= 0:
		hidden_board.board.place(hidden_cell, 1201)
		hidden_board._rebuild_pieces()
		hidden_board._select_item(hidden_cell)
		ok(not hidden_board._info_btn.visible, \
			"selecting an item keeps the hidden info button out of the live info bar")
		var hidden_icon_slot := hidden_board.get("_info_icon") as Control
		ok(hidden_icon_slot != null and hidden_icon_slot.visible, \
			"selecting an item keeps the selected item icon visible when the info button is hidden")
		if hidden_icon_slot != null:
			_push_tap(hidden_icon_slot.get_global_rect().get_center())
			await process_frame
			ok(hidden_board.get_node_or_null("LadderOverlay") != null, \
				"tapping the selected item icon opens the item info dialog when the info button is hidden")
			var hidden_ladder: Node = hidden_board.get_node_or_null("LadderOverlay")
			if hidden_ladder != null:
				hidden_ladder.queue_free()
				await process_frame
	hidden_board.queue_free()
	hidden_board = null
	Kit.clear_config_cache(Kit.CONFIG_PATH)

	# Watchdog: a stuck `animating` gate must self-heal so board taps can never soft-lock. Force the
	# gate true and confirm it clears within the watchdog window; a brief gate (a normal merge) must NOT.
	board_scene.animating = true
	board_scene._anim_t = 0.0
	await create_timer(0.25).timeout
	ok(board_scene.animating, "a brief animating gate (a normal merge) is NOT force-cleared early")
	await create_timer(0.6).timeout
	ok(not board_scene.animating, "a STUCK animating gate self-heals (watchdog re-enables board input)")

	# Lost-release guard: on mobile, a press can begin on the board but the release can be delivered
	# through scene-level input when another surface wins the GUI hit. That must still settle the board
	# gesture; otherwise `_pressing` stays true and every future board press is ignored.
	fresh("lost_release")
	var lost_board = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(lost_board)
	if lost_board.board == null:
		lost_board._ready()
	await process_frame
	var release_cell := Vector2i(-1, -1)
	for x in range(G.ROWS):
		for y in range(G.COLS):
			var c := Vector2i(x, y)
			if lost_board.board.is_open(c) and not lost_board.board.is_gen(c):
				lost_board.board.take(c)
				release_cell = c
				break
		if release_cell.x >= 0:
			break
	ok(release_cell.x >= 0, "lost-release test found an open non-generator cell")
	if release_cell.x >= 0:
		lost_board.board.place(release_cell, 101)
		lost_board._rebuild_pieces()
		var lat: Vector2 = lost_board._cell_pos(release_cell) + Vector2(lost_board.csz, lost_board.csz) / 2.0
		_press_emulated(lost_board, lat)
		ok(lost_board._pressing and lost_board._drag_node != null, "lost-release setup starts an in-flight board press")
		var lost_up := InputEventMouseButton.new()
		lost_up.button_index = MOUSE_BUTTON_LEFT
		lost_up.pressed = false
		lost_up.position = Vector2(5, 5)
		lost_up.global_position = lost_up.position
		lost_board._input(lost_up)
		ok(not lost_board._pressing and lost_board._drag_node == null, \
			"scene-level release settles the board gesture so future taps remain responsive")
		_tap_emulated(lost_board, lat)
		ok(lost_board._selected_cell == release_cell, "a board tap after the recovered release still focuses the tile")
	lost_board.queue_free()

	# Bundle A (tactile) board drag: the merge-target TELEGRAPH and the held-tile LEAN.
	_test_drag_feel()

	# PER-LINE PRODUCTION (gen redesign #4): a generator pops ONLY its own line through the real _pop_seed
	# tap path, even when several active quests want OTHER lines. roll_spawn leans ~ASK_WEIGHT toward the
	# quest-wanted set, so feeding it the un-narrowed `wanted` makes a line-1 generator also spew the other
	# quests' lines (the "both generators produce both lines" bug). Tap the anchor with two lines wanted and
	# assert nothing foreign ever lands. (The sibling _gen_line_entries highlight is asserted above.)
	fresh("per_line_pop")
	var spl = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(spl)
	if spl.board == null:
		spl._ready()
	await process_frame
	spl.rng.seed = 424242                               # deterministic spawn stream
	Save.grove()["pops"] = 99                           # past the FTUE free pops → charged bursts
	spl.water = 9_999_999
	spl.quests = [
		{"line": 1, "tier": 4, "reward": {"exp": 1, "coins": 0}},
		{"line": 2, "tier": 4, "reward": {"exp": 1, "coins": 0}},
	]
	spl.giver_chips = [{"chip": null, "qi": 0}, {"chip": null, "qi": 1}]
	var _gq: Array = spl._pop_pool_ctx()["giver_quests"]
	var _wl := {}
	for _q in _gq:
		_wl[int(_q.line)] = true
	ok(_wl.size() >= 2, "per-line: test setup — active quests want more than one line")
	var pl_cell: Vector2i = spl.board.gens.keys()[0]
	ok(int(G.gen_def(G.GENERATORS, spl.board.gen_id_at(pl_cell)).get("line", 0)) == 1, "per-line: the anchor generator is line 1")
	var pl_own := 0
	var pl_foreign := 0
	for _i in 30:
		for ci in spl.board.items.size():              # clear non-gen items so each tap pops onto open ground
			if spl.board.items[ci] > 0 and not spl.board.gens.has(BoardModel.cell_of(ci)):
				spl.board.items[ci] = 0
		spl._pop_seed(pl_cell)
		for v in spl.board.items:
			if v > 0:
				var ln := BoardModel.line_of(v)
				if ln == 1:
					pl_own += 1
				elif ln != 0:
					pl_foreign += 1
	ok(pl_own > 0, "per-line: the line-1 generator pops its own line")
	ok(pl_foreign == 0, "per-line: a line-1 generator never pops another quest's line (got %d foreign)" % pl_foreign)
	spl.queue_free()

	# §6 TREAT and SPECIAL-ITEM/bonus generators pop a SPREAD of tiers like a normal generator (no longer a
	# fixed tier), each tier rolled off the generator curve and CLAMPED to the item's merge ceiling. Drive the
	# REAL board pops on a seeded stream and sample the popped tiers, clearing each pop so the board never fills.
	fresh("special_gen_tier_spread")
	var sgt_scene = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(sgt_scene)
	if sgt_scene.board == null:
		sgt_scene._ready()
	sgt_scene.rng.seed = 4242                               # deterministic pop stream
	# water bonus generator: was a fixed t1 — now a clamped spread (water tops out at SPECIAL_TOP).
	var sgt_wgen := _first_empty_cell(sgt_scene, [])
	ok(sgt_wgen.x >= 0, "tier-spread: found a free cell for the water bonus generator")
	sgt_scene.board.place_gen("acc_water", sgt_wgen)
	sgt_scene._rebuild_all()
	var sgt_water_line := -1
	for sgt_swl in G.SPECIAL_ITEMS:
		if String((G.SPECIAL_ITEMS[sgt_swl] as Dictionary).get("kind", "")) == "water":
			sgt_water_line = int(sgt_swl)
			break
	var sgt_water_top := G.merge_top(sgt_water_line * 100 + 1)
	Save.grove()["bonus_clicks"] = 30
	var sgt_wtiers := {}
	var sgt_over := false
	for sgt_wtap in 30:
		if int(Save.grove().get("bonus_clicks", 0)) <= 0:
			break
		sgt_scene._collect_accumulator(sgt_wgen)
		for sgt_wi in sgt_scene.board.items.size():
			var sgt_wv: int = sgt_scene.board.items[sgt_wi]
			if sgt_wv <= 0:
				continue
			var sgt_wcell := BoardModel.cell_of(sgt_wi)
			if sgt_scene.board.is_gen(sgt_wcell):
				continue
			if BoardModel.line_of(sgt_wv) == sgt_water_line:
				var sgt_wtier := BoardModel.tier_of(sgt_wv)
				sgt_wtiers[sgt_wtier] = true
				if sgt_wtier > sgt_water_top:
					sgt_over = true
			sgt_scene.board.take(sgt_wcell)                # clear every loose item so the next tap has room
	ok(sgt_wtiers.size() >= 2, "a special-item (water) bonus generator pops a SPREAD of tiers, not one fixed tier")
	ok(not sgt_over, "the special-item pop never exceeds the item's merge ceiling (water tops at SPECIAL_TOP)")
	# treat generator: was a fixed TREAT_POP_TIER (2) — now the full normal spread (can roll BELOW 2).
	var sgt_tgen := _first_empty_cell(sgt_scene, [])
	ok(sgt_tgen.x >= 0, "tier-spread: found a free cell for the treat generator")
	var sgt_tline := int(G.TREAT_LINES[0])
	sgt_scene.board.place_gen(G.treat_gen_id(sgt_tline), sgt_tgen)
	sgt_scene._rebuild_all()
	Save.grove()["treat_clicks"] = 30
	var sgt_ttiers := {}
	for sgt_ttap in 30:
		if int(Save.grove().get("treat_clicks", 0)) <= 0:
			break
		sgt_scene._pop_treat(sgt_tgen)
		for sgt_ti in sgt_scene.board.items.size():
			var sgt_tv: int = sgt_scene.board.items[sgt_ti]
			if sgt_tv <= 0:
				continue
			var sgt_tcell := BoardModel.cell_of(sgt_ti)
			if sgt_scene.board.is_gen(sgt_tcell):
				continue
			if BoardModel.line_of(sgt_tv) == sgt_tline:
				sgt_ttiers[BoardModel.tier_of(sgt_tv)] = true
			sgt_scene.board.take(sgt_tcell)                # clear loose pops (treats + the special shower)
	ok(sgt_ttiers.size() >= 2, "a treat generator pops a SPREAD of tiers, not a fixed tier")
	ok(sgt_ttiers.has(1), "treat pops can roll BELOW the old fixed head-start tier (full normal spread)")
	sgt_scene.queue_free()

	board_scene.queue_free()
	board_scene = null
	content = null
	await process_frame
	await process_frame
	finish()

# Bundle A board-drag feel — the merge-target telegraph (glow + breathe + magnet) and the held-tile lean.
# Drives the real _on_board_input path: press a piece, motion the held tile over a mergeable neighbour
# (telegraph lights), motion onto a non-mergeable cell (telegraph clears), and release (all feel torn down,
# no stuck glow/rotation).
func _test_drag_feel() -> void:
	fresh("drag_feel")
	var b = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(b)
	if b.board == null:
		b._ready()
	# Gather three OPEN, non-generator cells (clearing any item on them), then plant a known MERGEABLE
	# PAIR (two tier-1 starters) and a third non-mergeable item — so a drag from the pair can light then
	# clear the telegraph. (A virgin board is mostly sealed brambles, so empty_ground_cells alone is thin.)
	var empties: Array = []
	for x in range(G.ROWS):
		for y in range(G.COLS):
			var c := Vector2i(x, y)
			if b.board.is_open(c) and not b.board.is_gen(c):
				b.board.take(c)   # clear any seeded item so place() lands cleanly
				empties.append(c)
				if empties.size() >= 3:
					break
		if empties.size() >= 3:
			break
	ok(empties.size() >= 3, "drag-feel test found three open board cells for the pair + a foil")
	if empties.size() < 3:
		b.queue_free()
		return
	var pair_code := 101                       # a tier-1 starter line (tier_of < merge_top → mergeable)
	var foil_code := 201                       # a DIFFERENT line → never merges with the held tile
	var from_cell: Vector2i = empties[0]
	var target_cell: Vector2i = empties[1]
	var foil_cell: Vector2i = empties[2]
	b.board.place(from_cell, pair_code)
	b.board.place(target_cell, pair_code)
	b.board.place(foil_cell, foil_code)
	b._rebuild_pieces()
	ok(b.board.can_merge(from_cell, target_cell), "the planted pair is a valid merge (telegraph precondition)")
	ok(not b.board.can_merge(from_cell, foil_cell), "the foil cell is NOT a valid merge (telegraph must clear over it)")

	var h := Vector2(b.csz, b.csz) / 2.0
	var target_node: Control = b.piece_nodes.get(target_cell)
	var held_node: Control = b.piece_nodes.get(from_cell)
	ok(target_node != null and held_node != null, "the pair rendered piece nodes to telegraph + lean")

	# press the held tile, then motion-follow it over the mergeable TARGET → the telegraph lights.
	_press_emulated(b, b._cell_pos(from_cell) + h)
	ok(b._drag_node == held_node, "pressing the pair tile picks it up for the drag")
	_motion(b, b._cell_pos(target_cell) + h)
	ok(b._telegraph_cell == target_cell, "hovering a mergeable target sets the telegraph cell")
	ok(target_node.modulate.is_equal_approx(FX.Tune.TELEGRAPH_GLOW), "the telegraphed target glows (modulate == TELEGRAPH_GLOW)")
	ok(target_node.has_meta("_fx_breathing"), "the telegraphed target runs a breathe pulse")

	# motion onto the NON-mergeable foil → the telegraph clears (glow + breathe + magnet undone).
	_motion(b, b._cell_pos(foil_cell) + h)
	ok(b._telegraph_cell == Vector2i(-1, -1), "moving onto a non-mergeable cell clears the telegraph cell")
	ok(target_node.modulate.is_equal_approx(Color(1, 1, 1, 1.0)), "the old target's glow is restored on hover-exit")
	ok(target_node.position.is_equal_approx(b._cell_pos(target_cell)), "the old target's magnet offset is undone on hover-exit")

	# horizontal motion tilts the HELD tile (lean), clamped to ±DRAG_LEAN_DEG.
	_motion(b, b._cell_pos(from_cell) + h + Vector2(40, 0))
	_motion(b, b._cell_pos(from_cell) + h + Vector2(120, 0))
	ok(absf(held_node.rotation) > 0.0001, "horizontal drag motion leans the held tile")
	ok(absf(held_node.rotation) <= deg_to_rad(FX.Tune.DRAG_LEAN_DEG) + 0.0001, "the held-tile lean is clamped to DRAG_LEAN_DEG")

	# release on empty ground (a move) → ALL drag feel tears down: telegraph clear, held rotation 0.
	_release_emulated(b, b._cell_pos(foil_cell) + h)   # foil is occupied; release where it began → snap-back
	ok(b._telegraph_cell == Vector2i(-1, -1), "dropping leaves no telegraphed target")
	ok(absf(held_node.rotation) < 0.0001, "dropping resets the held tile's lean to upright")
	ok(target_node.modulate.is_equal_approx(Color(1, 1, 1, 1.0)), "no glow leaks onto the target after the drop")

	b.queue_free()

# --- drag-gesture drivers (emulate_touch_from_mouse: mouse + synth touch per event) ----
func _press_emulated(board, at: Vector2) -> void:
	var md := InputEventMouseButton.new(); md.button_index = MOUSE_BUTTON_LEFT; md.pressed = true; md.position = at
	var td := InputEventScreenTouch.new(); td.pressed = true; td.position = at
	board._on_board_input(md)
	board._on_board_input(td)

func _release_emulated(board, at: Vector2) -> void:
	var mu := InputEventMouseButton.new(); mu.button_index = MOUSE_BUTTON_LEFT; mu.pressed = false; mu.position = at
	var tu := InputEventScreenTouch.new(); tu.pressed = false; tu.position = at
	board._on_board_input(mu)
	board._on_board_input(tu)

func _motion(board, at: Vector2) -> void:
	var mm := InputEventMouseMotion.new(); mm.position = at
	board._on_board_input(mm)

# A real still-tap routed through the viewport's GUI hit-testing (honours mouse_filter, z-order,
# overlays) at a GLOBAL screen point — the closest headless analog to a live finger tap.
func _push_tap(gpos: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = gpos
	down.global_position = gpos
	get_root().push_input(down, true)
	var up := down.duplicate()
	up.pressed = false
	get_root().push_input(up, true)

# A physical tap under emulate_touch_from_mouse=true: the engine delivers BOTH a mouse-button event AND a
# synthesized screen-touch event, so the board input handler sees the press/release TWICE per tap. Drives
# _on_board_input directly with board_area-local positions (its gui_input space).
func _tap_emulated(board, at: Vector2) -> void:
	var md := InputEventMouseButton.new(); md.button_index = MOUSE_BUTTON_LEFT; md.pressed = true; md.position = at
	var td := InputEventScreenTouch.new(); td.pressed = true; td.position = at
	board._on_board_input(md)
	board._on_board_input(td)
	var mu := InputEventMouseButton.new(); mu.button_index = MOUSE_BUTTON_LEFT; mu.pressed = false; mu.position = at
	var tu := InputEventScreenTouch.new(); tu.pressed = false; tu.position = at
	board._on_board_input(mu)
	board._on_board_input(tu)

func _first_empty_cell(board, skip: Array) -> Vector2i:
	for c in board.board.empty_ground_cells():
		if not board.board.is_gen(c) and not skip.has(c):
			return c
	return Vector2i(-1, -1)

func _has_texture_suffix(root: Node, suffix: String) -> bool:
	if root == null:
		return false
	if root.has_meta("gen_tex_path") and String(root.get_meta("gen_tex_path")).ends_with(suffix):
		return true
	if root is TextureRect and root.texture != null:
		var path := String(root.texture.resource_path)
		if path.ends_with(suffix):
			return true
	for child in root.get_children():
		if _has_texture_suffix(child, suffix):
			return true
	return false
