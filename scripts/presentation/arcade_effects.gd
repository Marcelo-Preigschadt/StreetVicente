class_name ArcadeEffects
extends RefCounted
## Authored contact/power cels. All clocks are presentation-only.
static var data: Dictionary = {}


static func load_data() -> void:
	if data.is_empty():
		data = JSON.parse_string(
			FileAccess.get_file_as_string("res://data/characters/arcade-effects-v8.json")
		)


static func draw_cel(
	canvas: CanvasItem, clip: String, exposure: int, scale_factor: float, tint := Color.WHITE
) -> void:
	load_data()
	var selected: Array = data.clips[clip]
	var frame: Dictionary = data.frames[int(selected[posmod(exposure, selected.size())])]
	var r: Array = frame.rect
	canvas.draw_texture_rect_region(
		LegacyRoster.texture(data.image),
		Rect2(
			-float(frame.anchor[0]) * scale_factor,
			-float(frame.anchor[1]) * scale_factor,
			float(r[2]) * scale_factor,
			float(r[3]) * scale_factor
		),
		Rect2(r[0], r[1], r[2], r[3]),
		tint
	)
