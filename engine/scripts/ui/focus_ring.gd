@tool
extends Control
## The SELECTED-cell focus frame: four L-shaped brackets hugging the cell corners — the
## "this cell is focused" cue that makes the tap-to-focus / tap-again-to-collect interaction
## visible (board.gd _show_focus). A soft wider underlay keeps the gold legible on any tile.
## Never eats input (the board surface stays the single input target).

# --- TWEAK THE LOOK HERE (live-editable in the UI workbench → "Focus ring") --------
@export var color := Color("#33402F"): set = _set_color   # bracket colour — high-contrast on the cream cell + the gold coin
@export var halo_color := Color("#FBF3EA"): set = _set_halo_color  # the light outline drawn BEHIND the brackets so they pop on any background
@export var halo_a := 0.9: set = _set_halo_a            # halo opacity
@export var arm_frac := 0.30: set = _set_arm            # bracket arm length as a fraction of the cell
@export var thick_frac := 0.08: set = _set_thick        # bracket line thickness as a fraction of the cell
@export var pad_frac := 0.04: set = _set_pad            # inset of the bracket from the cell edge
@export var halo := true: set = _set_halo               # a light underlay so the brackets stay legible over dark art
# -------------------------------------------------------------------------------------

func _set_color(v: Color) -> void: color = v; queue_redraw()
func _set_halo_color(v: Color) -> void: halo_color = v; queue_redraw()
func _set_halo_a(v: float) -> void: halo_a = v; queue_redraw()
func _set_arm(v: float) -> void: arm_frac = v; queue_redraw()
func _set_thick(v: float) -> void: thick_frac = v; queue_redraw()
func _set_pad(v: float) -> void: pad_frac = v; queue_redraw()
func _set_halo(v: bool) -> void: halo = v; queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	var s: float = minf(size.x, size.y)
	if s <= 0.0:
		return
	var pad := s * pad_frac
	var arm := s * arm_frac
	var w := maxf(2.0, s * thick_frac)
	var lo := pad
	var hi := s - pad
	# Each entry: the corner point + the two unit directions its L-arms extend along.
	var corners := [
		[Vector2(lo, lo), Vector2(1, 0), Vector2(0, 1)],    # top-left
		[Vector2(hi, lo), Vector2(-1, 0), Vector2(0, 1)],   # top-right
		[Vector2(lo, hi), Vector2(1, 0), Vector2(0, -1)],   # bottom-left
		[Vector2(hi, hi), Vector2(-1, 0), Vector2(0, -1)],  # bottom-right
	]
	if halo:
		var hcol := Color(halo_color, halo_a)
		for c in corners:
			_bracket(c[0], c[1], c[2], arm, w + maxf(3.0, s * 0.03), hcol)   # a light, wider outline behind
	for c in corners:
		_bracket(c[0], c[1], c[2], arm, w, color)

# One corner bracket: a connected L (arm → corner → arm) so the join is solid, not a gap.
func _bracket(p: Vector2, dx: Vector2, dy: Vector2, arm: float, w: float, col: Color) -> void:
	var pts := PackedVector2Array([p + dy * arm, p, p + dx * arm])
	draw_polyline(pts, col, w, true)
