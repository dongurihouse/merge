extends RefCounted
## IN-APP PURCHASE CATALOG — the single lookup over data/iap_products.json (the one place that maps a
## logical product KEY → its App Store Connect product id, displayed price, type, and reference name).
## grove_data.gd carries the grant AMOUNTS (gems/water) and tags each purchasable with a `key`; the UI
## reads the price via usd(key); the buy seam routes through buy(key, …) into StoreKit (core/store.gd).
##
## Off iOS / without the plugin, charging() is false, so callers take their honest non-charging path
## (the grant happens directly, "(test build — nothing is charged)") — exactly as before the wiring.
## See docs/design/apple-services-setup.md for the App Store Connect setup.

const Store = preload("res://engine/scripts/core/store.gd")
const CATALOG_PATH := "res://data/iap_products.json"

static var _cat: Dictionary = {}                    # key → {product_id, usd, type, reference_name}
static var _loaded := false

# Lazily parse the catalog once. Malformed / missing → empty (warned), so a bad file can never crash a
# purchase flow — callers just see "" ids (→ honest path) instead.
static func _catalog() -> Dictionary:
	if _loaded:
		return _cat
	_loaded = true
	if not FileAccess.file_exists(CATALOG_PATH):
		push_warning("Iap: catalog missing at %s" % CATALOG_PATH)
		return _cat
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if parsed is Dictionary and parsed.has("products") and parsed["products"] is Dictionary:
		_cat = parsed["products"]
	else:
		push_warning("Iap: %s has no `products` object" % CATALOG_PATH)
	return _cat

static func _entry(key: String) -> Dictionary:
	var c := _catalog()
	if not c.has(key):
		push_warning("Iap: unknown product key \"%s\"" % key)
		return {}
	return c[key]

## The App Store Connect product id for `key` (the string StoreKit buys), or "" if unknown.
static func product_id(key: String) -> String:
	return String(_entry(key).get("product_id", ""))

## The displayed price string for `key` (e.g. "$2.99"), or "" if unknown.
static func usd(key: String) -> String:
	return String(_entry(key).get("usd", ""))

## The App Store product type for `key` (e.g. "Consumable").
static func type(key: String) -> String:
	return String(_entry(key).get("type", ""))

## The App Store Connect reference name for `key` (internal label).
static func reference_name(key: String) -> String:
	return String(_entry(key).get("reference_name", ""))

## Every product key in the catalog.
static func keys() -> Array:
	return _catalog().keys()

## True only on an iOS build that bundles the plugin — i.e. a Confirm WILL move real money. False on
## desktop/headless/off-plugin, where callers grant directly via their honest non-charging path.
static func charging() -> bool:
	return Store.available()

## Buy `key`. on_done(success: bool) fires when settled. Immediately false (so the caller can take its
## honest non-charging fallback) when StoreKit is unavailable or the id is unknown/missing in ASC.
static func buy(key: String, on_done: Callable) -> void:
	Store.purchase(product_id(key), on_done)
