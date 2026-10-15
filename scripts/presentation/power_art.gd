class_name PowerArt
extends RefCounted
## Hand-drawn VFX atlas. Animation exposure is presentation; collision stays in PowerSystem.
static var data: Dictionary = {}


static func load_data() -> void:
	if data.is_empty():
		data = JSON.parse_string(
			FileAccess.get_file_as_string("res://data/characters/power-effects-v1.json")
		)


static func theme(character: String, effect: String = "") -> String:
	match character:
		"marcelo":
			return "code"
		"gustavo":
			return "smoke"
		"khauany":
			return "fork"
		"dienes":
			return "chalk" if effect == "chalkShot" else "book"
		"rafael", "adriano":
			return "scroll"
		"ruan", "joao":
			return "lightning"
		"gelton":
			return "paint"
	return "ribbon"


static func draw(
	canvas: CanvasItem,
	clip: String,
	frame: int,
	scale_factor: float = 1.0,
	tint: Color = Color.WHITE
) -> void:
	load_data()
	var keys: Array = data.clips[clip]
	var f: Dictionary = data.frames[int(keys[posmod(frame, keys.size())])]
	var r: Array = f.rect
	var a: Array = f.anchor
	canvas.draw_texture_rect_region(
		LegacyRoster.texture(data.image),
		Rect2(
			-float(a[0]) * scale_factor,
			-float(a[1]) * scale_factor,
			float(r[2]) * scale_factor,
			float(r[3]) * scale_factor
		),
		Rect2(r[0], r[1], r[2], r[3]),
		tint
	)
