extends SceneTree
## Headless tests for the in-game IAP waiting overlay shown while StoreKit opens.
##   godot --headless --path . -s res://engine/tests/purchase_wait_tests.gd

const Overlay = preload("res://engine/scripts/ui/overlay.gd")
const PurchaseWait = preload("res://engine/scripts/ui/purchase_wait.gd")

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
	print("== Purchase wait overlay tests ==")

	var root := Control.new()
	root.name = "Host"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(root)

	var wait := PurchaseWait.show(root, "Opening App Store", "Please wait...")
	ok(wait != null and is_instance_valid(wait), "show returns a live overlay")
	ok(wait.name == "PurchaseWaitOverlay", "overlay has a stable test/debug name")
	ok(wait.get_parent() == root, "overlay attaches to the supplied host")
	ok(wait.anchor_left == 0.0 and wait.anchor_top == 0.0
		and wait.anchor_right == 1.0 and wait.anchor_bottom == 1.0,
		"overlay fills the host rect")
	ok(wait.z_index >= Overlay.MODAL_TOP_Z, "overlay sits at the modal layer")
	ok(_has_label(wait, "Opening App Store"), "overlay shows the title")
	ok(_has_label(wait, "Please wait..."), "overlay shows the wait message")
	ok(_has_non_empty_label_named(wait, "PurchaseWaitSpinner"), "overlay includes a visible spinner glyph")

	PurchaseWait.close(wait)
	await process_frame
	ok(not is_instance_valid(wait), "close frees the overlay")

	_assert_purchase_wait_wired("res://engine/scripts/ui/shop.gd", "shop real-IAP confirm")
	_assert_purchase_wait_wired("res://engine/scripts/ui/vault.gd", "vault real-IAP confirm")

	root.queue_free()
	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)

func _assert_purchase_wait_wired(path: String, label: String) -> void:
	var src := FileAccess.get_file_as_string(path)
	var preload_i := src.find("purchase_wait.gd")
	var show_i := src.find("PurchaseWait.show")
	var buy_i := src.find("Iap.buy")
	var close_i := src.find("PurchaseWait.close")
	ok(preload_i >= 0, "%s preloads the shared wait overlay" % label)
	ok(show_i >= 0 and buy_i >= 0 and show_i < buy_i,
		"%s shows the wait overlay before starting StoreKit" % label)
	ok(close_i >= 0 and buy_i >= 0 and close_i > buy_i,
		"%s closes the wait overlay from the StoreKit callback" % label)

func _has_label(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text == text:
		return true
	for child in node.get_children():
		if _has_label(child, text):
			return true
	return false

func _has_non_empty_label_named(node: Node, wanted_name: String) -> bool:
	if node is Label and node.name == wanted_name and (node as Label).text.strip_edges() != "":
		return true
	for child in node.get_children():
		if _has_non_empty_label_named(child, wanted_name):
			return true
	return false
