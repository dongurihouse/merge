extends SceneTree
## Headless tests for the IAP provider (core/store.gd) — the part that CAN run off iOS: with no StoreKit
## plugin it must report unavailable and fail purchases at once, so callers take their honest
## non-charging path. The live purchase flow is iOS-only and not exercised here.
##   godot --headless -s res://engine/tests/store_tests.gd

const Store = preload("res://engine/scripts/core/store.gd")

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

	var got := {"called": false, "ok": true}
	Store.purchase("com.tidyup.piggybank", func(success: bool) -> void:
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
