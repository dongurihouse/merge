extends SceneTree
## Headless tests for the §5 full-bag OVERLAY (ui/bag_overlay.gd). The modal's LOOK (the kit
## parchment/banner/cards, the straddling ✕) is perceptual and verified by a screenshot, NOT here;
## the CORRECTNESS is the pure slot-ladder classification — which 1-based slot is owned (filled vs
## empty), which single slot is the gold "next" purchase, which are locked, and the 💎 price each
## locked/next slot carries — all asserted without building a node. A light build-smoke confirms
## open() assembles the modal and tears down cleanly.
##   godot --headless --path . -s res://engine/tests/bag_overlay_tests.gd

const BagOverlay = preload("res://engine/scripts/ui/bag_overlay.gd")
const G = preload("res://engine/scripts/core/content.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

# The slot-tile count in the overlay's grid (the kit lays the ladder out as one GridContainer).
func _grid_cells(overlay: Control) -> int:
	var grids := overlay.find_children("*", "GridContainer", true, false)
	return (grids[0] as GridContainer).get_child_count() if not grids.is_empty() else -1

# True if any Label in `overlay`'s subtree has exactly `text`.
func _has_label(overlay: Control, text: String) -> bool:
	for l in overlay.find_children("*", "Label", true, false):
		if String((l as Label).text) == text:
			return true
	return false

# Pull every slot of a given kind out of a plan, in order.
func _of_kind(plan: Array, kind: String) -> Array:
	var out: Array = []
	for e in plan:
		if e.kind == kind:
			out.append(e)
	return out

func _initialize() -> void:
	print("== Bag overlay tests ==")

	var prices: Array = G.BAG_SLOT_PRICES        # [10,10,10,15,15,15,20,20,20,25,25,25]
	var start: int = G.BAG_START_SLOTS           # 6
	var cap: int = G.BAG_MAX_SLOTS               # 18

	# 1. a fresh player (6 owned, empty bag): 18 tiles, the first 6 empty-owned, slot 7 the gold
	#    "next", slots 8..18 locked. The ladder length equals the cap.
	var fresh := BagOverlay.slot_plan(start, cap, 0, prices, start)
	ok(fresh.size() == cap, "the plan has one tile per slot up to the cap (%d)" % cap)
	ok(_of_kind(fresh, "empty").size() == start, "all %d starting slots read as owned-but-empty" % start)
	ok(_of_kind(fresh, "next").size() == 1, "exactly one slot is the purchasable (gold) next slot")
	ok(_of_kind(fresh, "locked").size() == cap - start - 1, "the rest (%d) are locked future slots" % (cap - start - 1))
	ok(fresh[start].kind == "next", "slot 7 (index 6) is the next slot")
	ok(int(fresh[start].price) == int(prices[0]), "the next slot's price is the first ladder rung (%d💎)" % int(prices[0]))
	ok(int(fresh[start + 1].price) == int(prices[1]), "the slot after next carries the SECOND rung's price")
	ok(int(fresh[cap - 1].price) == int(prices[prices.size() - 1]), "the last locked slot carries the final rung (%d💎)" % int(prices[prices.size() - 1]))

	# 2. a partly-filled bag: the first N owned slots hold pieces (in bag order), the rest are empty.
	var filled := BagOverlay.slot_plan(start, cap, 3, prices, start)
	var fl := _of_kind(filled, "filled")
	ok(fl.size() == 3, "three bagged pieces fill three tiles")
	ok(int(fl[0].index) == 0 and int(fl[1].index) == 1 and int(fl[2].index) == 2, "filled tiles carry the bag index 0,1,2 in order")
	ok(_of_kind(filled, "empty").size() == start - 3, "the remaining owned slots are empty")
	ok(filled[3].kind == "empty", "slot 4 (past the 3 pieces) is empty, not filled")

	# 3. a partly-expanded player (9 owned): owned slots stay 1..9, the next is slot 10 priced at the
	#    4th rung, the buy price matches content.gd's next_bag_slot_price (one source of truth).
	var expanded := BagOverlay.slot_plan(9, cap, 9, prices, start)
	ok(_of_kind(expanded, "filled").size() == 9, "nine owned+full slots all read as filled")
	ok(expanded[9].kind == "next", "slot 10 (index 9) is the next purchasable slot")
	ok(int(expanded[9].price) == G.next_bag_slot_price(9), "the next slot's price == G.next_bag_slot_price(owned)")

	# 4. a maxed player (18 owned): every tile is owned, NO next/locked tiles exist.
	var maxed := BagOverlay.slot_plan(cap, cap, cap, prices, start)
	ok(maxed.size() == cap, "a maxed bag still lists every slot")
	ok(_of_kind(maxed, "next").is_empty(), "a maxed bag offers no next-slot purchase")
	ok(_of_kind(maxed, "locked").is_empty(), "a maxed bag has no locked slots")
	ok(_of_kind(maxed, "filled").size() == cap, "every maxed slot holds a piece")

	# 5. the next slot's price always agrees with the live economy helper across the ladder.
	var price_ok := true
	for owned in range(start, cap):
		var plan := BagOverlay.slot_plan(owned, cap, 0, prices, start)
		if int(plan[owned].price) != G.next_bag_slot_price(owned):
			price_ok = false
	ok(price_ok, "the gold tile's price matches G.next_bag_slot_price at every owned count")

	# 6. build-smoke: open() assembles the modal under a host, built on the SHARED kit frame
	#    (engine ↔ workbench parity): the named DialogBanner + DialogClose ride INSIDE the card, the
	#    slot ladder is a grid of one tile per slot (the cap), and the reused acorn pill shows the
	#    balance. Then it frees without erroring.
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var overlay := BagOverlay.open(host, {
		"bag": [], "owned": start, "balance": 132,
		"max_slots": cap, "start_slots": start, "prices": prices,
		"on_retrieve": func(_i: int) -> void: pass,
		"on_buy_slot": func() -> void: pass,
	})
	ok(is_instance_valid(overlay) and overlay is Control, "open() returns a live Control overlay")
	ok(overlay.find_child("DialogBanner", true, false) != null, "the bag overlay rides the SHARED kit frame banner")
	ok(overlay.find_child("DialogClose", true, false) != null, "the shared frame's ✕ disc is docked on the bag card")
	ok(_grid_cells(overlay) == cap, "the slot ladder is a grid of one tile per slot (%d)" % cap)
	ok(_has_label(overlay, "132"), "the reused acorn pill shows the balance (132)")
	overlay.queue_free()
	host.queue_free()

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
