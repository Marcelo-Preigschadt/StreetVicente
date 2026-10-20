class_name TaisPoseV17
extends RefCounted
## Whole-body Savate. Release cels and boot sockets use the same fixed-step clock.


static func select(f: FighterModel) -> Dictionary:
	if f.state == FighterState.Id.WALK:
		var stride := int(f.character.legacy.get("stride", 170)) * FighterModel.SCALE
		var index := posmod(int(f.walk_distance * 8 / maxi(1, stride)), 8)
		if f.input.axis_x() == -f.facing:
			index = 7 - index
		return {"key": "walk", "index": index}
	if f.state != FighterState.Id.ATTACK:
		return {}
	var move := f.current_move()
	var name := str(move.legacy.name)
	var phase := move.phase(f.move_tick)
	if name == "crouchPunch":
		return {"key": "low", "index": FighterPose.move_key(
			f.move_tick, move, [0], [1], [2, 3, 0])}
	if name == "uppercut":
		if phase == "STARTUP":
			return {"key": "rise", "index": 0 if f.move_tick < move.startup else 1}
		if not f.move_motion_started:
			return {"key": "rise", "index": 2}
		if not f.grounded():
			return {"key": "rise", "index": (
				3 + mini(1, (f.move_tick - move.startup * 2) / 10)
				if phase == "ACTIVE" else 5 if f.vy < 0 else 6
			)}
		return {"key": "rise", "index": 7}
	if name == "super":
		if phase == "ACTIVE":
			var age := f.move_tick - move.startup * 2
			return {"key": "champion", "index": 3 + (age / 10) % 2 if age < 40 else 5}
		return {"key": "champion", "index": FighterPose.move_key(
			f.move_tick, move, [0, 1, 2], [3, 4], [5, 6, 7])}
	var sheet := "pulse" if name == "special" else "throw" if name == "throw" else ""
	if sheet.is_empty():
		return {}
	return {"key": sheet, "index": FighterPose.move_key(
		f.move_tick, move, [0, 1, 2], [3, 4], [5, 6, 7])}
