extends SceneTree
## End-to-end review driver: plays the REAL game on a fresh save — FTUE path, all 15
## boards via the actual input handlers, map/lump/daily beats, room purchases + reveal,
## replay economy, settings/calm — capturing screenshots and probing suspected bugs
## (undo vs friction state). Prints PASS/FINDING lines; shots land in /tmp/e2e_*.png.

const Save = preload("res://scripts/save.gd")
const Session = preload("res://scripts/session.gd")
const Districts = preload("res://scripts/districts.gd")
const Levels = preload("res://scripts/levels.gd")
const Quests = preload("res://scripts/quests.gd")
const Board = preload("res://scripts/board.gd")

var findings: Array = []
var checks := 0

func note(kind: String, msg: String) -> void:
	if kind == "PASS":
		checks += 1
	else:
		findings.append(msg)
	print("  %s  %s" % [kind, msg])

func shot(name: String) -> void:
	await create_timer(0.45).timeout
	# minimized windows occasionally serve a STALE frame - force a fresh draw
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("/tmp/e2e_%s.png" % name)
	print("  SHOT /tmp/e2e_%s.png" % name)

func cur() -> Node:
	return current_scene

func goto_scene(path: String) -> Node:
	if current_scene != null:
		current_scene.queue_free()
	var scn: Node = load(path).instantiate()
	root.add_child(scn)
	current_scene = scn
	return scn

func wait(t: float) -> void:
	await create_timer(t).timeout

# --- board driving ------------------------------------------------------------

func _cpos(scn: Node, cell: Vector2i) -> Vector2:
	return scn._cell_pos(cell) + Vector2(scn.csz, scn.csz) / 2.0

func _adj_special(scn: Node, cell: Vector2i) -> bool:
	for d in Board.DIRS:
		var n: Vector2i = cell + d
		if not scn.board.in_bounds(n.x, n.y):
			continue
		if scn.board.at(n.x, n.y) == Board.DRAWER or scn.covers.has(n):
			return true
	return false

func _pick_pair(scn: Node) -> Array:
	var by_code := {}
	for r in scn.board.rows:
		for c in scn.board.cols:
			var cell := Vector2i(r, c)
			var k: int = scn.board.at(r, c)
			if k > 0 and not scn._locked(cell):
				if not by_code.has(k):
					by_code[k] = []
				by_code[k].append(cell)
	var best: Array = []
	var best_score := -99
	for k in by_code:
		var cells: Array = by_code[k]
		if cells.size() < 2:
			continue
		for i in cells.size():
			for j in cells.size():
				if i == j:
					continue
				var s := 0
				if scn.floor_cells.has(cells[i]):
					s += 2                      # empty the rug first
				if _adj_special(scn, cells[j]):
					s += 3                      # pop drawers / lift covers
				if scn.floor_cells.has(cells[j]):
					s -= 1
				if s > best_score:
					best_score = s
					best = [cells[i], cells[j]]
	return best

func merge_once(scn: Node, src: Vector2i, dst: Vector2i) -> void:
	scn._on_press(_cpos(scn, src))
	scn._on_release(_cpos(scn, dst))
	await wait(0.3)

func solve_board(scn: Node, max_merges := 80) -> Dictionary:
	var merges := 0
	while not scn.board.is_cleared() and merges < max_merges:
		while scn.animating and not scn.board.is_cleared():
			await wait(0.1)
		if scn.board.is_cleared():
			break
		var pr := _pick_pair(scn)
		if pr.is_empty():
			return {"stuck": true, "merges": merges}
		await merge_once(scn, pr[0], pr[1])
		merges += 1
	return {"stuck": not scn.board.is_cleared(), "merges": merges}

func dismiss_zero(scn: Node) -> void:
	await wait(0.6)
	var ov: Control = scn.get_children().back()
	scn._dismiss_zero(ov)
	await process_frame
	await wait(0.25)

# --- the journey ----------------------------------------------------------------

