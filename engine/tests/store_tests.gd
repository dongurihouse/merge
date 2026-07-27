extends "res://engine/tests/test_base.gd"
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

func _initialize() -> void:
	print("== Store (IAP) tests ==")

	ok(not Store.available(), "StoreKit is unavailable without the iOS plugin (no class)")

	# The id-extraction the live match depends on: must read the StoreProduct `product_id` member.
	var pid := "com.dongurihouse.dongurimerge.piggybank"
	ok(Store._product_id(FakeProduct.new(pid)) == pid, "_product_id reads the StoreProduct product_id member")
	ok(Store._product_id(null) == "", "_product_id is safe on a null product")

	_test_successful_purchase_finishes_transaction_after_grant(pid)
	_test_a_stale_pending_purchase_is_abandoned(pid)

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

	finish()

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

# A DROPPED StoreKit signal must not wedge IAP for the process lifetime. `_pending_id` clears only in
# _settle(), which only the two native completion handlers reach — so if neither signal ever fires, the
# slot stays occupied forever and every later Confirm returns on_done(false) at once. ui/purchase_wait.gd
# gives the SHEET a 12s timeout, so the player's UI recovered while the state machine did not.
# Off iOS the replacement purchase still fails at _ensure() (no plugin), so what is asserted here is the
# part that survives without StoreKit: the wedge is cleared and the abandoned callback is settled false.
func _test_a_stale_pending_purchase_is_abandoned(pid: String) -> void:
	_reset_store_state()

	# A pending INSIDE the stale window is genuinely in flight (the native sheet may be open) — leave it.
	var in_flight := {"called": false}
	Store._pending_id = pid
	Store._pending_at_msec = Time.get_ticks_msec()
	Store._pending_cb = func(_success: bool) -> void:
		in_flight.called = true
	Store.purchase("com.dongurihouse.dongurimerge.gems_small", func(_success: bool) -> void: pass)
	ok(not in_flight.called and Store._pending_id == pid,
		"a purchase still inside the stale window keeps its slot and blocks a second purchase")

	# ...and one with no completion after PENDING_STALE_SECS is abandoned so the next purchase can run.
	_reset_store_state()
	var stale := {"called": false, "ok": true}
	Store._pending_id = pid
	Store._pending_at_msec = Time.get_ticks_msec() - int(Store.PENDING_STALE_SECS * 1000.0) - 1000
	Store._pending_cb = func(success: bool) -> void:
		stale.called = true
		stale.ok = success
	var second := {"called": false}
	Store.purchase("com.dongurihouse.dongurimerge.gems_small", func(_success: bool) -> void:
		second.called = true)

	ok(stale.called and stale.ok == false,
		"a pending purchase with no StoreKit completion is abandoned (its callback settles false)")
	ok(Store._pending_id == "" and not Store._pending_cb.is_valid(),
		"...and the in-flight slot is cleared, so a dropped signal cannot brick IAP for the process")
	ok(second.called, "the replacement purchase reports its own outcome instead of being refused silently")
	_reset_store_state()

func _reset_store_state() -> void:
	Store._pending_id = ""
	Store._pending_cb = Callable()
	Store._pending_at_msec = 0
