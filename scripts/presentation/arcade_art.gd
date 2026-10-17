class_name ArcadeArt
extends RefCounted
## Complete, registered cels. Partial sets fall back to previously approved art.
## Drawing and collision use the same deterministic key; no render-time hitboxes.
static var data: Dictionary = {}


static func load_data() -> void:
	if not data.is_empty():
		return
	for id in ["marcelo", "rafael", "adriano"]:
		data[id] = JSON.parse_string(
			FileAccess.get_file_as_string("res://data/characters/%s-arcade-v8.json" % id)
		)

	for id in ["adriano", "joao"]:
		var revision: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://data/characters/%s-arcade-v9.json" % id)
		)
		if not data.has(id):
			data[id] = {"sheets": {}}
		data[id].sheets.merge(revision.sheets, true)

	var roll: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/characters/joao-powers-v10.json")
	)
	data.joao.sheets.merge(roll.sheets, true)

	data.gustavo = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/characters/gustavo-arcade-v11.json")
	)

static func pose(f: FighterModel) -> Dictionary:
	load_data()
	if not data.has(f.character.id):
		return {}
	var selected := FighterPose.select(f)
	if not data[f.character.id].sheets.has(selected.key):
		return {}
	return selected


static func has_frame(f: FighterModel) -> bool:
	return not pose(f).is_empty()


static func frame(f: FighterModel) -> Dictionary:
	var selected := pose(f)
	if selected.is_empty():
		return {}
	var sheet: Dictionary = data[f.character.id].sheets[selected.key]
	return {
		"key": selected.key,
		"index": selected.index,
		"sheet": sheet,
		"frame": sheet.frames[int(selected.index)]
	}
