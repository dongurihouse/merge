extends SceneTree
## Headless tests for the IAP provider (core/store.gd) — the part that CAN run off iOS: with no StoreKit
## plugin it must report unavailable and fail purchases at once, so callers take their honest
## non-charging path. The live purchase flow is iOS-only and not exercised here.
##   godot --headless -s res://engine/tests/store_tests.gd

const Store = preload("res://engine/scripts/core/store.gd")

# A stand-in for GodotApplePlugins' StoreProduct: the plugin exposes the App Store id as the
# `product_id` property (getter get_product_id) — NOT `id`. _product_id() must read that member,
# or _on_products can never match the requested id and every purchase silently settles false.
class FakeProduct extends RefCounted:
	var product_id := ""
	func _init(pid: String) -> void:
		product_id = pid

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
	print("== Store (IAP) tests ==")

	ok(not Store.available(), "StoreKit is unavailable without the iOS plugin (no class)")

	# The id-extraction the live match depends on: must read the StoreProduct `product_id` member.
	var pid := "com.dongurihouse.dongurimerge.piggybank"
	ok(Store._product_id(FakeProduct.new(pid)) == pid, "_product_id reads the StoreProduct product_id member")
	ok(Store._product_id(null) == "", "_product_id is safe on a null product")

	var got := {"called": false, "ok": true}
	Store.purchase("com.dongurihouse.dongurimerge.piggybank", func(success: bool) -> void:
		got.called = true
		got.ok = success)
	ok(got.called and got.ok == false, "a purchase fails immediately when StoreKit is unavailable")

	var restored := {"called": false, "ok": true}
	Store.restore(func(success: bool) -> void:
		restored.called = true
		restored.ok = success)
	ok(restored.called and restored.ok == false, "restore reports false when StoreKit is unavailable")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
