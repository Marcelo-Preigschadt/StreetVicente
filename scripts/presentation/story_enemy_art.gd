class_name StoryEnemyArt
extends RefCounted
## The simulation supplies distance and attack phase; cels never drive combat.
static var revised: Dictionary = {}


static func load_data() -> void:
	if revised.is_empty():
		revised = JSON.parse_string(FileAccess.get_file_as_string("res://data/story/enemy-animation-v23.json")).enemies
		var registration: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/story/enemy-registration-v24.json")).enemies
		for kind in registration:
			for index in registration[kind].size():
				revised[kind].frames[index].merge(registration[kind][index], true)


static func atlas(kind: String) -> Dictionary:
	load_data()
	return revised.get(kind, LegacyRoster.catalog.story.enemies[kind].get("animation", {}))


static func sample(enemy: Dictionary, tick: int) -> Dictionary:
	var ani := atlas(str(enemy.kind))
	var f: FighterModel = enemy.fighter
	var seq: Dictionary = ani.get("sequences", {})
	var index := 0
	if f.health <= 0 or f.state in [FighterState.Id.KO, FighterState.Id.KNOCKDOWN]:
		var fall: Array = seq.get("fall", [13, 14, 15])
		var age := tick - int(enemy.dead_tick) if int(enemy.dead_tick) >= 0 else f.state_tick
		index = int(fall[clampi(age / 18, 0, fall.size() - 1)])
	elif f.state == FighterState.Id.WAKEUP:
		var rise: Array = seq.get("fall", [13, 14, 15]).duplicate()
		rise.reverse()
		rise.append(int(seq.get("hit", 12)))
		rise.append(int(seq.get("idle", 0)))
		index = int(rise[clampi(f.state_tick * rise.size() / (32 if f.quick_rise else 36), 0, rise.size() - 1)])
	elif f.state in [FighterState.Id.HITSTUN, FighterState.Id.DIZZY]:
		index = int(seq.get("hit", 12))
	elif f.state == FighterState.Id.ATTACK:
		var windup := int(seq.get("windup", 8))
		index = FighterPose.move_key(f.move_tick, f.current_move(),
			[windup, int(seq.get("acceleration", windup))],
			[int(seq.get("contacts", {}).get(str(enemy.attack_mode), seq.get("contact", 10)))],
			[int(seq.get("recovery", 11))])
	elif f.state == FighterState.Id.WALK or (seq.get("walkUnits", "distance") == "time" and (enemy.kind in ["snack", "book", "projector"] or LegacyRoster.catalog.story.enemies[enemy.kind].get("fly", 0) > 0)):
		var walk: Array = seq.get("walk", [0, 1, 2, 3, 4, 5, 6, 7])
		var tempo := maxi(1, int(seq.get("walkTempo", 150)))
		var step := int((tick + int(enemy.get("id", 0)) * 7) / tempo) if seq.get("walkUnits", "distance") == "time" else int(f.walk_distance * walk.size() / (tempo * FighterModel.SCALE))
		index = int(walk[posmod(step, walk.size())])
	index = clampi(index, 0, ani.frames.size() - 1)
	return {"index": index, "frame": ani.frames[index], "sheet": ani}
