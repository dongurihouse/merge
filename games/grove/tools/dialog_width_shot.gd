extends SceneTree
## Visual + numeric check for the GLOBAL dialog width. Builds every dialog through the SAME Kit
## builders the game uses, at the live config (frame.width_pct), captures a PNG of each, and prints
## the rendered card width — which should be ~75% of 1080 = 810px for ALL of them, with content
## scaled from each dialog's design baseline. Real renderer; run via the quiet wrapper:
##   engine/tools/quiet_godot.sh --path . -s res://games/grove/tools/dialog_width_shot.gd -- <outdir>

const Kit = preload("res://games/grove/tools/ui_workbench_kit.gd")
const Login = preload("res://engine/scripts/core/login.gd")
const LoginMystery = preload("res://engine/scripts/ui/login_mystery.gd")
const PHONE_W := 1080.0
const PHONE_H := 1920.0

func _w(id: String) -> float:
	return PHONE_W * float(Kit.DIALOG_DESIGN_PCT.get(id, 75.0)) / 100.0

func _find_card(n: Node) -> Control:
	if n is PanelContainer:
		return n
	for c in n.get_children():
		var r := _find_card(c)
		if r != null:
			return r
	return null

func _bag_entries() -> Array:
	var icons := ["leaf", "gift", "daisy", "water", "star"]
	var out: Array = []
	for k in range(1, 13):
		if k <= 5:
			out.append({"kind": "filled", "icon": icons[(k - 1) % icons.size()]})
		elif k <= 8:
			out.append({"kind": "empty"})
		elif k == 9:
			out.append({"kind": "next", "cost": 15})
		else:
			out.append({"kind": "locked", "cost": 20})
	return out

func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: real-renderer tool must run via engine/tools/quiet_godot.sh")
		quit(2)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var args := OS.get_cmdline_user_args()
	var outdir: String = String(args[0]) if args.size() >= 1 else "/tmp/dlgwidth"
	DirAccess.make_dir_recursive_absolute(outdir)
	await create_timer(0.2).timeout
	DisplayServer.window_set_size(Vector2i(int(PHONE_W), int(PHONE_H)))
	await create_timer(0.2).timeout

	var cfg: Dictionary = Kit.load_config(Kit.CONFIG_PATH)
	var target := PHONE_W * Kit.frame_width_pct(cfg) / 100.0
	print("frame.width_pct=%.0f  target≈%.0fpx (of %d)" % [Kit.frame_width_pct(cfg), target, int(PHONE_W)])

	var bg := ColorRect.new()
	bg.color = Color("#3a5a40")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var holder := CenterContainer.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(holder)

	var specs: Array = [
		{"id": "dialog", "build": func() -> Control:
			var o := Kit.dialog_opts_from_config(cfg); o["banner_text"] = "Mail"; o["entries_count"] = 4
			o["content_scale"] = Kit.dialog_content_scale(cfg, "dialog")
			return Kit.mail_dialog(Kit.DEMO_MAIL, _w("dialog"), o)},
		{"id": "daily", "build": func() -> Control:
			var o := Kit.daily_opts_from_config(cfg); o["banner_text"] = "Daily"
			o["content_scale"] = Kit.dialog_content_scale(cfg, "daily")
			return Kit.daily_dialog(Kit.DEMO_DAILY, _w("daily"), o)},
		{"id": "shop", "build": func() -> Control:
			var o := Kit.shop_opts_from_config(cfg); o["banner_text"] = "Shop"
			o["content_scale"] = Kit.dialog_content_scale(cfg, "shop")
			return Kit.shop_dialog(Kit.demo_shop(), _w("shop"), o)},
		{"id": "settings", "build": func() -> Control:
			var o := Kit.settings_opts_from_config(cfg); o["banner_text"] = "Settings"
			o["content_scale"] = Kit.dialog_content_scale(cfg, "settings")
			return Kit.settings_dialog(Kit.DEMO_SETTINGS, _w("settings"), o)},
		{"id": "vault", "build": func() -> Control:
			var o := Kit.vault_opts_from_config(cfg); o["banner_text"] = "Vault"
			o["content_scale"] = Kit.dialog_content_scale(cfg, "vault")
			return Kit.vault_dialog(Kit.DEMO_VAULT, _w("vault"), o)},
		{"id": "tiers", "build": func() -> Control:
			var o := Kit.tiers_opts_from_config(cfg); o["banner_text"] = "Wildflower"
			o["content_scale"] = Kit.dialog_content_scale(cfg, "tiers")
			return Kit.tiers_dialog(Kit.DEMO_TIERS, _w("tiers"), o)},
		{"id": "info", "build": func() -> Control:
			var o := Kit.info_opts_from_config(cfg); o["banner_text"] = "Welcome gift"
			o["banner_icon_on"] = false; o["got_it"] = "Got it"
			o["content_scale"] = Kit.dialog_content_scale(cfg, "info")
			var demo := [
				{"icon": "gem", "title": "Acorns", "body": "premium currency for shortcuts", "chip": {"icon": "gem", "text": "400"}},
				{"icon": "water", "title": "Water", "body": "tops up your watering can", "chip": {"icon": "water", "text": "60"}}]
			return Kit.mail_dialog(demo, _w("info"), o)},
		{"id": "level", "build": func() -> Control:
			var o := Kit.level_opts_from_config(cfg); o["banner_text"] = "Level 1"
			o["content_scale"] = Kit.dialog_content_scale(cfg, "level")
			var data := {"level": 1, "earned": 2, "next": 6, "into": 2, "span": 6, "remaining": 4, "mode": "info", "gift": {}}
			return Kit.level_dialog(data, _w("level"), o)},
		{"id": "bag", "build": func() -> Control:
			var o := Kit.bag_opts_from_config(cfg); o["banner_text"] = "Bag"
			o["banner_min_w"] = PHONE_W * Kit.BANNER_MIN_W_FRAC
			o["content_scale"] = Kit.dialog_content_scale(cfg, "bag")
			return Kit.bag_dialog(_bag_entries(), 320, _w("bag"), o)},
		{"id": "mystery", "build": func() -> Control:
			var mc: Dictionary = Login.mystery_config(7)
			var pool: Array = mc.get("pool", [])
			var show: int = mini(int(mc.get("show", 0)), pool.size())
			var win: int = mini(int(mc.get("win", 0)), show)
			var options: Array = []
			for i in show:
				options.append(pool[i])
			var built: Dictionary = LoginMystery.build_reveal(options, range(win), LoginMystery.reveal_width(PHONE_W), {"frame_cfg": cfg, "viewport_w": PHONE_W})
			return built["dialog"]},
	]

	for spec in specs:
		var id: String = spec["id"]
		var dlg: Control = (spec["build"] as Callable).call()
		holder.add_child(dlg)
		for i in 10:
			await process_frame
		RenderingServer.force_draw()
		await create_timer(0.12).timeout
		RenderingServer.force_draw()
		var card := _find_card(dlg)
		var cw := (card.size.x if card != null else -1.0)
		var img := root.get_texture().get_image()
		var path := "%s/%s.png" % [outdir, id]
		img.save_png(path)
		print("  %-9s card_w=%4.0f  scale=%.3f  -> %s" % [id, cw, Kit.dialog_content_scale(cfg, id), path])
		dlg.queue_free()
		await process_frame

	print("DONE")
	quit()
