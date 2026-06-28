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
## CONFIRM-ON-DEVICE — both verified against the plugin's bundled doc classes (addons/…StoreKit):
##   • STATUS_OK = 0 — StoreKitStatus.OK; the other statuses are INVALID_PRODUCT=1, CANCELLED=2,
##     UNVERIFIED_TRANSACTION=3, USER_CANCELLED=4, PURCHASE_PENDING=5, UNKNOWN_STATUS=6.
##   • _product_id() reads the StoreProduct `product_id` member (getter get_product_id) — NOT `id`,
##     which does not exist on the plugin's StoreProduct (reading it returned null → String(null) threw,
##     so every live purchase silently failed before opening the payment sheet).

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
		_sk.connect("purchase_completed", func(_tx: Object, status: int, err: String) -> void:
			if status != STATUS_OK:
				push_warning("Store: purchase_completed status=%d (not OK) err=\"%s\"" % [status, err])
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
	# No match → the payment sheet never opens. This is the silent dead-end behind "Confirm does
	# nothing": almost always an empty/mismatched products response (the id isn't live in App Store
	# Connect, agreements unsigned, or the wrong bundle id). Logged so the device console shows it.
	push_warning("Store: product \"%s\" not in the %d returned product(s) — purchase aborted" % [_pending_id, products.size()])
	_settle(false)

static func _product_id(p: Object) -> String:
	if p == null:
		return ""
	var v: Variant = p.get("product_id")            # the plugin's StoreProduct id member (getter get_product_id)
	return String(v) if v != null else ""

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
