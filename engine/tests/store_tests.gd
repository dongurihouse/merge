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

class FakeTransaction extends RefCounted:
	var product_id := ""
	var transaction_id := ""
	var finished := 0
	func _init(pid: String, tid: String = "tx-1") -> void:
		product_id = pid
		transaction_id = tid
	func finish() -> void:
		finished += 1

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

	_test_successful_purchase_finishes_transaction_after_grant(pid)

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

func _test_successful_purchase_finishes_transaction_after_grant(pid: String) -> void:
	_reset_store_state()
	var tx := FakeTransaction.new(pid)
	var got := {"called": false, "ok": false, "finished_during_callback": -1}
	Store._pending_id = pid
	Store._pending_cb = func(success: bool) -> void:
		got.called = true
		got.ok = success
		got.finished_during_callback = tx.finished

	var completion := Callable(Store, "_on_purchase_completed")
	if not completion.is_valid():
		ok(false, "Store has a named purchase-completion handler")
		_reset_store_state()
		return
	completion.call(tx, Store.STATUS_OK, "")

	ok(got.called and got.ok, "successful StoreKit completion settles the pending purchase")
	ok(int(got.finished_during_callback) == 0,
		"the transaction is not finished until after the grant callback runs")
	ok(tx.finished == 1,
		"successful StoreKit transactions are finished so consumables cannot replay on the next buy")
	ok(Store._pending_id == "" and not Store._pending_cb.is_valid(),
		"successful StoreKit completion clears pending purchase state")
	_reset_store_state()

func _reset_store_state() -> void:
	Store._pending_id = ""
	Store._pending_cb = Callable()
