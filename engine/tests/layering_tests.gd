extends SceneTree
## Headless guard for the engine layering invariant.
##   godot --headless --path . -s res://engine/tests/layering_tests.gd
## Imports may only flow scenes/ -> ui/ -> core/. This proves the direction holds:
## core/ never reaches up into ui/ or scenes/, and ui/ never reaches into scenes/.
## See docs/core/ui_backend_separation.md §1.

const CORE := "res://engine/scripts/core/"
const UI := "res://engine/scripts/ui/"
const SCENES := "res://engine/scripts/scenes/"

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _gd_files(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir + f)
	return out

# True if `path` mentions `needle` anywhere (preload/load both look like a path string).
func _reads(path: String, needle: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var t := f.get_as_text()
	f.close()
	return t.find(needle) != -1

func _initialize() -> void:
	print("== Engine layering guard ==")
	var core := _gd_files(CORE)
	var ui := _gd_files(UI)
	ok(core.size() >= 1, "core/ has scripts (%d found)" % core.size())
	ok(ui.size() >= 1, "ui/ has scripts (%d found)" % ui.size())
	# core/ is the bottom layer — it must not import ui/ or scenes/.
	for p in core:
		var base := p.get_file()
		ok(not _reads(p, UI), "core/%s does not import ui/" % base)
		ok(not _reads(p, SCENES), "core/%s does not import scenes/" % base)
	# ui/ is the middle layer — it must not import scenes/ (the top).
	for p in ui:
		ok(not _reads(p, SCENES), "ui/%s does not import scenes/" % p.get_file())
	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
