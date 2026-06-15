extends SceneTree
## Headless tests for the §13 "emoji purge" in runtime reward floaters (T32).
##   godot --headless --path . -s res://engine/tests/floater_tests.gd
## Proves FX.floating_reward / FX.celebrate_reward build an ICON SPRITE next to a
## NUMBER-ONLY label — the number is pure ASCII ("+N"), never an emoji glyph baked
## into the text, and each currency id maps to a real Look.icon. (The icon node's OWN
## code-drawn glyph fallback is the spec's sanctioned "ships twice" fallback — it is a
## separate child from the number label and is deliberately NOT asserted emoji-free.)

const FX = preload("res://engine/scripts/ui/fx.gd")
const Look = preload("res://engine/scripts/ui/skin.gd")
const Features = preload("res://engine/scripts/core/features.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

# A string is "ASCII number text" if every codepoint is low (< 0x2000 — well below
# any emoji or the ★/glyph block) and it reads as an optional sign + digits.
func _is_plain_number(s: String) -> bool:
	for cp in s.to_utf32_buffer():
		if cp > 0x2000:
			return false
	var re := RegEx.new()
	re.compile("^[+\\-]?[0-9]+$")
	return re.search(s) != null

func _has_emoji(s: String) -> bool:
	for cp in s.to_utf32_buffer():
		if cp > 0x2000:
			return true
	return false

# Walk a node tree; collect every Label's text.
func _labels(n: Node, out: Array) -> void:
	if n is Label:
		out.append((n as Label).text)
	for c in n.get_children():
		_labels(c, out)

# True if the subtree contains an "icon" node: a TextureRect (kit sprite) OR a Label
# whose text is NOT a plain number (the code-drawn glyph fallback — ★/🪙/💧/💎/etc.).
func _has_icon(n: Node) -> bool:
	if n is TextureRect:
		return true
	if n is Label and not _is_plain_number((n as Label).text):
		return true
	for c in n.get_children():
		if _has_icon(c):
			return true
	return false

# The number label is the lone Label whose text is a plain number. Returns "" if none.
func _number_text(n: Node) -> String:
	var found := ""
	var stack: Array = [n]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is Label and _is_plain_number((cur as Label).text):
			found = (cur as Label).text
		for c in cur.get_children():
			stack.append(c)
	return found

func _initialize() -> void:
	print("== Floater emoji-purge tests (§13) ==")
	# the helpers are flag-gated; force them ON so this runs deterministically
	Features.FLAGS["floaters"] = true
	Features.FLAGS["celebrate_bursts"] = true

	# a real in-tree host so create_tween() works (tweens need a node in the tree)
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(host)

	# the four engine currencies → their canonical Look.icon ids (§13 / ICON_GLYPHS)
	var cases := {"star": 5, "coin": 7, "water": 48, "gem": 1}

	for id in cases.keys():
		var amount: int = cases[id]

		# 1. Look.icon(id) resolves to a real Control (not null) for every currency
		var ic := Look.icon(id, 28.0)
		ok(ic != null and is_instance_valid(ic), "Look.icon(\"%s\") returns a real control" % id)

		# 2. floating_reward builds a node tree: an icon child + a number-only label
		var node := FX.floating_reward(host, Vector2(100, 100), id, amount, Color.WHITE)
		ok(node != null and is_instance_valid(node), "floating_reward(\"%s\") returns a node" % id)
		if node == null:
			continue
		ok(_has_icon(node), "floating_reward(\"%s\") tree contains an icon sprite child" % id)

		# 3. the NUMBER label is present, pure ASCII, equals the expected "+N", emoji-free
		var num := _number_text(node)
		ok(num != "", "floating_reward(\"%s\") has a numeric label" % id)
		ok(num == "+%d" % amount, "floating_reward(\"%s\") number label is \"+%d\" (got \"%s\")" % [id, amount, num])
		ok(not _has_emoji(num), "floating_reward(\"%s\") number label has NO emoji / codepoint > 0x2000" % id)
		ok(_is_plain_number(num), "floating_reward(\"%s\") number label matches a plain +N pattern" % id)

	# 4. a custom prefix is still ASCII-clean (e.g. a bare count, no leading +)
	var bare := FX.floating_reward(host, Vector2(0, 0), "coin", 3, Color.WHITE, 26, "")
	ok(bare != null, "floating_reward with an empty prefix returns a node")
	if bare != null:
		ok(_number_text(bare) == "3", "empty-prefix number label is the bare count \"3\"")

	# 5. celebrate_reward routes its currency feedback through the same icon+number path
	var before := host.get_child_count()
	FX.celebrate_reward(host, Vector2(50, 50), "star", 12, Color.WHITE)
	ok(host.get_child_count() > before, "celebrate_reward adds nodes to the host")
	var celeb_node: Node = null
	for c in host.get_children():
		var t := _number_text(c)
		if t == "+12":
			celeb_node = c
			break
	ok(celeb_node != null, "celebrate_reward floats an icon+number with a numeric \"+12\" label")
	if celeb_node != null:
		ok(_has_icon(celeb_node), "celebrate_reward floater contains an icon sprite")
		ok(not _has_emoji(_number_text(celeb_node)), "celebrate_reward number label has NO emoji")

	# 6. gated OFF → the helper is a no-op (returns null), never a stray emoji label
	Features.FLAGS["floaters"] = false
	ok(FX.floating_reward(host, Vector2.ZERO, "coin", 9, Color.WHITE) == null, "floating_reward is a no-op when the floaters flag is off")
	Features.FLAGS["floaters"] = true

	host.queue_free()
	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
