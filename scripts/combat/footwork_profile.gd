class_name FootworkProfile
extends RefCounted
## Distâncias, tempos e cancelamento importados por estilo; nunca concede invencibilidade.
static var profiles: Dictionary = {}


static func get_profile(id: String) -> Dictionary:
	if profiles.is_empty():
		profiles = (
			JSON
			. parse_string(FileAccess.get_file_as_string("res://data/characters/footwork-v1.json"))
			. profiles
		)
	return profiles.get(id, {})
