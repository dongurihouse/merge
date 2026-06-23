extends SceneTree
## Headless tests for the IAP catalog (core/iap.gd + data/iap_products.json) — the lookup that CAN run
## off iOS. Verifies every product resolves to a well-formed App Store id/price, that the catalog is the
## single source of truth, and that off-StoreKit buy()/charging() take the honest non-charging path.
##   godot --headless -s res://engine/tests/iap_tests.gd

const Iap = preload("res://engine/scripts/core/iap.gd")

# Every key the game buys by (mirrors the grove tags: vault, shop ladder, starter, out-of-water offer).
const EXPECTED := [
	"piggybank", "starter", "water_offer",
	"gems_tier1", "gems_tier2", "gems_tier3", "gems_tier4", "gems_tier5", "gems_tier6",
]

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _initialize() -> void:
	print("== IAP catalog tests ==")

	var keys := Iap.keys()
	ok(keys.size() >= EXPECTED.size(), "catalog loads (%d products)" % keys.size())

	var ids := {}
	for key in EXPECTED:
		var pid := Iap.product_id(key)
		var price := Iap.usd(key)
		ok(pid.begins_with("com.") and pid.length() <= 100, "%s → valid product id (%s)" % [key, pid])
		ok(price.begins_with("$"), "%s → a displayed price (%s)" % [key, price])
		ok(Iap.type(key) == "Consumable", "%s is a Consumable" % key)
		ok(Iap.reference_name(key) != "", "%s has an App Store reference name" % key)
		ids[pid] = int(ids.get(pid, 0)) + 1
	# product ids must be unique — a dup would map two products to one App Store SKU.
	var dupes := 0
	for pid in ids:
		if int(ids[pid]) > 1:
			dupes += 1
	ok(dupes == 0, "every product id is unique")

	# Graceful on a bad key (→ "", so a typo can never crash a buy flow).
	ok(Iap.product_id("nope") == "" and Iap.usd("nope") == "", "an unknown key resolves to empty, not a crash")

	# Off iOS / without the plugin: no real charge, and buy() fails at once so callers grant directly.
	ok(not Iap.charging(), "charging() is false without the iOS plugin (honest test path)")
	var got := {"called": false, "ok": true}
	Iap.buy("piggybank", func(success: bool) -> void:
		got.called = true
		got.ok = success)
	ok(got.called and got.ok == false, "buy() fails immediately off-StoreKit (caller falls back to its grant)")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