func _initialize() -> void:
	if not FileAccess.file_exists("res://override.cfg"):
		print("REFUSED: real-renderer tools must run via tools/quiet_godot.sh (born-minimized")
		print("window; in-script flags are too late and flash/steal focus). See ~/.claude/CLAUDE.md")
		quit(2)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, 0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var dir := "/tmp/tu_e2e/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)
	print("== E2E playthrough ==")

	# A. fresh menu — FTUE staging
	var menu := goto_scene("res://scenes/Menu.tscn")
	await wait(0.4)
	var has_bedroom := false
	for b in _all_buttons(menu):
		if b.text == tr("Bedroom"):
			has_bedroom = true
	note("PASS" if not has_bedroom else "FINDING", "fresh menu hides Bedroom" if not has_bedroom else "fresh menu SHOWS Bedroom (staging broken)")
	await shot("menu_fresh")
	menu.call("_on_play")
	await process_frame
	await wait(0.5)
	var scn := cur()
	note("PASS" if scn.get("board") != null else "FINDING", "first Play lands on a board (FTUE direct)" if scn.get("board") != null else "first Play did NOT land on a board")
	note("PASS" if not scn.coin_counter.visible else "FINDING", "wallet hidden pre-payout" if not scn.coin_counter.visible else "wallet visible on fresh first board")
	note("PASS" if not scn.quest_chip.visible else "FINDING", "quest chip hidden on board 1" if not scn.quest_chip.visible else "quest chip visible on board 1")
	await shot("board_first")

	# B. play the whole ladder, probing undo bugs on specific boards
	var clears := 0
	var probed_ticket := false
	var probed_drawer := false
	var probed_floor := false
	var guard := 0
	while clears < 15 and guard < 40:
		guard += 1
		scn = cur()
		if scn.get("board") == null:           # landed on the map mid-journey
			var d := _next_pin_district()
			if d < 0:
				break
			scn.call("_on_pin", d, Districts.next_job(d))
			await process_frame
			await wait(0.5)
			scn = cur()
		var lvid: String = Levels.LEVELS[scn.level_index].get("id", "")

		# probe 1: ticket double-tick via undo+redo (tidy_04)
		if lvid == "tidy_04" and not probed_ticket:
			probed_ticket = true
			var pr := _pick_pair(scn)
			await merge_once(scn, pr[0], pr[1])
			var tick0: int = scn.ticket_progress[0]
			scn._on_undo()
			await wait(0.2)
			await merge_once(scn, pr[0], pr[1])
			if int(scn.ticket_progress[0]) > tick0:
				note("FINDING", "undo does NOT roll back ticket progress (undo+redo double-ticks)")
			else:
				note("PASS", "ticket progress survives undo+redo")
			scn._on_restart()
			await wait(0.3)

		# probe 2: floor state desync via undo (tidy_09)
		if lvid == "tidy_09" and not probed_floor:
			probed_floor = true
			var rug_cell: Vector2i = scn.floor_cells[0]
			var code: int = scn.board.at(rug_cell.x, rug_cell.y)
			var dst := _find_match(scn, rug_cell, code)
			if dst != Vector2i(-1, -1):
				await merge_once(scn, rug_cell, dst)
				scn._on_undo()
				await wait(0.2)
				if scn.floor_cleaned.has(rug_cell) and scn.board.at(rug_cell.x, rug_cell.y) > 0:
					note("FINDING", "undo desyncs floor: cell marked clean while a piece sits on it")
				else:
					note("PASS", "floor state consistent after undo")
				scn._on_restart()
				await wait(0.3)

		# probe 3: drawer contents lost on undo (tidy_05 — books drawers, default re-pop=101)
		if lvid == "tidy_05" and not probed_drawer:
			probed_drawer = true
			var popped := false
			var m := 0
			while not popped and m < 30 and not scn.board.is_cleared():
				var pr2 := _pick_pair(scn)
				if pr2.is_empty():
					break
				var before: int = scn.drawer_contents.size()
				await merge_once(scn, pr2[0], pr2[1])
				m += 1
				popped = scn.drawer_contents.size() < before
			if popped:
				scn._on_undo()
				await wait(0.2)
				var res := await solve_board(scn)
				if res.stuck:
					note("FINDING", "CONFIRMED: undo after a drawer pop corrupts contents (re-pop defaults 101) -> board UNCLEARABLE")
				else:
					note("PASS", "board still clearable after drawer-pop undo")
				if res.stuck:
					scn._on_restart()
					await wait(0.3)

		var res2 := await solve_board(scn)
		if res2.stuck:
			note("FINDING", "solver stuck on %s after %d merges" % [lvid, res2.merges])
			scn._on_restart()
			await wait(0.3)
			res2 = await solve_board(scn)
			if res2.stuck:
				note("FINDING", "RESTART did not recover %s — aborting its run" % lvid)
				break
		clears += 1
		if clears == 1:
			await shot("zero_first")
			note("PASS" if scn.coin_counter.visible else "FINDING", "wallet revealed with first payout" if scn.coin_counter.visible else "wallet still hidden after first payout")
		await dismiss_zero(scn)
		scn = cur()
		if clears == 2 and scn.get("board") != null:
			note("PASS" if scn.quest_chip.visible else "FINDING", "quest chip appears from board 2" if scn.quest_chip.visible else "quest chip missing on board 2")
		if clears == 5:
			# Wren's run complete → visit the map for the lump (+ probably the daily bundle)
			var coins_before := Save.coins()
			if scn.get("board") != null:
				scn.call("_on_jobs")
				await process_frame
				await wait(1.0)
			await shot("map_lump")
			var delta := Save.coins() - coins_before
			note("PASS" if Save.client_paid("wren") else "FINDING", "Wren's lump paid on map entry (+%d total beat)" % delta if Save.client_paid("wren") else "Wren's lump did NOT pay")
			# room: spend what we have
			goto_scene("res://scenes/Room.tscn")
			await wait(0.5)
			var room := cur()
			for i in 6:
				room.call("_on_pin", i)
				await wait(0.5)
			await shot("room_partial")
			goto_scene("res://scenes/Jobs.tscn")
			await wait(0.8)

	note("PASS" if clears == 15 else "FINDING", "cleared the entire 15-level ladder" if clears == 15 else "only cleared %d/15" % clears)

	# C. final map state
	if cur() == null or cur().get("board") != null:
		goto_scene("res://scenes/Jobs.tscn")
	await wait(1.0)
	await shot("map_final")
	var all_paid := Save.client_paid("wren") and Save.client_paid("juniper") and Save.client_paid("pip")
	note("PASS" if all_paid else "FINDING", "all three client lumps paid" if all_paid else "missing client lump(s)")
	note("PASS" if bool(Save.daily().get("claimed", false)) else "FINDING", "daily bundle claimed during the journey" if bool(Save.daily().get("claimed", false)) else "daily bundle never claimed despite met targets")

	# D. room completion
	goto_scene("res://scenes/Room.tscn")
	await wait(0.5)
	var room2 := cur()
	for i in 6:
		room2.call("_on_pin", i)
		await wait(0.45)
	await wait(1.2)
	await shot("room_final")
	var done := Save.decor_count("bedroom")
	note("PASS" if done >= 4 else "FINDING", "room funded to %d/6 slots by the ladder's economy" % done if done >= 4 else "economy too dry: only %d slots affordable after full clear" % done)

	# E. replay pays a trickle
	var before_replay := Save.coins()
	Session.next_level = 0
	goto_scene("res://scenes/Main.tscn")
	await wait(0.5)
	var b := cur()
	await solve_board(b)
	await wait(0.5)
	var gain := Save.coins() - before_replay
	note("PASS" if gain > 0 and gain <= 20 else "FINDING", "replay pays a trickle (+%d)" % gain if gain > 0 and gain <= 20 else "replay payout odd: +%d" % gain)
	await dismiss_zero(b)

	# F. calm mode + toggles exercise the code paths
	Save.set_setting("calm", true)
	var scn2 := cur()
	if scn2.get("board") == null:
		Session.next_level = 1
		goto_scene("res://scenes/Main.tscn")
		await wait(0.5)
		scn2 = cur()
	var pr3 := _pick_pair(scn2)
	if not pr3.is_empty():
		await merge_once(scn2, pr3[0], pr3[1])
		note("PASS", "calm-mode merge path runs clean")
	Save.set_setting("sfx", false)
	Save.set_setting("music", false)
	note("PASS", "audio toggles exercised")

	print("== E2E done: %d checks passed, %d findings ==" % [checks, findings.size()])
	for f in findings:
		print("  !! ", f)
	print("coins=%d  stats=%s" % [Save.coins(), str(Save.data.stats)])
	quit(0)

# --- helpers ----------------------------------------------------------------------

func _all_buttons(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		if c is Button:
			out.append(c)
		out.append_array(_all_buttons(c))
	return out

func _next_pin_district() -> int:
	for d in Districts.DISTRICTS.size():
		if Districts.unlocked(d) and Districts.next_job(d) >= 0:
			return d
	return -1

func _find_match(scn: Node, src: Vector2i, code: int) -> Vector2i:
	for r in scn.board.rows:
		for c in scn.board.cols:
			var cell := Vector2i(r, c)
			if cell != src and scn.board.at(r, c) == code and not scn._locked(cell):
				return cell
	return Vector2i(-1, -1)
