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
		f.current_move().legacy.get("name", "") == "uppercut"
		and PowerMoves.UPPER.has(f.character.id)
	):
		var boxes := PowerMoves.upper_boxes(f)
		if f.current_move().phase(f.move_tick) == "ACTIVE":
			var band = frame(f).get("hit", f.character.pose_frame(f).get("hit"))
			if band is Array:
				boxes.append(
					BoxMath.world_rect(
						CharacterMetrics.rect(
							f.character.id,
							Rect2i(int(band[0]), int(band[1]), int(band[2]), int(band[3]))
						),
						f.x,
						f.y,
						f.facing
					)
				)
		return boxes
	if (
		f.character.id not in ["marcelo", "rafael", "adriano", "joao"]
		and not (f.character.id in ["gustavo", "gelton"] and CharacterArt.has_frame(f))
	):
		return null
	var move := f.current_move()
	if (
		(
			str(move.legacy.get("name", ""))
			not in ["punch", "kick", "crouchPunch", "sweep", "airPunch", "airKick", "uppercut"]
		)
		and not (f.character.id == "joao" and move.legacy.get("name", "") == "special")
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
	if (
		f.character.id == "joao"
		and f.state == FighterState.Id.ATTACK
		and f.current_move().legacy.get("name", "") == "special"
	):
		# H uses punch cels, so its charge follows their fist instead of the cast palm.
		var data := frame(f)
		if data.has("hit"):
			var hit: Array = data.hit
			socket = [int(hit[0] + hit[2] / 2), int(hit[1] + hit[3] / 2)]
		else:
			socket = [
				[32, -190],
				[19, -206],
				[104, -230],
				[156, -222],
				[185, -226],
				[93, -215],
				[57, -200],
				[35, -197]
			][int(FighterPose.select(f).index)]
	return Vector2i(
		(
			f.x
			+ CharacterMetrics.units(f.character.id, int(socket[0])) * f.facing * FighterModel.SCALE
		),
		f.y + CharacterMetrics.units(f.character.id, int(socket[1])) * FighterModel.SCALE
	)
