class_name CharacterArt
extends RefCounted
## Shared renderer/geometry exposure. Unmigrated moves retain the original atlas.
static var additions: Dictionary = {}


static func load_data() -> void:
	if not additions.is_empty():
		return
	for id in ["rafael", "gustavo"]:
		additions[id] = JSON.parse_string(
			FileAccess.get_file_as_string("res://data/characters/%s-art-v5.json" % id)
		)


static func has_frame(f: FighterModel) -> bool:
	load_data()
	return (
		f.character.id == "marcelo"
		or (
			additions.has(f.character.id)
			and (
				f.state == FighterState.Id.IDLE
				or (
					f.state == FighterState.Id.ATTACK
					and f.current_move().legacy.get("name", "") == "punch"
				)
			)
		)
	)


static func pose(f: FighterModel) -> Dictionary:
	if f.character.id == "marcelo":
		return FighterPose.select(f)
	var index := 0 if (f.state_tick / 40) % 2 == 0 else 7
	if f.state == FighterState.Id.ATTACK:
		index = FighterPose.move_key(f.move_tick, f.current_move(), [0, 1, 2], [3, 4], [5, 6, 7])
	return {"key": "punch_v5", "index": index}


static func frame(f: FighterModel) -> Dictionary:
	load_data()
	if f.character.id == "marcelo":
		return PilotArt.frame(f)
	if has_frame(f):
		var selected := pose(f)
		var sheet: Dictionary = additions[f.character.id]
		return {
			"key": selected.key,
			"index": selected.index,
			"sheet": sheet,
			"frame": sheet.frames[selected.index]
		}
	var selected: Array = f.character.pose_frame(f).pose
	var sheet: Dictionary = f.character.legacy.atlases[selected[0]]
	return {
		"key": selected[0],
		"index": int(selected[1]),
		"sheet": sheet,
		"frame": sheet.frames[int(selected[1])]
	}
