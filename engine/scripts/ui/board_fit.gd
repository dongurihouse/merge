extends RefCounted
## Shared board-fit math for framed merge grids placed between a top band
## and a bottom action or hint band.

static func fit_bottom_aligned(
		view: Vector2,
		cols: int,
		rows: int,
		gap: float,
		frame_out: float,
		side_margin: float,
		top_limit_y: float,
		bottom_limit_y: float,
		scale: float = 1.0,
		min_cell: float = 0.0,
		floor_cell: bool = false) -> Dictionary:
	var safe_cols: int = maxi(1, cols)
	var safe_rows: int = maxi(1, rows)
	var gutters_w := float(safe_cols - 1) * gap
	var gutters_h := float(safe_rows - 1) * gap
	var available_h := maxf(1.0, bottom_limit_y - top_limit_y)
	var w_csz := (view.x - 2.0 * side_margin - 2.0 * frame_out - gutters_w) / float(safe_cols)
	var h_csz := (available_h - 2.0 * frame_out - gutters_h) / float(safe_rows)
	var max_cell := maxf(1.0, minf(w_csz, h_csz))
	var cell := max_cell * scale
	if min_cell > 0.0 and max_cell >= min_cell:
		cell = maxf(min_cell, cell)
	if floor_cell:
		cell = floorf(cell)
	cell = maxf(1.0, cell)

	var grid_size := Vector2(
		float(safe_cols) * cell + gutters_w,
		float(safe_rows) * cell + gutters_h)
	var visual_size := grid_size + Vector2(frame_out * 2.0, frame_out * 2.0)
	var ideal_grid_x := (view.x - grid_size.x) * 0.5
	var min_grid_x := side_margin + frame_out
	var max_grid_x := view.x - side_margin - frame_out - grid_size.x
	var grid_x := ideal_grid_x
	if max_grid_x >= min_grid_x:
		grid_x = clampf(ideal_grid_x, min_grid_x, max_grid_x)
	var grid_y := maxf(top_limit_y + frame_out, bottom_limit_y - frame_out - grid_size.y)
	var grid_position := Vector2(grid_x, grid_y)
	var visual_rect := Rect2(grid_position - Vector2(frame_out, frame_out), visual_size)
	return {
		"cell": cell,
		"grid_size": grid_size,
		"grid_position": grid_position,
		"visual_size": visual_size,
		"visual_rect": visual_rect,
		"top_limit_y": top_limit_y,
		"bottom_limit_y": bottom_limit_y,
	}
