class_name CombatGeometry
extends RefCounted
## Immutable, precomputed integer geometry registered to the rendered drawings.
static var profiles: Dictionary = {}


static func load_data() -> void:
	if profiles.is_empty():
		profiles = JSON.parse_string(
			FileAccess.get_file_as_string("res://data/characters/combat-profiles-v3.json")
		)


static func frame(f: FighterModel) -> Dictionary:
	load_data()
	var arcade := ArcadeArt.frame(f)
	if not arcade.is_empty():
		return arcade.frame.collision
	if not profiles.has(f.character.id):
		return {}
	var pose: Dictionary
	if CharacterArt.has_frame(f):
		pose = CharacterArt.pose(f)
	else:
		var old: Array = f.character.pose_frame(f).pose
		pose = {"key": old[0], "index": int(old[1])}
	var frames: Array = profiles[f.character.id].frames.get(pose.key, [])
	return frames[int(pose.index)] if int(pose.index) < frames.size() else {}


static func attack(f: FighterModel):
	if f.state != FighterState.Id.ATTACK:
		return null
	if (
		f.character.id not in ["marcelo", "rafael", "adriano", "joao"]
		and not (f.character.id == "gustavo" and CharacterArt.has_frame(f))
	):
		return null
	var move := f.current_move()
	if (
		str(move.legacy.get("name", ""))
		not in ["punch", "kick", "crouchPunch", "sweep", "airPunch", "airKick", "uppercut"]
	):
		return null
	var result: Array[Rect2i] = []
	if move.phase(f.move_tick) != "ACTIVE":
		return result
	var data := frame(f)
	if data.has("hit"):
		var b: Array = data.hit
		result.append(
			BoxMath.world_rect(
				CharacterMetrics.rect(
					f.character.id, Rect2i(int(b[0]), int(b[1]), int(b[2]), int(b[3]))
				),
				f.x,
				f.y,
				f.facing
			)
		)
	return result


static func half_width(f: FighterModel) -> int:
	load_data()
	return (
		CharacterMetrics.units(
			f.character.id, int(profiles.get(f.character.id, {}).get("push_half", 38))
		)
		* FighterModel.SCALE
	)


static func hand(f: FighterModel) -> Vector2i:
	var socket: Array = frame(f).get("hand", [134, -199])
	return Vector2i(
		(
			f.x
			+ CharacterMetrics.units(f.character.id, int(socket[0])) * f.facing * FighterModel.SCALE
		),
		f.y + CharacterMetrics.units(f.character.id, int(socket[1])) * FighterModel.SCALE
	)
