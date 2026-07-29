extends SceneTree
## Dev tool (real renderer; run via engine/tools/quiet_godot.sh): screenshot the Grove
## in a given state.   quiet_godot.sh --path . -s res://games/grove/tools/grove_shot.gd -- <mode> <out.png>
## modes (a sampler; the AUTHORITATIVE list is the `modes` cfg passed to Base.begin below, which
## also makes an unknown mode refuse the run):
##        fresh | played | gate | fullline | ladder | farewell | flyaway | almanac | bag | level | levelup | endgame |
##        sky_calm | sky_sunbeam | sky_rain | sky_starfall | sky_starfall_blocked |
##        producing (generator → ⓘ Producing dialog) | producingdrill (→ tap a line → its Tiers ladder) |
##        ftue (fresh ledger → the live merge-drag hand hint) | ftuegen (merge taught → the live
##        generator-tap hand hint) | ftuesoil (L6 Soil-seed hand hint; phase=place for beat 2)
##
## BYTE-DETERMINISTIC: same code + same MODE ⇒ identical PNG. The board RNG is pinned BEFORE the
## scene loads (board.gd's forced_rng_seed — _load_state randomizes on a fresh save, and the quest
## fence it then rolls decides every generator's + item line's dimming), the window size is forced
## (shot_base), and weather is pinned to "clear" unless `weather=` says otherwise.

