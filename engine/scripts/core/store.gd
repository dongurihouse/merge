extends RefCounted
## IN-APP PURCHASES (StoreKit 2) — a thin provider over GodotApplePlugins' `StoreKitManager`. Off iOS /
## without the plugin available() is false, so purchase() reports failure at once and callers fall back to
## their honest non-charging path. Reached via ClassDB (plugin-only class — a bare `StoreKitManager` would
## fail to PARSE on desktop/headless). See docs/design/apple-services-setup.md for product config.
##
## API used (GodotApplePlugins StoreKitManager, verified):
##   start() · request_products(PackedStringArray) · purchase(StoreProduct) · restore_purchases()
##   signal products_request_completed(products: Array, status: int)
##   signal purchase_completed(transaction, status: int, error_message: String)
##   signal restore_completed(status: int, error_message: String)
##
## CONFIRM-ON-DEVICE (isolated below — undocumented specifics, a one-line fix after one sandbox buy):
##   • STATUS_OK — the `status` int that means "purchased" / "restored".
##   • _product_id() — the StoreProduct's id property name (Apple's Product.id → expected "id").

const SK_CLASS := "StoreKitManager"
const STATUS_OK := 0

static var _sk: Object = null
static var _pending_id := ""                        # one purchase in flight at a time (IAP is modal)
static var _pending_cb := Callable()

## True only on an iOS build that bundles the plugin — the gate for every native touch and the signal that
## a Confirm will move REAL money. Callers use the honest non-charging path when this is false. The plugin
## also ships macOS frameworks (so its GDExtension loads cleanly in the desktop editor), which register
## `StoreKitManager` on the dev Mac too; the `ios` feature check keeps this iPad-only game inert there.
static func available() -> bool:
	return ClassDB.class_exists(SK_CLASS) and OS.has_feature("ios")

# Lazily build + start the manager and wire its signals. False when StoreKit is unavailable.
static func _ensure() -> bool:
	if not available():
		return false
	if _sk == null:
		_sk = ClassDB.instantiate(SK_CLASS)
		if _sk == null:
			return false
		_sk.connect("products_request_completed", func(products: Array, _status: int) -> void:
			_on_products(products))
		_sk.connect("purchase_completed", func(_tx: Object, status: int, _err: String) -> void:
			_settle(status == STATUS_OK))
		_sk.call("start")
	return true

## Buy `product_id`. on_done(success: bool) fires when settled. Immediately false — so the caller takes its
## honest non-charging fallback — when StoreKit is unavailable or another purchase is already in flight.
static func purchase(product_id: String, on_done: Callable) -> void:
	if not _ensure() or _pending_id != "":
		if on_done.is_valid():
			on_done.call(false)
		return
	_pending_id = product_id
	_pending_cb = on_done
	_sk.call("request_products", PackedStringArray([product_id]))   # → _on_products → purchase the match

static func _on_products(products: Array) -> void:
	for p in products:
		if _product_id(p) == _pending_id:
			_sk.call("purchase", p)
			return
	_settle(false)                                  # the product id wasn't found in App Store Connect

static func _product_id(p: Object) -> String:
	return String(p.get("id")) if p != null else ""

static func _settle(success: bool) -> void:
	var cb := _pending_cb
	_pending_id = ""
	_pending_cb = Callable()
	if cb.is_valid():
		cb.call(success)

## Restore non-consumable purchases (an App Store requirement). on_done(ok). No-op false off iOS.
static func restore(on_done: Callable = Callable()) -> void:
	if not _ensure():
		if on_done.is_valid():
			on_done.call(false)
		return
	if on_done.is_valid():
		_sk.connect("restore_completed", func(status: int, _err: String) -> void:
			on_done.call(status == STATUS_OK), CONNECT_ONE_SHOT)
	_sk.call("restore_purchases")
