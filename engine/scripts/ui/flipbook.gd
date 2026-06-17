extends TextureRect
## A tiny frame-cycling sprite (a flipbook). Give it `frames` (an Array of Texture2D) and `fps`; it
## advances through them on a loop. Used for the chimney smoke (base_chimney's 9 growing puffs).

var frames: Array = []
var fps := 7.0
var _acc := 0.0
var _i := 0

func _process(delta: float) -> void:
	if frames.size() < 2:
		return
	_acc += delta
	var step := 1.0 / maxf(fps, 0.001)
	while _acc >= step:
		_acc -= step
		_i = (_i + 1) % frames.size()
		texture = frames[_i]
