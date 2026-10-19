class_name MarcosPoseV16
extends RefCounted
## Judo exposures share the simulation clock with authored collision and sockets.


static func select(f: FighterModel) -> Dictionary:
	if f.state == FighterState.Id.WALK:
		var stride := int(f.character.legacy.get("stride", 108)) * FighterModel.SCALE
		var index := posmod(int(f.walk_distance * 8 / maxi(1, stride)), 8)
		if f.input.axis_x() == -f.facing:
			index = 7 - index
		return {"key": "walk", "index": index}
	if f.state != FighterState.Id.ATTACK:
		return {}
	var move := f.current_move()
	var name := str(move.legacy.name)
	var sheet := ""
	match name:
		"special":
			sheet = "session"
		"uppercut":
			sheet = "rise"  # Pilha Reversa is a grounded lift, never an airborne punch.
		"super":
			sheet = "panic"
		"throw":
			sheet = "throw"
		"guardCounter":
			sheet = "punch"
	if sheet.is_empty():
		return {}
	return {
		"key": sheet,
		"index": FighterPose.move_key(f.move_tick, move, [0, 1, 2], [3, 4], [4, 5, 6, 7])
	}
