class_name ImpactArtV11
extends RefCounted
static var data: Dictionary = {}


static func draw(
	c: CanvasItem, clip: String, exposure: int, size: float, tint := Color.WHITE
) -> void:
	if data.is_empty():
		data = JSON.parse_string(
			FileAccess.get_file_as_string("res://data/characters/impact-cels-v11.json")
		)
	var indices: Array = data.clips[clip]
	var f: Dictionary = data.frames[int(indices[posmod(exposure, indices.size())])]
	var r: Array = f.rect
	var anchor := Vector2(f.anchor[0], f.anchor[1])
	c.draw_texture_rect_region(
		LegacyRoster.texture(data.image),
		Rect2(-anchor * size, Vector2(r[2], r[3]) * size),
		Rect2(r[0], r[1], r[2], r[3]),
		tint
	)
