class_name PowerCelsV10
extends RefCounted
## Neutral hand-drawn cels tinted per fighter; no collision or simulation clocks.
static var data: Dictionary = {}


static func draw(c: CanvasItem, clip: String, frame: int, scale_factor: float, tint: Color) -> void:
	if data.is_empty():
		data = JSON.parse_string(
			FileAccess.get_file_as_string("res://data/characters/power-cels-v10.json")
		)
	var indices: Array = data.clips[clip]
	var cel: Dictionary = data.frames[int(indices[posmod(frame, indices.size())])]
	var rect: Array = cel.rect
	c.draw_texture_rect_region(
		LegacyRoster.texture(data.image),
		Rect2(
			-Vector2(cel.anchor[0], cel.anchor[1]) * scale_factor,
			Vector2(rect[2], rect[3]) * scale_factor
		),
		Rect2(rect[0], rect[1], rect[2], rect[3]),
		tint
	)