const Base = preload("res://engine/tools/shot_base.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const G = preload("res://engine/scripts/core/content.gd")
const Claims = preload("res://engine/scripts/core/claims.gd")
const Improvements = preload("res://engine/scripts/core/improvements.gd")
const BoardScript = preload("res://engine/scripts/scenes/board.gd")
const BoardActions = preload("res://engine/scripts/core/board_actions.gd")
const Ambient = preload("res://engine/scripts/ui/ambient.gd")

const RNG_SEED := Base.RNG_SEED

## What the Starfall shot modes park in a lane cell to make it un-catchable — a plain base-line item, so
## the eye reads "this cell is taken", not "something special is happening here".
const LANE_BLOCKER := 101

## The flyaway fixture, named once so the seeding and the guard that checks it can never drift apart:
## the line that is swept and how many of its pieces are on the board when the sweep starts.
const FLYAWAY_LINE := 2
const FLYAWAY_PIECES := 6

func _initialize() -> void:
	var ctx := await Base.begin(self, {
		"tool": "grove",
		"default_mode": "fresh",
		"default_out": "/tmp/grove_%s.png",
		"save_dir": "/tmp/tu_groveshot_%s/",
		# Every mode this tool answers to — the `match` labels below plus the three handled outside
		# it ("fresh" has no branch at all; ftue/ftuegen/ftuesoil are seeded before the scene loads). Declaring
		# them makes an unknown MODE refuse instead of silently capturing the default board; keep this
		# list in step when adding or removing a branch.
		"modes": ["fresh", "ftue", "ftuegen", "ftuesoil",
			"played", "genfade", "gate", "genpreview", "hud", "endgame", "oowater", "unlock",
			"level", "levelup", "swap", "ladder", "farewell", "flyaway", "almanac", "recipe",
			"producingearly", "producing", "producingdrill", "infosel", "infobuy", "infoacorn", "focuscoin",
			"questready", "genburst", "genburstbroke", "genboost", "watershop", "bagwell", "bag",
			"bagbroke", "bagshop", "baggen", "dragwell", "dragwellfull", "grab", "grabgen",
			"cascade", "fullline", "mastery", "sky_calm", "sky_sunbeam", "sky_rain", "sky_starfall",
			"sky_starfall_blocked"],
		# Named for a compost-bin and a beehive generator the game no longer has; see the "fullline"
		# branch for the full story. Anyone reaching for them wants the ladder capture instead.
		"retired": {
			"compost": "the compost-bin generator is gone (maps 1–4 carry no spots) — use MODE=fullline [line=N]",
			"hive": "the beehive generator is gone (maps 1–4 carry no spots) — use MODE=fullline [line=N]",
		},
	})
	if ctx.is_empty():
		return                        # refused: begin() printed why and quit(2)
	var args: Array = ctx["args"]
	var mode: String = ctx["mode"]
	var out: String = ctx["out"]
	Save.mark_board_tutorial_seen()   # a capture shows the BOARD, never the How-to-Play overlay
	Save.mark_ftue_seen("merge")      # and never the FTUE hand-hint veil either — except ftue/ftuegen/
	Save.mark_ftue_seen("gen_tap")    # ftuesoil below, which explicitly re-seed the ledger to show it live
	if mode == "ftue":
		Save.data["ftue_seen"] = {}          # a brand-new player: the merge hand is live
	if mode == "ftuegen":
		Save.data["ftue_seen"] = {"merge": true}   # merge taught — the generator tap hand is live
	if mode == "ftuesoil":
		Save.data["ftue_seen"] = {"merge": true, "gen_tap": true}   # L6 grant: only Soil remains live
	if mode == "flyaway":
		Save.mark_ftue_seen("soil")
		Save.mark_ftue_seen("soil_seed")
	match mode:
		"sky_calm":
			Ambient.forced_weather = "calm"
		"sky_rain":
			Ambient.forced_weather = "rain"
		"sky_starfall", "sky_starfall_blocked":
			Ambient.forced_weather = "star"
		"sky_sunbeam":
			Ambient.forced_weather = "clear"

	# Seed the COIN CLOCK — the ONE level clock (G.level ← Save.coins_earned_lifetime) — BEFORE the scene
	# enters the tree. It has to be early for two reasons: the HUD's Lv chip is built ONCE with the level
	# it reads at build (board.gd stores hud.level and _update_hud only re-ticks the wallet), and _ready →
	# _load_state rolls the initial deal + quest fence off the same level. A post-load write leaves the
	# chip reading Level 1 over a level-1 board.
	# NEVER seed grove["exp"] / Save.add_exp for this: the clock moved off exp (save.gd SCHEMA v5), so
	# those feed no level at all and every "leveled" capture rendered at Level 1 at exit code 0.
	var clock_seed: int = int(_clock_seeds().get(mode, 0))
	if clock_seed > 0:
		if mode == "gate":
			Save.earn_coins(clock_seed)   # BOTH halves: earn_coins moves the clock AND the wallet
		else:
			var gcl := Save.grove()
			gcl["coins_earned"] = clock_seed
			Save.grove_write()

	# Pin the seed BEFORE the scene enters the tree: _ready → _load_state() rolls the quest fence off
	# this RNG, and on a fresh save it would otherwise randomize() — the fence composition drives
	# generator + item-line dimming, so an unpinned seed changed a quarter of the board's pixels.
	BoardScript.forced_rng_seed = RNG_SEED
	var scn = load("res://engine/scenes/Board.tscn").instantiate()
	root.add_child(scn)
	current_scene = scn
	await create_timer(0.5).timeout
	scn.rng.seed = RNG_SEED           # re-pin so each mode's own actions start from a fixed stream
	var custom_capture_done := false

	match mode:
		"ftuesoil":
			var soil_phase := String(Base.opt(args, "phase", "seed"))
			scn._maybe_soil_ftue()
			await create_timer(0.35).timeout
			if soil_phase == "place":
				var seed_cell: Vector2i = scn.board.first_item_of(Improvements.seed_code_for_kind(Improvements.KIND_SOIL))
				if seed_cell.x >= 0:
					scn._select_item(seed_cell)
					await create_timer(0.35).timeout
		"cascade":
			var phase := String(Base.opt(args, "phase", "run"))
			var hold_tier := int(String(Base.opt(args, "hold", "0")))
			for i in scn.board.items.size():
				scn.board.terrain[i] = 0
				scn.board.items[i] = 0
			scn.board.collect_rewards = {}
			scn.board.gens = {}
			scn.board.gen_boost = {}
			scn.quests = []
			var ready := {}
			if phase == "dragfocus":
				ready = {
					Vector2i(3, 1): 201,
					Vector2i(2, 1): 201,
					Vector2i(2, 2): 202,
					Vector2i(1, 1): 203,
					Vector2i(1, 2): 203,
					Vector2i(1, 3): 204,
					Vector2i(2, 3): 205,
				}
			elif phase == "seedguide":
				ready = {
					Vector2i(3, 1): 101,
					Vector2i(3, 4): 103,
					Vector2i(6, 6): 102,
				}
			elif phase == "tagtarget":
				ready = {
					Vector2i(3, 1): 101,
					Vector2i(3, 2): 102,
					Vector2i(3, 3): 103,
					Vector2i(3, 4): 104,
					Vector2i(6, 6): 101,
				}
			elif phase == "runway":
				ready = {
					Vector2i(3, 1): 102,
					Vector2i(3, 2): 103,
					Vector2i(3, 3): 104,
				}
				if hold_tier > 0:
					ready[Vector2i(6, 6)] = 100 + hold_tier
			else:
				ready = {
					Vector2i(3, 1): 101,
					Vector2i(3, 2): 101,
					Vector2i(3, 3): 102,
					Vector2i(3, 4): 103,
					Vector2i(3, 5): 104,
					Vector2i(6, 6): 101,
					# phase=guide drags (6,6) toward (5,2). This run needs THREE rungs, not two: the
					# guide only pads placements that would actually arm a cascade (CHAIN_MIN_N), so a
					# x2 ladder here renders a bare board at exit 0 and the mode silently shows nothing.
					Vector2i(5, 1): 101,
					Vector2i(5, 3): 102,
					Vector2i(5, 4): 103,
				}
			for cell in ready:
				scn.board.place(Vector2i(cell), int(ready[cell]))
			scn._rebuild_all()
			for n in scn.gen_nodes.values():
				if n != null and is_instance_valid(n):
					(n as Node).queue_free()
			# These run AFTER the loop, unconditionally: _rebuild_all() above re-seeds
			# generators, so the strip must happen even when gen_nodes is empty or holds
			# only freed nodes. Nested under the validity guard they silently no-op and
			# the capture keeps the generators this mode exists to remove.
			scn.gen_nodes.clear()
			scn.gen_node = null
			scn.board.gens = {}
			scn.board.gen_boost = {}
			await create_timer(0.25).timeout
			var chalf: Vector2 = Vector2(scn.csz, scn.csz) / 2.0
			if phase == "dragfocus":
				var held_focus := Vector2i(1, 1)
				var start_focus: Vector2 = scn._cell_pos(held_focus) + chalf
				var down_focus := InputEventMouseButton.new()
				down_focus.button_index = MOUSE_BUTTON_LEFT
				down_focus.pressed = true
				down_focus.position = start_focus
				scn._on_board_input(down_focus)
				var move_focus := InputEventMouseMotion.new()
				move_focus.position = scn._cell_pos(Vector2i(1, 2)) + chalf + Vector2(18.0, -24.0)
				scn._on_board_input(move_focus)
				await create_timer(0.35).timeout
			elif phase == "runway":
				if hold_tier > 0:
					var held_runway := Vector2i(6, 6)
					var start: Vector2 = scn._cell_pos(held_runway) + chalf
					var target_cell := Vector2i(3, 2)
					if hold_tier <= 2:
						target_cell = Vector2i(3, 0)
					elif hold_tier >= 5:
						target_cell = Vector2i(3, 4)
					var down := InputEventMouseButton.new()
					down.button_index = MOUSE_BUTTON_LEFT
					down.pressed = true
					down.position = start
					scn._on_board_input(down)
					var move := InputEventMouseMotion.new()
					move.position = scn._cell_pos(target_cell) + chalf + Vector2(18.0, -24.0)
					scn._on_board_input(move)
				await create_timer(0.35).timeout
			elif phase == "guide":
				var held := Vector2i(6, 6)
				scn._on_press(scn._cell_pos(held) + chalf)
				scn._begin_drag()
				scn._drag_follow(scn._cell_pos(Vector2i(5, 2)) + chalf + Vector2(18.0, -24.0))
				await create_timer(0.35).timeout
			elif phase == "seedguide":
				var held_seed := Vector2i(6, 6)
				scn._on_press(scn._cell_pos(held_seed) + chalf)
				scn._begin_drag()
				scn._drag_follow(scn._cell_pos(Vector2i(5, 5)) + chalf + Vector2(18.0, -24.0))
				await create_timer(0.35).timeout
			elif phase == "tagtarget":
				var held_tag := Vector2i(6, 6)
				scn._on_press(scn._cell_pos(held_tag) + chalf)
				scn._begin_drag()
				scn._drag_follow(scn._cell_pos(Vector2i(3, 1)) + chalf + Vector2(-56.0, -52.0))
				await create_timer(0.35).timeout
			elif phase == "run":
				scn._on_press(scn._cell_pos(Vector2i(3, 1)) + chalf)
				scn._on_release(scn._cell_pos(Vector2i(3, 2)) + chalf)
				var reached_run_frame := false
				for _i in 120:
					await process_frame
					if int(scn.get("_chain_n")) >= 2 and bool(scn.get("_chain_auto_step")):
						reached_run_frame = true
						break
				if not reached_run_frame:
					push_warning("cascade shot phase=run did not reach the seeded mid-run frame before capture")
				Engine.time_scale = 0.0
			else:
				await create_timer(0.35).timeout
		"played":
			var half: Vector2 = Vector2(scn.csz, scn.csz) / 2.0
			scn._on_press(scn._cell_pos(Vector2i(3, 2)) + half)   # merge the flowers
			scn._on_release(scn._cell_pos(Vector2i(3, 4)) + half)
			await create_timer(0.4).timeout
			for i in 5:                                            # pop a few seeds
				scn._pop_seed()
				await create_timer(0.3).timeout
			scn._on_press(scn._cell_pos(Vector2i(5, 2)) + half)   # merge the berries too
			scn._on_release(scn._cell_pos(Vector2i(5, 4)) + half)
			await create_timer(0.5).timeout
		"sky_sunbeam", "sky_rain":
			# The live Weather Hours patch + in-cell glyph, through Board.tscn. The save has both FTUE
			# verbs marked above, so the gift gate is open and the lane is visible.
			scn.debug_refresh_weather()
			await create_timer(0.45).timeout
		"sky_calm":
			# The SAME gate-open board on a Calm hour — the capture's whole point is what is MISSING:
			# no wash, no glyph, nothing outside the mat. Diff it against sky_sunbeam to see the
			# lane chrome appear and nothing else move.
			scn.debug_refresh_weather()
			await create_timer(0.45).timeout
		"sky_starfall", "sky_starfall_blocked":
			# The real Starfall catch path after its quiet delay: roll a quest-safe high-tier item and dock
			# it at the marker. The lane is the point of the feature, so the two modes capture its two
			# states — emptying the WHOLE lane, as this used to, shows neither.
			#   sky_starfall         — one lane cell still occupied, the rest lit. A wholly empty column is
			#                          not a state a played board is usually in, and it hides that the
			#                          highlight is PER CELL rather than a column-wide wash.
			#   sky_starfall_blocked — every lane cell taken, so nothing lights and the info bar carries
			#                          §6's other pending line, "clear a cell in the column to catch it".
			#                          That string shipped with no capture of the state it describes.
			scn.debug_refresh_weather()
			var lane_open: Array = []
			for cell in scn.call("_star_lane_cells"):
				var v := Vector2i(cell)
				if scn.board.is_open(v) and not scn.board.is_gen(v):
					lane_open.append(v)
			for i in lane_open.size():
				var blocked := mode == "sky_starfall_blocked" or i == 0
				scn.board.place(lane_open[i], LANE_BLOCKER if blocked else 0)
			scn._rebuild_all()
			scn.set("_sky_live_secs", float(G.STAR_DELAY))
			scn.call("_try_starfall")
			await create_timer(0.75).timeout
		"genfade":
			# quest-unused fade: swap the fence for quests asking a line NO on-board generator produces
			# or item carries, so every generator fades (GEN_UNUSED) and every base-line item greys
			# (ITEM_UNUSED).
			scn.quests = [{"line": 9, "tier": 2, "giver": 0}]
			scn._refresh_generator_dim()
			scn._refresh_item_line_dim()
			await create_timer(0.4).timeout
		"gate":
			# the gate-ready state this showcases (the lit Home button) is banked in _clock_seeds above —
			# G.cluster_ready needs BOTH halves, the LEVEL floor (the coin clock) and the wallet PRICE.
			scn._rebuild_givers()
			scn._update_hud()
			# the Home cue is a BREATHE (a transient tween), so a still frame can't prove it fired —
			# print the state it keys off instead, or a silently un-ready capture reads as a pass again.
			print("GATE ready=%s level=%d coins=%d" % [scn._gate_ready(), G.level(), Save.coins()])
			await create_timer(0.6).timeout
		"genpreview":
			# V1: open a path out to a line-3 (mushroom/compost) edge bramble so the
			# locked compost generator shows its greyed "after N spots" silhouette
			for cc in [Vector2i(1, 3), Vector2i(2, 3), Vector2i(2, 2), Vector2i(2, 1)]:
				scn.board.terrain[load("res://engine/scripts/core/board_model.gd").idx(cc)] = 0
			scn._rebuild_all()
			await create_timer(0.4).timeout
		"hud":
			# mid-game: FTUE long done (water shown) + leveled (Lv chip shows a real
			# value) — proves water sits in the top-right cluster next to 💧🪙💎
			var gh := Save.grove()
			gh["pops"] = 30
			gh["water"] = 42
			Save.grove_write()
			scn.water = 42
			scn._update_hud()
			scn._update_water_hud()
			scn._rebuild_givers()
			await create_timer(0.5).timeout
		"endgame":
			# ENDLESS-FENCE regression view (2026-07-23): a deep-endgame coin clock — far past the
			# retired arc-finish/inert threshold (arc_finish_threshold, the 12-zone roster's end). The
			# quest fence must render FULL and full-colour, never the old "endgame quiet" grey-out.
			var gee := Save.grove()
			gee["coins_earned"] = G.arc_finish_threshold() * 5
			gee["pops"] = 30
			gee["water"] = 42
			Save.grove_write()
			scn.water = 42
			scn._update_hud()
			scn._refill_quests()          # rebuild the fence at the (now high) level
			scn._rebuild_givers()
			scn._refresh_giver_lights()
			await create_timer(0.5).timeout
		"oowater":
			# the OUT-OF-WATER surfaces (option 1 + cues): empty can, today's free rain spent, and too few
			# 🌰 for the paid fill — the state that used to go SILENT (only a wobble). Now the refill offer
			# STAYS up as a "get water" invite to the stall, the water pill breathes, and a text hint drifts.
			var tutow: Node = scn.get_node_or_null("BoardTutorialOverlay")   # drop the first-run How-to-Play
			if tutow != null:
				tutow.queue_free()
			var gow := Save.grove()
			gow["pops"] = 30                       # past the FTUE so water is a live cost
			Save.grove_write()
			Claims.claim("refill_water")           # today's free rain is already spent
			Save.add_diamonds(-Save.diamonds())    # and too few 🌰 for the paid fill
			scn.water = 0
			scn._update_hud()
			scn._update_water_hud()                # shows the offer + breathes the pill
			scn._cue_empty_water()                 # + the drifting hint anchored to the water pill
			await create_timer(0.35).timeout       # catch the hint floater mid-rise (before it fades)
		"unlock":
			# the board's NEXT UNLOCK strip mid-arc: the coin clock banked to ~67% of the next
			# level threshold (matches the board_next_unlock_v1 mock face).
			var gu := Save.grove()
			gu["coins_earned"] = int(round(float(G.coins_at_level(2)) * 0.67))
			Save.grove_write()
			scn._update_unlock_bar()
			await create_timer(0.2).timeout
		"level":
			# the level screen (tapping the Lv badge or a locked cell): banked partway to the
			# next level so the tally + progress bar show a real fraction (banked in _clock_seeds above).
			scn._update_hud()
			load("res://engine/scripts/ui/level_popup.gd").open(scn)
			await create_timer(0.5).timeout
		"levelup":
			# the level-UP celebration (auto on a level gain): the Collect dialog showing the earned gift
			scn._update_hud()
			load("res://engine/scripts/ui/level_popup.gd").open_levelup(scn, 1)
			await create_timer(0.5).timeout
		"swap":
			# P3 proof: place two distinct items, drag one onto the other → they
			# trade places (the displaced one glides back). Captured mid-rearrange.
			var es: Array = scn.board.empty_ground_cells()
			var sc1 := Vector2i(es[0])
			var sc2 := Vector2i(es[1])
			scn.board.place(sc1, 101)         # a sapling
			scn.board.place(sc2, 401)         # a honey drop (clearly different)
			scn._rebuild_pieces()
			await create_timer(0.3).timeout
			var sh: Vector2 = Vector2(scn.csz, scn.csz) / 2.0
			scn._on_press(scn._cell_pos(sc1) + sh)
			scn._on_release(scn._cell_pos(sc2) + sh)
			await create_timer(0.25).timeout   # catch the displaced glide mid-flight
		"ladder":
			var half2: Vector2 = Vector2(scn.csz, scn.csz) / 2.0
			scn._on_press(scn._cell_pos(Vector2i(3, 2)) + half2)   # merge once: t2 seen
			scn._on_release(scn._cell_pos(Vector2i(3, 4)) + half2)
			await create_timer(0.5).timeout
			scn._open_ladder(1, 2)
			await create_timer(0.4).timeout
		"farewell":
			# The LINE-FAREWELL card: L65 has moved beyond Wild Berries, Woolens, and Spices, but the
			# player still has board presence. The first due line opens as a calm board-entry card.
			var gr := Save.grove()
			gr["coins_earned"] = G.coins_at_level(G.zone_unlock_level(10))
			gr["seen"] = {"201": true, "401": true, "801": true, "1601": true}
			Save.grove_write()
			for r in G.ROWS:
				for c in G.COLS:
					scn.board.terrain[load("res://engine/scripts/core/board_model.gd").idx(Vector2i(r, c))] = 0
					scn.board.take(Vector2i(r, c))
			for cell in scn.board.gens.keys():
				scn.board.remove_gen(cell)
			var stale_farewell := scn.find_child("FarewellCardOverlay", true, false) as Control
			if stale_farewell != null:
				stale_farewell.queue_free()
				await create_timer(0.1).timeout
			var free_cells: Array = scn.board.empty_ground_cells()
			if free_cells.size() >= 7:
				scn.board.place_gen("gen_2", free_cells[0])
				scn.board.arm_gen_boost(free_cells[0], 4)
				scn.board.place_gen("gen_4", free_cells[1])
				scn.board.place(free_cells[2], 202)
				scn.board.place(free_cells[3], 403)
				scn.board.place(free_cells[4], 801)
				scn.board.place(free_cells[5], 1602)
				scn.board.place(free_cells[6], 1901)
			scn._refill_quests()
			scn._rebuild_all()
			await create_timer(0.3).timeout
			scn._queue_farewell_check()
			await create_timer(0.7).timeout
		"flyaway":
			# The item fly-away sweep itself. The clock seed uses the zone accessor (not a literal level)
			# so the fixture follows progression retunes; phase=all saves launch/apex/arrival siblings.
			_seed_flyaway_board(scn)
			await create_timer(0.25).timeout
			# CHECK THE SEEDED BOARD HERE — after the seeding, before the sweep eats it, and in the
			# CALLER rather than at the end of _seed_flyaway_board: a runtime error inside that function
			# (a retired parameter on one of its calls, say) aborts it on the spot, so a self-check as its
			# last statement is the very first thing skipped. Without this, the sweep ran on an empty
			# board and the tool saved three believable PNGs of a bare field at err=0.
			var fly_seeded: Dictionary = BoardActions.farewell_preview(scn.board, FLYAWAY_LINE)
			var fly_bad := _flyaway_fixture_problem(fly_seeded)
			if fly_bad != "":
				print("REFUSED: the flyaway fixture did not seed — %s" % fly_bad)
				print("  The sweep is the whole capture; with nothing on the board it animates nothing and")
				print("  the frames would show an empty field. Look for a SCRIPT ERROR above this line —")
				print("  it names the call inside _seed_flyaway_board that aborted the seeding.")
				quit(2)
				return
			print("FLYAWAY fixture line=%d gens=%d pieces=%d coins=%d" % \
				[FLYAWAY_LINE, int(fly_seeded["gens"]), int(fly_seeded["pieces"]), int(fly_seeded["coins"])])
			var fly: Dictionary = await _capture_or_stage_flyaway(self, scn, args, out)
			if int(fly["err"]) != 0:
				print("REFUSED: a flyaway frame failed to save — err=%d" % int(fly["err"]))
				quit(2)
				return
			custom_capture_done = bool(fly["captured"])
		"almanac":
			# The read-only Collection/Almanac grid: discovered dormant lines show their away/complete badges,
			# current-producing lines stay bright, and unseen future lines remain locked.
			var ga := Save.grove()
			ga["coins_earned"] = G.coins_at_level(G.zone_unlock_level(10))
			ga["seen"] = {"101": true, "201": true, "401": true, "801": true, "1601": true}
			Save.grove_write()
			scn._refill_quests()
			scn._rebuild_all()
			await create_timer(0.3).timeout
			scn._open_almanac()
			await create_timer(0.5).timeout
		"recipe":
			# the MERGED-line tier screen: a special line (71 = Prize pumpkin, crafted from Wildflower + Feather)
			# opens its RECIPE view — the two ingredient items alone, each tapping through to its own tier screen.
			scn._open_ladder(71, 1)
			await create_timer(0.4).timeout
		"producingearly":
			# the BEGINNING the player first sees (low level — only Wildflower + Hearth embers have grown in).
			# The dialog must still preview the generator's FULL line-up: the live lines as pieces, the rest as
			# locked placeholder cells. Regression for "at the start it only shows 2 items".
			var gpe := Save.grove()
			gpe["pops"] = 30                       # past the FTUE so taps cost water
			gpe["water"] = 200
			Save.grove_write()
			scn.water = 200
			scn._update_hud()
			await create_timer(0.3).timeout
			for i in 4:                            # a few pops so the live lines get discovered (show pieces)
				scn._pop_seed()
				await create_timer(0.12).timeout
			scn._select_generator(scn.board.gens.keys()[0])
			await create_timer(0.2).timeout
			scn._on_info_pressed()                 # tap ⓘ → open the Producing dialog
			await create_timer(0.45).timeout
		"producing", "producingdrill":
			# the PRODUCING dialog (tap generator → ⓘ): the lines the anchor currently makes, at ~L6 — the live
			# pop pool's lines wear the gold ring, popped lines show their piece, and not-yet-discovered lines
			# fall to the locked "?". (The dialog's line-up is NOT level-gated at HEAD: board._gen_line_entries
			# walks the whole G.GENERATORS roster, so the seed sets the HUD + board state, not the roster.)
			var gpr := Save.grove()
			gpr["pops"] = 30                       # past the FTUE so taps cost water (and read the played state)
			gpr["water"] = 300
			gpr["seen"] = {}                       # an explicit blank discovery set, then pop to fill it
			Save.grove_write()
			scn.water = 300
			scn._update_hud()
			scn._rebuild_givers()
			await create_timer(0.3).timeout
			for i in 6:                            # pop bursts → establish the live pop pool (its lines wear the ring)
				scn._pop_seed()
				await create_timer(0.12).timeout
			# seed a legible discovery mix: Wildflower (1) + three Farm lines discovered → filled pieces; the
			# remaining live lines (Larder 64 · Porch 65 · Flower-box 66) stay unseen → locked "?" wells.
			var pseen: Dictionary = Save.grove().get("seen", {})
			for sc in [101, 102, 6101, 6201, 6301]:   # Wildflower t1/t2 · Hearth t1 · Kitchen-herbs t1 · Well-water t1
				pseen[str(sc)] = true
			scn._select_generator(scn.board.gens.keys()[0])
			await create_timer(0.2).timeout
			scn._on_info_pressed()                 # tap ⓘ → open the Producing dialog
			await create_timer(0.45).timeout
			if mode == "producingdrill":
				scn._open_ladder(1, 1)             # tap the Wildflower line → its tier ladder, stacked on top
				await create_timer(0.4).timeout
		"infosel", "infobuy", "infoacorn":
			# the bottom-bar INFO BAR with an item SELECTED: place a known item, select it → the bar shows
			# the piece + "<name> · Tier N" + the BUY chip (T55) + the sell button. Coins make the buy chip
			# read affordable (green); "infobuy" is just the explicit alias for the buy-chip capture.
			# "infoacorn" selects an ACORN-PAYING tier instead (§9 ladder, t >= G.SELL_ACORN_TIER), so the
			# sell button reads its payout in acorns — the one state where BOTH chips show the acorn icon.
			var tut: Node = scn.get_node_or_null("BoardTutorialOverlay")   # drop the first-run How-to-Play so the bar shows
			if tut != null:
				tut.queue_free()
			Save.add_coins(2000)
			Save.add_diamonds(50)
			var ies: Array = scn.board.empty_ground_cells()
			var icell := Vector2i(ies[0])
			# a tier-4 item (a clear name + a non-trivial buy/sell value), or the TOP tier for infoacorn
			scn.board.place(icell, 100 + (int(G.TOP_TIER) if mode == "infoacorn" else 4))
			scn._rebuild_pieces()
			scn._update_hud()
			await create_timer(0.3).timeout
			scn._select_item(icell)
			await create_timer(0.3).timeout
		"focuscoin":
			# the new SELECTED-cell focus frame (corner brackets) around a focused COIN — the on-board cue
			# that makes tap-to-focus / tap-again-to-collect visible. Prints the cell's pixel rect for a crop.
			Save.add_coins(2000)
			var fes: Array = scn.board.empty_ground_cells()
			var fcell := Vector2i(fes[fes.size() / 2])   # a coin near the middle of the open ground
			scn.board.place(fcell, 902)                  # a tier-2 coin
			scn._rebuild_pieces()
			scn._update_hud()
			await create_timer(0.3).timeout
			scn._select_item(fcell)
			await create_timer(0.3).timeout
			var frect: Rect2 = Rect2(scn.board_area.get_global_transform() * scn._cell_pos(fcell), Vector2(scn.csz, scn.csz))
			print("FOCUSCOIN cell=%s crop=%d,%d,%d,%d" % [str(fcell), int(frect.position.x), int(frect.position.y), int(frect.size.x), int(frect.size.y)])
		"questready":
			# the quest-ready GLOW via the REAL hook: seed the items the live givers want (one per quest),
			# then _rebuild_all (rebuilds pieces AND wells so the seeded cells aren't covered) — its giver-
			# lights refresh adds the gold cell-glow to each wanted tile.
			var tut: Node = scn.find_child("BoardTutorialOverlay", true, false)   # drop the FTUE card so the board shows
			if tut != null:
				tut.queue_free()
			await create_timer(0.4).timeout                   # let the board's deferred intro re-deal settle FIRST
			var qes: Array = scn.board.empty_ground_cells()
			var seeded: Array = []
			for ai in scn.quests.size():
				var ait: Dictionary = G.quest_item(scn.quests[ai])
				if ait.is_empty() or qes.is_empty():
					continue
				scn.board.place(Vector2i(qes.pop_back()), int(ait.line) * 100 + int(ait.tier))
				seeded.append(int(ait.line) * 100 + int(ait.tier))
			scn._rebuild_all()
			scn._update_hud()
			await create_timer(0.3).timeout
			print("QUESTREADY seeded %d wanted tiles: %s" % [seeded.size(), str(seeded)])
		"genburst", "genburstbroke":
			# T54→boost: the info bar with the GENERATOR selected → the boost chip in the action slot.
			# "genburst" = affordable, no boost live (coins present → green chip); "genburstbroke" = broke
			# (dimmed chip).
			var gbg := Save.grove()
			gbg["pops"] = 30                       # past the FTUE so the bar reads its played state
			Save.grove_write()
			if mode == "genburst":
				Save.add_coins(2000)               # enough to arm a boost → the chip lights green
			else:
				Save.spend(Save.coins())           # broke → the chip dims, cost shown as a goal
			scn._update_hud()
			await create_timer(0.3).timeout
			scn._select_generator(scn.board.gens.keys()[0])
			await create_timer(0.3).timeout
		"mastery":
			# The generator INFO BAR at a given mastery rank — the "· Tier N" title badge, the
			# within-rank progress bar. `line=` picks the generator (2 = Wild
			# Berries), `meter=` is written straight into the save, so a THRESHOLD entry lands exactly
			# on that rank. Seeds the meter
			# BEFORE selecting: _select_generator is what builds the row off Mastery.rank().
			var ml := int(Base.opt(args, "line", "2"))
			var mm := int(Base.opt(args, "meter", "1150"))
			var mg := Save.grove()
			mg["pops"] = 30                    # past the FTUE so the bar reads its played state
			mg["mastery"] = {str(ml): mm}
			Save.grove_write()
			var mcell := Vector2i(-1, -1)
			for c in scn.board.gens:
				if int(G.gen_def(G.GENERATORS, String(scn.board.gens[c])).get("line", 0)) == ml:
					mcell = c
					break
			if mcell.x < 0:                    # that line's generator is not on the fresh board — place it
				var freem: Array = scn.board.empty_ground_cells()
				if freem.is_empty():
					print("REFUSED: no free cell to place the line-%d generator" % ml)
					quit(2)
					return
				mcell = Vector2i(freem[0])
				scn.board.place_gen(G.gen_for_line(ml), mcell)
			scn._update_hud()
			await create_timer(0.3).timeout
			scn._select_generator(mcell)
			await create_timer(0.4).timeout
			print("MASTERY line=%d meter=%d cell=%s" % [ml, mm, str(mcell)])
		"genboost":
			# T57: a LIVE boost — every generator wears the sparkle + taps-left badge, the info bar reads
			# the boost detail (+N/tap · M left), and the boost chip is FADED (no re-buy while running).
			var gbo := Save.grove()
			gbo["pops"] = 30                       # past the FTUE so the bar reads its played state
			Save.grove_write()
			Save.add_coins(2000)
			scn._update_hud()
			await create_timer(0.2).timeout
			scn._select_generator(scn.board.gens.keys()[0])
			scn._on_burst_chip()                   # arm the boost → indicator lights up + chip fades
			await create_timer(2.0).timeout        # let the "Bigger bursts!" celebration floater clear
			scn._select_generator(scn.board.gens.keys()[0])   # re-read the bar (steady boosted state)
			await create_timer(0.3).timeout
		"watershop":
			# the WATER stall opened over the board → the FREE refill (a full can, capped + cooled) leads,
			# then the 💎 Fill-water card. Drive the REAL water-pill "+" button (the exact path a tap takes,
			# through _build_hud → Hud.build → shop_opts), NOT a direct open_water call — so the capture
			# matches the live board. Water is Save-backed now; the stall shows the same from any host.
			Save.add_coins(2000)
			Save.add_diamonds(50)
			scn._update_hud()
			var cluster: Control = scn._wallet_panel
			var water_pill_panel: Control = cluster.get_child(0)   # WATER · COIN · GEM — water is first
			var water_button := water_pill_panel as Button
			if water_button == null:
				water_button = water_pill_panel.find_child("GoldCurrencyPill", true, false) as Button
			print("WATERSHOP probe: cluster=%s water_pill=%s button=%s" % [cluster, water_pill_panel, water_button])
			water_button.pressed.emit()
			await create_timer(0.6).timeout
		"bagwell":
			# the bottom-nav Bag WELL in its FILLED state, overlay CLOSED: one stashed piece overlays
			# the satchel tile (the well only ever previews the most-recent item, whatever the count),
			# and the "x/y" count on the tile foot reads 1/6 against the starting capacity.
			scn.bag = [101]
			scn._rebuild_bag()
			await create_timer(0.4).timeout
		"bag":
			# §5 full-bag overlay: a few stashed pieces (filled tiles) + owned vacancies, a 💎
			# balance for the acorn counter, then open the modal so the whole ladder shows
			# (filled · empty · the gold next slot · the locked future slots with prices).
			Save.add_diamonds(132)
			scn.bag = [101, 201, 301, 401, 501]    # five distinct tier-1 pieces fill the first row
			scn._rebuild_bag()
			scn._open_bag_overlay()
			await create_timer(0.6).timeout
		"bagbroke", "bagshop":
				# the short-of-acorns prompt: a player with too few 💎 taps the gold next slot — the
				# bag stays open behind the card that sends them to the shop.
				Save.spend_diamonds(Save.diamonds())      # broke: 0 acorns against the 10 the slot costs
				scn._update_hud()                          # the wallet must show the emptied purse
				scn.bag = [101, 201]
				scn._rebuild_bag()
				scn._open_bag_overlay()
				await create_timer(0.4).timeout
				var bag_ov: Node = scn.find_child("BagOverlay", true, false)
				var grids: Array = bag_ov.find_children("*", "GridContainer", true, false)
				var next_tile: Node = (grids[0] as GridContainer).get_child(G.BAG_START_SLOTS)
				(next_tile as Button).pressed.emit()
				await create_timer(0.6).timeout
				if mode == "bagshop":
					# ...and follow the prompt through: the shop button must land on the acorn stall.
					var prompt: Node = scn.find_child("BagNeedMorePrompt", true, false)
					for b in prompt.find_children("*", "Button", true, false):
						if String((b as Button).text) == "Go to shop":
							(b as Button).pressed.emit()
							break
					await create_timer(0.8).timeout
		"baggen":
			# the bag overlay WITH the stored-generators row below the grid — the tiles there must
			# match the slot cells above them exactly (they share the dialog's fitted cell opts).
			Save.add_diamonds(132)
			scn.bag = [101, 201, 301]
			scn.board.gen_bag = []
			scn.board.gen_bag_boost = []
			scn.board.bag_add("gen_1")
			scn.board.bag_add("gen_2")
			scn._rebuild_bag()
			scn._open_bag_overlay()
			await create_timer(0.6).timeout
		"dragwell", "dragwellfull":
			# mid-DRAG: pick up a board piece so the drop-target wells (Bag + merchant cart) light
			# up. "dragwellfull" pre-fills the bag to capacity → the Bag must NOT highlight.
			if mode == "dragwellfull":
				scn.bag = [101, 201, 301, 401, 501, 102]   # 6 = the starting capacity (full)
				scn._rebuild_bag()
			var des: Array = scn.board.empty_ground_cells()
			var dc := Vector2i(des[0])
			scn.board.place(dc, 101)
			scn._rebuild_pieces()
			await create_timer(0.3).timeout
			var dhalf: Vector2 = Vector2(scn.csz, scn.csz) / 2.0
			scn._on_press(scn._cell_pos(dc) + dhalf)        # pick up → lights the drop targets
			scn._begin_drag()                               # cross the touch slop — the press only ARMS now
			await create_timer(0.5).timeout
		"grab":
			# the GRAB highlight on a REAL board piece (glow + white silhouette outline) via the actual
			# _on_press path — proves the rim aligns with the LIFTED art at the board's tuned piece size.
			var gtut: Node = scn.find_child("BoardTutorialOverlay", true, false)   # drop the FTUE card so the board shows
			if gtut != null:
				gtut.queue_free()
			await create_timer(0.4).timeout                # let the board's deferred intro re-deal settle FIRST
			var grabes: Array = scn.board.empty_ground_cells()
			var gcell := Vector2i(grabes[grabes.size() / 2])
			scn.board.place(gcell, 104)
			scn._rebuild_pieces()
			await create_timer(0.3).timeout
			var ghalf: Vector2 = Vector2(scn.csz, scn.csz) / 2.0
			scn._on_press(scn._cell_pos(gcell) + ghalf)   # REAL grab: scale 1.12 + set_lifted + GrabFx.grab
			scn._begin_drag()                             # cross the touch slop — the press only ARMS now
			await create_timer(0.3).timeout
			# instrument the REAL grabbed node: did the outline get added, and does its rect match the art's?
			var dn: Control = scn._drag_node
			print("GRAB dragnode=%s grabbed_cell=%s" % [dn, str(gcell)])
			if dn != null:
				var dart: Control = dn.get_node_or_null(NodePath("ItemArt"))
				var drim: Control = dn.get_node_or_null(NodePath("GrabOutline"))
				print("  modulate=%s scale=%s" % [str(dn.modulate), str(dn.scale)])
				if dart != null:
					print("  ART  offsets L/T/R/B=%.1f/%.1f/%.1f/%.1f size=%s" % [dart.offset_left, dart.offset_top, dart.offset_right, dart.offset_bottom, str(dart.size)])
				print("  RIM  node=%s" % drim)
				if drim != null:
					print("  RIM  offsets L/T/R/B=%.1f/%.1f/%.1f/%.1f size=%s inset=%s width=%s" % [drim.offset_left, drim.offset_top, drim.offset_right, drim.offset_bottom, str(drim.size), str(drim.get("inset")), str(drim.get("width"))])
				var dglow: Control = dn.get_node_or_null(NodePath("GrabGlow"))
				print("  GLOW node=%s modulate=%s size=%s" % [dglow, str(dglow.modulate) if dglow != null else "n/a", str(dglow.size) if dglow != null else "n/a"])
			# crop the grabbed node in FRAMEBUFFER pixels: get_global_transform_with_canvas folds in the
			# canvas_items stretch (the capture is post-stretch, so plain global coords miss it).
			var gxf: Transform2D = dn.get_global_transform_with_canvas() if dn != null else scn.board_area.get_global_transform_with_canvas()
			var gpos: Vector2 = gxf.origin
			var gsz: Vector2 = (dn.size if dn != null else Vector2(scn.csz, scn.csz)) * gxf.get_scale()
			# widen + extend UP (the lifted art rises above the cell) so the crop shows the whole rim
			print("GRAB cell=%s crop=%d,%d,%d,%d" % [str(gcell), int(gpos.x) - 24, int(gpos.y) - 40, int(gsz.x) + 48, int(gsz.y) + 64])
		"grabgen":
			# grab a GENERATOR (different node structure: gold GenOutline + glow + sprite) and DRAG it, then
			# instrument every layer's rect so we can see which outline is shifted vs the (lifted) sprite.
			var ggtut: Node = scn.find_child("BoardTutorialOverlay", true, false)
			if ggtut != null:
				ggtut.queue_free()
			await create_timer(0.4).timeout
			var gcellg: Vector2i = scn.board.gens.keys()[0]
			var gghalf: Vector2 = Vector2(scn.csz, scn.csz) / 2.0
			scn._on_press(scn._cell_pos(gcellg) + gghalf)              # REAL gen grab: scale + set_lifted + GrabFx.grab
			scn._begin_drag()                                          # cross the touch slop — the press only ARMS now
			scn._drag_follow(scn._cell_pos(gcellg) + gghalf + Vector2(40, -30))   # simulate a drag move
			await create_timer(0.3).timeout
			var gn: Control = scn._drag_node
			print("GRABGEN dragnode=%s cell=%s" % [gn, str(gcellg)])
			if gn != null:
				for cn in ["ItemArt", "GenOutline", "GrabOutline"]:
					var ch: Control = gn.get_node_or_null(NodePath(cn))
					if ch != null:
						print("  %-11s offsets L/T/R/B=%.1f/%.1f/%.1f/%.1f size=%s" % [cn, ch.offset_left, ch.offset_top, ch.offset_right, ch.offset_bottom, str(ch.size)])
					else:
						print("  %-11s <absent>" % cn)
		"fullline":
			# ONE item line laid out tier 1 → TOP_TIER on a cleared board: the whole ladder's art, at
			# board scale, in the real cell frame. `line=N` picks it (default 3 = Snow & Ice).
			#
			# This replaces the old "compost" + "hive" modes. They were named for a compost-bin and a
			# beehive generator that no longer exist, and they reached the board through the RETIRED
			# per-spot generator unlock — `G.MAPS[3].spots[1]` (maps 1–4 carry no spots since the
			# picture-book pages landed) and `scn._spots_bought()` (deleted outright). Both crashed;
			# neither could be salvaged as written, because the state they described is gone from the
			# game. The ladder capture they were actually FOR is what survives here.
			var fl := int(Base.opt(args, "line", "3"))
			var gfl := Save.grove()
			gfl["coins_earned"] = G.coins_at_level(14)      # deep enough that no tier reads level-gated
			Save.grove_write()
			for r in G.ROWS:                                # open the whole field so all TOP_TIER tiers fit
				for c in G.COLS:
					var cl := Vector2i(r, c)
					if scn.board.is_open(cl) and scn.board.item_at(cl) > 0:
						scn.board.take(cl)                  # ...clear the starters
					scn.board.terrain[load("res://engine/scripts/core/board_model.gd").idx(cl)] = 0   # ...and the brambles
			var empties: Array = scn.board.empty_ground_cells()
			empties.sort()
			for t in range(1, G.TOP_TIER + 1):
				if empties.is_empty():
					break
				scn.board.place(empties.pop_front(), fl * 100 + t)
			# ask for the line so the ladder reads LIT (an unasked line greys out — ITEM_UNUSED)
			scn.quests = [{"line": fl, "tier": G.TOP_TIER, "giver": 0}]
			scn._rebuild_all()
			scn._refresh_item_line_dim()
			scn._update_hud()
			await create_timer(0.6).timeout

	if custom_capture_done:
		# The literal err=0 is earned: the branch that set custom_capture_done already refused the run
		# on any non-zero save_png code, so this line cannot claim a save that did not happen.
		print("SHOT saved=%s err=0 level=%d coins_earned=%d coins=%d brambles=%d gens=%d genbag=%d" % \
			[out, G.level(), Save.coins_earned_lifetime(), Save.coins(), scn.board.bramble_count(),
			scn.board.gens.size(), scn.board.gen_bag.size()])
		quit()
		return
	var err := Base.capture(self, out, args)
	# Report the LIVE clock (level + the lifetime organic coins it derives from), not the retired
	# grove["exp"] — a capture that seeded the wrong clock used to print a plausible line and a Level-1 PNG.
	# gens/genbag report the generator state the PNG actually shows: modes that STRIP generators (cascade)
	# or SEED the stored-generator row (baggen) render a plausible board at exit 0 when their setup silently
	# no-ops, so tools/test_grove_shot_parse.sh asserts these counts instead of trusting the exit code.
	print("SHOT saved=%s err=%d level=%d coins_earned=%d coins=%d brambles=%d gens=%d genbag=%d" % \
		[out, err, G.level(), Save.coins_earned_lifetime(), Save.coins(), scn.board.bramble_count(),
		scn.board.gens.size(), scn.board.gen_bag.size()])
	quit()

## The lifetime-organic-coins each mode banks BEFORE the scene loads (see _initialize) — the ONLY way
## a capture sets its level now. A mode absent here keeps the fresh save's Level 1.
static func _clock_seeds() -> Dictionary:
	return {
		# L3 banked half-way to L4: the Lv chip reads 3 AND every progress readout shows a real fraction
		# (the level dialog's tally + bar, the board's NEXT UNLOCK strip) instead of sitting on 0%.
		"hud": _clock_midway(3),
		"level": _clock_midway(3),
		"levelup": _clock_midway(3),
		# L6 · 25🪙 — the level the Producing capture is written for.
		"producing": G.coins_at_level(6),
		"producingdrill": G.coins_at_level(6),
		"ftuesoil": G.coins_at_level(6),
		# Flyaway is a zone-transition visual, so seed by symbolic zone unlock level.
		"flyaway": G.coins_at_level(G.zone_unlock_level(3)),
		# gate: the SAME 25 is also earned into the WALLET (earn_coins), because G.cluster_ready gates on
		# the level floor AND the price — L6 · 25🪙 clears the first hollow clusters' floors and costs.
		"gate": G.coins_at_level(6),
	}

## Coin-clock seed for `level`, banked HALF-WAY to the next level. The clock is coins now
## (content.level_at_coins ← Save.coins_earned_lifetime), so a capture that wants a level seeds this —
## never grove["exp"], which feeds nothing. Seeding coins_at_level(N) exactly lands ON the threshold and
## every progress readout (the level dialog's tally + bar, the board's NEXT UNLOCK strip) reads 0%; the
## midpoint makes them show a real fraction. Symbolic, so a curve re-tune can't strand it.
static func _clock_midway(level: int) -> int:
	var base := G.coins_at_level(level)
	return base + (G.coins_at_level(level + 1) - base) / 2

## Sweep the seeded line and either save the phase=all frames or freeze on a single phase.
## Returns {captured: bool, err: int} — `captured` is true when this call already wrote the PNG(s),
## `err` the worst save_png code across them (the caller refuses on a non-zero one; the SHOT line it
## prints for a custom capture reads a literal err=0, which is only honest if that is checked).
static func _capture_or_stage_flyaway(tree: SceneTree, scn: Node, args: Array, out: String) -> Dictionary:
	scn._sweep_farewell(FLYAWAY_LINE, G.next_need(FLYAWAY_LINE, scn._quest_level()))
	var phase := String(Base.opt(args, "phase", "apex"))
	if phase == "all":
		await tree.create_timer(_flyaway_phase_delay("launch")).timeout
		var launch_path := _phase_out_path(out, "launch")
		var launch_err := Base.capture(tree, launch_path, args)
		await tree.create_timer(_flyaway_phase_delay("apex") - _flyaway_phase_delay("launch")).timeout
		var apex_path := _phase_out_path(out, "apex")
		var apex_err := Base.capture(tree, apex_path, args)
		await tree.create_timer(_flyaway_phase_delay("arrival") - _flyaway_phase_delay("apex")).timeout
		var arrival_path := _phase_out_path(out, "arrival")
		var arrival_err := Base.capture(tree, arrival_path, args)
		print("FLYAWAY frames launch=%s err=%d apex=%s err=%d arrival=%s err=%d" % \
			[launch_path, launch_err, apex_path, apex_err, arrival_path, arrival_err])
		return {"captured": true, "err": maxi(launch_err, maxi(apex_err, arrival_err))}
	if not (phase in ["launch", "apex", "arrival"]):
		push_warning("flyaway shot: unknown phase '%s', using apex" % phase)
		phase = "apex"
	await tree.create_timer(_flyaway_phase_delay(phase)).timeout
	Engine.time_scale = 0.0
	return {"captured": false, "err": 0}

## What is WRONG with the board the flyaway capture was just handed, read off the sweep's own preview;
## "" when it is exactly what the animation needs. The three conditions are the three things the frames
## are supposed to show: the keepsake generator that fades in place, the pieces that detach and fly, and
## a payout at the wallet. A sweep that pays nothing has nothing to watch fly.
static func _flyaway_fixture_problem(preview: Dictionary) -> String:
	if int(preview.get("gens", 0)) < 1:
		return "the line-%d generator is not on the board (no keepsake to fade)" % FLYAWAY_LINE
	if int(preview.get("pieces", 0)) != FLYAWAY_PIECES:
		return "expected %d line-%d pieces on the board, found %d" % \
			[FLYAWAY_PIECES, FLYAWAY_LINE, int(preview.get("pieces", 0))]
	if int(preview.get("coins", 0)) <= 0:
		return "the sweep would pay 0 coins — nothing would fly to the wallet"
	return ""

## Clear the board and lay out the fixture the sweep consumes: the line's generator (boosted, so it
## wears its badge) plus one piece per tier. NOT self-checking on purpose — see the caller.
static func _seed_flyaway_board(scn: Node) -> void:
	var g := Save.grove()
	var seen := {}
	for i in FLYAWAY_PIECES:
		seen[str(FLYAWAY_LINE * 100 + 1 + i)] = true
	g["seen"] = seen
	Save.grove_write()
	var BM: GDScript = load("res://engine/scripts/core/board_model.gd")
	for r in G.ROWS:
		for c in G.COLS:
			var cell := Vector2i(r, c)
			scn.board.terrain[BM.idx(cell)] = 0
			scn.board.take(cell)
	for cell in scn.board.gens.keys():
		scn.board.remove_gen(cell)
	var stale_farewell := scn.find_child("FarewellCardOverlay", true, false) as Control
	if stale_farewell != null:
		stale_farewell.queue_free()
	var free_cells: Array = scn.board.empty_ground_cells()
	if free_cells.size() < FLYAWAY_PIECES + 1:
		push_warning("flyaway shot: expected at least %d free cells, got %d" % \
			[FLYAWAY_PIECES + 1, free_cells.size()])
		return
	scn.board.place_gen(G.gen_for_line(FLYAWAY_LINE), free_cells[0])
	scn.board.arm_gen_boost(free_cells[0], 4)
	for i in FLYAWAY_PIECES:
		scn.board.place(free_cells[i + 1], FLYAWAY_LINE * 100 + 1 + i)
	scn._refill_quests()
	scn._rebuild_all()
	scn._update_hud()

static func _flyaway_phase_delay(phase: String) -> float:
	match phase:
		"launch":
			return 0.08
		"arrival":
			return 0.78
		_:
			return 0.26

static func _phase_out_path(out: String, phase: String) -> String:
	var ext := out.get_extension()
	if ext == "":
		return "%s_%s.png" % [out, phase]
	return "%s_%s.%s" % [out.get_basename(), phase, ext]
