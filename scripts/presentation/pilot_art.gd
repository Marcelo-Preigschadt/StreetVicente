class_name PilotArt
extends RefCounted
## New drawings are presentation only. Combat tick and phase select the exposed key.
## No mesh deformation/interpolated invented poses; root interpolation stays separate.
static var data: Dictionary = {}


static func load_data() -> void:
	if data.is_empty():
		data = JSON.parse_string(
			FileAccess.get_file_as_string("res://data/characters/marcelo-art-v1.json")
		)
		data.sheets.air = JSON.parse_string(
			FileAccess.get_file_as_string("res://data/characters/marcelo-air-v2.json")
		)


static func frame(f: FighterModel) -> Dictionary:
	load_data()
	var arcade := ArcadeArt.frame(f)
	if not arcade.is_empty():
		return arcade
	var pose := FighterPose.select(f)
	var atlas: Dictionary = data.sheets[pose.key]
	return {"sheet": atlas, "frame": atlas.frames[pose.index], "key": pose.key, "index": pose.index}
