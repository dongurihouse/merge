extends SceneTree
## Guards engine/scripts/core/bucket.gd — the Save-backed adapter over the PURE resident bucket
## (resident_bucket.gd): cells-from-completion, save migration, collect crediting, boost stockpile.

const Save = preload("res://engine/scripts/core/save.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const G = preload("res://engine/scripts/core/content.gd")
const Bucket = preload("res://engine/scripts/core/bucket.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

# Point Save at a clean temp dir (never touches the real save or progress.cfg).
func fresh(name: String) -> void:
	var dir := "user://tu_bucket_" + name + "/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)
	Save.reset()

func _restore_map(z: int) -> void:
	var g := Save.grove()
	if not g.has("unlocks"):
		g["unlocks"] = {}
	for sp in G.MAPS[z].spots:
		g["unlocks"][String(sp.id)] = true
	Save.grove_write()

func _test_cells_from_completion() -> void:
	fresh("cells")
	ok(Bucket.cells_total() == 0, "a fresh save has 0 cells")
	ok(Bucket.state().cells == 0, "state syncs the derived cell count")
	_restore_map(0)
	ok(Bucket.cells_total() == int(Game.DATA.BUCKET_CELL_GRANTS[0]), "completing map 0 grants its cells")
	for z in G.MAPS.size():
		_restore_map(z)
	var want := 0
	for grant in Game.DATA.BUCKET_CELL_GRANTS:
		want += int(grant)
	ok(Bucket.cells_total() == want, "all five maps grant the full 8-cell bucket")
	ok(Bucket.state().cells == want, "state re-syncs cells after completion")

func _test_migration() -> void:
	fresh("migration")
	var g := Save.grove()
	g["hand"] = [{"kind": "ember", "tier": 3}]
	g["habitat"] = {"farmhouse": [{"kind": "breeze", "tier": 2}], "pond": [{"kind": "dewdrop", "tier": 5}]}
	g["hab_prod"] = {"farmhouse": {"acc": 2.7, "last": 0.0}}
	g["hab_cap"] = {"farmhouse": 9}
	Save.grove_write()
	var coins_before := Save.coins()
	var st := Bucket.state()
	ok(st.hand.size() == 3 and st.placed.is_empty(), "legacy hand + all placed migrate into the new hand")
	var lines := {}
	for inst in st.hand:
		lines[String(inst.line) + ":" + str(int(inst.tier))] = true
	ok(lines.has("boost:3") and lines.has("coin:2") and lines.has("water:5"),
		"legacy kinds map to lines (ember→boost, breeze→coin, dewdrop→water) at their tiers")
	ok(Save.coins() == coins_before + 2, "banked legacy accrual credits floor(acc) in the old currency")
	var g2 := Save.grove()
	ok(not g2.has("hand") and not g2.has("habitat") and not g2.has("hab_prod") and not g2.has("hab_cap"),
		"legacy habitat keys are erased")
	ok(g2.has("bucket"), "the bucket state persists in the save")

func _test_place_and_sell() -> void:
	fresh("place_sell")
	Bucket.hand_add("coin", 1)
	ok(not Bucket.place(0), "place refuses with 0 cells")
	_restore_map(0)
	ok(Bucket.place(0), "place succeeds once completion granted cells")
	ok(Bucket.placed().size() == 1 and Bucket.hand().is_empty(), "place moved the spirit into a cell")
	Bucket.hand_add("coin", 1)
	ok(Bucket.place_merge(0, 0), "place_merge climbs the placed spirit")
	ok(int(Bucket.placed()[0].tier) == 2, "placed tier climbed")
	ok(Bucket.unplace(0), "unplace returns the spirit to hand")
	var coins_before := Save.coins()
	var got := Bucket.sell_hand(0)
	ok(got == 2 * Bucket.SELL_PER_TIER, "sell_hand pays SELL_PER_TIER x tier")
	ok(Save.coins() == coins_before + got, "sell_hand credits the coins itself")
	Bucket.hand_add("water", 1)
	Bucket.hand_add("water", 1)
	ok(Bucket.hand_merge(0, 1), "hand_merge pairs via indexes")
	ok(Bucket.hand().size() == 1 and int(Bucket.hand()[0].tier) == 2, "hand_merge climbed a tier")

func _test_collect_crediting() -> void:
	fresh("collect")
	var st := Bucket.state()
	st["banks"] = {"coin": 3.7, "water": 9999.0, "diamond": 5.0, "boost": 2.2}
	Save.grove_write()
	Save.set_water(int(Game.DATA.WATER_CAP) - 3)
	var coins_before := Save.coins()
	var dia_before := Save.diamonds()
	var got := Bucket.collect()
	ok(int(got.get("coin", 0)) == 3 and Save.coins() == coins_before + 3, "collect credits whole coins")
	ok(Save.water() == int(Game.DATA.WATER_CAP), "collected water clamps to WATER_CAP")
	ok(int(got.get("diamond", 0)) <= 2 and Save.diamonds() == dia_before + int(got.get("diamond", 0)),
		"the diamond line grants at most its day cap")
	ok(Bucket.boost_charges() == 2, "collected boost banks as board charges")
	ok(is_equal_approx(float(Bucket.state().banks["coin"]), 0.7), "the coin fraction stays banked")
	ok(Bucket.spend_boost_charge() and Bucket.boost_charges() == 1, "spend_boost_charge decrements")
	Bucket.spend_boost_charge()
	ok(not Bucket.spend_boost_charge(), "spend refuses when the stock is empty")

func _test_grant_box() -> void:
	fresh("grant_box")
	var got := Bucket.grant_box(3)
	ok(got.size() == 3 and Bucket.hand().size() == 3, "grant_box drops count spirits into the hand")
	var sound := true
	for inst in got:
		if not (String(inst.line) in Bucket.LINES):
			sound = false
		if String(inst.kind) != Bucket.line_kind(String(inst.line)):
			sound = false
		if int(inst.tier) < 1 or int(inst.tier) > 4:
			sound = false
	ok(sound, "each grant carries a valid line, its art kind, and a t1..t4 tier")
	ok(Bucket.kind_line("sprout") == "coin" and Bucket.line_kind("diamond") == "starlight",
		"line<->kind mapping round-trips")

func _initialize() -> void:
	print("== bucket adapter (save-backed) ==")
	_test_cells_from_completion()
	_test_migration()
	_test_place_and_sell()
	_test_collect_crediting()
	_test_grant_box()
	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
